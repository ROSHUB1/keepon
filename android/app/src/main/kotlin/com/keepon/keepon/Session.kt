package com.keepon.keepon

import android.content.Context

/**
 * An active protection session starts when a confirmed trigger fires and ends only when
 * the owner stops it (or turns protection off). It is saved to storage, so it survives
 * process death and reboots.
 */
object Session {
    private const val ACTIVE = "session_active"
    private const val STARTED = "session_started"
    private const val REASON = "session_reason"

    /** Called when a session ends (the service stops location tracking). */
    @Volatile
    var onEnded: (() -> Unit)? = null

    fun isActive(ctx: Context): Boolean = Store.prefs(ctx).getBoolean(ACTIVE, false)

    fun begin(ctx: Context, reason: String) {
        val p = Store.prefs(ctx)
        if (p.getBoolean(ACTIVE, false)) return
        p.edit().putBoolean(ACTIVE, true).putLong(STARTED, System.currentTimeMillis()).putString(REASON, reason).apply()
    }

    fun info(ctx: Context): Map<String, Any?> {
        val p = Store.prefs(ctx)
        val active = p.getBoolean(ACTIVE, false)
        return mapOf(
            "active" to active,
            "started" to (if (active) p.getLong(STARTED, 0L) else null),
            "reason" to (if (active) p.getString(REASON, "") else null),
        )
    }

    /** Ends the session and records who/what ended it. No-op when no session is active. */
    fun end(ctx: Context, source: String) {
        val p = Store.prefs(ctx)
        if (!p.getBoolean(ACTIVE, false)) return
        p.edit().remove(ACTIVE).remove(STARTED).remove(REASON).apply()
        EventStore.add(
            ctx, "alarmStopped", "info",
            "The alarm and protection session ended.", source, false, "Session ended"
        )
        onEnded?.invoke()
    }
}
