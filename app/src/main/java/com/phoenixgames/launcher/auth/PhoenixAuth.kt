package com.phoenixgames.launcher.auth

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.security.SecureRandom

data class PhoenixAccount(
    val accountId: String,
    val telegramId: String?,
    val email: String?,
    val emailVerified: Boolean,
    val nickname: String,
    val ppaNickname: String?,
    val classKey: String,
    val telegramUsername: String?,
    val firstName: String,
    val lastName: String,
    val createdAt: Long
) {
    val avatarLetter: String
        get() = nickname.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "P"
}

data class PhoenixAuthResult(
    val account: PhoenixAccount,
    val sessionToken: String
)

object PhoenixAuth {
    const val API_BASE = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"

    private const val PREFS = "phoenix_launcher_auth"
    private const val KEY_TOKEN = "session_token"
    private const val KEY_TG_STATE = "telegram_state"
    private const val KEY_TG_VERIFIER = "telegram_verifier"

    private val random = SecureRandom()

    suspend fun restore(context: Context): PhoenixAuthResult? {
        val token = sessionToken(context) ?: return null
        return try {
            val json = request("/api/launcher/me", "GET", null, token)
            PhoenixAuthResult(parseAccount(json.getJSONObject("account")), token)
        } catch (_: Throwable) {
            clearSession(context)
            null
        }
    }

    suspend fun startTelegram(context: Context) {
        val verifier = randomUrlToken(48)
        val state = randomUrlToken(48)
        val challenge = base64Url(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8)))

        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TG_STATE, state)
            .putString(KEY_TG_VERIFIER, verifier)
            .apply()

        val payload = JSONObject()
            .put("state", state)
            .put("codeChallenge", challenge)

        val json = request(
            path = "/api/launcher/auth/telegram/start",
            method = "POST",
            body = payload,
            bearer = sessionToken(context)
        )
        val authUrl = json.optString("authUrl")
        if (authUrl.isBlank()) error("Сервер не вернул ссылку Telegram")

        withContext(Dispatchers.Main) {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(authUrl))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    suspend fun exchangeTelegram(context: Context, uri: Uri): PhoenixAuthResult {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val expectedState = prefs.getString(KEY_TG_STATE, null).orEmpty()
        val verifier = prefs.getString(KEY_TG_VERIFIER, null).orEmpty()
        val state = uri.getQueryParameter("state").orEmpty()
        val code = uri.getQueryParameter("code").orEmpty()

        if (expectedState.isBlank() || verifier.isBlank() || state != expectedState || code.isBlank()) {
            error("Некорректный ответ Telegram. Повтори вход.")
        }

        val payload = JSONObject()
            .put("state", state)
            .put("code", code)
            .put("codeVerifier", verifier)
        val json = request("/api/launcher/auth/exchange", "POST", payload, null)
        val result = parseLogin(json)

        prefs.edit()
            .remove(KEY_TG_STATE)
            .remove(KEY_TG_VERIFIER)
            .putString(KEY_TOKEN, result.sessionToken)
            .apply()

        return result
    }

    suspend fun emailLogin(context: Context, email: String, password: String): PhoenixAuthResult {
        val payload = JSONObject().put("email", email.trim()).put("password", password)
        val json = request("/api/launcher/email/login", "POST", payload, null)
        return parseLogin(json).also { saveToken(context, it.sessionToken) }
    }

    suspend fun emailRegister(context: Context, email: String, password: String): PhoenixAuthResult {
        val payload = JSONObject().put("email", email.trim()).put("password", password)
        val json = request("/api/launcher/email/register", "POST", payload, null)
        return parseLogin(json).also { saveToken(context, it.sessionToken) }
    }

    suspend fun bindEmail(context: Context, email: String, password: String): PhoenixAccount {
        val token = sessionToken(context) ?: error("Сессия Phoenix не найдена")
        val payload = JSONObject().put("email", email.trim()).put("password", password)
        val json = request("/api/launcher/email/bind", "POST", payload, token)
        return parseAccount(json.getJSONObject("account"))
    }

    suspend fun refresh(context: Context): PhoenixAccount {
        val token = sessionToken(context) ?: error("Сессия Phoenix не найдена")
        val json = request("/api/launcher/me", "GET", null, token)
        return parseAccount(json.getJSONObject("account"))
    }

    suspend fun logout(context: Context) {
        val token = sessionToken(context)
        if (token != null) {
            try { request("/api/launcher/logout", "POST", JSONObject(), token) } catch (_: Throwable) {}
        }
        clearSession(context)
    }

    fun sessionToken(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TOKEN, null)
            ?.takeIf { it.isNotBlank() }

    fun clearSession(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun saveToken(context: Context, token: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TOKEN, token)
            .apply()
    }

    private fun parseLogin(json: JSONObject): PhoenixAuthResult {
        val session = json.getJSONObject("session")
        val token = session.getString("token")
        return PhoenixAuthResult(parseAccount(json.getJSONObject("account")), token)
    }

    private fun parseAccount(j: JSONObject): PhoenixAccount {
        fun nullableString(key: String): String? =
            if (j.isNull(key)) null else j.optString(key).takeIf { it.isNotBlank() }

        return PhoenixAccount(
            accountId = j.optString("accountId"),
            telegramId = nullableString("telegramId"),
            email = nullableString("email"),
            emailVerified = j.optBoolean("emailVerified", false),
            nickname = j.optString("nickname").ifBlank { "Phoenix" },
            ppaNickname = nullableString("ppaNickname"),
            classKey = j.optString("classKey"),
            telegramUsername = nullableString("telegramUsername"),
            firstName = j.optString("firstName"),
            lastName = j.optString("lastName"),
            createdAt = j.optLong("createdAt", 0L)
        )
    }

    private suspend fun request(
        path: String,
        method: String,
        body: JSONObject?,
        bearer: String?
    ): JSONObject = withContext(Dispatchers.IO) {
        val connection = (URL(API_BASE + path).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 20_000
            useCaches = false
            setRequestProperty("Accept", "application/json")
            if (!bearer.isNullOrBlank()) setRequestProperty("Authorization", "Bearer $bearer")
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
        }

        try {
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val json = try { JSONObject(raw) } catch (_: Throwable) { JSONObject() }

            if (status !in 200..299 || !json.optBoolean("ok", false)) {
                val message = json.optString("message").ifBlank { "Phoenix server HTTP $status" }
                throw IllegalStateException(message)
            }
            json
        } finally {
            connection.disconnect()
        }
    }

    private fun randomUrlToken(bytes: Int): String {
        val data = ByteArray(bytes)
        random.nextBytes(data)
        return base64Url(data)
    }

    private fun base64Url(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
}
