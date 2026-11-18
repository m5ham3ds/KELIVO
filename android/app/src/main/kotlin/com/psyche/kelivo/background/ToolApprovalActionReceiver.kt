package com.psyche.kelivo.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.psyche.kelivo.KelivoApplication

/** Receives explicit approve/deny actions from KELIVO's pending-tool notification. */
class ToolApprovalActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext as? KelivoApplication ?: return
        app.backgroundRuntime.receiveApprovalAction(intent)
    }
}
