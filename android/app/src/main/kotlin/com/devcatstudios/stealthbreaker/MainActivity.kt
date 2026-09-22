package com.devcatstudios.stealthbreaker

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val previewSecurityChannel = "stealth_breaker/preview_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            previewSecurityChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecurePreview" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disableSecurePreview" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onDestroy()
    }
}
