package com.keepon.keepon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper

/**
 * Reports a network drop: no active network for 20 s (4 polls, 5 s apart) or airplane mode
 * turned on. It reports ONCE per outage and re-arms when the network returns, so a long
 * outage does not create a stream of events. The alarm decision is made by
 * ProtectionService.trigger(), not here.
 */
class ConnectivityMonitor(
    private val ctx: Context,
    private val onDrop: (reason: String) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var missStreak = 0
    private var reported = false
    private var running = false
    private var registered = false

    @Suppress("DEPRECATION")
    private fun hasNetwork(): Boolean =
        if (Build.VERSION.SDK_INT >= 23) cm.activeNetwork != null
        else cm.activeNetworkInfo?.isConnected == true

    private fun report(reason: String) {
        if (reported) return
        reported = true
        onDrop(reason)
    }

    private val poll = object : Runnable {
        override fun run() {
            if (!running) return
            if (hasNetwork()) {
                missStreak = 0
                reported = false // network is back: a new outage can be reported
            } else {
                missStreak++
                if (missStreak >= 4) report("No active network for 20 s")
            }
            handler.postDelayed(this, 5_000L)
        }
    }

    private val airplane = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_AIRPLANE_MODE_CHANGED) return
            if (intent.getBooleanExtra("state", false)) report("Airplane mode turned on")
        }
    }

    fun start() {
        if (running) return
        running = true
        handler.post(poll)
        val f = IntentFilter(Intent.ACTION_AIRPLANE_MODE_CHANGED)
        if (Build.VERSION.SDK_INT >= 33) ctx.registerReceiver(airplane, f, Context.RECEIVER_EXPORTED)
        else ctx.registerReceiver(airplane, f)
        registered = true
    }

    fun stop() {
        if (!running) return
        running = false
        handler.removeCallbacks(poll)
        if (registered) {
            try { ctx.unregisterReceiver(airplane) } catch (_: Exception) {}
            registered = false
        }
    }
}
