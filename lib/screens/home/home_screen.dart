import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:wallet_ai/screens/home/tabs/categories_tab.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/screens/home/tabs/records_tab.dart';
import 'package:wallet_ai/screens/home/tabs/test_tab.dart';

// Private data class: one entry per tab in the NavigationBar + PageView.
class _TabConfig {
  final IconData icon;
  final String label;
  final Widget page;
  const _TabConfig({required this.icon, required this.label, required this.page});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _recordingFocusNode = FocusNode();
  late final PageController _pageController;
  int _currentIndex = 0;

  // Stable page widget instances — built once so PageView children don't
  // reconstruct on locale changes. Labels are resolved separately in build().
  // kDebugMode is a compile-time constant: the `if (kDebugMode)` branch is
  // eliminated by the compiler in release builds (AD-5).
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      ChatTab(focusNode: _recordingFocusNode),
      const RecordsTab(),
      const CategoriesTab(),
      if (kDebugMode) const TestTab(),
    ];

    _pageController = PageController(initialPage: 0);

    // Check if the app was opened from a widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) _handleWidgetClick(uri);
    });

    // Listen for clicks while the app is in the background
    HomeWidget.widgetClicked.listen(_handleWidgetClick);

    // Show onboarding dialog on first launch — or always when dev mode is on
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notDone = StorageService().getBool(StorageService.keyOnboardingComplete) != true;
      if (notDone || AppConfig().devMode) {
        OnboardingDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _recordingFocusNode.dispose();
    super.dispose();
  }

  void _handleWidgetClick(Uri? uri) {
    debugPrint('Widget Clicked: $uri');
    if (uri?.host == 'record') {
      // Switch to chat tab (index 0)
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentIndex = 0);

      // Wait for page animation to finish before requesting focus
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _recordingFocusNode.requestFocus();
      });
    }
  }

  // Build tab descriptors with live locale labels. Icons and page count mirror
  // _pages (same kDebugMode gate) so indices always align.
  List<_TabConfig> _buildTabs(LocaleProvider l10n) => [
        _TabConfig(
          icon: Icons.chat_bubble_outline,
          label: l10n.translate('drawer_chat'),
          page: _pages[0],
        ),
        _TabConfig(
          icon: Icons.receipt_long_outlined,
          label: l10n.translate('drawer_records'),
          page: _pages[1],
        ),
        _TabConfig(
          icon: Icons.category_outlined,
          label: l10n.translate('drawer_categories'),
          page: _pages[2],
        ),
        if (kDebugMode)
          _TabConfig(
            icon: Icons.science_outlined,
            label: 'Test',
            page: _pages[3],
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = _buildTabs(l10n);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: colorScheme.surface,
          elevation: AppElevation.none,
          surfaceTintColor: Colors.transparent,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            AppConfig().appName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {}, // placeholder — v1 has no notification behavior
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        drawer: _buildAppDrawer(l10n),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: tabs.map((t) => t.page).toList(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          destinations: tabs
              .map(
                (t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildAppDrawer(LocaleProvider l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: AppSpacing.xxl,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppConfig().appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      l10n.translate('app_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: SectionLabel(l10n.translate('settings_header')),
            ),
            ListTile(
              leading: Icon(
                Icons.language,
                size: AppSpacing.xl,
                color: AppColors.onSurface,
              ),
              title: Text(
                l10n.translate('language_label'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.onSurface),
              ),
              trailing: Text(
                l10n.language == AppLanguage.english ? 'English' : 'Tiếng Việt',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
              ),
              onTap: () {
                final current = l10n.language;
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card),
                    ),
                  ),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English'),
                          trailing: current == AppLanguage.english
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            l10n.setLanguage(AppLanguage.english);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Tiếng Việt'),
                          trailing: current == AppLanguage.vietnamese
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            l10n.setLanguage(AppLanguage.vietnamese);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.currency_exchange,
                size: AppSpacing.xl,
                color: AppColors.onSurface,
              ),
              title: Text(
                l10n.translate('currency_label'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.onSurface),
              ),
              trailing: Text(
                L10nConfig.currencyCodes[l10n.currency] ?? 'VND',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
              ),
              onTap: () async {
                final localeProvider = context.read<LocaleProvider>();
                final recordProvider = context.read<RecordProvider>();
                final navigator = Navigator.of(context);
                final currentCurrency = localeProvider.currency;
                final currentCode = L10nConfig.currencyCodes[currentCurrency] ?? 'VND';

                final selected = await showCurrencySelectionPopup(
                  context: context,
                  currentCurrency: currentCode,
                );

                if (selected != null) {
                  final newCurrency = AppCurrency.values.firstWhere(
                    (e) => L10nConfig.currencyCodes[e] == selected,
                    orElse: () => AppCurrency.vnd,
                  );

                  if (newCurrency != currentCurrency) {
                    // ignore: use_build_context_synchronously
                    showDialog(
                      context: context,
                      builder: (dialogContext) => ConfirmationDialog(
                        title: localeProvider.translate('currency_change_confirm_title'),
                        content: localeProvider.translate('currency_change_confirm_content'),
                        confirmLabel: localeProvider.translate('popup_confirm'),
                        cancelLabel: localeProvider.translate('popup_cancel'),
                        isDestructive: true,
                        onConfirm: () async {
                          await recordProvider.resetAllData();
                          await localeProvider.setCurrency(newCurrency);
                          navigator.pop(); // Close drawer
                        },
                      ),
                    );
                  }
                }
              },
            ),
            Builder(
              builder: (tileContext) => ListTile(
                leading: Icon(
                  Icons.share_outlined,
                  size: AppSpacing.xl,
                  color: AppColors.onSurface,
                ),
                title: Text(
                  l10n.translate('share_app_label'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.onSurface),
                ),
                onTap: () {
                  final box = tileContext.findRenderObject() as RenderBox?;
                  final origin =
                      box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
                  final message = l10n
                      .translate('share_app_message')
                      .replaceAll('{android_url}', AppConfig.androidPlayStoreUrl);
                  Share.share(message, sharePositionOrigin: origin);
                },
              ),
            ),
            const Spacer(),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                size: AppSpacing.xl,
                color: AppColors.error,
              ),
              title: Text(
                l10n.translate('reset_all_data'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => ConfirmationDialog(
                    title: l10n.translate('reset_data_confirm_title'),
                    content: l10n.translate('reset_data_confirm_content'),
                    confirmLabel: l10n.translate('reset_button'),
                    cancelLabel: l10n.translate('popup_cancel'),
                    isDestructive: true,
                    onConfirm: () {
                      context.read<RecordProvider>().resetAllData();
                      Navigator.of(context).pop(); // Close drawer
                    },
                  ),
                );
              },
            ),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                AppConfig().fullVersion,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
