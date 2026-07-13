package com.nisarg.wildcard;

import static com.google.android.libraries.identity.googleid.GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL;

import android.content.Intent;
import android.os.Bundle;
import android.os.CancellationSignal;

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

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.android.gms.games.PlayGames;
import com.google.android.libraries.identity.googleid.GetGoogleIdOption;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;
import com.google.firebase.Timestamp;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.firestore.DocumentReference;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FieldValue;
import com.google.firebase.firestore.FirebaseFirestore;

import java.util.HashMap;
import java.util.Map;

/**
 * Small native bridge for optional Firebase accounts/cloud saves and Google
 * Play Games leaderboards. Guest play never depends on this plugin.
 */
@CapacitorPlugin(name = "WildcardCloud")
public class WildcardCloudPlugin extends Plugin {
    private static final int MAX_SAVE_CHARS = 150_000;
    private static final int LEADERBOARD_REQUEST = 6904;

    private FirebaseAuth auth;
    private FirebaseFirestore firestore;
    private CredentialManager credentialManager;

    @Override
    public void load() {
        auth = FirebaseAuth.getInstance();
        firestore = FirebaseFirestore.getInstance();
        credentialManager = CredentialManager.create(getContext());
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

    @PluginMethod
    public void authState(PluginCall call) {
        call.resolve(authResult(auth.getCurrentUser()));
    }

    @PluginMethod
    public void signInWithGoogle(PluginCall call) {
        GetGoogleIdOption option = new GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setAutoSelectEnabled(false)
            .setServerClientId(getActivity().getString(R.string.default_web_client_id))
            .build();
        GetCredentialRequest request = new GetCredentialRequest.Builder()
            .addCredentialOption(option)
            .build();

        getActivity().runOnUiThread(() -> credentialManager.getCredentialAsync(
            getActivity(),
            request,
            new CancellationSignal(),
            ContextCompat.getMainExecutor(getContext()),
            new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                @Override
                public void onResult(GetCredentialResponse result) {
                    handleGoogleCredential(call, result.getCredential());
                }

                @Override
                public void onError(@NonNull GetCredentialException error) {
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

    private DocumentReference saveRef(FirebaseUser user) {
        return firestore.collection("users")
            .document(user.getUid())
            .collection("saves")
            .document("main");
    }

    @PluginMethod
    public void readCloudSave(PluginCall call) {
        FirebaseUser user = auth.getCurrentUser();
        if (user == null) {
            call.reject("Sign in before reading a cloud save");
            return;
        }

        saveRef(user).get()
            .addOnSuccessListener(doc -> call.resolve(cloudSaveResult(doc)))
            .addOnFailureListener(error -> reject(call, "Cloud save could not be read", error));
    }

    private JSObject cloudSaveResult(DocumentSnapshot doc) {
        JSObject out = new JSObject();
        out.put("exists", doc.exists());
        out.put("fromCache", doc.getMetadata().isFromCache());
        if (doc.exists()) {
            out.put("accountJson", doc.getString("accountJson"));
            out.put("runJson", doc.getString("runJson"));
            Long savedAt = doc.getLong("clientSavedAt");
            out.put("clientSavedAt", savedAt == null ? 0 : savedAt);
            Timestamp updatedAt = doc.getTimestamp("updatedAt");
            out.put("serverUpdatedAt", updatedAt == null ? 0 : updatedAt.toDate().getTime());
        }
        return out;
    }

    @PluginMethod
    public void writeCloudSave(PluginCall call) {
        FirebaseUser user = auth.getCurrentUser();
        if (user == null) {
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
        data.put("uid", user.getUid());
        data.put("schemaVersion", 1L);
        data.put("appVersion", "6.9");
        data.put("accountJson", accountJson);
        data.put("runJson", runJson);
        data.put("clientSavedAt", clientSavedAt == null ? 0L : Math.max(0L, clientSavedAt));
        data.put("updatedAt", FieldValue.serverTimestamp());

        saveRef(user).set(data)
            .addOnSuccessListener(ignored -> {
                JSObject out = new JSObject();
                out.put("queued", true);
                call.resolve(out);
            })
            .addOnFailureListener(error -> reject(call, "Cloud save could not be written", error));
    }

    @PluginMethod
    public void playGamesState(PluginCall call) {
        PlayGames.getGamesSignInClient(getActivity()).isAuthenticated()
            .addOnSuccessListener(result -> {
                JSObject out = new JSObject();
                out.put("signedIn", result.isAuthenticated());
                call.resolve(out);
            })
            .addOnFailureListener(error -> reject(call, "Play Games status unavailable", error));
    }

    @PluginMethod
    public void signInPlayGames(PluginCall call) {
        PlayGames.getGamesSignInClient(getActivity()).signIn()
            .addOnSuccessListener(result -> {
                JSObject out = new JSObject();
                out.put("signedIn", result.isAuthenticated());
                call.resolve(out);
            })
            .addOnFailureListener(error -> reject(call, "Play Games sign-in failed", error));
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
                call.resolve(out);
            })
            .addOnFailureListener(error -> reject(call, "Score submission failed", error));
    }

    @PluginMethod
    public void showLeaderboard(PluginCall call) {
        PlayGames.getLeaderboardsClient(getActivity())
            .getLeaderboardIntent(getActivity().getString(R.string.leaderboard_high_score))
            .addOnSuccessListener(intent -> {
                getActivity().startActivityForResult(intent, LEADERBOARD_REQUEST);
                call.resolve();
            })
            .addOnFailureListener(error -> reject(call, "Leaderboard unavailable", error));
    }
}
