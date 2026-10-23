package com.biruk.amharic_sudoku

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Hosts Flutter plus two small channels:
 *  - geez_sudoku/platform: share sheet, store link and web links
 *  - geez_sudoku/audio: sound effects (SoundPool) and pronunciation (TextToSpeech)
 */
class MainActivity : FlutterActivity() {
    private var sounds: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var amharicVoice = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "geez_sudoku/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "share" -> {
                    val text = call.argument<String>("text") ?: ""
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(send, null))
                    result.success(true)
                }
                "openStore" -> result.success(openStore())
                "openUrl" -> result.success(openUrl(call.argument<String>("url") ?: ""))
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "geez_sudoku/audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val name = call.argument<String>("name") ?: ""
                    val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    val id = soundIds[name]
                    if (id != null) sounds?.play(id, volume, volume, 1, 0, 1f)
                    result.success(id != null)
                }
                "speak" -> {
                    speak(
                        call.argument<String>("text") ?: "",
                        call.argument<String>("fallback") ?: "",
                    )
                    result.success(amharicVoice)
                }
                "hasAmharicVoice" -> result.success(amharicVoice)
                else -> result.notImplemented()
            }
        }

        loadSounds()
        initTts()
    }

    private fun loadSounds() {
        val pool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
        val raw = mapOf(
            "tap" to R.raw.sfx_tap,
            "place" to R.raw.sfx_place,
            "note" to R.raw.sfx_note,
            "error" to R.raw.sfx_error,
            "unit" to R.raw.sfx_unit,
            "hint" to R.raw.sfx_hint,
            "coin" to R.raw.sfx_coin,
            "word" to R.raw.sfx_word,
            "win" to R.raw.sfx_win,
            "lose" to R.raw.sfx_lose,
            "splash" to R.raw.sfx_splash,
        )
        for ((name, res) in raw) soundIds[name] = pool.load(this, res, 1)
        sounds = pool
    }

    private fun initTts() {
        tts = TextToSpeech(this) { status ->
            if (status != TextToSpeech.SUCCESS) return@TextToSpeech
            val engine = tts ?: return@TextToSpeech
            val am = Locale("am", "ET")
            amharicVoice = engine.isLanguageAvailable(am) >= TextToSpeech.LANG_AVAILABLE
            ttsReady = true
        }
    }

    /** Speaks [text] with an Amharic voice if installed, else [fallback] in English. */
    private fun speak(text: String, fallback: String) {
        val engine = tts ?: return
        if (!ttsReady) return
        if (amharicVoice) {
            engine.language = Locale("am", "ET")
            engine.setSpeechRate(0.85f)
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "word")
        } else {
            engine.language = Locale.US
            engine.setSpeechRate(0.75f)
            engine.speak(fallback, TextToSpeech.QUEUE_FLUSH, null, "word")
        }
    }

    private fun openStore(): Boolean {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
        val web = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName"))
        return try {
            startActivity(market)
            true
        } catch (e: ActivityNotFoundException) {
            try {
                startActivity(web)
                true
            } catch (e2: ActivityNotFoundException) {
                false
            }
        }
    }

    /** Opens an https link in the browser; false if none can handle it. */
    private fun openUrl(url: String): Boolean {
        if (!url.startsWith("https://")) return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
