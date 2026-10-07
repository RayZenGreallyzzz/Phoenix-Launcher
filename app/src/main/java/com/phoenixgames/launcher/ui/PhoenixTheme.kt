package com.phoenixgames.launcher.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Phoenix Launcher v0.1 visual lock.
// These values are direct sRGB conversions of the approved prototype tokens.
// Do not "approximate" them in native UI without an explicit visual redesign.
val PhoenixBg = Color(0xFF07080A)
val PhoenixText = Color(0xFFEDEFF0)
val PhoenixPanel = Color(0xFF101214)
val PhoenixCard = Color(0xFF101214)
val PhoenixSecondary = Color(0xFF171A1D)
val PhoenixAccent = Color(0xFF1D2227)
val PhoenixBorder = Color(0xFF292B2F)
val PhoenixMuted = Color(0xFF7E848B)
val PhoenixOrange = Color(0xFFFE6D1C)
val PhoenixOrange2 = PhoenixOrange
val PhoenixGreen = Color(0xFF53CDAB)
val PhoenixDanger = Color(0xFFF14D4C)
val PhoenixArtText = Color(0xFFFAF8F6)
val PhoenixScrim = Color(0xFF020304)

// Kept for places where a cool accent is useful (progress/network state).
// It is secondary to the locked orange Phoenix brand accent.
val PhoenixBlue = Color(0xFF38A5FF)

private val PhoenixScheme = darkColorScheme(
    primary = PhoenixOrange,
    onPrimary = PhoenixArtText,
    secondary = PhoenixSecondary,
    onSecondary = PhoenixText,
    background = PhoenixBg,
    onBackground = PhoenixText,
    surface = PhoenixPanel,
    onSurface = PhoenixText,
    surfaceVariant = PhoenixCard,
    onSurfaceVariant = PhoenixMuted,
    outline = PhoenixBorder,
    error = PhoenixDanger
)

@Composable
fun PhoenixTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = PhoenixScheme,
        content = content
    )
}
