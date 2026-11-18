package com.keepon.keepon

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * Records the phone's location while a protection session is active.
 *
 * - Uses Android's LocationManager (GPS and network providers).
 * - The first entry is the newest last-known fix, labelled "last_known"; later fixes are "live".
 * - Updates arrive when the phone moves (at most every 10 s / 5 m). A 60 s check re-records
 *   the newest last-known fix if no live fix arrived, so the log shows the phone is still reachable.
 * - Tracks connectivity: GPS keeps working offline; each entry says whether the phone was online.
 *   Android does not guarantee 1-second updates, so none are promised.
 */
class LocationTracker(private val ctx: Context) {
    private val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private var running = false
    @Volatile private var online = true
    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private var lastLiveAt = 0L

    private val listener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            lastLiveAt = System.currentTimeMillis()
            LocationLog.add(ctx, location, "live", online)
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    private val heartbeat = object : Runnable {
        override fun run() {
            if (!running) return
            if (System.currentTimeMillis() - lastLiveAt > 60_000) recordLastKnown()
            handler.postDelayed(this, 60_000)
        }
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return ctx.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ctx.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun recordLastKnown() {
        try {
            var best: Location? = null
            for (p in lm.getProviders(true)) {
                val l = lm.getLastKnownLocation(p)
                if (l != null && (best == null || l.time > best.time)) best = l
            }
            best?.let { LocationLog.add(ctx, it, "last_known", online) }
        } catch (_: SecurityException) {
        }
    }

    /** Returns null when tracking started, otherwise the reason it could not start. */
    fun start(): String? {
        if (running) return null
        if (!hasPermission()) return "Location permission is not granted."
        return try {
            recordLastKnown()
            var any = false
            for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (lm.isProviderEnabled(p)) {
                    lm.requestLocationUpdates(p, 10_000L, 5f, listener, Looper.getMainLooper())
                    any = true
                }
            }
            registerConnectivity()
            running = true
            handler.postDelayed(heartbeat, 60_000)
            if (any) null else "Location services are turned off, so only the last known location is recorded."
        } catch (e: SecurityException) {
            "Location permission is not granted."
        } catch (e: Exception) {
            e.message ?: "Location tracking could not start."
        }
    }

    fun stop() {
        if (!running) return
        running = false
        handler.removeCallbacks(heartbeat)
        try { lm.removeUpdates(listener) } catch (_: Exception) {}
        val cb = netCallback
        if (cb != null) {
            try {
                (ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(cb)
            } catch (_: Exception) {
            }
            netCallback = null
        }
    }

    private fun registerConnectivity() {
        if (Build.VERSION.SDK_INT < 24 || netCallback != null) return
        try {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val cb = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    if (!online) {
                        online = true
                        // Connectivity is back: network-assisted locations resume, so record a fresh point.
                        recordLastKnown()
                    }
                }

                override fun onLost(network: Network) {
                    online = false
                }
            }
            cm.registerDefaultNetworkCallback(cb)
            netCallback = cb
        } catch (_: Exception) {
        }
    }
}
