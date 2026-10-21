#!/bin/bash
# Kör detta i roten av ditt repo (tv-launcher): bash setup.sh
set -e
mkdir -p .github/workflows app/src/main/java/com/example/tvlauncher

cat > settings.gradle.kts <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "tv-launcher"
include(":app")
EOF

cat > build.gradle.kts <<'EOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
EOF

cat > gradle.properties <<'EOF'
android.useAndroidX=true
org.gradle.jvmargs=-Xmx2g
EOF

cat > .gitignore <<'EOF'
.gradle/
build/
local.properties
.idea/
*.iml
EOF

cat > app/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.example.tvlauncher"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.tvlauncher"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
}
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />

    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
        </intent>
        <package android:name="com.google.android.youtube.tv" />
        <package android:name="com.netflix.ninja" />
        <package android:name="com.amazon.amazonvideo.livingroom" />
        <package android:name="com.spotify.tv.android" />
        <package android:name="com.google.android.youtube.tvmusic" />
    </queries>

    <application
        android:label="TV Launcher"
        android:theme="@android:style/Theme.Material.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.HOME" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > app/src/main/java/com/example/tvlauncher/MainActivity.kt <<'EOF'
package com.example.tvlauncher

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.delay

// Skriv ditt namn här om du vill ha det i hälsningen, t.ex. "Anna"
const val OWNER_NAME = ""

data class AppItem(val label: String, val pkg: String, val color: Color)

val FAVORITES = listOf(
    AppItem("YouTube", "com.google.android.youtube.tv", Color(0xFFD32F2F)),
    AppItem("Netflix", "com.netflix.ninja", Color(0xFF8E0000)),
    AppItem("Prime Video", "com.amazon.amazonvideo.livingroom", Color(0xFF1565C0)),
    AppItem("Spotify", "com.spotify.tv.android", Color(0xFF2E7D32)),
    AppItem("YouTube Music", "com.google.android.youtube.tvmusic", Color(0xFFAD1457))
)

fun launchApp(ctx: Context, pkg: String) {
    val pm = ctx.packageManager
    val intent = pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg)
    if (intent != null) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(intent)
    } else {
        Toast.makeText(ctx, "Appen är inte installerad", Toast.LENGTH_SHORT).show()
    }
}

fun installedApps(ctx: Context): List<AppItem> {
    val pm = ctx.packageManager
    val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)
    return pm.queryIntentActivities(intent, 0)
        .map { AppItem(it.loadLabel(pm).toString(), it.activityInfo.packageName, Color(0xFF3949AB)) }
        .filter { it.pkg != ctx.packageName }
        .sortedBy { it.label.lowercase() }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                LauncherScreen()
            }
        }
    }
}

@Composable
fun FocusCard(
    modifier: Modifier = Modifier,
    bg: Color,
    onClick: () -> Unit,
    content: @Composable BoxScope.() -> Unit
) {
    var focused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (focused) 1.08f else 1f, label = "scale")
    val shape = RoundedCornerShape(16.dp)
    Box(
        modifier = modifier
            .scale(scale)
            .onFocusChanged { focused = it.isFocused }
            .then(if (focused) Modifier.border(3.dp, Color.White, shape) else Modifier)
            .clip(shape)
            .background(bg)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
        content = content
    )
}

@Composable
fun LauncherScreen() {
    val ctx = LocalContext.current
    var tab by remember { mutableIntStateOf(0) }
    var ambient by remember { mutableStateOf(false) }
    var now by remember { mutableStateOf(Date()) }

    LaunchedEffect(Unit) {
        while (true) {
            now = Date()
            delay(1000)
        }
    }

    BackHandler(enabled = ambient) { ambient = false }

    val sv = Locale("sv", "SE")
    val timeFmt = remember { SimpleDateFormat("HH:mm", sv) }
    val dateFmt = remember { SimpleDateFormat("EEEE d MMMM", sv) }
    val timeText = timeFmt.format(now)
    val dateText = dateFmt.format(now).replaceFirstChar { it.uppercase() }

    val hour = Calendar.getInstance().apply { time = now }.get(Calendar.HOUR_OF_DAY)
    val hello = when {
        hour < 5 -> "God natt"
        hour < 10 -> "God morgon"
        hour < 12 -> "God förmiddag"
        hour < 18 -> "God eftermiddag"
        else -> "God kväll"
    }
    val greeting = if (OWNER_NAME.isBlank()) hello else "$hello, $OWNER_NAME"

    if (ambient) {
        AmbientScreen(timeText, dateText) { ambient = false }
    } else {
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF4B3F9E), Color(0xFF1E2358), Color(0xFF0B0D26))
                    )
                )
        ) {
            Column(Modifier.fillMaxSize().padding(horizontal = 56.dp, vertical = 32.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        listOf("Home", "Appar", "Smart Home").forEachIndexed { i, name ->
                            FocusCard(
                                Modifier.height(44.dp),
                                if (tab == i) Color(0x66FFFFFF) else Color(0x22FFFFFF),
                                { tab = i }
                            ) {
                                Text(
                                    name,
                                    color = Color.White,
                                    fontSize = 16.sp,
                                    modifier = Modifier.padding(horizontal = 22.dp)
                                )
                            }
                        }
                    }
                    Text(timeText, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(24.dp))
                when (tab) {
                    0 -> HomeTab(ctx, greeting, dateText) { ambient = true }
                    1 -> AppsTab(ctx)
                    else -> SmartHomeTab()
                }
            }
        }
    }
}

@Composable
fun HomeTab(ctx: Context, greeting: String, dateText: String, onAmbient: () -> Unit) {
    val first = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { first.requestFocus() } }

    Column {
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(Color(0x33FFFFFF))
                .padding(32.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(dateText.uppercase(), color = Color(0xCCFFFFFF), fontSize = 16.sp)
                    Text(greeting, color = Color.White, fontSize = 44.sp, fontWeight = FontWeight.Bold)
                }
                FocusCard(Modifier.size(150.dp, 80.dp), Color(0x44FFFFFF), onAmbient) {
                    Text("Ambient", color = Color.White, fontSize = 18.sp)
                }
            }
        }
        Spacer(Modifier.height(32.dp))
        Text("Appar", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        LazyRow(
            contentPadding = PaddingValues(vertical = 20.dp, horizontal = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            itemsIndexed(FAVORITES) { index, app ->
                FocusCard(
                    Modifier
                        .size(200.dp, 112.dp)
                        .then(if (index == 0) Modifier.focusRequester(first) else Modifier),
                    app.color,
                    { launchApp(ctx, app.pkg) }
                ) {
                    Text(app.label, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
fun AppsTab(ctx: Context) {
    val apps = remember { installedApps(ctx) }
    LazyVerticalGrid(
        columns = GridCells.Adaptive(170.dp),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        items(apps) { app ->
            FocusCard(
                Modifier.fillMaxWidth().height(90.dp),
                Color(0x33FFFFFF),
                { launchApp(ctx, app.pkg) }
            ) {
                Text(
                    app.label,
                    color = Color.White,
                    fontSize = 16.sp,
                    modifier = Modifier.padding(8.dp)
                )
            }
        }
    }
}

@Composable
fun SmartHomeTab() {
    val names = listOf("Vardagsrum – lampa", "Sovrum – lampa", "Ytterdörr – låst")
    val states = remember { mutableStateListOf(true, false, true) }
    Column {
        Text(
            "Demo: inte kopplat till riktiga enheter än",
            color = Color(0xAAFFFFFF),
            fontSize = 14.sp
        )
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp), modifier = Modifier.padding(8.dp)) {
            names.forEachIndexed { i, name ->
                FocusCard(
                    Modifier.size(220.dp, 120.dp),
                    if (states[i]) Color(0xFF5E52C9) else Color(0x33FFFFFF),
                    { states[i] = !states[i] }
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(name, color = Color.White, fontSize = 16.sp)
                        Text(
                            if (states[i]) "På" else "Av",
                            color = Color.White,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun AmbientScreen(timeText: String, dateText: String, onExit: () -> Unit) {
    val fr = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(fr)
            .clickable(onClick = onExit),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(timeText, color = Color(0x99FFFFFF), fontSize = 120.sp, fontWeight = FontWeight.Light)
            Text(dateText, color = Color(0x66FFFFFF), fontSize = 24.sp)
        }
    }
}
EOF

cat > .github/workflows/build.yml <<'EOF'
name: Build APK

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: 8.9

      - name: Build debug APK
        run: gradle assembleDebug --no-daemon

      - name: Spara APK som artifact
        uses: actions/upload-artifact@v4
        with:
          name: tv-launcher-apk
          path: app/build/outputs/apk/debug/app-debug.apk

      - name: Publicera i Releases
        uses: softprops/action-gh-release@v2
        with:
          tag_name: latest
          name: Senaste bygget
          files: app/build/outputs/apk/debug/app-debug.apk
EOF

echo "Klart! Nu: git add -A && git commit -m 'Add launcher' && git push"