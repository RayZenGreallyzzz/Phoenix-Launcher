package com.phoenixgames.launcher.auth

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

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

    suspend fun exchangeNativeTelegram(context: Context, idToken: String): PhoenixAuthResult {
        val payload = JSONObject().put("idToken", idToken)
        val json = request(
            path = "/api/launcher/auth/telegram/native",
            method = "POST",
            body = payload,
            bearer = sessionToken(context)
        )
        return parseLogin(json).also { saveToken(context, it.sessionToken) }
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

}
