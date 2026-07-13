package com.nisarg.wildcard;

import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(WildcardCloudPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
