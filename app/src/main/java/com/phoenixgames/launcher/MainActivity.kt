package com.phoenixgames.launcher

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.phoenixgames.launcher.data.GameCatalog
import com.phoenixgames.launcher.model.GameManifest
import com.phoenixgames.launcher.ui.*
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { PhoenixTheme { PhoenixLauncherApp() } }
    }
}

private enum class Stage { Splash, Login, Launcher }
private enum class Tab(val title: String, val glyph: String) {
    Home("Главная", "⌂"),
    Library("Библиотека", "▦"),
    News("Новости", "▤"),
    Profile("Профиль", "●"),
    Settings("Настройки", "⚙")
}

@Composable
private fun PhoenixLauncherApp() {
    var stage by remember { mutableStateOf(Stage.Splash) }
    var tab by remember { mutableStateOf(Tab.Home) }
    var selectedGame by remember { mutableStateOf<GameManifest?>(null) }
    var downloadOpen by remember { mutableStateOf(false) }
    var runtimeOpen by remember { mutableStateOf(false) }
    var installed by remember { mutableStateOf(false) }
    var downloading by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(Unit) {
        delay(1200)
        stage = Stage.Login
    }
    LaunchedEffect(downloading) {
        if (!downloading) return@LaunchedEffect
        while (progress < 1f) {
            delay(180)
            progress = (progress + .06f).coerceAtMost(1f)
        }
        downloading = false
        installed = true
    }

    Surface(Modifier.fillMaxSize(), color = PhoenixBg) {
        AnimatedContent(
            targetState = stage,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "boot"
        ) { current ->
            when (current) {
                Stage.Splash -> SplashScreen()
                Stage.Login -> LoginScreen { stage = Stage.Launcher }
                Stage.Launcher -> when {
                    runtimeOpen -> RuntimePlaceholder { runtimeOpen = false }
                    downloadOpen -> DownloadScreen(
                        progress = progress,
                        downloading = downloading,
                        installed = installed,
                        onBack = { downloadOpen = false },
                        onStart = {
                            if (!installed) {
                                progress = 0f
                                downloading = true
                            }
                        },
                        onPlay = {
                            downloadOpen = false
                            runtimeOpen = true
                        }
                    )
                    selectedGame != null -> GameDetails(
                        game = selectedGame!!,
                        installed = installed && selectedGame!!.id == GameCatalog.ppa.id,
                        onBack = { selectedGame = null },
                        onPrimary = {
                            if (selectedGame!!.id == GameCatalog.ppa.id) {
                                if (installed) runtimeOpen = true else downloadOpen = true
                            }
                        }
                    )
                    else -> LauncherShell(
                        tab = tab,
                        onTab = { tab = it },
                        installed = installed,
                        onOpenGame = { selectedGame = it },
                        onInstall = { downloadOpen = true }
                    )
                }
            }
        }
    }
}

@Composable
private fun SplashScreen() {
    Box(Modifier.fillMaxSize().background(PhoenixBg)) {
        Image(
            painter = painterResource(R.drawable.phoenix_splash),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(Color.Transparent, Color.Black.copy(alpha = .12f), Color.Black.copy(alpha = .78f))
                )
            )
        )
        Column(
            Modifier.fillMaxSize().padding(28.dp, 52.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Bottom
        ) {
            Text("PHOENIX", fontSize = 34.sp, fontWeight = FontWeight.Black, letterSpacing = 5.sp)
            Text("LAUNCHER", color = PhoenixOrange2, fontSize = 12.sp, letterSpacing = 4.sp)
            Spacer(Modifier.height(28.dp))
            LinearProgressIndicator(
                modifier = Modifier.width(120.dp).height(4.dp).clip(CircleShape),
                color = PhoenixOrange,
                trackColor = Color.White.copy(alpha = .14f)
            )
            Spacer(Modifier.height(28.dp))
            Text("ИГРЫ. МИРЫ. ОДИН АККАУНТ.", color = Color.White.copy(alpha = .78f), fontSize = 11.sp)
        }
    }
}

@Composable
private fun LoginScreen(onContinue: () -> Unit) {
    Box(Modifier.fillMaxSize().background(PhoenixBg)) {
        Image(
            painter = painterResource(R.drawable.phoenix_splash),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .58f)))
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Image(
                painter = painterResource(R.drawable.phoenix_emblem),
                contentDescription = "Phoenix",
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(132.dp).clip(RoundedCornerShape(32.dp))
            )
            Spacer(Modifier.height(14.dp))
            Text("PHOENIX", fontSize = 28.sp, fontWeight = FontWeight.Black, letterSpacing = 4.sp)
            Text("LAUNCHER", color = PhoenixOrange2, fontSize = 11.sp, letterSpacing = 3.sp)
            Spacer(Modifier.height(32.dp))
            Text("Вход в аккаунт", fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text("Один аккаунт для всех игр Phoenix", color = PhoenixMuted, fontSize = 13.sp)
            Spacer(Modifier.height(22.dp))
            PrimaryButton("✈  Войти через Telegram", onContinue)
            Spacer(Modifier.height(10.dp))
            SecondaryButton("Войти по Email", onContinue)
            Spacer(Modifier.height(12.dp))
            TextButton(onClick = onContinue) { Text("Создать аккаунт", color = PhoenixBlue) }
        }
    }
}

@Composable
private fun LauncherShell(
    tab: Tab,
    onTab: (Tab) -> Unit,
    installed: Boolean,
    onOpenGame: (GameManifest) -> Unit,
    onInstall: () -> Unit
) {
    Scaffold(
        containerColor = PhoenixBg,
        topBar = { PhoenixTopBar() },
        bottomBar = { BottomNav(tab, onTab) }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (tab) {
                Tab.Home -> HomeScreen(installed, onOpenGame, onInstall)
                Tab.Library -> LibraryScreen(installed, onOpenGame, onInstall)
                Tab.News -> NewsScreen()
                Tab.Profile -> ProfileScreen()
                Tab.Settings -> SettingsScreen()
            }
        }
    }
}

@Composable
private fun PhoenixTopBar() {
    Row(
        Modifier.fillMaxWidth().background(PhoenixPanel).padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.size(38.dp).clip(RoundedCornerShape(12.dp))
                .background(Brush.linearGradient(listOf(PhoenixOrange, Color(0xFF671700)))),
            contentAlignment = Alignment.Center
        ) { Text("🔥", fontSize = 19.sp) }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text("PHOENIX", fontSize = 15.sp, fontWeight = FontWeight.Black, letterSpacing = 3.sp)
            Text("Game Launcher", color = PhoenixMuted, fontSize = 10.sp)
        }
        Text("●", color = PhoenixOrange, fontSize = 8.sp)
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier.size(38.dp).clip(CircleShape).background(PhoenixCard)
                .border(1.dp, PhoenixBorder, CircleShape),
            contentAlignment = Alignment.Center
        ) { Text("R", fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun HomeScreen(
    installed: Boolean,
    onOpenGame: (GameManifest) -> Unit,
    onInstall: () -> Unit
) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 24.dp)) {
        item {
            HeroCard(
                GameCatalog.ppa,
                installed,
                onPrimary = { if (installed) onOpenGame(GameCatalog.ppa) else onInstall() },
                onMore = { onOpenGame(GameCatalog.ppa) }
            )
        }
        item {
            SectionTitle("Все игры", "1 доступна · 2 в разработке")
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(GameCatalog.games) { game ->
                    GameCard(game, installed && game.id == GameCatalog.ppa.id) { onOpenGame(game) }
                }
            }
        }
        item {
            SectionTitle("Последние новости", "Все новости")
            NewsCard(
                "Phoenix Launcher — первая сборка",
                "Запускаем единый клиент для PPA и будущих игр Phoenix.",
                "Сегодня"
            )
        }
    }
}

@Composable
private fun HeroCard(
    game: GameManifest,
    installed: Boolean,
    onPrimary: () -> Unit,
    onMore: () -> Unit
) {
    Box(
        Modifier.padding(14.dp).fillMaxWidth().height(330.dp)
            .clip(RoundedCornerShape(22.dp))
            .border(1.dp, PhoenixBorder, RoundedCornerShape(22.dp))
    ) {
        Image(
            painter = painterResource(game.heroRes),
            contentDescription = game.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(Color.Transparent, Color.Black.copy(alpha = .18f), Color.Black.copy(alpha = .9f))
                )
            )
        )
        Column(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(18.dp)) {
            Text("ГЛАВНАЯ ИГРА", color = PhoenixOrange2, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(5.dp))
            Text(game.title, fontSize = 29.sp, fontWeight = FontWeight.Black, lineHeight = 31.sp)
            Text(game.subtitle, color = Color.White.copy(alpha = .78f), fontSize = 12.sp)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                game.tags.take(4).forEach { Tag(it) }
            }
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onPrimary,
                    modifier = Modifier.weight(1f).height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = PhoenixOrange, contentColor = Color.Black),
                    shape = RoundedCornerShape(13.dp)
                ) { Text(if (installed) "Играть" else "Скачать", fontWeight = FontWeight.Black) }
                OutlinedButton(
                    onClick = onMore,
                    modifier = Modifier.width(58.dp).height(48.dp),
                    shape = RoundedCornerShape(13.dp),
                    border = BorderStroke(1.dp, PhoenixBorder)
                ) { Text("•••") }
            }
        }
    }
}

@Composable
private fun GameCard(game: GameManifest, installed: Boolean, onClick: () -> Unit) {
    Column(
        Modifier.width(160.dp).clip(RoundedCornerShape(17.dp)).background(PhoenixCard)
            .border(1.dp, PhoenixBorder, RoundedCornerShape(17.dp))
            .clickable(onClick = onClick).padding(10.dp)
    ) {
        Image(
            painter = painterResource(game.cardRes),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxWidth().height(94.dp).clip(RoundedCornerShape(12.dp))
        )
        Spacer(Modifier.height(9.dp))
        Text(game.title, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.height(4.dp))
        Text(
            if (installed) "● Установлено" else if (game.released) game.sizeLabel else "◌ Скоро",
            color = if (installed) PhoenixGreen else PhoenixMuted,
            fontSize = 11.sp
        )
    }
}

@Composable
private fun LibraryScreen(
    installed: Boolean,
    onOpenGame: (GameManifest) -> Unit,
    onInstall: () -> Unit
) {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Библиотека", fontSize = 26.sp, fontWeight = FontWeight.Black)
            Text("Все игры Phoenix в одном месте", color = PhoenixMuted, fontSize = 13.sp)
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tag("Все игры 3")
                Tag("Установленные 1")
                Tag("Скоро 2")
            }
        }
        items(GameCatalog.games) { game ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(PhoenixCard)
                    .border(1.dp, PhoenixBorder, RoundedCornerShape(16.dp))
                    .clickable { onOpenGame(game) }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Image(
                    painter = painterResource(game.cardRes),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(62.dp).clip(RoundedCornerShape(13.dp))
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(game.title, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Text(
                        if (installed && game.id == GameCatalog.ppa.id) "● Установлено" else game.sizeLabel,
                        color = if (installed && game.id == GameCatalog.ppa.id) PhoenixGreen else PhoenixMuted,
                        fontSize = 11.sp
                    )
                }
                Button(
                    onClick = {
                        if (game.id == GameCatalog.ppa.id && !installed) onInstall() else onOpenGame(game)
                    },
                    enabled = game.released,
                    colors = ButtonDefaults.buttonColors(containerColor = PhoenixOrange, contentColor = Color.Black),
                    shape = RoundedCornerShape(11.dp)
                ) {
                    Text(
                        if (installed && game.id == GameCatalog.ppa.id) "Играть" else if (game.released) "Скачать" else "Скоро",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun NewsScreen() {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { Text("Новости", fontSize = 26.sp, fontWeight = FontWeight.Black) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tag("Все")
                Tag("PPA")
                Tag("Обновления")
                Tag("События")
            }
        }
        item { NewsCard("Сезон 1: Пробуждение", "Новые локации, события и развитие мира Phoenix Pix Arena.", "Скоро") }
        item { NewsCard("Phoenix Launcher 0.1", "Первая нативная версия лаунчера.", "Сегодня") }
        item { NewsCard("Project 02", "Вторая игра уже зарезервирована в библиотеке Phoenix.", "В разработке") }
    }
}

@Composable
private fun NewsCard(title: String, text: String, date: String) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(PhoenixCard)
            .border(1.dp, PhoenixBorder, RoundedCornerShape(16.dp)).padding(15.dp)
    ) {
        Text(title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Spacer(Modifier.height(6.dp))
        Text(text, color = PhoenixMuted, fontSize = 13.sp, lineHeight = 18.sp)
        Spacer(Modifier.height(10.dp))
        Text(date, color = PhoenixOrange2, fontSize = 11.sp)
    }
}

@Composable
private fun ProfileScreen() {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp)) {
        item {
            Text("Профиль", fontSize = 26.sp, fontWeight = FontWeight.Black)
            Spacer(Modifier.height(18.dp))
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(PhoenixCard)
                    .border(1.dp, PhoenixBorder, RoundedCornerShape(20.dp)).padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    Modifier.size(76.dp).clip(CircleShape)
                        .background(Brush.linearGradient(listOf(PhoenixOrange, Color(0xFF341009)))),
                    contentAlignment = Alignment.Center
                ) { Text("R", fontSize = 28.sp, fontWeight = FontWeight.Black) }
                Spacer(Modifier.height(10.dp))
                Text("RayZenGX", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Phoenix Account", color = PhoenixMuted, fontSize = 12.sp)
                Spacer(Modifier.height(16.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Tag("Telegram привязан")
                    Tag("PPA")
                }
            }
            Spacer(Modifier.height(16.dp))
            SettingCard {
                InfoRow("Аккаунт", "Phoenix ID")
                InfoRow("Telegram", "Привязан")
                InfoRow("Игры", "1 активная")
            }
        }
    }
}

@Composable
private fun SettingsScreen() {
    var autoUpdate by remember { mutableStateOf(true) }
    var wifiOnly by remember { mutableStateOf(false) }
    var notifications by remember { mutableStateOf(true) }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item { Text("Настройки", fontSize = 26.sp, fontWeight = FontWeight.Black) }
        item {
            SettingCard {
                ToggleRow("Автообновление игр", "Обновлять игровые модули автоматически", autoUpdate) { autoUpdate = it }
                ToggleRow("Только Wi‑Fi", "Не тратить мобильный трафик", wifiOnly) { wifiOnly = it }
                ToggleRow("Уведомления", "Новости и готовность обновлений", notifications) { notifications = it }
            }
        }
        item {
            SettingCard {
                InfoRow("Тема", "Тёмная")
                InfoRow("Качество артов", "Высокое")
                InfoRow("Launcher", "0.1.0")
            }
        }
    }
}

@Composable
private fun GameDetails(
    game: GameManifest,
    installed: Boolean,
    onBack: () -> Unit,
    onPrimary: () -> Unit
) {
    LazyColumn(Modifier.fillMaxSize().background(PhoenixBg)) {
        item {
            Box(Modifier.fillMaxWidth().height(290.dp)) {
                Image(
                    painter = painterResource(game.heroRes),
                    contentDescription = game.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
                Box(
                    Modifier.fillMaxSize().background(
                        Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = .88f)))
                    )
                )
                TextButton(
                    onClick = onBack,
                    modifier = Modifier.align(Alignment.TopStart).padding(12.dp)
                ) { Text("←", color = Color.White, fontSize = 24.sp) }
                Column(Modifier.align(Alignment.BottomStart).padding(18.dp)) {
                    Text(game.title, fontSize = 28.sp, fontWeight = FontWeight.Black)
                    Text(game.subtitle, color = PhoenixMuted, fontSize = 12.sp)
                }
            }
        }
        item {
            Column(Modifier.padding(18.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    game.tags.forEach { Tag(it) }
                }
                Spacer(Modifier.height(16.dp))
                PrimaryButton(
                    if (!game.released) "Скоро" else if (installed) "Играть" else "Скачать " + game.sizeLabel,
                    onPrimary,
                    enabled = game.released
                )
                Spacer(Modifier.height(20.dp))
                Text("О игре", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(game.description, color = Color.White.copy(alpha = .76f), fontSize = 14.sp, lineHeight = 20.sp)
                Spacer(Modifier.height(18.dp))
                InfoRow("Версия", game.version)
                InfoRow("Размер", game.sizeLabel)
                InfoRow("Платформа", "Android")
                InfoRow("Аккаунт", "Phoenix / Telegram")
            }
        }
    }
}

@Composable
private fun DownloadScreen(
    progress: Float,
    downloading: Boolean,
    installed: Boolean,
    onBack: () -> Unit,
    onStart: () -> Unit,
    onPlay: () -> Unit
) {
    Column(Modifier.fillMaxSize().background(PhoenixBg).padding(horizontal = 18.dp, vertical = 36.dp)) {
        TextButton(onClick = onBack, contentPadding = PaddingValues(0.dp)) { Text("←  Назад", color = Color.White) }
        Spacer(Modifier.height(20.dp))
        Text("Загрузка игры", fontSize = 28.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(22.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                painter = painterResource(R.drawable.ppa_card),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(72.dp).clip(RoundedCornerShape(16.dp))
            )
            Spacer(Modifier.width(14.dp))
            Column {
                Text("Phoenix Pix Arena", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Text("Версия 0.1.0", color = PhoenixMuted, fontSize = 12.sp)
                Text("Размер: ≈ 380 МБ", color = PhoenixMuted, fontSize = 12.sp)
            }
        }
        Spacer(Modifier.height(28.dp))
        LinearProgressIndicator(
            progress = { if (installed) 1f else progress },
            modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
            color = PhoenixBlue,
            trackColor = PhoenixBorder
        )
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(
                when {
                    installed -> "Готово к запуску"
                    downloading -> "Загрузка… " + (progress * 380).toInt() + " МБ из 380 МБ"
                    else -> "Готово к загрузке"
                },
                color = PhoenixMuted,
                fontSize = 12.sp
            )
            Text((if (installed) 100 else (progress * 100).toInt()).toString() + "%", fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(22.dp))
        PrimaryButton(
            when {
                installed -> "Играть"
                downloading -> "Загрузка…"
                else -> "Начать загрузку"
            },
            if (installed) onPlay else onStart,
            enabled = !downloading
        )
        Spacer(Modifier.height(28.dp))
        DownloadStep("Загрузка файлов игры", progress > .25f || installed)
        DownloadStep("Проверка файлов", progress > .72f || installed)
        DownloadStep("Установка модуля", progress >= 1f || installed)
        DownloadStep("Готово к запуску", installed)
        Spacer(Modifier.weight(1f))
        Text(
            "В v0.1 прогресс демонстрационный. Следующий этап — реальный manifest/update API.",
            color = PhoenixMuted,
            fontSize = 11.sp
        )
    }
}

@Composable
private fun RuntimePlaceholder(onExit: () -> Unit) {
    Box(Modifier.fillMaxSize().background(PhoenixBg)) {
        Image(
            painter = painterResource(R.drawable.ppa_hero),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .62f)))
        Column(
            Modifier.align(Alignment.Center).padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("PHOENIX PIX ARENA", fontSize = 25.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center)
            Spacer(Modifier.height(10.dp))
            Text(
                "Слот игрового клиента готов. Сюда подключается нативный PPA/Godot-модуль к текущему серверу.",
                color = Color.White.copy(alpha = .78f),
                fontSize = 13.sp,
                lineHeight = 19.sp,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(22.dp))
            SecondaryButton("Вернуться в Launcher", onExit)
        }
    }
}

@Composable
private fun DownloadStep(text: String, complete: Boolean) {
    Row(Modifier.fillMaxWidth().padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(28.dp).clip(CircleShape)
                .background(if (complete) PhoenixGreen.copy(alpha = .18f) else PhoenixCard)
                .border(1.dp, if (complete) PhoenixGreen else PhoenixBorder, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(if (complete) "✓" else "–", color = if (complete) PhoenixGreen else PhoenixMuted)
        }
        Spacer(Modifier.width(12.dp))
        Text(text, color = if (complete) Color.White else PhoenixMuted, fontSize = 13.sp)
    }
}

@Composable
private fun BottomNav(selected: Tab, onSelect: (Tab) -> Unit) {
    NavigationBar(containerColor = PhoenixPanel, tonalElevation = 0.dp) {
        Tab.entries.forEach { tab ->
            NavigationBarItem(
                selected = selected == tab,
                onClick = { onSelect(tab) },
                icon = { Text(tab.glyph, fontSize = 18.sp) },
                label = { Text(tab.title, fontSize = 9.sp, maxLines = 1) },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = PhoenixOrange,
                    selectedTextColor = PhoenixOrange,
                    indicatorColor = PhoenixOrange.copy(alpha = .12f),
                    unselectedIconColor = PhoenixMuted,
                    unselectedTextColor = PhoenixMuted
                )
            )
        }
    }
}

@Composable
private fun SectionTitle(title: String, trailing: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
        Text(trailing, color = PhoenixMuted, fontSize = 11.sp)
    }
}

@Composable
private fun Tag(text: String) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = .35f))
            .border(1.dp, Color.White.copy(alpha = .14f), RoundedCornerShape(50))
            .padding(horizontal = 9.dp, vertical = 6.dp)
    ) { Text(text, fontSize = 10.sp, color = Color.White.copy(alpha = .88f)) }
}

@Composable
private fun PrimaryButton(text: String, onClick: () -> Unit, enabled: Boolean = true) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(50.dp),
        colors = ButtonDefaults.buttonColors(containerColor = PhoenixOrange, contentColor = Color.Black),
        shape = RoundedCornerShape(14.dp)
    ) { Text(text, fontWeight = FontWeight.Black) }
}

@Composable
private fun SecondaryButton(text: String, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().height(50.dp),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, PhoenixBorder)
    ) { Text(text, color = Color.White) }
}

@Composable
private fun SettingCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(PhoenixCard)
            .border(1.dp, PhoenixBorder, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp),
        content = content
    )
}

@Composable
private fun ToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onChecked: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp)
            Text(subtitle, color = PhoenixMuted, fontSize = 11.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChecked,
            colors = SwitchDefaults.colors(checkedThumbColor = Color.White, checkedTrackColor = PhoenixBlue)
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
        Text(label, color = PhoenixMuted, fontSize = 12.sp, modifier = Modifier.width(110.dp))
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.Medium)
    }
}
