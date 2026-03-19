package com.example.wallet_ai

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color // Standard Color for background
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.action.actionStartActivity // Essential for click actions
import androidx.glance.unit.ColorProvider
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
        // Retrieve data saved from Flutter using HomeWidget.saveWidgetData('title', value)
        val title = prefs.getString("title", "No Data") ?: "No Data"

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(Color.White)
                .appWidgetBackground()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = title,
                    style = TextStyle(
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color.Black)
                    )
                )
                
                Spacer(modifier = GlanceModifier.height(8.dp))

                // This Button opens the app's MainActivity
                Button(
                    text = "Check Wallet",
                    onClick = actionStartActivity<MainActivity>(
                        // This tells Flutter what happened
                        parameters = actionParametersOf(
                            ActionParameters.Key<String>("route") to "/wallet"
                        )
                    )
                )
            }
        }
    }
}