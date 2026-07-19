package com.nisarg.wildcard;

import static com.google.android.libraries.identity.googleid.GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL;

import android.content.Intent;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.credentials.ClearCredentialStateRequest;
import androidx.credentials.Credential;
import androidx.credentials.CredentialManager;
import androidx.credentials.CredentialManagerCallback;
import androidx.credentials.CustomCredential;
import androidx.credentials.GetCredentialRequest;
import androidx.credentials.GetCredentialResponse;
import androidx.credentials.exceptions.ClearCredentialException;
import androidx.credentials.exceptions.GetCredentialException;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.games.GamesClientStatusCodes;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.LeaderboardsClient;
import com.google.android.gms.games.leaderboard.LeaderboardScore;
import com.google.android.gms.games.leaderboard.LeaderboardScoreBuffer;
import com.google.android.gms.games.leaderboard.LeaderboardVariant;
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.functions.FirebaseFunctions;
import com.google.firebase.functions.FirebaseFunctionsException;
import com.google.firebase.functions.HttpsCallableOptions;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Small native bridge for optional Firebase accounts/cloud saves and Google
 * Play Games leaderboards. Guest play never depends on this plugin.
 */
@CapacitorPlugin(name = "WildcardCloud")
public class WildcardCloudPlugin extends Plugin {
    private static final int MAX_SAVE_CHARS = 150_000;
    private static final int LEADERBOARD_REQUEST = 6904;

    private FirebaseAuth auth;
    private FirebaseFunctions functions;
    private CredentialManager credentialManager;

    @Override
    public void load() {
        auth = FirebaseAuth.getInstance();
        functions = FirebaseFunctions.getInstance("europe-west2");
        credentialManager = CredentialManager.create(getContext());
    }

    private JSObject callableResult(Object value) {
        try {
            if (value instanceof Map<?, ?> map) {
                return JSObject.fromJSONObject(new JSONObject(map));
            }
        } catch (JSONException ignored) {}
        return new JSObject();
    }

    private void rejectCallable(PluginCall call, String operation, Exception error) {
        String status = "UNKNOWN";
        if (error instanceof FirebaseFunctionsException functionsError) {
            status = functionsError.getCode().name();
        }
        JSObject data = new JSObject();
        data.put("operation", operation);
        data.put("status", status);
        data.put("retryable", status.equals("UNAVAILABLE") || status.equals("DEADLINE_EXCEEDED"));
        call.reject(
            operation + " could not be completed",
            "FUNCTION_" + status,
            error,
            data
        );
    }

    private Map<String, Object> purchaseRequest(PluginCall call) {
        String productId = call.getString("productId");
        String purchaseToken = call.getString("purchaseToken");
        if (productId == null || productId.isBlank()
            || purchaseToken == null || purchaseToken.length() < 16
            || purchaseToken.length() > 4096) {
            return null;
        }
        Map<String, Object> data = new HashMap<>();
        data.put("packageName", getContext().getPackageName());
        data.put("productId", productId);
        data.put("purchaseToken", purchaseToken);
        return data;
    }

    private JSObject authResult(FirebaseUser user) {
        JSObject out = new JSObject();
        out.put("signedIn", user != null);
        if (user != null) {
            out.put("uid", user.getUid());
            out.put("displayName", user.getDisplayName());
            out.put("email", user.getEmail());
            out.put("photoUrl", user.getPhotoUrl() == null ? null : user.getPhotoUrl().toString());
        }
        return out;
    }

    private void reject(PluginCall call, String message, Exception error) {
        String detail = error == null ? null : error.getLocalizedMessage();
        call.reject(detail == null || detail.isBlank() ? message : message + ": " + detail);
    }

    /**
     * Return documented, non-sensitive Play Games diagnostics to the web
     * layer. Free-form exception text stays in native device logs because it
     * may contain implementation or account-specific details.
     */
    private void rejectPlayGames(PluginCall call, String operation, Exception error) {
        int statusCode = -1;
        String statusName = "UNKNOWN";
        if (error instanceof ApiException apiError) {
            statusCode = apiError.getStatusCode();
            statusName = playGamesStatusName(statusCode);
        }
        statusName = statusName == null ? "UNKNOWN" : statusName
            .toUpperCase(Locale.ROOT)
            .replaceAll("[^A-Z0-9]+", "_")
            .replaceAll("^_+|_+$", "");
        if (statusName.isBlank()) statusName = "UNKNOWN";

        JSObject data = new JSObject();
        data.put("operation", operation);
        data.put("statusCode", statusCode);
        data.put("statusName", statusName);
        data.put("category", playGamesCategory(statusCode));
        data.put("retryable", playGamesRetryable(statusCode));
        call.reject("Play Games " + operation + " failed", "PGS_" + statusName, error, data);
    }

    private String playGamesStatusName(int statusCode) {
        if (statusCode == CommonStatusCodes.DEVELOPER_ERROR) return "DEVELOPER_ERROR";
        if (statusCode == CommonStatusCodes.SIGN_IN_REQUIRED) return "SIGN_IN_REQUIRED";
        if (statusCode == CommonStatusCodes.INVALID_ACCOUNT) return "INVALID_ACCOUNT";
        if (statusCode == CommonStatusCodes.CANCELED) return "CANCELED";
        if (statusCode == CommonStatusCodes.NETWORK_ERROR) return "NETWORK_ERROR";
        if (statusCode == CommonStatusCodes.TIMEOUT) return "TIMEOUT";
        if (statusCode == CommonStatusCodes.INTERNAL_ERROR) return "INTERNAL_ERROR";
        if (statusCode == CommonStatusCodes.SERVICE_DISABLED) return "SERVICE_DISABLED";
        if (statusCode == CommonStatusCodes.SERVICE_VERSION_UPDATE_REQUIRED) return "SERVICE_VERSION_UPDATE_REQUIRED";
        if (statusCode == CommonStatusCodes.API_NOT_CONNECTED) return "API_NOT_CONNECTED";
        if (statusCode == GamesClientStatusCodes.APP_MISCONFIGURED) return "APP_MISCONFIGURED";
        if (statusCode == GamesClientStatusCodes.GAME_NOT_FOUND) return "GAME_NOT_FOUND";
        if (statusCode == GamesClientStatusCodes.CONSENT_REQUIRED) return "CONSENT_REQUIRED";
        if (statusCode == GamesClientStatusCodes.LICENSE_CHECK_FAILED) return "LICENSE_CHECK_FAILED";
        if (statusCode == GamesClientStatusCodes.NETWORK_ERROR_NO_DATA) return "NETWORK_ERROR_NO_DATA";
        if (statusCode == GamesClientStatusCodes.NETWORK_ERROR_OPERATION_FAILED) return "NETWORK_ERROR_OPERATION_FAILED";
        return GamesClientStatusCodes.getStatusCodeString(statusCode);
    }

    private String playGamesCategory(int statusCode) {
        if (statusCode == CommonStatusCodes.DEVELOPER_ERROR
            || statusCode == GamesClientStatusCodes.APP_MISCONFIGURED
            || statusCode == GamesClientStatusCodes.GAME_NOT_FOUND) return "configuration";
        if (statusCode == CommonStatusCodes.SIGN_IN_REQUIRED
            || statusCode == CommonStatusCodes.INVALID_ACCOUNT
            || statusCode == CommonStatusCodes.CANCELED
            || statusCode == GamesClientStatusCodes.CONSENT_REQUIRED
            || statusCode == GamesClientStatusCodes.LICENSE_CHECK_FAILED) return "access";
        if (statusCode == CommonStatusCodes.NETWORK_ERROR
            || statusCode == GamesClientStatusCodes.NETWORK_ERROR_NO_DATA
            || statusCode == GamesClientStatusCodes.NETWORK_ERROR_OPERATION_FAILED) return "network";
        if (statusCode == CommonStatusCodes.SERVICE_DISABLED
            || statusCode == CommonStatusCodes.SERVICE_VERSION_UPDATE_REQUIRED
            || statusCode == CommonStatusCodes.API_NOT_CONNECTED) return "service";
        return "unknown";
    }

    private boolean playGamesRetryable(int statusCode) {
        return statusCode == CommonStatusCodes.NETWORK_ERROR
            || statusCode == CommonStatusCodes.INTERNAL_ERROR
            || statusCode == CommonStatusCodes.TIMEOUT
            || statusCode == CommonStatusCodes.CONNECTION_SUSPENDED_DURING_CALL
            || statusCode == CommonStatusCodes.RECONNECTION_TIMED_OUT
            || statusCode == CommonStatusCodes.RECONNECTION_TIMED_OUT_DURING_UPDATE
            || statusCode == GamesClientStatusCodes.NETWORK_ERROR_NO_DATA
            || statusCode == GamesClientStatusCodes.NETWORK_ERROR_OPERATION_FAILED;
    }

    private JSObject playGamesAuthResult(boolean signedIn) {
        JSObject out = new JSObject();
        out.put("signedIn", signedIn);
        out.put("code", signedIn ? "PGS_OK" : "PGS_SIGN_IN_REQUIRED");
        if (!signedIn) {
            out.put("statusCode", CommonStatusCodes.SIGN_IN_REQUIRED);
            out.put("category", "access");
            out.put("retryable", false);
        }
        return out;
    }

    @PluginMethod
    public void authState(PluginCall call) {
        call.resolve(authResult(auth.getCurrentUser()));
    }

    @PluginMethod
    public void signInWithGoogle(PluginCall call) {
        // This method is called from an explicit Sign in with Google button, so
        // use Credential Manager's button flow rather than its passive bottom
        // sheet. Besides matching Google's UX guidance, the button flow avoids
        // known Android 14+ account-sheet failures on some Google Play Services
        // builds.
        GetSignInWithGoogleOption option = new GetSignInWithGoogleOption.Builder(
            getActivity().getString(R.string.default_web_client_id)
        )
            .build();
        GetCredentialRequest request = new GetCredentialRequest.Builder()
            .addCredentialOption(option)
            .build();

        CancellationSignal cancellation = new CancellationSignal();
        Handler handler = new Handler(Looper.getMainLooper());
        AtomicBoolean chooserFinished = new AtomicBoolean(false);
        Runnable timeout = () -> {
            if (!chooserFinished.compareAndSet(false, true)) return;
            cancellation.cancel();
            call.reject("Google sign-in could not open. Update Google Play Services and try again.");
        };
        handler.postDelayed(timeout, 15_000L);

        getActivity().runOnUiThread(() -> credentialManager.getCredentialAsync(
            getActivity(),
            request,
            cancellation,
            ContextCompat.getMainExecutor(getContext()),
            new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                @Override
                public void onResult(GetCredentialResponse result) {
                    if (!chooserFinished.compareAndSet(false, true)) return;
                    handler.removeCallbacks(timeout);
                    handleGoogleCredential(call, result.getCredential());
                }

                @Override
                public void onError(@NonNull GetCredentialException error) {
                    if (!chooserFinished.compareAndSet(false, true)) return;
                    handler.removeCallbacks(timeout);
                    reject(call, "Google sign-in was cancelled or unavailable", error);
                }
            }
        ));
    }

    private void handleGoogleCredential(PluginCall call, Credential credential) {
        if (!(credential instanceof CustomCredential custom)
            || !TYPE_GOOGLE_ID_TOKEN_CREDENTIAL.equals(credential.getType())) {
            call.reject("Google did not return an ID token");
            return;
        }

        try {
            Bundle data = custom.getData();
            GoogleIdTokenCredential token = GoogleIdTokenCredential.createFrom(data);
            AuthCredential firebaseCredential = GoogleAuthProvider.getCredential(token.getIdToken(), null);
            auth.signInWithCredential(firebaseCredential)
                .addOnSuccessListener(result -> call.resolve(authResult(result.getUser())))
                .addOnFailureListener(error -> reject(call, "Firebase sign-in failed", error));
        } catch (RuntimeException error) {
            reject(call, "Google credential could not be read", error);
        }
    }

    @PluginMethod
    public void signOut(PluginCall call) {
        auth.signOut();
        ClearCredentialStateRequest request = new ClearCredentialStateRequest();
        credentialManager.clearCredentialStateAsync(
            request,
            new CancellationSignal(),
            ContextCompat.getMainExecutor(getContext()),
            new CredentialManagerCallback<Void, ClearCredentialException>() {
                @Override
                public void onResult(Void ignored) {
                    call.resolve(authResult(null));
                }

                @Override
                public void onError(@NonNull ClearCredentialException error) {
                    // Firebase is already signed out. Clearing the chooser state
                    // can safely be retried next time.
                    call.resolve(authResult(null));
                }
            }
        );
    }

    @PluginMethod
    public void readCloudSave(PluginCall call) {
        if (auth.getCurrentUser() == null) {
            call.reject("Sign in before reading a cloud save");
            return;
        }
        functions.getHttpsCallable("readSecureCloudSave")
            .call(new HashMap<String, Object>())
            .addOnSuccessListener(result -> call.resolve(callableResult(result.getData())))
            .addOnFailureListener(error -> rejectCallable(call, "Cloud save read", error));
    }

    @PluginMethod
    public void writeCloudSave(PluginCall call) {
        if (auth.getCurrentUser() == null) {
            call.reject("Sign in before writing a cloud save");
            return;
        }

        String accountJson = call.getString("accountJson");
        String runJson = call.getString("runJson");
        Long clientSavedAt = call.getLong("clientSavedAt");
        if (accountJson == null) accountJson = "";
        if (runJson == null) runJson = "";
        if (accountJson.length() > MAX_SAVE_CHARS || runJson.length() > MAX_SAVE_CHARS) {
            call.reject("Cloud save is too large");
            return;
        }

        Map<String, Object> data = new HashMap<>();
        data.put("accountJson", accountJson);
        data.put("runJson", runJson);
        data.put("clientSavedAt", clientSavedAt == null ? 0L : Math.max(0L, clientSavedAt));
        Long expectedProgressVersion = call.getLong("expectedProgressVersion");
        Long billingAdjustmentApplied = call.getLong("billingAdjustmentApplied");
        data.put(
            "expectedProgressVersion",
            expectedProgressVersion == null ? 0L : Math.max(0L, expectedProgressVersion)
        );
        data.put(
            "billingAdjustmentApplied",
            billingAdjustmentApplied == null ? 0L : Math.max(0L, billingAdjustmentApplied)
        );

        functions.getHttpsCallable("writeSecureCloudSave")
            .call(data)
            .addOnSuccessListener(result -> call.resolve(callableResult(result.getData())))
            .addOnFailureListener(error -> rejectCallable(call, "Cloud save write", error));
    }

    /**
     * Ask the protected Firebase backend to verify an Android one-time product
     * directly with the Google Play Developer API. The client never treats the
     * Billing Library callback by itself as proof of payment.
     */
    @PluginMethod
    public void verifyPlayPurchase(PluginCall call) {
        if (auth.getCurrentUser() == null) {
            call.reject("Sign in with Google before purchasing", "FUNCTION_UNAUTHENTICATED");
            return;
        }
        Map<String, Object> data = purchaseRequest(call);
        if (data == null) {
            call.reject("Invalid Play purchase", "FUNCTION_INVALID_ARGUMENT");
            return;
        }
        functions.getHttpsCallable("verifyPlayPurchase")
            .call(data)
            .addOnSuccessListener(result -> call.resolve(callableResult(result.getData())))
            .addOnFailureListener(error -> rejectCallable(call, "Purchase verification", error));
    }

    /**
     * Mark a verified token delivered only after the web layer has persisted
     * the local recovery claim and the resulting ordinary balance through the
     * protected cloud callable. Paid-only fields never enter accountJson.
     * The Billing receipt is consumed/acknowledged after this resolves.
     */
    @PluginMethod
    public void markPlayPurchaseDelivered(PluginCall call) {
        if (auth.getCurrentUser() == null) {
            call.reject("Sign in with Google before delivering a purchase", "FUNCTION_UNAUTHENTICATED");
            return;
        }
        Map<String, Object> data = purchaseRequest(call);
        if (data == null) {
            call.reject("Invalid Play purchase", "FUNCTION_INVALID_ARGUMENT");
            return;
        }
        functions.getHttpsCallable("markPlayPurchaseDelivered")
            .call(data)
            .addOnSuccessListener(result -> call.resolve(callableResult(result.getData())))
            .addOnFailureListener(error -> rejectCallable(call, "Purchase delivery", error));
    }

    /** Return server-backed durable entitlements such as Remove Ads. */
    @PluginMethod
    public void getPlayEntitlements(PluginCall call) {
        if (auth.getCurrentUser() == null) {
            call.reject("Sign in with Google before restoring purchases", "FUNCTION_UNAUTHENTICATED");
            return;
        }
        functions.getHttpsCallable("getPlayEntitlements")
            .call(new HashMap<String, Object>())
            .addOnSuccessListener(result -> call.resolve(callableResult(result.getData())))
            .addOnFailureListener(error -> rejectCallable(call, "Purchase restore", error));
    }

    /**
     * Return variant-scoped monetization configuration. Release builds expose
     * no ad-unit IDs unless all owner-created AdMob properties were supplied
     * at build time; developer builds expose only Google's demonstration IDs.
     */
    @PluginMethod
    public void serviceConfig(PluginCall call) {
        JSObject out = new JSObject();
        out.put("adsEnabled", BuildConfig.WILDCARD_ADS_ENABLED);
        out.put("adTesting", BuildConfig.WILDCARD_ADS_TESTING);
        out.put("rewardedAdId", BuildConfig.WILDCARD_REWARDED_AD_ID);
        out.put("interstitialAdId", BuildConfig.WILDCARD_INTERSTITIAL_AD_ID);
        out.put("billingVerificationRequired", true);
        call.resolve(out);
    }

    /**
     * Submit a completed Daily score through the authenticated Firebase
     * callable. The backend assigns the UTC board date and consumes a
     * limited-use App Check token, so neither the phone clock nor a replayed
     * App Check assertion can choose a different board day.
     */
    @PluginMethod
    public void submitDailyScore(PluginCall call) {
        if (auth.getCurrentUser() == null) {
            call.reject("Sign in with Google before posting a Daily score", "FUNCTION_UNAUTHENTICATED");
            return;
        }

        String nameValue = call.getString("name");
        Long scoreValue = call.getLong("score");
        String idempotencyKey = call.getString("idempotencyKey");
        String name = nameValue == null ? "" : nameValue.trim().toUpperCase(Locale.ROOT);
        if (!name.matches("^[A-Z0-9]{1,8}$")
            || scoreValue == null || scoreValue < 0L || scoreValue > 10_000_000L
            || idempotencyKey == null
            || !idempotencyKey.matches("^[A-Za-z0-9_-]{16,80}$")) {
            call.reject("Invalid Daily score", "FUNCTION_INVALID_ARGUMENT");
            return;
        }

        Map<String, Object> data = new HashMap<>();
        data.put("name", name);
        data.put("score", scoreValue);
        data.put("idempotencyKey", idempotencyKey);
        HttpsCallableOptions options = new HttpsCallableOptions.Builder()
            .setLimitedUseAppCheckTokens(true)
            .build();
        functions.getHttpsCallable("submitDailyScore", options)
            .call(data)
            .addOnSuccessListener(result -> call.resolve(callableResult(result.getData())))
            .addOnFailureListener(error -> rejectCallable(call, "Daily score submission", error));
    }

    /**
     * Delete the signed-in Firebase account through the backend. Server-side
     * deletion avoids the unsafe sequence where Auth is deleted before its
     * Firestore save, or a stale login deletes the save but cannot delete Auth.
     */
    @PluginMethod
    public void deleteAccount(PluginCall call) {
        FirebaseUser user = auth.getCurrentUser();
        if (user == null) {
            JSObject out = new JSObject();
            out.put("deleted", false);
            out.put("signedIn", false);
            out.put("status", "ALREADY_SIGNED_OUT");
            call.resolve(out);
            return;
        }

        Map<String, Object> confirmation = new HashMap<>();
        confirmation.put("confirm", "DELETE");
        HttpsCallableOptions options = new HttpsCallableOptions.Builder()
            .setLimitedUseAppCheckTokens(true)
            .build();
        functions.getHttpsCallable("deleteMyAccount", options)
            .call(confirmation)
            .addOnSuccessListener(result -> {
                auth.signOut();
                JSObject out = callableResult(result.getData());
                out.put("signedIn", false);
                out.put("status", "DELETED");

                credentialManager.clearCredentialStateAsync(
                    new ClearCredentialStateRequest(),
                    new CancellationSignal(),
                    ContextCompat.getMainExecutor(getContext()),
                    new CredentialManagerCallback<Void, ClearCredentialException>() {
                        @Override
                        public void onResult(Void ignored) {
                            call.resolve(out);
                        }

                        @Override
                        public void onError(@NonNull ClearCredentialException error) {
                            // The Firebase account and cloud data are already
                            // deleted. A stale chooser hint is not a deletion
                            // failure and is cleared on the next sign-in/out.
                            out.put("credentialChooserCleared", false);
                            call.resolve(out);
                        }
                    }
                );
            })
            .addOnFailureListener(error -> rejectCallable(call, "Account deletion", error));
    }

    @PluginMethod
    public void playGamesState(PluginCall call) {
        PlayGames.getGamesSignInClient(getActivity()).isAuthenticated()
            .addOnSuccessListener(result -> call.resolve(playGamesAuthResult(result.isAuthenticated())))
            .addOnFailureListener(error -> rejectPlayGames(call, "status", error));
    }

    @PluginMethod
    public void signInPlayGames(PluginCall call) {
        PlayGames.getGamesSignInClient(getActivity()).signIn()
            .addOnSuccessListener(result -> call.resolve(playGamesAuthResult(result.isAuthenticated())))
            .addOnFailureListener(error -> rejectPlayGames(call, "sign_in", error));
    }

    @PluginMethod
    public void submitScore(PluginCall call) {
        Long score = call.getLong("score");
        if (score == null || score <= 0) {
            call.reject("Score must be positive");
            return;
        }

        PlayGames.getLeaderboardsClient(getActivity())
            .submitScoreImmediate(getActivity().getString(R.string.leaderboard_high_score), score)
            .addOnSuccessListener(result -> {
                JSObject out = new JSObject();
                out.put("submitted", true);
                out.put("code", "PGS_OK");
                call.resolve(out);
            })
            .addOnFailureListener(error -> rejectPlayGames(call, "submit_score", error));
    }

    @PluginMethod
    public void showLeaderboard(PluginCall call) {
        PlayGames.getLeaderboardsClient(getActivity())
            .getLeaderboardIntent(getActivity().getString(R.string.leaderboard_high_score))
            .addOnSuccessListener(intent -> {
                getActivity().startActivityForResult(intent, LEADERBOARD_REQUEST);
                JSObject out = new JSObject();
                out.put("opened", true);
                out.put("code", "PGS_OK");
                call.resolve(out);
            })
            .addOnFailureListener(error -> rejectPlayGames(call, "open_leaderboard", error));
    }

    @PluginMethod
    public void loadLeaderboardScores(PluginCall call) {
        String spanParam = call.getString("span");
        final String requestedSpan = spanParam == null ? "all" : spanParam;

        final int span;
        switch (requestedSpan) {
            case "daily":
                span = LeaderboardVariant.TIME_SPAN_DAILY;
                break;
            case "weekly":
                span = LeaderboardVariant.TIME_SPAN_WEEKLY;
                break;
            case "all":
                span = LeaderboardVariant.TIME_SPAN_ALL_TIME;
                break;
            default:
                call.reject("Unknown leaderboard time span");
                return;
        }

        PlayGames.getLeaderboardsClient(getActivity())
            .loadTopScores(
                getActivity().getString(R.string.leaderboard_high_score),
                span,
                LeaderboardVariant.COLLECTION_PUBLIC,
                20,
                true
            )
            .addOnSuccessListener(data -> {
                LeaderboardsClient.LeaderboardScores page = data.get();
                if (page == null) {
                    call.reject("Leaderboard returned no data");
                    return;
                }

                JSArray rows = new JSArray();
                try {
                    LeaderboardScoreBuffer scores = page.getScores();
                    for (int i = 0; i < scores.getCount(); i++) {
                        LeaderboardScore score = scores.get(i);
                        JSObject row = new JSObject();
                        row.put("rank", score.getRank());
                        row.put("displayRank", score.getDisplayRank());
                        row.put("displayScore", score.getDisplayScore());
                        row.put("rawScore", score.getRawScore());
                        row.put("displayName", score.getScoreHolderDisplayName());
                        row.put(
                            "iconUrl",
                            score.getScoreHolderIconImageUri() == null
                                ? null
                                : score.getScoreHolderIconImageUri().toString()
                        );
                        rows.put(row);
                    }

                    JSObject out = new JSObject();
                    out.put("span", requestedSpan);
                    out.put("stale", data.isStale());
                    out.put("scores", rows);
                    call.resolve(out);
                } finally {
                    page.release();
                }
            })
            .addOnFailureListener(error -> rejectPlayGames(call, "load_scores", error));
    }
}
