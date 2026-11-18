package com.keepon.keepon

import android.content.Context
import android.location.Location
import org.json.JSONArray
import org.json.JSONObject

/**
 * Encrypted on-device log of locations recorded during a protection session.
 * Nothing in this file sends data anywhere.
 */
object LocationLog {
    private const val KEY = "loc_log"
    private const val MAX = 200
    private val lock = Any()

    private fun read(ctx: Context): JSONArray {
        val stored = Store.prefs(ctx).getString(KEY, null) ?: return JSONArray()
        val plain = SecureStore.decrypt(stored) ?: return JSONArray()
        return try { JSONArray(plain) } catch (e: Exception) { JSONArray() }
    }

    private fun write(ctx: Context, arr: JSONArray) {
        Store.prefs(ctx).edit().putString(KEY, SecureStore.encrypt(arr.toString())).apply()
    }

    /** kind = "live" (fresh fix) or "last_known" (older fix reported by Android). */
    fun add(ctx: Context, l: Location, kind: String, online: Boolean) {
        synchronized(lock) {
            try {
                val arr = read(ctx)
                // Skip an exact repeat of the previous fix.
                val last = if (arr.length() > 0) arr.getJSONObject(arr.length() - 1) else null
                if (last != null && last.optLong("time") == l.time && last.optString("provider") == (l.provider ?: "")) return
                val o = JSONObject()
                o.put("lat", l.latitude)
                o.put("lng", l.longitude)
                o.put("time", l.time)
                o.put("recorded", System.currentTimeMillis())
                o.put("accuracy", if (l.hasAccuracy()) l.accuracy.toDouble() else JSONObject.NULL)
                o.put("provider", l.provider ?: "unknown")
                o.put("kind", kind)
                o.put("online", online)
                arr.put(o)
                while (arr.length() > MAX) arr.remove(0)
                write(ctx, arr)
            } catch (e: Exception) {
                // A failed log write must never crash the protection service.
            }
        }
        EventStore.notifyChanged()
    }

    fun json(ctx: Context): String = synchronized(lock) { read(ctx).toString() }

    fun clear(ctx: Context) {
        synchronized(lock) { Store.prefs(ctx).edit().remove(KEY).apply() }
    }
}
