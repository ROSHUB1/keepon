package com.keepon.keepon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/**
 * Resumes protection after a reboot or an app update.
 *
 * It listens for LOCKED_BOOT_COMPLETED, which arrives BEFORE the owner unlocks the phone,
 * so a thief cannot switch protection off by restarting the phone. State is read from
 * device-protected storage (see [Store]). The service is a single instance, so repeated
 * boot signals never create duplicate services, and the alarm is only resumed by the
 * service when a saved protection session requires it.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        val prefs = Store.prefs(context)
        if (!prefs.getBoolean("armed", false)) return

        // Record each reboot once (LOCKED_BOOT_COMPLETED and BOOT_COMPLETED both arrive).
        val bootId = if (Build.VERSION.SDK_INT >= 24) {
            try { Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT) } catch (e: Exception) { -1 }
        } else -1
        val firstSignal = action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            bootId == -1 || prefs.getInt("last_boot", -2) != bootId

        val sessionActive = Session.isActive(context)
        try {
            val i = Intent(context, ProtectionService::class.java)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
            if (firstSignal) {
                prefs.edit().putInt("last_boot", bootId).apply()
                EventStore.add(
                    context, "serviceInterrupted", "attention",
                    if (action == Intent.ACTION_MY_PACKAGE_REPLACED) "KEEPON was updated. Protection resumed."
                    else "The phone restarted. KEEPON resumed protection.",
                    "Signal: ${action?.substringAfterLast('.')}",
                    false,
                    if (sessionActive) "Protection session resumed" else "Protection resumed"
                )
            }
        } catch (e: Exception) {
            if (firstSignal) {
                EventStore.add(
                    context, "serviceInterrupted", "attention",
                    "The phone restarted but protection could not resume. Open KEEPON to turn it on again.",
                    e.message ?: "Unknown error", false, "Protection NOT running"
                )
            }
        }
    }
}
