package com.habitsync.habitsync

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Screen pinning: while a focus session runs, Android blocks the
        // Home / Recents buttons so other apps (YouTube, WhatsApp,
        // Instagram...) cannot be opened. Tabs inside this app still work.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_forest/lock")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "lock" -> { startLockTask(); result.success(true) }
                        "unlock" -> { stopLockTask(); result.success(true) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
