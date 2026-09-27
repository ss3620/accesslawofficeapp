package com.accesslawoffice.access_law_office

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    "alf_messages",
                    "Messages",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Chat and lobby alerts"
                    enableVibration(true)
                }
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    "alf_lobby",
                    "Virtual Lobby",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Someone waiting in the Virtual Lobby"
                    enableVibration(true)
                }
            )
        }
    }
}
