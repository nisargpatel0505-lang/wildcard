package com.nisarg.wildcard;

import android.app.Application;
import android.util.Log;

import com.google.android.gms.games.PlayGamesSdk;
import com.google.firebase.FirebaseApp;
import com.google.firebase.appcheck.FirebaseAppCheck;
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory;

/** Initializes native services before the Capacitor activity starts. */
public class WildcardApplication extends Application {
    private static final String TAG = "WildcardApplication";

    @Override
    public void onCreate() {
        super.onCreate();
        PlayGamesSdk.initialize(this);

        try {
            FirebaseApp app = FirebaseApp.initializeApp(this);
            if (app != null) {
                FirebaseAppCheck.getInstance()
                    .installAppCheckProviderFactory(
                        PlayIntegrityAppCheckProviderFactory.getInstance()
                    );
            }
        } catch (RuntimeException e) {
            // Guest/local play must remain available if Play Integrity cannot
            // issue a token (for example, a developer sideload).
            Log.w(TAG, "App Check initialization deferred", e);
        }
    }
}
