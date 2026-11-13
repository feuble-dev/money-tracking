package com.rftech.mobitracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * BroadcastReceiver natif pour capter les SMS entrants.
 * Transmet les SMS à MainActivity via un singleton.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
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
            // Ni expéditeur ni contenu dans les journaux du téléphone.
            onSmsReceived?.invoke(sender, body.toString())
        }
    }
}
