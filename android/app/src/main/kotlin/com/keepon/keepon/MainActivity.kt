package com.keepon.keepon

import android.Manifest
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val methodChannel = "keepon/native"
    private val eventChannel = "keepon/events"
    private val permRequest = 4711

    private var sink: EventChannel.EventSink? = null
    private val authRequest = 4712
    private var authResult: MethodChannel.Result? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingName: String? = null

    private val prefs by lazy { Store.prefs(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyAlarmWindow(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyAlarmWindow(intent)
    }

    override fun onStop() {
        super.onStop()
        // Never keep KEEPON visible over the lock screen after the alarm screen is gone.
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        }
    }

    /** Only an alarm launch may show over the lock screen. */
    private fun applyAlarmWindow(i: Intent?) {
        if (Build.VERSION.SDK_INT >= 27) {
            val alarm = i?.getBooleanExtra("alarm", false) == true && AlarmPlayer.ringing
            setShowWhenLocked(alarm)
            setTurnScreenOn(alarm)
        }
    }

    private fun deviceSecure(): Boolean {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return if (Build.VERSION.SDK_INT >= 23) km.isDeviceSecure else km.isKeyguardSecure
    }

    private fun authenticate(title: String, description: String, result: MethodChannel.Result) {
        if (!deviceSecure()) return result.success("unavailable")
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val intent = km.createConfirmDeviceCredentialIntent(title, description)
            ?: return result.success("unavailable")
        if (authResult != null) return result.error("BUSY", "Another confirmation is in progress.", null)
        authResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, authRequest)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == authRequest) {
            val r = authResult
            authResult = null
            r?.success(if (resultCode == RESULT_OK) "success" else "failed")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, eventChannel).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                EventStore.onChanged = { runOnUiThread { sink?.success("changed") } }
            }

            override fun onCancel(arguments: Any?) {
                sink = null
                EventStore.onChanged = null
            }
        })

        MethodChannel(messenger, methodChannel).setMethodCallHandler { call, result ->
            try {
                handle(call.method, call, result)
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.message ?: e.toString(), null)
            }
        }
    }

    private fun handle(method: String, call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (method) {
            "getDeviceInfo" -> {
                val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val version = try {
                    @Suppress("DEPRECATION")
                    packageManager.getPackageInfo(packageName, 0).versionName ?: ""
                } catch (e: Exception) {
                    ""
                }
                val name = try {
                    Settings.Global.getString(contentResolver, "device_name") ?: Build.MODEL
                } catch (e: Exception) {
                    Build.MODEL
                }
                result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "device" to name,
                        "androidVersion" to Build.VERSION.RELEASE,
                        "sdk" to Build.VERSION.SDK_INT,
                        "appVersion" to version,
                        "hasAccelerometer" to (sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                        "hasTelephony" to packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
                    )
                )
            }
            "isServiceRunning" -> result.success(ProtectionService.running)
            "isDeviceSecure" -> result.success(deviceSecure())
            "simulateTrigger" -> {
                if (!ProtectionService.running) {
                    result.error("NOT_RUNNING", "Turn on protection first, then run the test.", null)
                } else {
                    val i = Intent(this, ProtectionService::class.java).setAction(ProtectionService.ACTION_TEST)
                    try {
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message ?: "Could not start the test.", null)
                    }
                }
            }
            "getSession" -> result.success(Session.info(this))
            "isAdminActive" -> result.success(AdminLock.isActive(this))
            "requestAdmin" -> {
                val i = Intent(android.app.admin.DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    .putExtra(android.app.admin.DevicePolicyManager.EXTRA_DEVICE_ADMIN, AdminLock.component(this))
                    .putExtra(
                        android.app.admin.DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                        "KEEPON uses this to lock the screen when an alarm is triggered and to notice wrong lock-screen codes. It cannot read your PIN. You can turn it off at any time in KEEPON settings or Android settings."
                    )
                result.success(launch(i))
            }
            "removeAdmin" -> {
                AdminLock.remove(this)
                result.success(null)
            }
            "getLocationLog" -> result.success(LocationLog.json(this))
            "clearLocationLog" -> {
                LocationLog.clear(this)
                result.success(null)
            }
            "canUseFullScreenIntent" -> {
                if (Build.VERSION.SDK_INT >= 34) {
                    result.success(getSystemService(NotificationManager::class.java).canUseFullScreenIntent())
                } else {
                    result.success(null)
                }
            }
            "openFullScreenSettings" -> {
                val ok = launch(
                    Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT", Uri.parse("package:$packageName"))
                )
                if (!ok) launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "authenticate" -> authenticate(
                call.argument<String>("title") ?: "KEEPON",
                call.argument<String>("description") ?: "",
                result,
            )
            "openUrl" -> {
                val url = call.argument<String>("url") ?: return result.error("BAD_ARGS", "Missing URL.", null)
                launch(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                result.success(null)
            }
            "openSecuritySettings" -> {
                launch(Intent(Settings.ACTION_SECURITY_SETTINGS))
                result.success(null)
            }
            "isAlarmRinging" -> result.success(AlarmPlayer.ringing)
            "startService" -> {
                val cfg = call.argument<String>("config")
                    ?: return result.error("BAD_ARGS", "Missing configuration.", null)
                val i = Intent(this, ProtectionService::class.java).putExtra(ProtectionService.EXTRA_CONFIG, cfg)
                try {
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("START_FAILED", "Android refused to start the monitoring service: ${e.message}", null)
                }
            }
            "stopService" -> {
                ProtectionService.setArmed(this, false)
                // Turning protection off ends any active alarm session (the owner confirmed in Dart).
                AlarmPlayer.stop(this, "Protection was turned off")
                stopService(Intent(this, ProtectionService::class.java))
                result.success(null)
            }
            "stopAlarm" -> {
                AlarmPlayer.stop(this, "Stopped in the app")
                result.success(null)
            }
            "testAlarm" -> {
                val err = AlarmPlayer.start(
                    this,
                    call.argument<String>("sound") ?: "alarm",
                    call.argument<Int>("volume") ?: 80,
                    call.argument<Boolean>("vibrate") ?: true,
                    4,
                )
                result.success(err)
            }
            "permissionStatus" -> result.success(statusFor(call.argument<String>("name")))
            "requestPermission" -> requestPermission(call.argument<String>("name"), result)
            "getLocation" -> fetchLocation(result)
            "openAppSettings" -> {
                launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "openBatterySettings" -> {
                val ok = launch(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                if (!ok) launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "isIgnoringBatteryOptimizations" -> {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(packageName))
            }
            "openFindHub" -> {
                val app = packageManager.getLaunchIntentForPackage("com.google.android.apps.adm")
                if (app == null || !launch(app)) {
                    launch(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/android/find")))
                }
                result.success(null)
            }
            "openMap" -> {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                launch(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lng?q=$lat,$lng(Last+known+location)")))
                result.success(null)
            }
            "peekEvents" -> result.success(EventStore.peek(this))
            "ackEvents" -> {
                val ids = call.argument<List<String>>("ids") ?: emptyList()
                EventStore.ack(this, ids)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun launch(i: Intent): Boolean = try {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
        true
    } catch (e: ActivityNotFoundException) {
        false
    } catch (e: Exception) {
        false
    }

    // ---------- permissions ----------

    private fun permStatus(perm: String): String {
        if (Build.VERSION.SDK_INT < 23) return "granted"
        if (checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED) return "granted"
        val asked = prefs.getBoolean("asked_$perm", false)
        return if (asked && !shouldShowRequestPermissionRationale(perm)) "permanentlyDenied" else "denied"
    }

    private fun statusFor(name: String?): String = when (name) {
        "notifications" -> {
            val nm = getSystemService(NotificationManager::class.java)
            when {
                nm.areNotificationsEnabled() -> "granted"
                Build.VERSION.SDK_INT >= 33 -> permStatus(Manifest.permission.POST_NOTIFICATIONS)
                else -> "permanentlyDenied"
            }
        }
        "backgroundLocation" -> {
            if (Build.VERSION.SDK_INT < 29) "granted"
            else if (checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED) "granted"
            else "denied"
        }
        "location" -> {
            if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            ) "granted" else permStatus(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        else -> "unknown"
    }

    private fun requestPermission(name: String?, result: MethodChannel.Result) {
        if (statusFor(name) == "granted") return result.success("granted")
        val perms: Array<String> = when {
            name == "notifications" && Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.POST_NOTIFICATIONS)
            name == "location" && Build.VERSION.SDK_INT >= 23 -> arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
            else -> return result.success(statusFor(name))
        }
        if (pendingResult != null) return result.error("BUSY", "Another permission request is in progress.", null)
        pendingResult = result
        pendingName = name
        val e = prefs.edit()
        for (p in perms) e.putBoolean("asked_$p", true)
        e.apply()
        requestPermissions(perms, permRequest)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permRequest) {
            val r = pendingResult
            val n = pendingName
            pendingResult = null
            pendingName = null
            r?.success(statusFor(n))
        }
    }

    // ---------- location ----------

    private fun fetchLocation(result: MethodChannel.Result) {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        var best: Location? = null
        try {
            for (p in lm.getProviders(true)) {
                val l = lm.getLastKnownLocation(p)
                if (l != null && (best == null || l.time > best!!.time)) best = l
            }
        } catch (e: SecurityException) {
            return result.error("NO_PERMISSION", "Location permission is not granted.", null)
        }
        val provider = when {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> null
        }
        fun reply(l: Location) = result.success(
            mapOf(
                "lat" to l.latitude,
                "lng" to l.longitude,
                "time" to l.time,
                "accuracy" to (if (l.hasAccuracy()) l.accuracy.toDouble() else null),
                "provider" to (l.provider ?: "unknown"),
            )
        )
        if (provider == null) {
            val b = best
            if (b != null) reply(b) else result.error(
                "LOCATION_OFF", "Location services are turned off. Turn them on in Android settings and try again.", null
            )
            return
        }
        val replied = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (replied.compareAndSet(false, true)) reply(location)
            }

            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }
        try {
            @Suppress("DEPRECATION")
            lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        } catch (e: SecurityException) {
            return result.error("NO_PERMISSION", "Location permission is not granted.", null)
        }
        handler.postDelayed({
            if (replied.compareAndSet(false, true)) {
                try { lm.removeUpdates(listener) } catch (_: Exception) {}
                val b = best
                if (b != null) reply(b) else result.error(
                    "NO_FIX", "No location fix yet. Try again outdoors or with a stronger signal.", null
                )
            }
        }, 15000)
    }
}
