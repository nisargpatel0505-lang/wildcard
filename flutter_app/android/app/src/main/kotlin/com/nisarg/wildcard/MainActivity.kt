package com.nisarg.wildcard

import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SAVE_MIGRATION_CHANNEL = "com.nisarg.wildcard/save_migration"
        private const val PLAY_GAMES_CHANNEL = "com.nisarg.wildcard/play_games"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.post(::enterImmersiveMode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Astra starts with its own local save and never imports Play progress.
        MethodChannel(messenger, SAVE_MIGRATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "readLegacyPreferences" -> result.success(emptyMap<String, Any?>())
                else -> result.notImplemented()
            }
        }
        // Retain the channel contract without initializing a Google account SDK.
        MethodChannel(messenger, PLAY_GAMES_CHANNEL).setMethodCallHandler { _, result ->
            result.error(
                "ASTRA_OFFLINE",
                "Online rankings are disabled in WILDCARD Astra.",
                null,
            )
        }
    }

    override fun onResume() {
        super.onResume()
        window.decorView.post(::enterImmersiveMode)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enterImmersiveMode()
    }

    private fun enterImmersiveMode() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
    }
}
