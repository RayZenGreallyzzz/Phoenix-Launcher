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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
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
        Modifier
            .fillMaxWidth()
            .height(73.dp)
            .background(PhoenixBg)
            .padding(horizontal = 20.dp)
            .border(width = 0.dp, color = Color.Transparent),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.size(34.dp).clip(RoundedCornerShape(8.dp))
                .background(Brush.linearGradient(listOf(PhoenixOrange, Color(0xFF8F2500), PhoenixScrim)))
                .border(1.dp, PhoenixOrange.copy(alpha = .35f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) { Text("🔥", fontSize = 17.sp) }
        Spacer(Modifier.width(8.dp))
        Column(Modifier.weight(1f)) {
            Text("PHOENIX", fontSize = 24.sp, fontWeight = FontWeight.Black, letterSpacing = 1.sp)
            Text("GAME LAUNCHER", color = PhoenixMuted, fontSize = 8.sp, letterSpacing = 2.sp)
        }
        Box {
            Text("●", color = PhoenixMuted, fontSize = 18.sp)
            Box(
                Modifier.size(5.dp).clip(CircleShape).background(PhoenixOrange)
                    .align(Alignment.TopEnd)
            )
        }
        Spacer(Modifier.width(12.dp))
        Box(
            Modifier.size(37.dp).clip(CircleShape).background(PhoenixSecondary)
                .border(1.dp, PhoenixBorder, CircleShape),
            contentAlignment = Alignment.Center
        ) { Text("R", color = PhoenixOrange, fontSize = 18.sp, fontWeight = FontWeight.Bold) }
    }
    HorizontalDivider(color = PhoenixBorder, thickness = 1.dp)
}

@Composable
private fun HomeScreen(
    installed: Boolean,
    onOpenGame: (GameManifest) -> Unit,
    onInstall: () -> Unit
) {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 0.dp)
    ) {
        item {
            Row(
                Modifier.fillMaxWidth().padding(top = 24.dp, bottom = 20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "ТВОЯ ИГРОВАЯ ВСЕЛЕННАЯ",
                        color = PhoenixMuted,
                        fontSize = 8.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.7.sp
                    )
                    Spacer(Modifier.height(5.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Привет, RayZenGX", fontSize = 21.sp, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.width(6.dp))
                        Text("✦", color = PhoenixOrange, fontSize = 15.sp)
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(5.dp).clip(CircleShape).background(PhoenixGreen))
                    Spacer(Modifier.width(6.dp))
                    Text("Все системы онлайн", color = PhoenixGreen, fontSize = 9.sp)
                }
            }
        }
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
        Modifier.fillMaxWidth().height(487.dp)
            .clip(RoundedCornerShape(10.dp))
            .border(1.dp, PhoenixBorder, RoundedCornerShape(10.dp))
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
                    listOf(
                        Color.Transparent,
                        Color.Black.copy(alpha = .08f),
                        PhoenixScrim.copy(alpha = .42f),
                        PhoenixScrim.copy(alpha = .94f)
                    )
                )
            )
        )
        Row(
            Modifier.fillMaxWidth().padding(17.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Tag("⚡ ВЫБОР PHOENIX")
            Tag("РАННИЙ ДОСТУП")
        }
        Column(
            Modifier.align(Alignment.BottomStart).fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 23.dp)
        ) {
            Text(
                "ТВОЯ ЛЕГЕНДА НАЧИНАЕТСЯ ЗДЕСЬ",
                color = PhoenixOrange,
                fontSize = 8.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 1.8.sp
            )
            Spacer(Modifier.height(7.dp))
            Text("PHOENIX", fontSize = 53.sp, fontWeight = FontWeight.Black, lineHeight = 45.sp)
            Text("PIX ARENA", fontSize = 53.sp, fontWeight = FontWeight.Black, lineHeight = 45.sp)
            Spacer(Modifier.height(10.dp))
            Text(
                "Стань частью нового мира. Собери клан.\nЗажги свою легенду на арене.",
                color = PhoenixArtText.copy(alpha = .72f),
                fontSize = 10.sp,
                lineHeight = 18.sp
            )
            Spacer(Modifier.height(10.dp))
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                game.tags.take(4).forEach { Tag(it) }
            }
            Spacer(Modifier.height(18.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = onPrimary,
                    modifier = Modifier.height(44.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = PhoenixOrange,
                        contentColor = PhoenixArtText
                    ),
                    shape = RoundedCornerShape(6.dp),
                    contentPadding = PaddingValues(horizontal = 21.dp)
                ) {
                    Text(if (installed) "▶  Играть" else "↓  Скачать", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
                OutlinedButton(
                    onClick = onMore,
                    modifier = Modifier.height(44.dp),
                    shape = RoundedCornerShape(6.dp),
                    border = BorderStroke(1.dp, PhoenixArtText.copy(alpha = .22f)),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = PhoenixScrim.copy(alpha = .55f),
                        contentColor = PhoenixArtText
                    )
                ) { Text("Об игре  ›", fontSize = 11.sp) }
            }
        }
    }
}

@Composable
private fun GameCard(game: GameManifest, installed: Boolean, onClick: () -> Unit) {
    Column(
        Modifier.width(154.dp).clip(RoundedCornerShape(8.dp)).background(PhoenixCard)
            .border(1.dp, PhoenixBorder, RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
    ) {
        Image(
            painter = painterResource(game.cardRes),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxWidth().height(114.dp)
        )
        Column(Modifier.padding(11.dp)) {
            Text(game.title, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(4.dp))
            Text(
                if (game.id == GameCatalog.ppa.id) "MMORPG · Открытый мир" else game.subtitle,
                color = PhoenixMuted,
                fontSize = 8.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(10.dp))
            Text(
                if (installed) "Готово к запуску" else if (game.released) "Доступна сейчас" else "Следи за новостями",
                color = if (installed || game.released) PhoenixGreen else PhoenixMuted,
                fontSize = 8.sp
            )
        }
    }
}

@Composable
private fun LibraryScreen(
    installed: Boolean,
    onOpenGame: (GameManifest) -> Unit,
    onInstall: () -> Unit
) {
    var filter by remember { mutableStateOf("Все игры") }
    val visibleGames = GameCatalog.games.filter { game ->
        when (filter) {
            "Установлены" -> installed && game.id == GameCatalog.ppa.id
            "Скоро" -> !game.released
            else -> true
        }
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 22.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Библиотека", fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Text("Твои миры всегда рядом", color = PhoenixMuted, fontSize = 11.sp)
            Spacer(Modifier.height(18.dp))
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf("Все игры", "Установлены", "Скоро").forEach { item ->
                    val selected = filter == item
                    OutlinedButton(
                        onClick = { filter = item },
                        modifier = Modifier.height(34.dp),
                        shape = RoundedCornerShape(6.dp),
                        border = BorderStroke(1.dp, if (selected) PhoenixOrange.copy(alpha = .55f) else PhoenixBorder),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (selected) PhoenixOrange.copy(alpha = .08f) else Color.Transparent,
                            contentColor = if (selected) PhoenixOrange else PhoenixMuted
                        ),
                        contentPadding = PaddingValues(horizontal = 12.dp)
                    ) {
                        Text(
                            if (item == "Установлены") item + " " + if (installed) "1" else "0" else item,
                            fontSize = 11.sp
                        )
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        if (visibleGames.isEmpty()) {
            item {
                Column(
                    Modifier.fillMaxWidth().padding(vertical = 60.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("Пока нет установленных игр", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Text("Phoenix Pix Arena уже ждёт тебя.", color = PhoenixMuted, fontSize = 11.sp)
                    Spacer(Modifier.height(20.dp))
                    PrimaryButton("Скачать Phoenix Pix Arena", onInstall)
                }
            }
        } else {
            items(visibleGames) { game ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(PhoenixCard)
                        .border(1.dp, PhoenixBorder, RoundedCornerShape(8.dp))
                        .clickable { onOpenGame(game) }
                        .padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Image(
                        painter = painterResource(game.cardRes),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(72.dp).clip(RoundedCornerShape(6.dp))
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(game.title, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(5.dp))
                        Text(
                            if (installed && game.id == GameCatalog.ppa.id) "● Установлено" else if (game.released) "Доступна сейчас" else "Скоро",
                            color = if (installed && game.id == GameCatalog.ppa.id) PhoenixGreen else PhoenixMuted,
                            fontSize = 10.sp
                        )
                    }
                    if (game.id == GameCatalog.ppa.id) {
                        Button(
                            onClick = { if (installed) onOpenGame(game) else onInstall() },
                            modifier = Modifier.height(36.dp),
                            shape = RoundedCornerShape(6.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = PhoenixOrange, contentColor = PhoenixArtText),
                            contentPadding = PaddingValues(horizontal = 13.dp)
                        ) {
                            Text(if (installed) "Играть" else "Скачать", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NewsScreen() {
    var filter by remember { mutableStateOf("Все") }
    val newsItems = listOf(
        Triple("Новая арена. Новая легенда.", "PPA", "7 октября 2026"),
        Triple("Будущее уже близко", "События", "5 октября 2026"),
        Triple("Phoenix Launcher: обновление 0.2", "Обновления", "7 октября 2026"),
        Triple("По ту сторону портала", "События", "1 октября 2026")
    )

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 22.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Text("Новости", fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Text("Всё, чем живёт вселенная Phoenix", color = PhoenixMuted, fontSize = 11.sp)
            Spacer(Modifier.height(18.dp))
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf("Все", "PPA", "Обновления", "События").forEach { item ->
                    val selected = filter == item
                    OutlinedButton(
                        onClick = { filter = item },
                        modifier = Modifier.height(34.dp),
                        shape = RoundedCornerShape(6.dp),
                        border = BorderStroke(1.dp, if (selected) PhoenixOrange.copy(alpha = .55f) else PhoenixBorder),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (selected) PhoenixOrange.copy(alpha = .08f) else Color.Transparent,
                            contentColor = if (selected) PhoenixOrange else PhoenixMuted
                        ),
                        contentPadding = PaddingValues(horizontal = 12.dp)
                    ) { Text(item, fontSize = 11.sp) }
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        items(newsItems.filter { filter == "Все" || it.second == filter }) { item ->
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(PhoenixCard)
                    .border(1.dp, PhoenixBorder, RoundedCornerShape(8.dp))
            ) {
                Image(
                    painter = painterResource(
                        when (item.second) {
                            "PPA", "Обновления" -> R.drawable.ppa_hero
                            else -> R.drawable.cyber_card
                        }
                    ),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().height(190.dp)
                )
                Column(Modifier.padding(16.dp)) {
                    Row(Modifier.fillMaxWidth()) {
                        Text(item.second.uppercase(), color = PhoenixOrange, fontSize = 9.sp, modifier = Modifier.weight(1f))
                        Text(item.third, color = PhoenixMuted, fontSize = 9.sp)
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(item.first, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(9.dp))
                    Text(
                        "Новости и события игровой вселенной Phoenix. Следи за обновлениями и новыми мирами.",
                        color = PhoenixMuted,
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                    Spacer(Modifier.height(10.dp))
                    Text("Читать  ›", color = PhoenixText, fontSize = 11.sp)
                }
            }
        }
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
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 22.dp)
    ) {
        item {
            Text("Профиль", fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(24.dp))
            Column(
                Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    Modifier.size(86.dp).clip(CircleShape).background(PhoenixSecondary)
                        .border(1.dp, PhoenixOrange.copy(alpha = .55f), CircleShape),
                    contentAlignment = Alignment.Center
                ) { Text("R", color = PhoenixOrange, fontSize = 36.sp, fontWeight = FontWeight.Bold) }
                Spacer(Modifier.height(16.dp))
                Text("RayZenGX", fontSize = 30.sp, fontWeight = FontWeight.Black)
                Text("Phoenix Account", color = PhoenixMuted, fontSize = 12.sp)
                Spacer(Modifier.height(14.dp))
                Tag("✓ АККАУНТ ПОДТВЕРЖДЁН")
            }
            Spacer(Modifier.height(24.dp))
            HorizontalDivider(color = PhoenixBorder)
            Spacer(Modifier.height(22.dp))
            Text("Связанные аккаунты", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            InfoRow("Telegram", "@RayZenGX   ·   ✓ Привязан")
            HorizontalDivider(color = PhoenixBorder)
            InfoRow("Phoenix Pix Arena", "RayZenGX · Phoenix ID   ·   ✓")
            HorizontalDivider(color = PhoenixBorder)
            Spacer(Modifier.height(24.dp))
            Text("Твоя активность", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(18.dp))
            Row(Modifier.fillMaxWidth()) {
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("1", color = PhoenixOrange, fontSize = 30.sp, fontWeight = FontWeight.Black)
                    Text("Установлено игр", color = PhoenixMuted, fontSize = 9.sp)
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("1", fontSize = 30.sp, fontWeight = FontWeight.Black)
                    Text("Игровой аккаунт", color = PhoenixMuted, fontSize = 9.sp)
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("2026", fontSize = 30.sp, fontWeight = FontWeight.Black)
                    Text("С нами с", color = PhoenixMuted, fontSize = 9.sp)
                }
            }
        }
    }
}

@Composable
private fun SettingsScreen() {
    var autoUpdate by remember { mutableStateOf(true) }
    var wifiOnly by remember { mutableStateOf(true) }
    var notifications by remember { mutableStateOf(true) }
    var darkTheme by remember { mutableStateOf(true) }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 22.dp)
    ) {
        item {
            Text("Настройки", fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Text("Phoenix по твоим правилам", color = PhoenixMuted, fontSize = 11.sp)
            Spacer(Modifier.height(26.dp))
            Text("ЛАУНЧЕР", color = PhoenixMuted, fontSize = 8.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp)
            ToggleRow("Автообновление", "Всегда последняя версия игры", autoUpdate) { autoUpdate = it }
            HorizontalDivider(color = PhoenixBorder)
            ToggleRow("Только через Wi-Fi", "Не использовать мобильный интернет", wifiOnly) { wifiOnly = it }
            HorizontalDivider(color = PhoenixBorder)
            ToggleRow("Уведомления", "Новости игр и важные события", notifications) { notifications = it }
            HorizontalDivider(color = PhoenixBorder)
            ToggleRow("Тёмная тема", "Фирменное оформление Phoenix", darkTheme) { darkTheme = it }
            HorizontalDivider(color = PhoenixBorder)
            Spacer(Modifier.height(26.dp))
            Text("О ПРИЛОЖЕНИИ", color = PhoenixMuted, fontSize = 8.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp)
            InfoRow("Phoenix Launcher", "v0.2 · Native Visual Lock")
            HorizontalDivider(color = PhoenixBorder)
            Spacer(Modifier.height(30.dp))
            Text(
                "PHOENIX · РОЖДЁН ДЛЯ ИГРЫ",
                color = PhoenixMuted,
                fontSize = 9.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
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
            Box(Modifier.fillMaxWidth().height(410.dp)) {
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
                Column(Modifier.align(Alignment.BottomStart).padding(20.dp)) {
                    Text("PHOENIX ORIGINAL", color = PhoenixOrange, fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(game.title, fontSize = 34.sp, fontWeight = FontWeight.Black)
                    Spacer(Modifier.height(9.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        game.tags.forEach { Tag(it) }
                    }
                }
            }
        }
        item {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 22.dp)) {
                PrimaryButton(
                    if (!game.released) "Скоро" else if (installed) "Играть" else "Скачать " + game.sizeLabel,
                    onPrimary,
                    enabled = game.released
                )
                Spacer(Modifier.height(28.dp))
                Text("Один мир. Тысячи легенд.", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(10.dp))
                Text(game.description, color = PhoenixMuted, fontSize = 12.sp, lineHeight = 20.sp)
                Spacer(Modifier.height(22.dp))
                Row(Modifier.fillMaxWidth()) {
                    Column(Modifier.weight(1f)) {
                        Text("ВЕРСИЯ", color = PhoenixMuted, fontSize = 8.sp, letterSpacing = 1.2.sp)
                        Spacer(Modifier.height(6.dp))
                        Text(game.version, fontSize = 12.sp)
                    }
                    Column(Modifier.weight(1f)) {
                        Text("РАЗМЕР", color = PhoenixMuted, fontSize = 8.sp, letterSpacing = 1.2.sp)
                        Spacer(Modifier.height(6.dp))
                        Text(game.sizeLabel, fontSize = 12.sp)
                    }
                    Column(Modifier.weight(1f)) {
                        Text("ПЛАТФОРМА", color = PhoenixMuted, fontSize = 8.sp, letterSpacing = 1.2.sp)
                        Spacer(Modifier.height(6.dp))
                        Text("Android", fontSize = 12.sp)
                    }
                }
                Spacer(Modifier.height(24.dp))
                HorizontalDivider(color = PhoenixBorder)
                Spacer(Modifier.height(22.dp))
                Text("Мир игры", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    repeat(3) {
                        Image(
                            painter = painterResource(game.heroRes),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.weight(1f).height(88.dp).clip(RoundedCornerShape(6.dp))
                        )
                    }
                }
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
    val pct = if (installed) 100 else (progress * 100).toInt()
    val stage = when {
        pct >= 100 -> 3
        pct >= 93 -> 2
        pct >= 83 -> 1
        else -> 0
    }
    val stages = listOf("Загрузка файлов игры", "Проверка файлов", "Установка модуля", "Готово к запуску")

    LazyColumn(
        Modifier.fillMaxSize().background(PhoenixBg),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 20.dp)
    ) {
        item {
            TextButton(onClick = onBack, contentPadding = PaddingValues(0.dp)) {
                Text("←  Назад", color = PhoenixText, fontSize = 12.sp)
            }
            Spacer(Modifier.height(14.dp))
            Text(if (installed) "Игра установлена" else "Установка игры", fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(22.dp))
            Image(
                painter = painterResource(R.drawable.ppa_hero),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxWidth().aspectRatio(1.8f).clip(RoundedCornerShape(8.dp))
            )
            Spacer(Modifier.height(22.dp))
            Text("Phoenix Pix Arena", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(5.dp))
            Text("Версия 0.1.0  ·  380 МБ", color = PhoenixMuted, fontSize = 11.sp)
            Spacer(Modifier.height(26.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Text(
                    when {
                        installed -> "Готово к запуску"
                        pct >= 93 -> "Установка модуля"
                        pct >= 83 -> "Проверка файлов"
                        else -> "Загрузка файлов игры"
                    },
                    color = PhoenixText,
                    fontSize = 12.sp,
                    modifier = Modifier.weight(1f)
                )
                Text(pct.toString() + "%", color = PhoenixOrange, fontSize = 34.sp, fontWeight = FontWeight.Black)
            }
            Spacer(Modifier.height(12.dp))
            LinearProgressIndicator(
                progress = { if (installed) 1f else progress },
                modifier = Modifier.fillMaxWidth().height(6.dp),
                color = PhoenixOrange,
                trackColor = PhoenixSecondary
            )
            Spacer(Modifier.height(10.dp))
            Row(Modifier.fillMaxWidth()) {
                Text(((380 * pct) / 100).toString() + " / 380 МБ", color = PhoenixMuted, fontSize = 10.sp, modifier = Modifier.weight(1f))
                Text(
                    if (installed) "Установка завершена" else "12,8 МБ/с · ~" + maxOf(1, (100 - pct + 2) / 3) + " сек",
                    color = PhoenixMuted,
                    fontSize = 10.sp
                )
            }
            Spacer(Modifier.height(24.dp))
            HorizontalDivider(color = PhoenixBorder)
            stages.forEachIndexed { index, title ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 13.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val complete = installed || stage > index
                    val current = !installed && stage == index
                    Box(
                        Modifier.size(24.dp).clip(CircleShape)
                            .border(1.dp, if (complete) PhoenixGreen else if (current) PhoenixOrange else PhoenixBorder, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(if (complete) "✓" else if (current) "•" else "–", color = if (complete) PhoenixGreen else if (current) PhoenixOrange else PhoenixMuted, fontSize = 11.sp)
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(title, color = if (complete) PhoenixGreen else if (current) PhoenixText else PhoenixMuted, fontSize = 12.sp)
                }
            }
            HorizontalDivider(color = PhoenixBorder)
            Spacer(Modifier.height(22.dp))
            PrimaryButton(
                if (installed) "Играть" else if (downloading) "Загрузка…" else "Начать загрузку",
                if (installed) onPlay else onStart,
                enabled = !downloading || installed
            )
            Spacer(Modifier.height(18.dp))
            Text(
                "Файлы проверяются системой Phoenix",
                color = PhoenixMuted,
                fontSize = 10.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }
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
    Row(
        Modifier
            .fillMaxWidth()
            .background(PhoenixBg.copy(alpha = .98f))
            .height(76.dp)
            .padding(horizontal = 9.dp),
        verticalAlignment = Alignment.Top
    ) {
        Tab.entries.forEach { tab ->
            val active = selected == tab
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clickable { onSelect(tab) }
                    .padding(top = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(Modifier.height(3.dp).width(27.dp)) {
                    if (active) Box(Modifier.fillMaxSize().background(PhoenixOrange))
                }
                Spacer(Modifier.height(7.dp))
                Text(
                    tab.glyph,
                    color = if (active) PhoenixOrange else PhoenixMuted,
                    fontSize = 18.sp
                )
                Spacer(Modifier.height(5.dp))
                Text(
                    tab.title,
                    color = if (active) PhoenixOrange else PhoenixMuted,
                    fontSize = 8.sp,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun SectionTitle(title: String, trailing: String) {
    Row(
        Modifier.fillMaxWidth().padding(top = 25.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
        Text(trailing, color = PhoenixMuted, fontSize = 9.sp)
    }
}

@Composable
private fun Tag(text: String) {
    Box(
        Modifier.clip(RoundedCornerShape(4.dp)).background(PhoenixScrim.copy(alpha = .45f))
            .border(1.dp, PhoenixArtText.copy(alpha = .15f), RoundedCornerShape(4.dp))
            .padding(horizontal = 8.dp, vertical = 5.dp)
    ) { Text(text, fontSize = 9.sp, color = if (text.contains("Онлайн")) PhoenixGreen else PhoenixArtText) }
}

@Composable
private fun PrimaryButton(text: String, onClick: () -> Unit, enabled: Boolean = true) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(49.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = PhoenixOrange,
            contentColor = PhoenixArtText,
            disabledContainerColor = PhoenixSecondary,
            disabledContentColor = PhoenixMuted
        ),
        shape = RoundedCornerShape(6.dp)
    ) { Text(text, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
}

@Composable
private fun SecondaryButton(text: String, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().height(49.dp),
        shape = RoundedCornerShape(6.dp),
        border = BorderStroke(1.dp, PhoenixArtText.copy(alpha = .22f)),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = PhoenixScrim.copy(alpha = .50f),
            contentColor = PhoenixArtText
        )
    ) { Text(text, fontSize = 12.sp) }
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
        Modifier.fillMaxWidth().padding(vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp)
            Spacer(Modifier.height(4.dp))
            Text(subtitle, color = PhoenixMuted, fontSize = 10.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChecked,
            colors = SwitchDefaults.colors(
                checkedThumbColor = PhoenixArtText,
                checkedTrackColor = PhoenixOrange,
                uncheckedThumbColor = PhoenixMuted,
                uncheckedTrackColor = PhoenixSecondary,
                uncheckedBorderColor = PhoenixBorder
            )
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
