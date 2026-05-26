package com.nebaj.leerlus

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.nebaj.leerlus/wifi"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        val wifi = applicationContext
                            .getSystemService(Context.WIFI_SERVICE) as WifiManager
                        if (multicastLock == null) {
                            multicastLock = wifi.createMulticastLock("MedBrewSync").apply {
                                setReferenceCounted(false)
                                acquire()
                            }
                        }
                        result.success(null)
                    }
                    "releaseMulticastLock" -> {
                        multicastLock?.release()
                        multicastLock = null
                        result.success(null)
                    }
                    "getDeviceName" -> result.success(Build.MODEL)
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }
}
