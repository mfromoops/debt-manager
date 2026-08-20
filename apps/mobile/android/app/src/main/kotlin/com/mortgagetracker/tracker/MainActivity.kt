package com.mortgagetracker.tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "debt_manager/launcher_widgets",
        ).setMethodCallHandler { call, result ->
            if (call.method != "updateWidgets") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            @Suppress("UNCHECKED_CAST")
            val snapshot = call.arguments as? Map<String, Any?>
            if (snapshot == null) {
                result.error("invalid_snapshot", "Expected widget snapshot", null)
                return@setMethodCallHandler
            }
            DebtWidgetStore.save(this, snapshot)
            DebtWidgetUpdater.updateAll(this)
            result.success(null)
        }
    }
}

