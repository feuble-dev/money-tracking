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
    private val AUTOSTART_CHANNEL = "com.rftech.moneytracking/autostart"

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

        // === MethodChannel pour ouvrir l'écran "démarrage automatique" du
        // constructeur (Xiaomi/MIUI, Transsion/Tecno/Infinix/itel, Oppo,
        // Vivo, Huawei, Samsung...). L'exemption Doze standard
        // (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS) ne suffit pas sur ces
        // surcouches : elles ont leur propre gestionnaire "autostart" qui
        // peut tuer l'app après un redémarrage même Doze désactivé, et
        // Android ne propose aucune API standard pour ce réglage — on tente
        // les écrans constructeur connus, chacun protégé individuellement,
        // et on renvoie false si aucun ne s'est ouvert (repli Dart :
        // openAppSettings()). ===
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTOSTART_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAutostartSettings" -> result.success(openAutostartSettings())
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

    /// Essaie une liste d'écrans "démarrage automatique" connus par
    /// constructeur, du plus probable au moins probable ; s'arrête au
    /// premier qui s'ouvre sans exception. Chaque nom de composant est une
    /// activité interne non documentée par le constructeur (jamais garantie
    /// par une API publique), d'où le try/catch individuel : un changement
    /// de version OS peut la faire disparaître sans que ça casse l'app.
    private fun openAutostartSettings(): Boolean {
        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
        val candidates = mutableListOf<Intent>()

        fun addCandidate(pkg: String, cls: String) {
            candidates.add(Intent().apply {
                component = android.content.ComponentName(pkg, cls)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        }

        when {
            manufacturer.contains("xiaomi") -> {
                addCandidate("com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity")
            }
            manufacturer.contains("transsion") || manufacturer.contains("tecno") ||
                manufacturer.contains("infinix") -> {
                addCandidate("com.transsion.phonemanager",
                    "com.transsion.phonemanager.ui.PowerAndProtectActivity")
                addCandidate("com.transsion.phonemanager",
                    "com.transsion.phonemanager.ui.appmanager.AutoStartActivity")
            }
            manufacturer.contains("itel") -> {
                addCandidate("com.itel.autobootmanager",
                    "com.itel.autobootmanager.activity.AutoBootManagerActivity")
                addCandidate("com.transsion.phonemanager",
                    "com.transsion.phonemanager.ui.PowerAndProtectActivity")
            }
            manufacturer.contains("oppo") -> {
                addCandidate("com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                addCandidate("com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity")
            }
            manufacturer.contains("vivo") -> {
                addCandidate("com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                addCandidate("com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManagerActivity")
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                addCandidate("com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
            }
            manufacturer.contains("samsung") -> {
                addCandidate("com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity")
            }
        }

        for (intent in candidates) {
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // Écran absent sur cette variante ROM/version — essai suivant.
            }
        }
        return false
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
