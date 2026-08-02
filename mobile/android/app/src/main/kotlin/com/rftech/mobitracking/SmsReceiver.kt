package com.rftech.mobitracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * BroadcastReceiver natif pour capter les SMS entrants.
 * Transmet les SMS à MainActivity via un singleton.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
        var onSmsReceived: ((sender: String, body: String) -> Unit)? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        // Regrouper les parties d'un même SMS (multi-part)
        val grouped = mutableMapOf<String, StringBuilder>()
        for (msg in messages) {
            val sender = msg.displayOriginatingAddress ?: continue
            val body = msg.displayMessageBody ?: continue
            grouped.getOrPut(sender) { StringBuilder() }.append(body)
        }

        for ((sender, body) in grouped) {
            Log.d(TAG, "SMS reçu de: $sender")
            Log.d(TAG, "Corps: ${body.toString().take(80)}...")
            onSmsReceived?.invoke(sender, body.toString())
        }
    }
}
