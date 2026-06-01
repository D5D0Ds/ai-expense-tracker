package io.github.openexpense.tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.openexpense.tracker.ai.GemmaBridgePlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GemmaBridgePlugin.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
