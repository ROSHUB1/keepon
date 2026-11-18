package com.keepon.keepon

import kotlin.math.PI
import kotlin.math.sin

/**
 * KEEPON security siren, generated in code (no audio file).
 *
 * One cycle (about 2 seconds, then it loops):
 *  1. three sharp 3.2 kHz beeps
 *  2. a fast two-tone warble between 2.6 kHz and 3.6 kHz
 *  3. a rising sweep from 1.8 kHz to 3.8 kHz
 *
 * Everything stays between 1.8 and 3.8 kHz: very audible and clearly "electronic",
 * but well below ultrasonic. A 3rd harmonic adds a sharp, buzzer-like edge. Peak level is
 * 80% of full scale with 4 ms fades so there are no clicks; loudness is controlled by the
 * alarm volume setting, not by clipping the signal.
 */
object SirenSynth {
    const val SAMPLE_RATE = 44100
    private const val PEAK = 0.8
    private const val FADE_MS = 4.0
    private const val TWO_PI = 2.0 * PI

    private val cached: ShortArray by lazy { build() }

    fun cycle(): ShortArray = cached

    private fun build(): ShortArray {
        val out = ArrayList<Short>(100_000)

        fun add(v: Double) {
            out.add((v.coerceIn(-1.0, 1.0) * 32767.0 * PEAK).toInt().toShort())
        }

        fun envelope(i: Int, n: Int): Double {
            val fade = (SAMPLE_RATE * FADE_MS / 1000.0)
            return minOf(1.0, i / fade, (n - 1 - i) / fade).coerceAtLeast(0.0)
        }

        fun voice(phase: Double) = (sin(phase) + 0.25 * sin(3.0 * phase)) / 1.25

        fun tone(freq: Double, ms: Int) {
            val n = SAMPLE_RATE * ms / 1000
            for (i in 0 until n) {
                val t = i.toDouble() / SAMPLE_RATE
                add(envelope(i, n) * voice(TWO_PI * freq * t))
            }
        }

        fun silence(ms: Int) {
            repeat(SAMPLE_RATE * ms / 1000) { out.add(0) }
        }

        fun sweep(f0: Double, f1: Double, ms: Int) {
            val n = SAMPLE_RATE * ms / 1000
            var phase = 0.0
            for (i in 0 until n) {
                val f = f0 + (f1 - f0) * i / n
                phase += TWO_PI * f / SAMPLE_RATE
                add(envelope(i, n) * voice(phase))
            }
        }

        // 1. three sharp beeps
        repeat(3) {
            tone(3200.0, 110)
            silence(70)
        }
        silence(60)
        // 2. fast warble
        repeat(10) { i ->
            tone(if (i % 2 == 0) 2600.0 else 3600.0, 70)
        }
        silence(80)
        // 3. rising sweep
        sweep(1800.0, 3800.0, 450)
        silence(150)

        return out.toShortArray()
    }
}
