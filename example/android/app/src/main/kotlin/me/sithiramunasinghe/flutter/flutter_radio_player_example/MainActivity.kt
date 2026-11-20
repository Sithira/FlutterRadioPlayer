package me.sithiramunasinghe.flutter.flutter_radio_player_example

import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import me.sithiramunasinghe.flutter.flutter_radio_player.core.RadioPlayerClient

class MainActivity : FlutterActivity() {
    private var secondEngine: FlutterEngine? = null

    // Lets the conformance tests run a second engine against the shared player (C11).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frp_test_host").setMethodCallHandler { call, result ->
            when (call.method) {
                "spawnSecondEngine" -> {
                    secondEngine?.destroy()
                    val callback = FlutterCallbackInformation.lookupCallbackInformation((call.arguments as Number).toLong())
                    val entrypoint = DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        callback.callbackLibraryPath,
                        callback.callbackName,
                    )
                    secondEngine = FlutterEngineGroup(this).createAndRunEngine(this, entrypoint)
                    result.success(null)
                }
                "coreExists" -> {
                    val client = RadioPlayerClient(this)
                    result.success(client.snapshot.sources.size >= 0)
                    client.release()
                }
                "destroySecondEngine" -> {
                    secondEngine?.destroy()
                    secondEngine = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
