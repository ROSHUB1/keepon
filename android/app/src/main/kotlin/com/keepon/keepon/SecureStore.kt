package com.keepon.keepon

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** AES-256-GCM encryption with a key that never leaves the Android Keystore. */
object SecureStore {
    private const val ALIAS = "keepon_location_key"
    private const val TRANSFORM = "AES/GCM/NoPadding"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    fun encrypt(plain: String): String {
        if (Build.VERSION.SDK_INT < 23) return "p:$plain" // no Keystore AES before Android 6
        val c = Cipher.getInstance(TRANSFORM)
        c.init(Cipher.ENCRYPT_MODE, key())
        val iv = c.iv
        val ct = c.doFinal(plain.toByteArray(Charsets.UTF_8))
        return "e:" + Base64.encodeToString(iv + ct, Base64.NO_WRAP)
    }

    fun decrypt(stored: String): String? {
        return try {
            when {
                stored.startsWith("p:") -> stored.substring(2)
                stored.startsWith("e:") -> {
                    val all = Base64.decode(stored.substring(2), Base64.NO_WRAP)
                    val iv = all.copyOfRange(0, 12)
                    val ct = all.copyOfRange(12, all.size)
                    val c = Cipher.getInstance(TRANSFORM)
                    c.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
                    String(c.doFinal(ct), Charsets.UTF_8)
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }
}
