package com.justinhinckley.gt_scheduling_app

import io.flutter.embedding.android.FlutterActivity

import android.app.NotificationManager
import android.content.Context

class MainActivity: FlutterActivity() {
    override fun onResume() {
        super.onResume()
        // Removing All Notifications
        cancelAllNotifications()
    }

    private fun cancelAllNotifications() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancelAll()
    }
}
