package com.rftech.mobitracking

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (pas FlutterActivity) est requis par local_auth :
// BiometricPrompt a besoin d'un FragmentActivity pour s'attacher. Avec
// FlutterActivity, authenticate() échouait silencieusement (exception
// "no_fragment_activity" avalée par le try/catch de BiometricService), donc
// le prompt d'empreinte ne s'affichait jamais, quel que soit l'état de
// isBiometricEnabledProvider.
class MainActivity : FlutterFragmentActivity() {

    private val USSD_CHANNEL = "com.rftech.moneytracking/ussd"
    private val SMS_EVENT_CHANNEL = "com.rftech.moneytracking/sms"
    private val SMS_INBOX_CHANNEL = "com.rftech.moneytracking/sms_inbox"

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

        // === MethodChannel pour lire les SMS inbox (import historique) ===
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_INBOX_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInboxSms" -> {
                    val dateFrom = call.argument<Long>("dateFrom") ?: 0L
                    val dateTo = call.argument<Long>("dateTo") ?: System.currentTimeMillis()
                    Thread {
                        try {
                            val smsList = readInboxSms(dateFrom, dateTo)
                            runOnUiThread { result.success(smsList) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("SMS_READ_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // === EventChannel pour recevoir les SMS en temps réel ===
        // Le BroadcastReceiver lui-même (.SmsReceiver) est déclaré une seule
        // fois dans AndroidManifest.xml et reste actif tant que le process
        // vit (premier plan ou arrière-plan) — ici on ne fait que
        // brancher/débrancher le callback statique qui relaie vers l'
        // EventSink Flutter. Registrer un DEUXIÈME receiver dynamique en
        // plus du receiver déclaré dans le manifest ferait recevoir chaque
        // SMS deux fois (même callback statique invoqué par les deux
        // instances) — la déduplication côté Dart existe, mais autant ne
        // pas dupliquer l'enregistrement du receiver pour rien.
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
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
                android.util.Log.d("MainActivity", "SMS EventChannel: listening")
            }

            override fun onCancel(arguments: Any?) {
                SmsReceiver.onSmsReceived = null
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

    private fun readInboxSms(dateFrom: Long, dateTo: Long): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("address", "body", "date")
        val selection = "date >= ? AND date <= ?"
        val selectionArgs = arrayOf(dateFrom.toString(), dateTo.toString())
        val sortOrder = "date ASC"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val addressIdx = cursor.getColumnIndexOrThrow("address")
                val bodyIdx = cursor.getColumnIndexOrThrow("body")
                val dateIdx = cursor.getColumnIndexOrThrow("date")

                do {
                    val address = cursor.getString(addressIdx) ?: ""
                    val body = cursor.getString(bodyIdx) ?: ""
                    val date = cursor.getLong(dateIdx)

                    if (body.isNotEmpty()) {
                        smsList.add(mapOf(
                            "address" to address,
                            "body" to body,
                            "date" to date
                        ))
                    }
                } while (cursor.moveToNext())
            }
        } finally {
            cursor?.close()
        }

        android.util.Log.d("MainActivity", "SMS Inbox: ${smsList.size} messages lus (${dateFrom} -> ${dateTo})")
        return smsList
    }

    override fun onDestroy() {
        SmsReceiver.onSmsReceived = null
        super.onDestroy()
    }
}
