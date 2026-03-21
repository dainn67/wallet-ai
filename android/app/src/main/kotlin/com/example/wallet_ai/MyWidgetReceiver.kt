package com.leslie.wallyai

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MyWidgetReceiver : HomeWidgetGlanceWidgetReceiver<AppWidget>() {
    override val glanceAppWidget = AppWidget()
}