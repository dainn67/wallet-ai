package com.example.wallet_ai

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

class AppWidget : GlanceAppWidget() {
    // This connects the widget to home_widget's data storage
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        val title = prefs.getString("title", "No Title") ?: "No Title"

        Column(modifier = GlanceModifier.fillMaxSize().padding(16.dp)) {
            Text(text = title, style = TextStyle(fontSize = 16.sp))
        }
    }
}