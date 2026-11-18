package com.keepon.keepon

import android.content.Context
import android.content.SharedPreferences
import android.os.Build

/**
 * KEEPON's native state lives in device-protected storage so that protection can resume
 * after a reboot BEFORE the owner unlocks the phone (Direct Boot).
 */
object Store {
    const val PREFS = "keepon_native"
    private var migrated = false

    @Synchronized
    fun prefs(ctx: Context): SharedPreferences {
        val app = ctx.applicationContext
        if (Build.VERSION.SDK_INT >= 24) {
            val dp = app.createDeviceProtectedStorageContext()
            if (!migrated) {
                try {
                    // One-time move of older data from credential-protected storage.
                    migrated = dp.moveSharedPreferencesFrom(app, PREFS)
                } catch (_: Exception) {
                    // Storage still locked (Direct Boot); try again on the next call.
                }
            }
            return dp.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        }
        return app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }
}
