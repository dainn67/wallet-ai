import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:wallet_ai/screens/home/tabs/categories_tab.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/screens/home/tabs/records_tab.dart';
import 'package:wallet_ai/screens/home/tabs/test_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final FocusNode _recordingFocusNode = FocusNode();
  late TabController _tabController;

  // Dev mode toggle logic
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AppConfig().devMode ? 4 : 3,
      vsync: this,
      initialIndex: 0,
    );

    // Check if the app was opened from a widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) _handleWidgetClick(uri);
    });

    // Listen for clicks while the app is in the background
    HomeWidget.widgetClicked.listen(_handleWidgetClick);

    // Show onboarding dialog on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (StorageService().getBool(StorageService.keyOnboardingComplete) != true) {
        OnboardingDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recordingFocusNode.dispose();
    super.dispose();
  }

  void _handleWidgetClick(Uri? uri) {
    debugPrint('Widget Clicked: $uri');
    if (uri?.host == 'record') {
      // Switch to chat tab
      _tabController.animateTo(0);

      // Wait for tab animation to finish before requesting focus
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _recordingFocusNode.requestFocus();
      });
    }
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 5)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 10) {
      _tapCount = 0;
      final localeProvider = context.read<LocaleProvider>();
      AppConfig().toggleDevMode().then((_) {
        if (mounted) {
          final oldIndex = _tabController.index;
          _tabController.dispose();
          _tabController = TabController(
            length: AppConfig().devMode ? 4 : 3,
            vsync: this,
            initialIndex: oldIndex.clamp(0, AppConfig().devMode ? 3 : 2),
          );
          setState(() {});
          final message = AppConfig().devMode ? localeProvider.translate('dev_mode_enabled') : localeProvider.translate('dev_mode_disabled');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
        }
      });
    }
  }

  Widget _buildAppBarTitle() {
    return GestureDetector(
      onTap: _handleTitleTap,
      child: Column(
        children: [
          Text(AppConfig().appName, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            'Expense Tracker ${AppConfig().devMode ? "(dev)" : ""}',
            style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // For Android
            statusBarBrightness: Brightness.light,    // For iOS (dark icons)
          ),
          title: _buildAppBarTitle(),
          // actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
          bottom: TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(icon: const Icon(Icons.chat_bubble_outline), text: l10n.translate('drawer_chat')),
              Tab(icon: const Icon(Icons.receipt_long), text: l10n.translate('drawer_records')),
              Tab(icon: const Icon(Icons.category_outlined), text: l10n.translate('drawer_categories')),
              if (AppConfig().devMode) const Tab(icon: Icon(Icons.science_outlined), text: 'Test'),
            ],
          ),
        ),
        drawer: _buildAppDrawer(),
        body: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChatTab(focusNode: _recordingFocusNode),
              const RecordsTab(),
              const CategoriesTab(),
              if (AppConfig().devMode) const TestTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    final l10n = context.watch<LocaleProvider>();

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConfig().appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.translate('app_subtitle'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.translate('settings_header'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language, size: 20),
              title: Text(l10n.translate('language_label')),
              trailing: Text(
                l10n.language == AppLanguage.english ? 'English' : 'Tiếng Việt',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              onTap: () {
                final current = l10n.language;
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English'),
                          trailing: current == AppLanguage.english ? const Icon(Icons.check, color: Colors.blue) : null,
                          onTap: () {
                            l10n.setLanguage(AppLanguage.english);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Tiếng Việt'),
                          trailing: current == AppLanguage.vietnamese ? const Icon(Icons.check, color: Colors.blue) : null,
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
              leading: const Icon(Icons.currency_exchange, size: 20),
              title: Text(l10n.translate('currency_label')),
              trailing: Text(
                L10nConfig.currencyCodes[l10n.currency] ?? 'VND',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
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
                    orElse: () => AppCurrency.vnd
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
            const Spacer(),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
              title: Text(l10n.translate('reset_all_data'), style: const TextStyle(color: Colors.red)),
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
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                AppConfig().fullVersion,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
