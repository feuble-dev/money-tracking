package com.rftech.mobitracking

import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.provider.Telephony
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val USSD_CHANNEL = "com.rftech.moneytracking/ussd"
    private val SMS_EVENT_CHANNEL = "com.rftech.moneytracking/sms"

    private var smsReceiver: SmsReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // === MethodChannel pour USSD ===
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            USSD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "dialUssd" -> {
                    val code = call.argument<String>("code")
                    if (code != null) {
                        dialUssd(code, result)
                    } else {
                        result.error("INVALID_CODE", "Code USSD null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // === EventChannel pour recevoir les SMS en temps réel ===
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events

                // Enregistrer le BroadcastReceiver
                smsReceiver = SmsReceiver()
                SmsReceiver.onSmsReceived = { sender, body ->
                    // Envoyer vers Flutter via l'EventSink (thread UI)
                    runOnUiThread {
                        eventSink?.success(mapOf(
                            "sender" to sender,
                            "body" to body,
                            "timestamp" to System.currentTimeMillis().toString()
                        ))
                    }
                }

                val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
                filter.priority = 999
                registerReceiver(smsReceiver, filter)

                android.util.Log.d("MainActivity", "SMS EventChannel: listening")
            }

            override fun onCancel(arguments: Any?) {
                SmsReceiver.onSmsReceived = null
                smsReceiver?.let {
                    try { unregisterReceiver(it) } catch (_: Exception) {}
                }
                smsReceiver = null
                eventSink = null
                android.util.Log.d("MainActivity", "SMS EventChannel: cancelled")
            }
        })
    }

    private fun dialUssd(ussdCode: String, result: MethodChannel.Result) {
        try {
            val encoded = ussdCode.replace("#", "%23")
            val uri = Uri.parse("tel:$encoded")
            val intent = Intent(Intent.ACTION_CALL, uri)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Permission CALL_PHONE requise", null)
        } catch (e: Exception) {
            result.error("USSD_ERROR", e.message, null)
        }
    }

    override fun onDestroy() {
        SmsReceiver.onSmsReceived = null
        smsReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        super.onDestroy()
    }
}
