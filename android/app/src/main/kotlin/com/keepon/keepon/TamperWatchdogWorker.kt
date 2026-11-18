package com.keepon.keepon

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Second watchdog signal: a WorkManager job every 15 minutes (the minimum Android allows).
 * It is only scheduled while protection is on, and does the same thing as the alarm
 * watchdog: restart the service if it is not running. It is a backstop for phones where
 * the 30 s alarm is delayed or blocked.
 */
class TamperWatchdogWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        if (!Store.prefs(ctx).getBoolean("armed", false)) return Result.success()
        if (!ProtectionService.running) {
            val i = Intent(ctx, ProtectionService::class.java)
                .putExtra(ProtectionService.EXTRA_WATCHDOG, true)
            try {
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } catch (e: Exception) {
                EventStore.add(
                    ctx, "tamperDetected", "attention",
                    "KEEPON could not restart its protection service.",
                    e.message ?: "WorkManager restart failed", false, "Protection NOT running"
                )
            }
        }
        return Result.success()
    }

    companion object {
        private const val NAME = "keepon_tamper_watchdog"

        fun schedule(ctx: Context) {
            try {
                val req = PeriodicWorkRequestBuilder<TamperWatchdogWorker>(15, TimeUnit.MINUTES).build()
                WorkManager.getInstance(ctx.applicationContext)
                    .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, req)
            } catch (_: Exception) {
            }
        }

        fun cancel(ctx: Context) {
            try {
                WorkManager.getInstance(ctx.applicationContext).cancelUniqueWork(NAME)
            } catch (_: Exception) {
            }
        }
    }
}
