package com.keepon.keepon

import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * KEEPON alarm.
 *
 * Sound "siren" (default) is the synthesized security siren from [SirenSynth], played with
 * AudioTrack on the alarm stream. The other sounds ("alarm", "ringtone", "notification") are
 * Android's own sounds and are kept as options.
 *
 * Reliability:
 *  - requests audio focus; losing it (call, other app) never silences the alarm, it is resumed
 *  - a watchdog checks playback every 1.5 s and restarts it; after repeated failures it falls
 *    back to the system alarm tone and records an event
 *  - the alarm is routed to the built-in speaker even if headphones/Bluetooth are connected
 *  - the user's own alarm volume is restored when the alarm stops
 *  - the volume follows the user's setting (never raised above the phone's alarm maximum)
 */
object AlarmPlayer {
    @Volatile
    var ringing = false
        private set

    private var track: AudioTrack? = null
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var previousVolume = -1
    private var focusRequest: AudioFocusRequest? = null
    private var focusListener: AudioManager.OnAudioFocusChangeListener? = null
    private var deviceCallback: AudioDeviceCallback? = null
    private var appCtx: Context? = null
    private var sound = "siren"
    private var vibrate = true
    private var failures = 0
    private var usingFallback = false
    private val handler = Handler(Looper.getMainLooper())
    private var stopRunnable: Runnable? = null
    private var watchdog: Runnable? = null

    private fun attrs(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    /** Starts (or restarts) the alarm. Returns null on success, or an error message. */
    @Synchronized
    fun start(ctx: Context, soundKey: String, volumePercent: Int, vibrate: Boolean, autoStopSeconds: Int): String? {
        val app = ctx.applicationContext
        halt(app)
        appCtx = app
        sound = soundKey
        this.vibrate = vibrate
        failures = 0
        usingFallback = false
        val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            if (previousVolume < 0) previousVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            am.setStreamVolume(AudioManager.STREAM_ALARM, (max * volumePercent / 100).coerceIn(1, max), 0)
        } catch (_: Exception) {
            // Some phones restrict volume changes in Do Not Disturb; play at the current volume.
        }
        requestFocus(am)

        var err = if (soundKey == "siren") startSiren(app) else startSystemTone(app, soundKey)
        if (err != null && soundKey == "siren") {
            // Siren playback failed: fall back to the system alarm tone.
            usingFallback = true
            err = startSystemTone(app, "alarm")
        }
        if (err != null) {
            halt(app)
            return err
        }
        if (vibrate) startVibration(app)
        ringing = true
        if (autoStopSeconds > 0) {
            val r = Runnable { stop(app, "Auto-stop timer ended") }
            stopRunnable = r
            handler.postDelayed(r, autoStopSeconds * 1000L)
        }
        startWatchdog()
        registerDeviceCallback(am)
        EventStore.notifyChanged()
        return null
    }

    // ---------- siren ----------

    private fun startSiren(app: Context): String? {
        return try {
            val pcm = SirenSynth.cycle()
            val bytes = pcm.size * 2
            val t = if (Build.VERSION.SDK_INT >= 23) {
                AudioTrack.Builder()
                    .setAudioAttributes(attrs())
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(SirenSynth.SAMPLE_RATE)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(bytes)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                AudioTrack(
                    AudioManager.STREAM_ALARM, SirenSynth.SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, bytes, AudioTrack.MODE_STATIC
                )
            }
            t.write(pcm, 0, pcm.size)
            t.setLoopPoints(0, pcm.size, -1)
            preferSpeaker(app, t)
            t.play()
            track = t
            null
        } catch (e: Exception) {
            e.message ?: "Siren playback failed."
        }
    }

    /** Keeps the alarm on the phone speaker, even when headphones or Bluetooth are connected. */
    private fun preferSpeaker(app: Context, t: AudioTrack) {
        if (Build.VERSION.SDK_INT < 23) return
        try {
            val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val speaker = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            if (speaker != null) t.setPreferredDevice(speaker)
        } catch (_: Exception) {
        }
    }

    private fun registerDeviceCallback(am: AudioManager) {
        if (Build.VERSION.SDK_INT < 23) return
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                val ctx = appCtx ?: return
                track?.let { preferSpeaker(ctx, it) }
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                ensurePlaying()
            }
        }
        deviceCallback = cb
        am.registerAudioDeviceCallback(cb, handler)
    }

    // ---------- system tones (fallback and options) ----------

    private fun startSystemTone(app: Context, key: String): String? {
        return try {
            val type = when (key) {
                "ringtone" -> RingtoneManager.TYPE_RINGTONE
                "notification" -> RingtoneManager.TYPE_NOTIFICATION
                else -> RingtoneManager.TYPE_ALARM
            }
            val uri = RingtoneManager.getDefaultUri(type)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: return "No alarm sound is available on this phone."
            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs())
            mp.setDataSource(app, uri)
            mp.isLooping = true
            mp.prepare()
            mp.start()
            player = mp
            null
        } catch (e: Exception) {
            e.message ?: "System alarm sound failed."
        }
    }

    // ---------- audio focus ----------

    @Suppress("DEPRECATION")
    private fun requestFocus(am: AudioManager) {
        val listener = AudioManager.OnAudioFocusChangeListener { ensurePlaying() }
        focusListener = listener
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(attrs())
                    .setOnAudioFocusChangeListener(listener, handler)
                    .setWillPauseWhenDucked(false)
                    .build()
                focusRequest = req
                am.requestAudioFocus(req)
            } else {
                am.requestAudioFocus(listener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            }
        } catch (_: Exception) {
        }
    }

    @Suppress("DEPRECATION")
    private fun abandonFocus(app: Context) {
        try {
            val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= 26) {
                focusRequest?.let { am.abandonAudioFocusRequest(it) }
            } else {
                focusListener?.let { am.abandonAudioFocus(it) }
            }
        } catch (_: Exception) {
        }
        focusRequest = null
        focusListener = null
    }

    // ---------- watchdog ----------

    private fun startWatchdog() {
        val w = object : Runnable {
            override fun run() {
                if (!ringing) return
                ensurePlaying()
                handler.postDelayed(this, 1500)
            }
        }
        watchdog = w
        handler.postDelayed(w, 1500)
    }

    /** Resumes playback after an interruption; falls back to the system tone if it keeps failing. */
    @Synchronized
    private fun ensurePlaying() {
        if (!ringing) return
        val app = appCtx ?: return
        var healthy = true
        try {
            val t = track
            if (t != null && t.playState != AudioTrack.PLAYSTATE_PLAYING) {
                healthy = false
                t.play()
                healthy = t.playState == AudioTrack.PLAYSTATE_PLAYING
            }
            val m = player
            if (m != null && !m.isPlaying) {
                healthy = false
                m.start()
                healthy = m.isPlaying
            }
        } catch (_: Exception) {
            healthy = false
        }
        if (healthy) {
            failures = 0
            return
        }
        failures++
        if (failures >= 3 && !usingFallback) {
            usingFallback = true
            releasePlayers()
            val err = startSystemTone(app, "alarm")
            EventStore.add(
                app, "serviceInterrupted", "attention",
                "The siren stopped playing, so KEEPON switched to the phone's alarm sound.",
                err ?: "Fallback alarm sound started", false, "Alarm still active"
            )
            failures = 0
        } else if (failures >= 6) {
            EventStore.add(
                app, "serviceInterrupted", "attention",
                "The alarm could not keep playing.", "Repeated playback failures", false, "Alarm failed"
            )
            failures = 0
        }
    }

    // ---------- vibration ----------

    @Suppress("DEPRECATION")
    private fun startVibration(app: Context) {
        try {
            val vib = if (Build.VERSION.SDK_INT >= 31) {
                (app.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                app.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val pattern = longArrayOf(0, 500, 250)
            if (Build.VERSION.SDK_INT >= 26) vib.vibrate(VibrationEffect.createWaveform(pattern, 0)) else vib.vibrate(pattern, 0)
            vibrator = vib
        } catch (_: Exception) {
        }
    }

    // ---------- stopping ----------

    private fun releasePlayers() {
        try { track?.stop() } catch (_: Exception) {}
        try { track?.release() } catch (_: Exception) {}
        track = null
        try { player?.stop() } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
    }

    /** Stops sound, vibration, focus and callbacks. Does NOT end the protection session. */
    @Synchronized
    private fun halt(app: Context) {
        stopRunnable?.let { handler.removeCallbacks(it) }
        stopRunnable = null
        watchdog?.let { handler.removeCallbacks(it) }
        watchdog = null
        releasePlayers()
        try { vibrator?.cancel() } catch (_: Exception) {}
        vibrator = null
        if (Build.VERSION.SDK_INT >= 23) {
            deviceCallback?.let {
                try {
                    (app.getSystemService(Context.AUDIO_SERVICE) as AudioManager).unregisterAudioDeviceCallback(it)
                } catch (_: Exception) {
                }
            }
        }
        deviceCallback = null
        abandonFocus(app)
        if (previousVolume >= 0) {
            try {
                (app.getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                    .setStreamVolume(AudioManager.STREAM_ALARM, previousVolume, 0)
            } catch (_: Exception) {
            }
            previousVolume = -1
        }
        val was = ringing
        ringing = false
        try {
            (app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ProtectionService.ID_ALARM)
        } catch (_: Exception) {
        }
        if (was) EventStore.notifyChanged()
    }

    /**
     * Stops the alarm. When [endSessionSource] is given, the protection session is also ended
     * and that source is recorded (use it for authorized stops by the owner).
     */
    @Synchronized
    fun stop(ctx: Context, endSessionSource: String? = null) {
        val app = ctx.applicationContext
        halt(app)
        if (endSessionSource != null) Session.end(app, endSessionSource)
    }
}
