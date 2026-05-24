import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/configs/app_theme.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/services.dart';

class TestTab extends StatefulWidget {
  const TestTab({super.key});

  @override
  State<TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<TestTab> {
  static const int _demoSourceId = 1; // Wallet (default from DB)
  String? _apiResult;
  bool _isLoading = false;
  String? _storedPattern;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  void _loadStoredData() {
    setState(() {
      _storedPattern = StorageService().getString(StorageService.keyUserPattern);
      final lastUpdateMs = StorageService().getInt(StorageService.keyLastPatternUpdateTime);
      if (lastUpdateMs != null && lastUpdateMs != -1) {
        _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      } else {
        _lastUpdateTime = null;
      }
    });
  }

  Future<void> _addDemoRecords(BuildContext context) async {
    final provider = context.read<RecordProvider>();
    final demoRecords = [
      Record(moneySourceId: _demoSourceId, amount: 3000, currency: 'USD', description: 'Monthly salary', type: 'income'),
      Record(moneySourceId: _demoSourceId, amount: 5.5, currency: 'USD', description: 'Coffee shop', type: 'expense'),
      Record(moneySourceId: _demoSourceId, amount: 85, currency: 'USD', description: 'Groceries', type: 'expense'),
      Record(moneySourceId: _demoSourceId, amount: 500, currency: 'USD', description: 'Freelance project', type: 'income'),
      Record(moneySourceId: _demoSourceId, amount: 12, currency: 'USD', description: 'Lunch', type: 'expense'),
      Record(moneySourceId: _demoSourceId, amount: 200, currency: 'USD', description: 'Bonus', type: 'income'),
    ];
    for (final r in demoRecords) {
      await provider.addRecord(r);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added 6 demo records'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _addDemoMoneySources(BuildContext context) async {
    final provider = context.read<RecordProvider>();
    final demoSources = [MoneySource(sourceName: 'Cash'), MoneySource(sourceName: 'Card')];
    for (final s in demoSources) {
      await provider.addMoneySource(s);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added 2 demo money sources'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _testAiSync() async {
    setState(() {
      _isLoading = true;
      _apiResult = null;
    });

    try {
      await AiPatternService().updateUserPattern(force: true);
      final result = StorageService().getString(StorageService.keyUserPattern);
      setState(() {
        _apiResult = result ?? 'Sync completed but no pattern returned.';
      });
    } catch (e) {
      setState(() {
        _apiResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _loadStoredData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Text(
          'Demo data',
          style: textTheme.titleLarge?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Add sample records and money sources for testing.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton.icon(
          onPressed: () => _addDemoRecords(context),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Add demo records'),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => _addDemoMoneySources(context),
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text('Add demo money sources'),
        ),
        const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
        Text(
          'AI Pattern Sync',
          style: textTheme.titleLarge?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Test syncing your records with the server.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton.icon(
          onPressed: _isLoading ? null : _testAiSync,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(_isLoading ? 'Syncing...' : 'Test AI Sync'),
        ),
        if (_apiResult != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Result:',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              _apiResult!,
              style: textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _apiResult = null;
              });
            },
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear result'),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stored AI Pattern',
              style: textTheme.titleLarge?.copyWith(color: AppColors.onSurface),
            ),
            IconButton(
              onPressed: _loadStoredData,
              icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _lastUpdateTime != null
              ? 'Last updated: ${DateFormat('HH:mm d MMM yyyy').format(_lastUpdateTime!)}'
              : 'Never updated',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: AppColors.outline),
          ),
          child: SingleChildScrollView(
            child: Text(
              _storedPattern?.isNotEmpty == true ? _storedPattern! : 'No pattern stored yet.',
              style: textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
      ],
    );
  }
}
