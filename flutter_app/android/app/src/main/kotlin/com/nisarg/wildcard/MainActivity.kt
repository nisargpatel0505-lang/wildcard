package com.nisarg.wildcard

import android.content.Context
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.google.android.gms.games.LeaderboardsClient
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import com.google.android.gms.games.leaderboard.LeaderboardVariant
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SAVE_MIGRATION_CHANNEL = "com.nisarg.wildcard/save_migration"
        private const val PLAY_GAMES_CHANNEL = "com.nisarg.wildcard/play_games"
        private const val LEGACY_PREFERENCES = "CapacitorStorage"
        private const val LEGACY_PREFERENCE_PREFIX = "wildcard.phone."
    }

    private var playGamesInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.post(::enterImmersiveMode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, SAVE_MIGRATION_CHANNEL).setMethodCallHandler {
                call,
                result,
            ->
            when (call.method) {
                "readLegacyPreferences" -> result.success(readLegacyPreferences())
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, PLAY_GAMES_CHANNEL).setMethodCallHandler(
            ::handlePlayGamesCall,
        )
    }

    private fun readLegacyPreferences(): Map<String, Any?> {
        val preferences = getSharedPreferences(LEGACY_PREFERENCES, Context.MODE_PRIVATE)
        val source = preferences.all
        val keys = listOf(
            "wildcard_save_v1",
            "wildcard_run_v1",
            "wildcard_privacy_accept_v1",
            "wildcard_cloud_owner_v2",
        )
        // v6.9+ deliberately namespaced native copies with `wildcard.phone.`.
        // Keep the unprefixed fallback for older development builds. Migration
        // is read-only so either version can still be restored after rollback.
        return keys.associateWith { key ->
            source[LEGACY_PREFERENCE_PREFIX + key] ?: source[key]
        }
    }

    private fun handlePlayGamesCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "initialize") {
            try {
                if (!playGamesInitialized) {
                    PlayGamesSdk.initialize(applicationContext)
                    playGamesInitialized = true
                }
                result.success(null)
            } catch (error: RuntimeException) {
                rejectPlayGames(result, "PGS_INITIALIZATION_FAILED", error)
            }
            return
        }
        if (!playGamesInitialized) {
            result.error(
                "PGS_NOT_INITIALIZED",
                "Play Games has not been initialized after privacy acceptance.",
                null,
            )
            return
        }

        when (call.method) {
            "isAuthenticated" -> {
                PlayGames.getGamesSignInClient(this).isAuthenticated()
                    .addOnSuccessListener { auth ->
                        result.success(mapOf("signedIn" to auth.isAuthenticated, "code" to "PGS_OK"))
                    }
                    .addOnFailureListener { error ->
                        rejectPlayGames(result, "PGS_STATUS_UNAVAILABLE", error)
                    }
            }

            "signIn" -> {
                PlayGames.getGamesSignInClient(this).signIn()
                    .addOnSuccessListener { auth ->
                        result.success(mapOf("signedIn" to auth.isAuthenticated, "code" to "PGS_OK"))
                    }
                    .addOnFailureListener { error ->
                        rejectPlayGames(result, "PGS_SIGN_IN_FAILED", error)
                    }
            }

            "submitScore" -> submitScore(call, result)
            "showLeaderboard" -> showLeaderboard(result)
            "loadScores" -> loadScores(call, result)
            else -> result.notImplemented()
        }
    }

    private fun submitScore(call: MethodCall, result: MethodChannel.Result) {
        val score = (call.argument<Number>("score"))?.toLong() ?: 0L
        if (score <= 0L) {
            result.error("PGS_INVALID_SCORE", "Score must be positive.", null)
            return
        }
        PlayGames.getLeaderboardsClient(this)
            .submitScoreImmediate(getString(R.string.leaderboard_high_score), score)
            .addOnSuccessListener {
                result.success(mapOf("submitted" to true, "code" to "PGS_OK"))
            }
            .addOnFailureListener { error ->
                rejectPlayGames(result, "PGS_SCORE_SUBMISSION_FAILED", error)
            }
    }

    private fun showLeaderboard(result: MethodChannel.Result) {
        PlayGames.getLeaderboardsClient(this)
            .getLeaderboardIntent(getString(R.string.leaderboard_high_score))
            .addOnSuccessListener { intent ->
                startActivity(intent)
                result.success(mapOf("opened" to true, "code" to "PGS_OK"))
            }
            .addOnFailureListener { error ->
                rejectPlayGames(result, "PGS_OPEN_LEADERBOARD_FAILED", error)
            }
    }

    private fun loadScores(call: MethodCall, result: MethodChannel.Result) {
        val requestedSpan = call.argument<String>("span") ?: "all"
        val span = when (requestedSpan) {
            "daily" -> LeaderboardVariant.TIME_SPAN_DAILY
            "weekly" -> LeaderboardVariant.TIME_SPAN_WEEKLY
            "all" -> LeaderboardVariant.TIME_SPAN_ALL_TIME
            else -> {
                result.error("PGS_INVALID_SPAN", "Unknown leaderboard time span.", null)
                return
            }
        }
        PlayGames.getLeaderboardsClient(this)
            .loadTopScores(
                getString(R.string.leaderboard_high_score),
                span,
                LeaderboardVariant.COLLECTION_PUBLIC,
                20,
                true,
            )
            .addOnSuccessListener { annotatedData ->
                val page: LeaderboardsClient.LeaderboardScores? = annotatedData.get()
                if (page == null) {
                    result.error("PGS_EMPTY", "Leaderboard returned no data.", null)
                    return@addOnSuccessListener
                }
                try {
                    val scores = page.scores
                    val rows = mutableListOf<Map<String, Any?>>()
                    for (index in 0 until scores.count) {
                        val score = scores[index]
                        rows.add(
                            mapOf(
                                "rank" to score.rank,
                                "displayRank" to score.displayRank,
                                "displayScore" to score.displayScore,
                                "rawScore" to score.rawScore,
                                "displayName" to score.scoreHolderDisplayName,
                                "iconUrl" to score.scoreHolderIconImageUri?.toString(),
                            ),
                        )
                    }
                    result.success(
                        mapOf(
                            "span" to requestedSpan,
                            "stale" to annotatedData.isStale,
                            "scores" to rows,
                        ),
                    )
                } finally {
                    page.release()
                }
            }
            .addOnFailureListener { error ->
                rejectPlayGames(result, "PGS_LOAD_SCORES_FAILED", error)
            }
    }

    private fun rejectPlayGames(
        result: MethodChannel.Result,
        code: String,
        error: Exception,
    ) {
        result.error(code, error.localizedMessage ?: "Google Play Games failed.", null)
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
