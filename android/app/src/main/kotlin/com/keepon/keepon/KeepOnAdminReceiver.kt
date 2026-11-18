package com.keepon.keepon

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build

/** Device admin entry point. KEEPON only asks for the "lock screen" policy. */
class KeepOnAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        EventStore.add(
            context, "permissionUnavailable", "info",
            "Device admin was turned on. KEEPON can now lock the phone when an alarm triggers.",
            "Policy: lock screen only", false, "Lock available"
        )
    }

    override fun onDisabled(context: Context, intent: Intent) {
        EventStore.add(
            context, "permissionUnavailable", "attention",
            "Device admin was turned off. KEEPON can no longer lock the phone.",
            "Turned off in Android settings or by the owner", false, "Lock unavailable"
        )
    }

    /**
     * Wrong lock-screen code (needs the "watch login" policy). After 3 failed attempts while
     * protection is on, the protection service handles it like any trigger: entry delay,
     * alarm, optional lock and location. The owner unlocking in time cancels it.
     */
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        val prefs = Store.prefs(context)
        val count = try {
            AdminLock.failedAttempts(context)
        } catch (e: SecurityException) {
            0
        }
        EventStore.add(
            context, "pinFailed", "attention",
            "Wrong lock-screen code entered.",
            "Failed attempts since the last unlock: $count", false, "Recorded"
        )
        if (count < 3 || !prefs.getBoolean("armed", false) || AlarmPlayer.ringing) return
        try {
            val i = Intent(context, ProtectionService::class.java)
                .setAction(ProtectionService.ACTION_PIN_FAILED)
                .putExtra("count", count)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
        } catch (e: Exception) {
            // The service could not be reached: sound the alarm directly so it is not lost.
            val c = ProtectionService.parse(prefs.getString("config", null)) ?: return
            Session.begin(context, "pinFailed")
            val err = AlarmPlayer.start(context, c.sound, c.volume, c.vibrate, c.autoStop)
            EventStore.add(
                context, "pinFailed", "critical", "Three wrong lock-screen codes. Alarm started.",
                "Direct alarm (service unreachable)" + (if (err != null) " | $err" else ""), err == null,
                if (err == null) "Alarm active" else "ALARM FAILED"
            )
        }
    }
}

object AdminLock {
    fun component(ctx: Context) = ComponentName(ctx, KeepOnAdminReceiver::class.java)

    private fun dpm(ctx: Context) = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    /** Failed unlock attempts since the last successful one (needs the watch-login policy). */
    fun failedAttempts(ctx: Context): Int = dpm(ctx).currentFailedPasswordAttempts

    fun isActive(ctx: Context): Boolean = try {
        dpm(ctx).isAdminActive(component(ctx))
    } catch (e: Exception) {
        false
    }

    /** Locks the screen. Returns false when device admin is not enabled. */
    fun lock(ctx: Context): Boolean {
        if (!isActive(ctx)) return false
        return try {
            dpm(ctx).lockNow()
            true
        } catch (e: SecurityException) {
            false
        }
    }

    /** The owner removes KEEPON's admin rights (needed before uninstalling). */
    fun remove(ctx: Context) {
        try {
            dpm(ctx).removeActiveAdmin(component(ctx))
        } catch (_: Exception) {
        }
    }
}
