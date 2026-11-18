package com.keepon.keepon

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Queue of security events written natively (works while the Flutter UI is closed). */
object EventStore {
    private const val KEY = "pending_events"
    private const val MAX = 200
    private val lock = Any()

    @Volatile
    var onChanged: (() -> Unit)? = null

    private fun read(ctx: Context): JSONArray = try {
        JSONArray(Store.prefs(ctx).getString(KEY, "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    /** [status] is the security status at that moment, e.g. "Alarm active" or "Cancelled by owner". */
    fun add(
        ctx: Context, type: String, severity: String, description: String,
        detection: String, alarm: Boolean, status: String = "",
    ) {
        synchronized(lock) {
            val arr = read(ctx)
            val o = JSONObject()
            o.put("id", UUID.randomUUID().toString())
            o.put("type", type)
            o.put("ts", System.currentTimeMillis())
            o.put("severity", severity)
            o.put("description", description)
            o.put("detection", detection)
            o.put("alarm", alarm)
            o.put("status", status)
            arr.put(o)
            while (arr.length() > MAX) arr.remove(0)
            Store.prefs(ctx).edit().putString(KEY, arr.toString()).apply()
        }
        notifyChanged()
    }

    fun peek(ctx: Context): String = synchronized(lock) { read(ctx).toString() }

    fun ack(ctx: Context, ids: List<String>) {
        synchronized(lock) {
            val arr = read(ctx)
            val keep = JSONArray()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (!ids.contains(o.optString("id"))) keep.put(o)
            }
            Store.prefs(ctx).edit().putString(KEY, keep.toString()).apply()
        }
    }

    fun notifyChanged() {
        onChanged?.invoke()
    }
}
