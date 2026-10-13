package com.fukton.fukton

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: today's creed line, the chosen vow and how far the lotus has opened. */
class LotusWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.lotus_widget).apply {
                setTextViewText(R.id.widget_line, widgetData.getString("line", "จงเป็นดั่งราชสีห์ ที่ไม่ตื่นเสียง"))
                setTextViewText(R.id.widget_vow, widgetData.getString("vow", "แตะเพื่อตั้งจิต"))
                setTextViewText(R.id.widget_bloom, widgetData.getString("bloom", "ดอกบัวยังตูม"))
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
