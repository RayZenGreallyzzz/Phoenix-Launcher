package com.phoenixgames.launcher.runtime

import android.content.Context
import android.content.Intent
import com.phoenixgames.launcher.auth.PhoenixAuth

object GameRuntime {
    const val PPA_PACKAGE = "com.phoenixgames.ppa"
    private const val PPA_BETA_PACKAGE = "com.phoenixgames.ppa.beta"
    const val PPA_GAME_ID = "phoenix-pix-arena"
    const val EXTRA_GAME_TICKET = "phoenix_game_ticket"
    const val EXTRA_GAME_ID = "phoenix_game_id"

    private fun installed(context: Context, packageName: String): Boolean =
        try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Throwable) {
            false
        }

    fun isPpaInstalled(context: Context): Boolean =
        installed(context, PPA_BETA_PACKAGE) || installed(context, PPA_PACKAGE)

    suspend fun launchPpa(context: Context) {
        // Use new separately installable game if it exists; the restored
        // regular PPA remains available and retains its local saves.
        val packageName = if (installed(context, PPA_BETA_PACKAGE)) PPA_BETA_PACKAGE else PPA_PACKAGE
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: error("Phoenix Pix Arena не установлена")

        val ticket = PhoenixAuth.createGameTicket(context, PPA_GAME_ID)

        launchIntent
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            .putExtra(EXTRA_GAME_TICKET, ticket)
            .putExtra(EXTRA_GAME_ID, PPA_GAME_ID)

        context.startActivity(launchIntent)
    }
}
