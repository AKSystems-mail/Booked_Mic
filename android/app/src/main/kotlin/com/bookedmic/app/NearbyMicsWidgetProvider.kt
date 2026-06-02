package com.bookedmic.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.net.Uri

class NearbyMicsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nearby_mics_widget).apply {
                val count = widgetData.getInt("nearby_count", 0)
                val city = widgetData.getString("nearby_city", "Unknown City")

                setTextViewText(R.id.count_number, count.toString())
                setTextViewText(R.id.nearby_city, city)

                // Launch app on tap - deep link to nearbyMics screen
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context, 
                    MainActivity::class.java, 
                    Uri.parse("bookedmic://nearbyMics")
                )
                setOnClickPendingIntent(R.id.nearby_mics_widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
