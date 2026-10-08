package com.phoenixgames.launcher.runtime

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

/**
 * Official beta channel: signed native PPA APK is published as a public GitHub
 * release asset by the same workflow that builds/verifies it.
 *
 * No executable is fetched from a chat attachment or arbitrary URL.
 * Android validates the package signature again when it installs the update.
 */
object PpaUpdater {
    private const val REPO = "RayZenGreallyzzz/Phoenix-Launcher"
    private const val RELEASE_TAG = "ppa-native-stable"
    private const val RELEASE_ASSET = "PhoenixPixArena-native.apk"
    private const val RELEASE_API =
        "https://api.github.com/repos/$REPO/releases/tags/$RELEASE_TAG"
    private const val RELEASE_DOWNLOAD =
        "https://github.com/$REPO/releases/download/$RELEASE_TAG/$RELEASE_ASSET"

    private const val PREFS = "ppa_native_update_cache"
    private const val CACHE_CODE = "version_code"
    private const val CACHE_SHA = "sha256"
    private const val CACHE_FILE = "ppa-native.apk"
    private const val MIN_APK_BYTES = 2_000_000L
    private const val MAX_APK_BYTES = 250_000_000L

    data class Release(
        val versionCode: Long,
        val versionName: String,
        val sha256: String,
        val bytes: Long,
        val downloadUrl: String
    )

    @Suppress("DEPRECATION")
    fun installedVersionCode(context: Context): Long {
        val info = try {
            context.packageManager.getPackageInfo(GameRuntime.PPA_PACKAGE, 0)
        } catch (_: PackageManager.NameNotFoundException) {
            return 0L
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else info.versionCode.toLong()
    }

    suspend fun latestRelease(): Release = withContext(Dispatchers.IO) {
        val connection = (URL(RELEASE_API).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 20_000
            setRequestProperty("Accept", "application/vnd.github+json")
            setRequestProperty("User-Agent", "Phoenix-Launcher-Android")
            useCaches = false
        }
        try {
            val status = connection.responseCode
            if (status != 200) {
                error(if (status == 404) {
                    "Первая версия для обновления ещё не опубликована"
                } else {
                    "Не удалось проверить версию игры (HTTP $status)"
                })
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val release = JSONObject(body)
            require(release.optString("tag_name") == RELEASE_TAG) { "Неверный канал обновления PPA" }
            val metadata = JSONObject(release.getString("body"))
            require(metadata.getString("gameId") == GameRuntime.PPA_GAME_ID)
            require(metadata.getString("packageName") == GameRuntime.PPA_PACKAGE)
            val code = metadata.getLong("versionCode")
            val name = metadata.getString("versionName")
            val digest = metadata.getString("sha256").lowercase(Locale.ROOT)
            val length = metadata.getLong("sizeBytes")
            require(code > 1L && digest.matches(Regex("[0-9a-f]{64}")))
            require(length in MIN_APK_BYTES..MAX_APK_BYTES)
            val assets = release.getJSONArray("assets")
            var link: String? = null
            for (index in 0 until assets.length()) {
                val asset = assets.getJSONObject(index)
                if (asset.optString("name") == RELEASE_ASSET && asset.getLong("size") == length) {
                    link = asset.getString("browser_download_url")
                    break
                }
            }
            require(link == RELEASE_DOWNLOAD) { "Адрес APK не совпадает с официальным релизом" }
            Release(code, name, digest, length, link)
        } finally {
            connection.disconnect()
        }
    }

    fun hasVerifiedCache(context: Context, release: Release): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val file = apkFile(context)
        return file.isFile && file.length() == release.bytes &&
            prefs.getLong(CACHE_CODE, 0L) == release.versionCode &&
            prefs.getString(CACHE_SHA, "") == release.sha256
    }

    suspend fun download(
        context: Context,
        release: Release,
        onProgress: (Long, Long) -> Unit
    ): File = withContext(Dispatchers.IO) {
        if (hasVerifiedCache(context, release)) {
            withContext(Dispatchers.Main) { onProgress(release.bytes, release.bytes) }
            return@withContext apkFile(context)
        }

        val finalFile = apkFile(context)
        val tempFile = File(finalFile.parentFile, "ppa-native-download.apk")
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        finalFile.delete()
        tempFile.delete()
        val connection = (URL(release.downloadUrl).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20_000
            readTimeout = 45_000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Phoenix-Launcher-Android")
        }

        try {
            require(connection.responseCode == 200) {
                "Сервер не отдал APK: HTTP ${connection.responseCode}"
            }
            val declaredLength = connection.contentLengthLong
            require(declaredLength == -1L || declaredLength == release.bytes) {
                "Размер загружаемого APK отличается от релиза"
            }
            val digest = MessageDigest.getInstance("SHA-256")
            var received = 0L
            var lastPercent = -1
            connection.inputStream.use { input ->
                tempFile.outputStream().buffered().use { output ->
                    val buffer = ByteArray(128 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        received += count
                        require(received <= release.bytes && received <= MAX_APK_BYTES) {
                            "Сервер отправил больше данных, чем ожидалось"
                        }
                        output.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                        val percent = (received * 100L / release.bytes).toInt()
                        if (percent != lastPercent) {
                            lastPercent = percent
                            val progressBytes = received
                            withContext(Dispatchers.Main) {
                                onProgress(progressBytes, release.bytes)
                            }
                        }
                    }
                }
            }
            require(received == release.bytes) { "Загрузка APK прервана" }
            val actual = digest.digest().joinToString("") { "%02x".format(it) }
            require(actual == release.sha256) { "Контрольная сумма APK не совпадает" }

            // Refuse another package/version even if the server metadata changes.
            @Suppress("DEPRECATION")
            val packageInfo = context.packageManager.getPackageArchiveInfo(
                tempFile.absolutePath, 0
            ) ?: error("Android не распознал загруженный APK")
            val downloadedCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                packageInfo.longVersionCode else packageInfo.versionCode.toLong()
            require(packageInfo.packageName == GameRuntime.PPA_PACKAGE) { "Это не APK Phoenix Pix Arena" }
            require(downloadedCode == release.versionCode) { "Версия APK не совпадает с релизом" }

            require(tempFile.renameTo(finalFile)) { "Не удалось сохранить проверенный APK" }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putLong(CACHE_CODE, release.versionCode)
                .putString(CACHE_SHA, release.sha256)
                .apply()
            finalFile
        } catch (ex: Exception) {
            tempFile.delete()
            finalFile.delete()
            throw ex
        } finally {
            connection.disconnect()
        }
    }

    /**
     * Returns false when the user must first grant Android's "install unknown
     * apps" permission for this launcher. The APK stays in private cache.
     */
    fun openInstaller(context: Context, release: Release): Boolean {
        require(hasVerifiedCache(context, release)) { "Проверенная APK отсутствует в кэше" }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !context.packageManager.canRequestPackageInstalls()
        ) {
            val permissionIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(permissionIntent)
            return false
        }
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.updates",
            apkFile(context)
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
        return true
    }

    fun clearInstalledUpdate(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val cachedCode = prefs.getLong(CACHE_CODE, 0L)
        if (cachedCode > 0L && installedVersionCode(context) >= cachedCode) {
            apkFile(context).delete()
            File(apkFile(context).parentFile, "ppa-native.part").delete()
            prefs.edit().clear().apply()
        }
    }

    private fun apkFile(context: Context): File {
        val dir = File(context.cacheDir, "ppa-updates")
        if (!dir.isDirectory) require(dir.mkdirs()) { "Не удалось подготовить кэш обновлений" }
        return File(dir, CACHE_FILE)
    }
}
