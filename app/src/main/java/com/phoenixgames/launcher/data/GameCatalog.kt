package com.phoenixgames.launcher.data

import com.phoenixgames.launcher.R
import com.phoenixgames.launcher.model.GameManifest

object GameCatalog {
    val ppa = GameManifest(
        id = "phoenix-pix-arena",
        title = "Phoenix Pix Arena",
        subtitle = "MMORPG • Онлайн мир",
        version = "Native Beta",
        sizeLabel = "≈ 40 МБ",
        description = "Исследуй огромный мир, сражайся, развивай персонажа, вступай в кланы и играй вместе с другими игроками. Один сервер для Telegram и Phoenix Launcher.",
        tags = listOf("Онлайн", "Кланы", "PvP", "Подземелья"),
        heroRes = R.drawable.ppa_hero,
        cardRes = R.drawable.ppa_hero,
        released = true
    )

    val games = listOf(
        ppa,
        GameManifest(
            id = "cyber-arena",
            title = "Cyber Arena",
            subtitle = "Проект 02",
            version = "—",
            sizeLabel = "В разработке",
            description = "Следующая игра экосистемы Phoenix.",
            tags = listOf("Скоро"),
            heroRes = R.drawable.cyber_card,
            cardRes = R.drawable.cyber_card,
            released = false
        ),
        GameManifest(
            id = "project-03",
            title = "Project 03",
            subtitle = "Зарезервировано",
            version = "—",
            sizeLabel = "В разработке",
            description = "Слот для следующей игры Phoenix.",
            tags = listOf("Скоро"),
            heroRes = R.drawable.project03_card,
            cardRes = R.drawable.project03_card,
            released = false
        )
    )
}
