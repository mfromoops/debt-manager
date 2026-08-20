package com.mortgagetracker.tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToLong

internal object DebtWidgetStore {
    private const val PREFS = "debt_launcher_widgets"

    fun save(context: Context, values: Map<String, Any?>) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear()
        values.forEach { (key, value) ->
            when (value) {
                is Boolean -> editor.putBoolean(key, value)
                is Number -> editor.putLong(key, value.toDouble().roundToLong())
                is String -> editor.putString(key, value)
            }
        }
        editor.apply()
    }

    fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

internal object DebtWidgetUpdater {
    private val money = NumberFormat.getCurrencyInstance(Locale.US).apply {
        maximumFractionDigits = 0
    }
    private val date = SimpleDateFormat("MMM d", Locale.US)
    private val month = SimpleDateFormat("MMM yyyy", Locale.US)

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        updateProvider(context, manager, PaymentCycleWidget::class.java)
        updateProvider(context, manager, DebtProgressWidget::class.java)
        updateProvider(context, manager, NextPaymentWidget::class.java)
        updateProvider(context, manager, IncomeFreedomWidget::class.java)
    }

    fun updateProvider(
        context: Context,
        manager: AppWidgetManager,
        provider: Class<out AppWidgetProvider>,
    ) {
        manager.getAppWidgetIds(ComponentName(context, provider)).forEach { id ->
            manager.updateAppWidget(id, viewsFor(context, provider))
        }
    }

    private fun viewsFor(context: Context, provider: Class<out AppWidgetProvider>): RemoteViews {
        val prefs = DebtWidgetStore.prefs(context)
        val hasDebts = prefs.getBoolean("hasDebts", false)
        val views = when (provider) {
            PaymentCycleWidget::class.java -> RemoteViews(
                context.packageName,
                R.layout.widget_payment_cycle,
            ).also {
                val payment = prefs.getLong("strategyPayment", 0)
                val minimum = prefs.getLong("minimumDue", 0)
                val extra = prefs.getLong("strategyExtra", 0)
                it.setTextViewText(R.id.primary_value, money.format(payment))
                it.setTextViewText(R.id.minimum_value, money.format(minimum))
                it.setTextViewText(
                    R.id.secondary_text,
                    if (!hasDebts) "Add a debt to build your plan"
                    else if (extra > 0) "${money.format(minimum)} minimum + ${money.format(extra)} extra"
                    else "Minimum due · no extra strategy this cycle",
                )
                setNextDate(it, prefs.getLong("nextDate", 0), prefs.getString("nextName", null))
            }
            DebtProgressWidget::class.java -> RemoteViews(
                context.packageName,
                R.layout.widget_debt_progress,
            ).also {
                val balance = prefs.getLong("totalDebt", 0)
                val saved = prefs.getLong("interestSaved", 0)
                val percent = prefs.getLong("paidPercent", 0).toInt().coerceIn(0, 100)
                val months = prefs.getLong("monthsRemaining", 0)
                it.setTextViewText(R.id.primary_value, money.format(balance))
                it.setTextViewText(
                    R.id.secondary_text,
                    if (!hasDebts) "No active debts"
                    else if (saved > 0) "${money.format(saved)} projected interest saved"
                    else "Projected balance with your active plan",
                )
                it.setProgressBar(R.id.debt_progress, 100, percent, false)
                it.setTextViewText(R.id.progress_value, "$percent% paid")
                it.setTextViewText(R.id.timeline_value, duration(months))
            }
            NextPaymentWidget::class.java -> RemoteViews(context.packageName, R.layout.widget_next_payment).also {
                val due = prefs.getLong("nextDate", 0)
                val scheduled = prefs.getLong("nextAmount", 0)
                val planned = prefs.getLong("nextStrategyAmount", scheduled)
                it.setTextViewText(
                    R.id.debt_name,
                    prefs.getString("nextName", null) ?: "No payment due",
                )
                it.setTextViewText(R.id.primary_value, money.format(planned))
                it.setTextViewText(
                    R.id.secondary_text,
                    if (!hasDebts) "Add a debt to see its next payment"
                    else if (planned > scheduled) "${money.format(scheduled)} required + ${money.format(planned - scheduled)} extra"
                    else "Required payment",
                )
                it.setTextViewText(R.id.due_value, if (due > 0) date.format(Date(due)) else "All paid")
                it.setTextViewText(R.id.balance_value, money.format(prefs.getLong("nextBalance", 0)))
                it.setTextViewText(
                    R.id.debt_type,
                    prefs.getString("nextType", "DEBT")?.uppercase(Locale.US),
                )
            }
            else -> RemoteViews(context.packageName, R.layout.widget_income_freedom).also {
                val hasIncome = prefs.getBoolean("hasIncome", false)
                val available = prefs.getLong("incomeAvailableNow", 0)
                val afterPayoffs = prefs.getLong("incomeAvailableAfterPayoffs", 0)
                val releaseDate = prefs.getLong("nextIncomeReleaseDate", 0)
                val releaseAmount = prefs.getLong("nextIncomeReleaseAmount", 0)
                val debtFreeDate = prefs.getLong("strategyDebtFreeDate", 0)
                it.setTextViewText(
                    R.id.primary_value,
                    if (hasIncome) money.format(available) else "Add income",
                )
                it.setTextViewText(
                    R.id.secondary_text,
                    if (!hasIncome) "Add salary in Profile to unlock this forecast"
                    else "available after this cycle's strategy payments",
                )
                it.setTextViewText(
                    R.id.after_payoffs_value,
                    if (hasIncome) money.format(afterPayoffs) else "—",
                )
                it.setTextViewText(
                    R.id.next_release_value,
                    if (releaseDate > 0) month.format(Date(releaseDate)) else "Not projected",
                )
                it.setTextViewText(
                    R.id.next_release_detail,
                    prefs.getString("nextIncomeReleaseNames", null) ?: "No active payoff milestone",
                )
                it.setTextViewText(
                    R.id.release_amount_value,
                    if (releaseAmount > 0) "+${money.format(releaseAmount)}/mo" else "",
                )
                it.setTextViewText(
                    R.id.debt_free_value,
                    if (debtFreeDate > 0) "Plan ends ${month.format(Date(debtFreeDate))}" else "Strategy timeline",
                )
            }
        }

        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
        return views
    }

    private fun setNextDate(views: RemoteViews, timestamp: Long, name: String?) {
        views.setTextViewText(R.id.next_value, if (timestamp > 0) date.format(Date(timestamp)) else "All paid")
        views.setTextViewText(R.id.next_detail, name ?: "No active debts")
    }

    private fun duration(months: Long): String {
        if (months <= 0) return "Debt-free"
        val years = months / 12
        val remainder = months % 12
        return when {
            years == 0L -> "$months mo left"
            remainder == 0L -> "$years yr left"
            else -> "$years y ${remainder}m left"
        }
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

abstract class BaseDebtWidget : AppWidgetProvider() {
    abstract val providerClass: Class<out AppWidgetProvider>

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        DebtWidgetUpdater.updateProvider(context, manager, providerClass)
    }

    override fun onEnabled(context: Context) {
        DebtWidgetUpdater.updateAll(context)
    }
}

class PaymentCycleWidget : BaseDebtWidget() {
    override val providerClass = PaymentCycleWidget::class.java
}

class DebtProgressWidget : BaseDebtWidget() {
    override val providerClass = DebtProgressWidget::class.java
}

class NextPaymentWidget : BaseDebtWidget() {
    override val providerClass = NextPaymentWidget::class.java
}

class IncomeFreedomWidget : BaseDebtWidget() {
    override val providerClass = IncomeFreedomWidget::class.java
}
