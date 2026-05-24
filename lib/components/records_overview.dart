import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:wallet_ai/components/section_label.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';

import 'popups/add_source_popup.dart';

/// A component that displays a financial overview including total balance,
/// income, expenses, and a horizontal list of money sources.
///
/// Layout is composed of 3 vertically-stacked zones:
///   Zone 1 — Net Worth hero card (with balance-mask toggle)
///   Zone 2 — Side-by-side Income / Expense tiles
///   Zone 3 — Horizontal scrolling money-source cards
///
/// Money-source card accent rule: each card uses
/// `AppSemanticColors.categoryAccents[idx % categoryAccents.length]` —
/// sequential index modulo the palette length (resolves PRD warning W2).
class RecordsOverview extends StatefulWidget {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final List<MoneySource> sources;
  final Function(MoneySource)? onSourceTap;
  final VoidCallback? onAddSource;

  const RecordsOverview({
    super.key,
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.sources,
    this.onSourceTap,
    this.onAddSource,
  });

  @override
  State<RecordsOverview> createState() => _RecordsOverviewState();
}

class _RecordsOverviewState extends State<RecordsOverview> {
  static const String _hiddenValue = '*****';

  bool _valuesHidden = true;

  // Fallback used only when host theme doesn't register AppSemanticColors
  // (e.g. minimal MaterialApp in widget tests). Pulls from ColorScheme so
  // no hex literals leak into this file.
  AppSemanticColors _fallbackSem(ThemeData theme) {
    final cs = theme.colorScheme;
    return AppSemanticColors(
      incomeGreen: cs.primary,
      expenseRed: cs.error,
      transferTint: cs.primary,
      categoryAccents: [cs.primary, cs.secondary, cs.tertiary, cs.error, cs.primary, cs.secondary],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final sem = theme.extension<AppSemanticColors>() ?? _fallbackSem(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNetWorthHero(context, l10n),
        const SizedBox(height: AppSpacing.md),
        _buildIncomeExpenseRow(l10n, sem),
        const SizedBox(height: AppSpacing.md),
        _buildSourcesSection(context, l10n, sem),
      ],
    );
  }

  // ─── Zone 1: Net Worth hero card ────────────────────────────────────────
  Widget _buildNetWorthHero(BuildContext context, LocaleProvider l10n) {
    final currencyCode = L10nConfig.currencyCodes[l10n.currency] ?? 'VND';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.translate('total_balance_label')),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        _valuesHidden ? _hiddenValue : CurrencyHelper.format(widget.totalBalance),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        currencyCode,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _valuesHidden = !_valuesHidden),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    _valuesHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Zone 2: Income / Expense tiles ─────────────────────────────────────
  Widget _buildIncomeExpenseRow(LocaleProvider l10n, AppSemanticColors sem) {
    return Row(
      children: [
        Expanded(
          child: _OverviewTile(
            label: l10n.translate('income_label'),
            value: _valuesHidden ? _hiddenValue : CurrencyHelper.format(widget.totalIncome),
            tint: sem.incomeGreen,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _OverviewTile(
            label: l10n.translate('spent_label'),
            // Expense remains visible per task spec, even when masked.
            value: CurrencyHelper.format(widget.totalExpense),
            tint: sem.expenseRed,
          ),
        ),
      ],
    );
  }

  // ─── Zone 3: Money-source horizontal scroll ─────────────────────────────
  Widget _buildSourcesSection(BuildContext context, LocaleProvider l10n, AppSemanticColors sem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(l10n.translate('sources_label')),
              IconButton(
                onPressed: widget.onAddSource ?? () => _handleAddSource(context),
                icon: const Icon(Icons.add_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          if (widget.sources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.sources.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final source = widget.sources[index];
                  final accent = sem.categoryAccents[index % sem.categoryAccents.length];
                  return _SourceCard(
                    source: source,
                    accent: accent,
                    hidden: _valuesHidden,
                    onTap: widget.onSourceTap == null ? null : () => widget.onSourceTap!(source),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAddSource(BuildContext context) async {
    final result = await showDialog<MoneySource>(
      context: context,
      builder: (context) => const AddSourcePopup(),
    );
    if (result != null && context.mounted) {
      await context.read<RecordProvider>().addMoneySource(result);
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Private widgets
// ──────────────────────────────────────────────────────────────────────────

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.accent,
    required this.hidden,
    this.onTap,
  });

  final MoneySource source;
  final Color accent;
  final bool hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              source.sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              hidden ? '*****' : CurrencyHelper.format(source.amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
