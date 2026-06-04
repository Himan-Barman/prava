package com.prava.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var pendingLocationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "prava/platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    shareText(text, result)
                }
                "requestLocationTimeAccess" -> requestLocationTimeAccess(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun shareText(text: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(false)
            return
        }

        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(sendIntent, "Share post"))
        result.success(true)
    }

    private fun requestLocationTimeAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(timeZonePayload(true))
            return
        }

        val coarseGranted = checkSelfPermission(
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val fineGranted = checkSelfPermission(
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (coarseGranted || fineGranted) {
            result.success(timeZonePayload(true))
            return
        }

        if (pendingLocationResult != null) {
            result.success(timeZonePayload(false))
            return
        }

        pendingLocationResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION
            ),
            4101
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == 4101) {
            val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            pendingLocationResult?.success(timeZonePayload(granted))
            pendingLocationResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun timeZonePayload(permissionGranted: Boolean): Map<String, Any> {
        val zone = TimeZone.getDefault()
        return mapOf(
            "timeZoneName" to zone.id,
            "timeZoneOffsetMinutes" to (zone.getOffset(System.currentTimeMillis()) / 60000),
            "permissionGranted" to permissionGranted
        )
    }
}
