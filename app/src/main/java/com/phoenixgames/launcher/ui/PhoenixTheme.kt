package com.phoenixgames.launcher.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val PhoenixBg = Color(0xFF080B0F)
val PhoenixPanel = Color(0xFF0E1319)
val PhoenixCard = Color(0xFF121820)
val PhoenixBorder = Color(0xFF26303B)
val PhoenixMuted = Color(0xFF8D99A6)
val PhoenixOrange = Color(0xFFFF6A23)
val PhoenixOrange2 = Color(0xFFFF9A3D)
val PhoenixGreen = Color(0xFF31D58B)
val PhoenixBlue = Color(0xFF38A5FF)

private val PhoenixScheme = darkColorScheme(
    primary = PhoenixOrange,
    secondary = PhoenixOrange2,
    background = PhoenixBg,
    surface = PhoenixPanel,
    surfaceVariant = PhoenixCard,
    onPrimary = Color.Black,
    onBackground = Color.White,
    onSurface = Color.White,
    outline = PhoenixBorder
)

@Composable
fun PhoenixTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = PhoenixScheme, content = content)
}
