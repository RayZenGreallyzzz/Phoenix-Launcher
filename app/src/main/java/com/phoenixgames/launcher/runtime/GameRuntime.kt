package com.phoenixgames.launcher.runtime

import android.content.Context
import android.content.Intent
import com.phoenixgames.launcher.auth.PhoenixAuth

object GameRuntime {
    const val PPA_PACKAGE = "com.phoenixgames.ppa"
    const val PPA_GAME_ID = "phoenix-pix-arena"
    const val EXTRA_GAME_TICKET = "phoenix_game_ticket"
    const val EXTRA_GAME_ID = "phoenix_game_id"

    fun isPpaInstalled(context: Context): Boolean {
        return try {
            context.packageManager.getPackageInfo(PPA_PACKAGE, 0)
            true
        } catch (_: Throwable) {
            false
        }
    }

    suspend fun launchPpa(context: Context) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(PPA_PACKAGE)
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
