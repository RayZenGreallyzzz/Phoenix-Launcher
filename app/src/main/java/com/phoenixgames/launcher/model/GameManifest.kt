package com.phoenixgames.launcher.model

data class GameManifest(
    val id: String,
    val title: String,
    val subtitle: String,
    val version: String,
    val sizeLabel: String,
    val description: String,
    val tags: List<String>,
    val heroRes: Int,
    val cardRes: Int,
    val released: Boolean
)
