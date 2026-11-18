package com.keepon.keepon

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Watchdog: every 30 s an AlarmManager alarm checks whether the protection service is still
 * running while protection is on. If not, it restarts the service with EXTRA_WATCHDOG.
 * The service then re-applies all detectors and records a "tamper" event. Whether that also
 * sounds an alarm is the owner's choice (Settings > "Alarm if KEEPON is stopped"), because
 * Android itself sometimes ends background processes and that must not cause false alarms.
 *
 * Android limits: exact alarms need the "Alarms & reminders" permission on Android 13+
 * (otherwise a slightly less precise alarm is used), Doze can delay alarms, and a
 * "Force stop" from Android settings cancels all alarms until KEEPON is opened again.
 */
class WatchdogAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ctx = context.applicationContext
        if (!Store.prefs(ctx).getBoolean("armed", false)) return

        if (!ProtectionService.running) {
            val i = Intent(ctx, ProtectionService::class.java)
                .putExtra(ProtectionService.EXTRA_WATCHDOG, true)
            try {
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } catch (e: Exception) {
                EventStore.add(
                    ctx, "tamperDetected", "attention",
                    "KEEPON could not restart its protection service.",
                    e.message ?: "Watchdog restart failed", false, "Protection NOT running"
                )
            }
        }
        scheduleNext(ctx)
    }

    companion object {
        private const val REQ = 7741
        private const val INTERVAL_MS = 30_000L

        private fun pending(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
            ctx, REQ,
            Intent(ctx, WatchdogAlarmReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        fun scheduleNext(ctx: Context) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = pending(ctx)
            val next = System.currentTimeMillis() + INTERVAL_MS
            try {
                if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
                }
            } catch (_: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
            }
        }

        fun cancel(ctx: Context) {
            (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(ctx))
        }
    }
}
