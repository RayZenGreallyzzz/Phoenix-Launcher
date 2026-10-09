package com.phoenixgames.launcher.runtime

import android.content.Context
import android.content.Intent
import com.phoenixgames.launcher.auth.PhoenixAuth

object GameRuntime {
    const val PPA_PACKAGE = "com.phoenixgames.ppa"
    const val PPA_BETA_PACKAGE = "com.phoenixgames.ppa.beta"
    const val PPA_GAME_ID = "phoenix-pix-arena"
    const val EXTRA_GAME_TICKET = "phoenix_game_ticket"
    const val EXTRA_GAME_ID = "phoenix_game_id"

    private fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Throwable) {
            false
        }
    }

    fun isBetaInstalled(context: Context): Boolean = isPackageInstalled(context, PPA_BETA_PACKAGE)

    fun isPpaInstalled(context: Context): Boolean =
        isBetaInstalled(context) || isPackageInstalled(context, PPA_PACKAGE)

    suspend fun launchPpa(context: Context) {
        // Prefer the isolated test game; the original installed PPA is untouched.
        val packageName = if (isBetaInstalled(context)) PPA_BETA_PACKAGE else PPA_PACKAGE
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: error("Phoenix Pix Arena не установлена")

        val ticket = PhoenixAuth.createGameTicket(context, PPA_GAME_ID)

        launchIntent
            // A different Phoenix account must NEVER resume a previous Godot process.
            // New one-time ticket => new task/scene/session, not onNewIntent on an old hero.
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            .putExtra(EXTRA_GAME_TICKET, ticket)
            .putExtra(EXTRA_GAME_ID, PPA_GAME_ID)

        context.startActivity(launchIntent)
    }
}
