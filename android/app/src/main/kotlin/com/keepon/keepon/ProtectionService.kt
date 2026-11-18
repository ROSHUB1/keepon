package com.keepon.keepon

import android.Manifest
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.telephony.TelephonyManager
import org.json.JSONObject
import kotlin.math.sqrt

class ProtectionService : Service(), SensorEventListener {

    data class Mod(val enabled: Boolean, val alarm: Boolean, val sensitivity: String)
    data class Cfg(
        val motion: Mod, val charger: Mod, val headphones: Mod, val sim: Mod, val connectivity: Mod,
        val sound: String, val volume: Int, val vibrate: Boolean, val autoStop: Int,
        val entryDelay: Int, val ignoreUnlocked: Boolean, val lockOnAlarm: Boolean, val trackLocation: Boolean,
        val tamperAlarm: Boolean,
        val notifySecurity: Boolean, val notifyAlarm: Boolean, val requireAuth: Boolean,
    )

    companion object {
        const val EXTRA_CONFIG = "config"
        const val EXTRA_WATCHDOG = "watchdog"
        const val ACTION_PIN_FAILED = "com.keepon.keepon.PIN_FAILED"
        const val ACTION_TEST = "com.keepon.keepon.TEST_ALARM"
        const val ACTION_STOP_ALARM = "com.keepon.keepon.STOP_ALARM"
        const val ID_ALARM = 2
        private const val CH_STATUS = "keepon_status"
        private const val CH_ALERTS = "keepon_alerts"
        private const val ID_STATUS = 1
        private const val ARM_DELAY_MS = 10_000L
        private const val COOLDOWN_MS = 30_000L
        private const val CHARGER_CONFIRM_MS = 2_000L

        @Volatile
        var running = false

        fun setArmed(ctx: Context, armed: Boolean) {
            Store.prefs(ctx).edit().putBoolean("armed", armed).apply()
        }

        private fun mod(o: JSONObject, key: String): Mod {
            val m = o.optJSONObject(key)
            return Mod(
                m?.optBoolean("enabled", false) ?: false,
                m?.optBoolean("alarm", true) ?: true,
                m?.optString("sensitivity", "medium") ?: "medium",
            )
        }

        fun parse(json: String?): Cfg? {
            if (json == null) return null
            return try {
                val o = JSONObject(json)
                val a = o.optJSONObject("alarm")
                Cfg(
                    mod(o, "motion"), mod(o, "charger"), mod(o, "headphones"), mod(o, "sim"), mod(o, "connectivity"),
                    a?.optString("sound", "siren") ?: "siren",
                    a?.optInt("volume", 70) ?: 70,
                    a?.optBoolean("vibrate", true) ?: true,
                    a?.optInt("autoStop", 60) ?: 60,
                    a?.optInt("entryDelay", 5) ?: 5,
                    a?.optBoolean("ignoreOwnerPresent", false) ?: false,
                    a?.optBoolean("lockOnAlarm", false) ?: false,
                    a?.optBoolean("trackLocation", true) ?: true,
                    a?.optBoolean("tamperAlarm", false) ?: false,
                    o.optBoolean("notifySecurity", true),
                    o.optBoolean("notifyAlarm", true),
                    o.optBoolean("requireAuth", true),
                )
            } catch (e: Exception) {
                null
            }
        }
    }

    private var cfg: Cfg? = null
    private val prefs by lazy { Store.prefs(this) }
    private val handler = Handler(Looper.getMainLooper())
    private var notifCounter = 100
    private var connMonitor: ConnectivityMonitor? = null

    // Motion
    private var sensorManager: SensorManager? = null
    private var sensorRegistered = false
    private var wakeLock: PowerManager.WakeLock? = null
    private val gravity = FloatArray(3)
    private var armedAt = 0L
    private var lastTrigger = 0L
    private var hits = 0
    private var firstHit = 0L

    // Receivers
    private var powerRegistered = false
    private var simRegistered = false
    private var audioRegistered = false
    private var userRegistered = false
    private var lastHeadphoneEvent = 0L
    private val simState = HashMap<Int, String>()

    // Response state
    private var pendingFire: Runnable? = null
    private var pendingCharger: Runnable? = null
    private var tracker: LocationTracker? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ALARM) {
            AlarmPlayer.stop(this, "Stopped from the notification")
            return START_STICKY
        }

        try {
            enterForeground("Starting protection")
        } catch (e: Exception) {
            EventStore.add(
                this, "serviceInterrupted", "attention",
                "Android did not allow the monitoring service to start.", e.message ?: "", false, "Protection NOT running"
            )
            stopSelf()
            return START_NOT_STICKY
        }
        val json = intent?.getStringExtra(EXTRA_CONFIG)
        if (json != null) {
            prefs.edit().putString("config", json).putBoolean("armed", true).apply()
        }
        val parsed = parse(prefs.getString("config", null))
        if (parsed == null || !prefs.getBoolean("armed", false)) {
            stopSelf()
            return START_NOT_STICKY
        }
        val firstStart = !running
        cfg = parsed
        Session.onEnded = { handler.post { stopTracking() } }
        // Re-apply detectors only when needed (new config, first start, or a system restart),
        // so a watchdog or PIN signal does not reset the motion arming delay.
        if (json != null || firstStart || intent == null) applyConfig(parsed)
        running = true

        // Two watchdog signals: a 30 s alarm and a 15 min WorkManager job.
        WatchdogAlarmReceiver.scheduleNext(this)
        TamperWatchdogWorker.schedule(this)

        // A saved session means an alarm was active before a restart or process death: bring it
        // back once. AlarmPlayer.ringing prevents a second alarm instance.
        if (Session.isActive(this) && !AlarmPlayer.ringing) resumeSession()

        if (intent?.getBooleanExtra(EXTRA_WATCHDOG, false) == true) onWatchdogRestart(parsed, firstStart)
        if (intent?.action == ACTION_TEST) {
            // Drill from KEEPON settings: runs the real alarm path (siren, notification, full-screen alarm).
            fire(
                "motionDetected", "Test alarm: this is a drill.",
                "Started from KEEPON settings", Mod(true, true, "medium"), "Alarm active (test)"
            )
        }
        if (intent?.action == ACTION_PIN_FAILED) {
            val n = intent?.getIntExtra("count", 0) ?: 0
            trigger(
                "pinFailed", "Wrong lock-screen code entered $n times.",
                "Failed attempts since the last unlock: $n", Mod(true, true, "medium"), force = true
            )
        }
        return START_STICKY
    }

    override fun onDestroy() {
        teardown()
        pendingFire?.let { handler.removeCallbacks(it) }
        pendingCharger?.let { handler.removeCallbacks(it) }
        pendingFire = null
        pendingCharger = null
        stopTracking()

        // Cancel the watchdogs only when the owner turned protection off.
        if (!prefs.getBoolean("armed", false)) {
            WatchdogAlarmReceiver.cancel(this)
            TamperWatchdogWorker.cancel(this)
        }

        AlarmPlayer.stop(this)
        Session.onEnded = null
        running = false
        super.onDestroy()
    }

    private fun channels() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CH_STATUS, "Protection status", NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(NotificationChannel(CH_ALERTS, "Security alerts", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    @Suppress("DEPRECATION")
    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)

    private fun openAppIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun statusNotification(text: String): Notification =
        builder(CH_STATUS)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("KEEPON protection is on")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(openAppIntent())
            .build()

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun enterForeground(text: String) {
        channels()
        val n = statusNotification(text)
        val withLocation = hasLocationPermission()
        if (Build.VERSION.SDK_INT >= 34) {
            var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            if (withLocation) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            try {
                startForeground(ID_STATUS, n, type)
            } catch (e: SecurityException) {
                startForeground(ID_STATUS, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            }
        } else if (Build.VERSION.SDK_INT >= 29 && withLocation) {
            try {
                startForeground(ID_STATUS, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } catch (e: SecurityException) {
                startForeground(ID_STATUS, n)
            }
        } else {
            startForeground(ID_STATUS, n)
        }
    }

    private fun updateStatus(c: Cfg) {
        val names = mutableListOf<String>()
        if (c.motion.enabled) names.add("Motion")
        if (c.charger.enabled) names.add("Charger")
        if (c.headphones.enabled) names.add("Headphones")
        if (c.sim.enabled) names.add("SIM")
        if (c.connectivity.enabled) names.add("Network")
        var text = if (names.isEmpty()) "No modules enabled" else "Watching: " + names.joinToString(", ")
        if (Session.isActive(this)) text = "Alarm session active. $text"
        getSystemService(NotificationManager::class.java).notify(ID_STATUS, statusNotification(text))
    }

    private fun postAlert(text: String, withStop: Boolean) {
        val b = builder(CH_ALERTS)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(if (withStop) "KEEPON alarm" else "KEEPON alert")
            .setContentText(text)
            .setAutoCancel(!withStop)
            .setContentIntent(openAppIntent())
        if (withStop) {
            val stop = PendingIntent.getService(
                this, 1,
                Intent(this, ProtectionService::class.java).setAction(ACTION_STOP_ALARM),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            if (Build.VERSION.SDK_INT >= 31) {
                val action = Notification.Action.Builder(
                    android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_media_pause),
                    "Stop alarm", stop
                ).setAuthenticationRequired(cfg?.requireAuth ?: true).build()
                b.addAction(action)
            } else {
                @Suppress("DEPRECATION")
                b.addAction(android.R.drawable.ic_media_pause, "Stop alarm", stop)
            }
            b.setOngoing(true)
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            if (launch != null) {
                launch.putExtra("alarm", true)
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val alarmPi = PendingIntent.getActivity(
                    this, 3, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                b.setContentIntent(alarmPi)
                b.setFullScreenIntent(alarmPi, true)
            }
        }
        val id = if (withStop) ID_ALARM else notifCounter++
        try {
            getSystemService(NotificationManager::class.java).notify(id, b.build())
        } catch (_: Exception) {
        }
    }

    private fun registerCompat(r: BroadcastReceiver, f: IntentFilter) {
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(r, f, Context.RECEIVER_EXPORTED) else registerReceiver(r, f)
    }

    private fun teardown() {
        connMonitor?.stop()
        connMonitor = null
        if (sensorRegistered) {
            sensorManager?.unregisterListener(this)
            sensorRegistered = false
        }
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        wakeLock = null
        if (powerRegistered) {
            try { unregisterReceiver(powerReceiver) } catch (_: Exception) {}
            powerRegistered = false
        }
        if (simRegistered) {
            try { unregisterReceiver(simReceiver) } catch (_: Exception) {}
            simRegistered = false
        }
        if (userRegistered) {
            try { unregisterReceiver(userReceiver) } catch (_: Exception) {}
            userRegistered = false
        }
        if (audioRegistered) {
            try {
                (getSystemService(Context.AUDIO_SERVICE) as AudioManager).unregisterAudioDeviceCallback(audioCallback)
            } catch (_: Exception) {
            }
            audioRegistered = false
        }
    }

    private fun applyConfig(c: Cfg) {
        teardown()
        updateStatus(c)

        registerCompat(userReceiver, IntentFilter(Intent.ACTION_USER_PRESENT))
        userRegistered = true

        if (c.motion.enabled) {
            val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            sensorManager = sm
            val accel = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            if (accel != null) {
                gravity.fill(0f)
                hits = 0
                armedAt = SystemClock.elapsedRealtime()
                try {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "keepon:motion").also { it.acquire() }
                } catch (_: Exception) {
                }
                sensorRegistered = sm.registerListener(this, accel, SensorManager.SENSOR_DELAY_NORMAL)
                if (!sensorRegistered) {
                    EventStore.add(
                        this, "serviceInterrupted", "attention",
                        "Motion detection could not start.", "The accelerometer could not be registered.", false, "Motion NOT monitored"
                    )
                }
            } else {
                EventStore.add(
                    this, "permissionUnavailable", "attention",
                    "Motion detection is unavailable on this phone.", "No accelerometer reported by Android.", false, "Motion NOT monitored"
                )
            }
        }

        if (c.charger.enabled) {
            val f = IntentFilter().apply {
                addAction(Intent.ACTION_POWER_DISCONNECTED)
                addAction(Intent.ACTION_POWER_CONNECTED)
            }
            registerCompat(powerReceiver, f)
            powerRegistered = true
        }

        if (c.headphones.enabled && Build.VERSION.SDK_INT >= 23) {
            (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                .registerAudioDeviceCallback(audioCallback, Handler(Looper.getMainLooper()))
            audioRegistered = true
        }

        if (c.sim.enabled && packageManager.hasSystemFeature("android.hardware.telephony")) {
            simState.clear()
            try {
                val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                val slots = if (Build.VERSION.SDK_INT >= 23) maxOf(tm.phoneCount, 1) else 1
                for (i in 0 until slots) {
                    val s = if (Build.VERSION.SDK_INT >= 26) tm.getSimState(i) else tm.simState
                    classifyInt(s)?.let { simState[i] = it }
                }
            } catch (_: Exception) {
            }
            registerCompat(simReceiver, IntentFilter("android.intent.action.SIM_STATE_CHANGED"))
            simRegistered = true
        }

        // Network connectivity module
        if (c.connectivity.enabled) {
            val monitor = ConnectivityMonitor(this) { reason ->
                trigger(
                    "connectivityLost", "The phone lost network connection.",
                    reason, c.connectivity
                )
            }
            monitor.start()
            connMonitor = monitor
        }
    }

    private fun ownerPresent(): Boolean {
        return try {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isInteractive && !km.isKeyguardLocked
        } catch (e: Exception) {
            false
        }
    }

    private fun trigger(type: String, description: String, detection: String, mod: Mod, force: Boolean = false) {
        val c = cfg ?: return
        if (!mod.enabled) return
        if (Session.isActive(this) && AlarmPlayer.ringing) {
            EventStore.add(this, type, "critical", description, detection, false, "Alarm already active")
            return
        }
        if (!force && c.ignoreUnlocked && ownerPresent()) {
            EventStore.add(this, type, "info", description, "$detection | The phone was unlocked and in use", false, "Ignored: owner present")
            return
        }
        if (pendingFire != null) return
        if (c.entryDelay > 0 && mod.alarm) {
            val r = Runnable {
                pendingFire = null
                fire(type, description, detection, mod, "Alarm active (entry delay ended)")
            }
            pendingFire = r
            EventStore.add(
                this, type, "attention", description, detection, false,
                "Entry delay ${c.entryDelay}s: unlock the phone to cancel"
            )
            handler.postDelayed(r, c.entryDelay * 1000L)
        } else {
            fire(type, description, detection, mod, "Alarm active")
        }
    }

    private fun cancelPending(reason: String) {
        val r = pendingFire ?: return
        handler.removeCallbacks(r)
        pendingFire = null
        EventStore.add(
            this, "alarmCancelled", "info", "The alarm was cancelled before it started.", reason, false, "Cancelled by owner"
        )
    }

    private fun fire(type: String, description: String, detection: String, mod: Mod, status: String) {
        val c = cfg ?: return
        if (!mod.alarm) {
            EventStore.add(this, type, "critical", description, detection, false, "Recorded only (alarm is off for this module)")
            return
        }
        Session.begin(this, type)
        var detail = detection
        var st = status
        val err = AlarmPlayer.start(this, c.sound, c.volume, c.vibrate, c.autoStop)
        val alarmOk = err == null
        if (!alarmOk) {
            detail += " | Alarm failed: $err"
            st += " · ALARM FAILED"
        }
        if (c.lockOnAlarm) {
            st += if (AdminLock.lock(this)) " · Phone locked" else " · Lock unavailable (device admin is off)"
        }
        if (c.trackLocation) startTracking()
        EventStore.add(this, type, "critical", description, detail, alarmOk, st)
        updateStatus(c)
        if (alarmOk && c.notifyAlarm) postAlert(description, true)
        else if (c.notifySecurity) postAlert(description, false)
    }

    private fun resumeSession() {
        val c = cfg ?: return
        val err = AlarmPlayer.start(this, c.sound, c.volume, c.vibrate, c.autoStop)
        if (c.trackLocation) startTracking()
        if (err == null) {
            if (c.notifyAlarm) postAlert("The alarm is active again after a restart.", true)
            EventStore.add(this, "serviceInterrupted", "attention", "The alarm session resumed.", "Resumed from saved state", true, "Alarm active")
        } else {
            EventStore.add(this, "serviceInterrupted", "attention", "The alarm could not resume.", err, false, "ALARM FAILED")
        }
        updateStatus(c)
    }

    private fun startTracking() {
        val t = tracker ?: LocationTracker(applicationContext).also { tracker = it }
        val err = t.start()
        if (err != null) {
            EventStore.add(
                this, "permissionUnavailable", "attention",
                "Location could not be recorded during the alarm.", err, false, "Location NOT recording"
            )
        }
    }

    private fun stopTracking() {
        tracker?.stop()
    }

    /** The service was found stopped while protection was on and has been restarted. */
    private fun onWatchdogRestart(c: Cfg, wasDown: Boolean) {
        if (!wasDown) return
        EventStore.add(
            this, "tamperDetected", if (c.tamperAlarm) "critical" else "attention",
            "KEEPON protection was stopped while it was on, and was restarted.",
            "Restarted by the watchdog", false,
            if (c.tamperAlarm) "Checking whether to sound the alarm" else "Restarted"
        )
        // Opt-in: goes through the normal checks (owner present, entry delay).
        if (c.tamperAlarm) {
            trigger(
                "tamperDetected", "KEEPON protection was stopped while it was on.",
                "Restarted by the watchdog", Mod(true, true, "medium")
            )
        }
    }

    private val userReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_USER_PRESENT) {
                cancelPending("The owner unlocked the phone during the entry delay.")
            }
        }
    }

    override fun onSensorChanged(e: SensorEvent) {
        val c = cfg ?: return
        if (e.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val a = 0.8f
        for (i in 0..2) gravity[i] = a * gravity[i] + (1 - a) * e.values[i]
        val lx = e.values[0] - gravity[0]
        val ly = e.values[1] - gravity[1]
        val lz = e.values[2] - gravity[2]
        val mag = sqrt(lx * lx + ly * ly + lz * lz)
        val now = SystemClock.elapsedRealtime()
        if (now - armedAt < ARM_DELAY_MS) return
        if (now - lastTrigger < COOLDOWN_MS) return
        val threshold = when (c.motion.sensitivity) {
            "low" -> 4.0f
            "high" -> 1.5f
            else -> 2.5f
        }
        if (mag > threshold) {
            if (hits == 0 || now - firstHit > 1500) {
                hits = 1
                firstHit = now
            } else {
                hits++
            }
            if (hits >= 3) {
                hits = 0
                lastTrigger = now
                trigger(
                    "motionDetected", "Your phone was moved.",
                    "Motion %.1f m/s² (threshold %.1f, sensitivity %s)".format(mag, threshold, c.motion.sensitivity),
                    c.motion
                )
            }
        } else if (hits > 0 && now - firstHit > 1500) {
            hits = 0
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private val powerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val c = cfg ?: return
            if (!c.charger.enabled) return
            when (intent.action) {
                Intent.ACTION_POWER_DISCONNECTED -> {
                    if (pendingCharger != null) return
                    val r = Runnable {
                        pendingCharger = null
                        trigger(
                            "chargerDisconnected", "The charger was unplugged.",
                            "Power stayed disconnected for 2 s.", c.charger
                        )
                    }
                    pendingCharger = r
                    handler.postDelayed(r, CHARGER_CONFIRM_MS)
                }
                Intent.ACTION_POWER_CONNECTED -> {
                    val r = pendingCharger ?: return
                    handler.removeCallbacks(r)
                    pendingCharger = null
                    EventStore.add(
                        context, "chargerDisconnected", "info", "The charger reconnected within 2 seconds.",
                        "Treated as a loose cable, not theft", false, "Ignored: reconnected"
                    )
                }
            }
        }
    }

    private fun isHeadphone(d: AudioDeviceInfo): Boolean {
        if (!d.isSink) return false
        return when (d.type) {
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            26 -> true
            else -> false
        }
    }

    private fun kindOf(d: AudioDeviceInfo): String = when (d.type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLUETOOTH_SCO, 26 -> "Bluetooth"
        AudioDeviceInfo.TYPE_USB_HEADSET -> "USB"
        else -> "Wired"
    }

    private val audioCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            val c = cfg ?: return
            if (!c.headphones.enabled || removedDevices == null) return
            val gone = removedDevices.firstOrNull { isHeadphone(it) } ?: return
            val now = SystemClock.elapsedRealtime()
            if (now - lastHeadphoneEvent < 2000) return
            lastHeadphoneEvent = now
            trigger(
                "headphonesDisconnected", "Headphones were disconnected.",
                "${kindOf(gone)} device removed: ${gone.productName}", c.headphones
            )
        }
    }

    private fun classify(ss: String?): String? = when (ss) {
        "ABSENT" -> "absent"
        "LOCKED", "PIN_REQUIRED", "PUK_REQUIRED", "NETWORK_LOCKED" -> "locked"
        "READY", "LOADED", "IMSI" -> "present"
        else -> null
    }

    private fun classifyInt(s: Int): String? = when (s) {
        TelephonyManager.SIM_STATE_ABSENT -> "absent"
        TelephonyManager.SIM_STATE_PIN_REQUIRED,
        TelephonyManager.SIM_STATE_PUK_REQUIRED,
        TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "locked"
        TelephonyManager.SIM_STATE_READY -> "present"
        else -> null
    }

    private val simReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val c = cfg ?: return
            if (!c.sim.enabled) return
            val slot = intent.getIntExtra("slot", intent.getIntExtra("phone", 0))
            val now = classify(intent.getStringExtra("ss")) ?: return
            val before = simState[slot]
            simState[slot] = now
            if (before == null || before == now) return
            val detection = "SIM slot ${slot + 1}: $before -> $now"
            when (now) {
                "absent" -> trigger("simStateChanged", "The SIM card was removed (slot ${slot + 1}).", detection, c.sim, force = true)
                "locked" -> EventStore.add(context, "simStateChanged", "attention", "The SIM card is locked (slot ${slot + 1}).", detection, false, "Recorded")
                else -> EventStore.add(context, "simStateChanged", "attention", "A SIM card is ready (slot ${slot + 1}).", detection, false, "Recorded")
            }
        }
    }
}
