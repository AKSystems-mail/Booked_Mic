package com.bookedmic.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class BookedMicWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.up_next_widget).apply {
                val listName = widgetData.getString("list_name", "No Active List")
                val spotNumber = widgetData.getString("spot_number", "--")
                val isOnStage = widgetData.getBoolean("is_on_stage", false)
                val isUpNext = widgetData.getBoolean("is_up_next", false)

                setTextViewText(R.id.list_name, listName)
                setTextViewText(R.id.spot_number, spotNumber)
                
                val statusText = when {
                    isOnStage -> "YOU ARE ON"
                    isUpNext -> "YOU ARE UP NEXT!"
                    else -> "Waiting..."
                }
                setTextViewText(R.id.up_next_text, statusText)

                // PendingIntent to launch the app on tap
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.up_next_widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
