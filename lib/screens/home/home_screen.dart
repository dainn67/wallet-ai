import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/services.dart';
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
    _tabController = TabController(length: AppConfig().devMode ? 4 : 3, vsync: this, initialIndex: 0);

    // Check if the app was opened from a widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) _handleWidgetClick(uri);
    });

    // Listen for clicks while the app is in the background
    HomeWidget.widgetClicked.listen(_handleWidgetClick);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notDone = StorageService().getBool(StorageService.keyOnboardingComplete) != true;
      if (notDone) {
        // ignore: use_build_context_synchronously
        await OnboardingDialog.show(context);
      }
      _maybeAskNotificationPermission();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recordingFocusNode.dispose();
    super.dispose();
  }

  /// First-launch only: surface the OS notification permission prompt 2 seconds
  /// after the home screen is ready. If granted, flips the Reminders toggle on.
  Future<void> _maybeAskNotificationPermission() async {
    final storage = StorageService();
    final alreadyAsked = storage.getBool(StorageService.keyRemindersPermissionAsked) ?? false;
    if (alreadyAsked) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final granted = await NotificationService().requestPermission();
    await storage.setBool(StorageService.keyRemindersPermissionAsked, true);
    await storage.setBool(StorageService.keyRemindersEnabled, granted);

    if (mounted) {
      // ignore: use_build_context_synchronously
      context.read<NotificationProvider>().setEnabled(granted);
    }
  }

  /// Toggle handler for the drawer "Reminders" switch. When the user tries to
  /// turn it ON, we re-check the OS permission first — if it was revoked from
  /// system settings, we surface the existing [ConfirmationDialog] to send
  /// them to the OS settings page instead of silently flipping a useless
  /// toggle. When turning OFF, just persist + cancel pending notifications.
  Future<void> _handleRemindersToggle(
    bool nextValue,
    NotificationProvider notifProvider,
  ) async {
    if (!nextValue) {
      await notifProvider.setEnabled(false);
      return;
    }

    // Capture l10n strings BEFORE the await so we don't reach back into
    // BuildContext after the async gap.
    final l10n = context.read<LocaleProvider>();
    final title = l10n.translate('reminders_permission_denied_title');
    final content = l10n.translate('reminders_permission_denied_content');
    final confirmLabel = l10n.translate('open_settings_button');
    final cancelLabel = l10n.translate('popup_cancel');

    final granted = await NotificationService().isPermissionGranted();
    if (!mounted) return;
    if (granted) {
      await notifProvider.setEnabled(true);
      return;
    }

    // Denied — guide the user to system settings instead.
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => NotificationService().openSystemSettings(),
      ),
    );
  }

  void _handleWidgetClick(Uri? uri) {
    debugPrint('Widget Clicked: $uri');
    if (uri == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dispatchWidgetUri(uri);
    });
  }

  void _dispatchWidgetUri(Uri uri) {
    // Drop widget intents silently while onboarding is in progress.
    final onboardingDone = StorageService().getBool(StorageService.keyOnboardingComplete) == true;
    if (!onboardingDone) {
      debugPrint('[HomeScreen] Widget intent dropped: onboarding in progress');
      return;
    }

    switch (uri.host) {
      case 'record':
        // Switch to chat tab and focus the text input.
        _tabController.animateTo(0);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _recordingFocusNode.requestFocus();
        });
        break;
      case 'camera':
        // Switch to chat tab, then open the camera picker.
        _tabController.animateTo(0);
        context.read<ChatProvider>().pickImageFromCamera(context: context);
        break;
      case 'open':
      default:
        // Root fallback: just bring the app to foreground — no-op.
        break;
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
          _tabController = TabController(length: AppConfig().devMode ? 4 : 3, vsync: this, initialIndex: oldIndex.clamp(0, AppConfig().devMode ? 3 : 2));
          setState(() {});
          final message = AppConfig().devMode ? localeProvider.translate('dev_mode_enabled') : localeProvider.translate('dev_mode_disabled');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
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
            statusBarBrightness: Brightness.light, // For iOS (dark icons)
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
          bottom: false,
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
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary])),
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
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text(l10n.translate('app_subtitle'), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.translate('settings_header'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language, size: 20),
              title: Text(l10n.translate('language_label')),
              trailing: Text(
                l10n.language == AppLanguage.english ? 'English' : 'Tiếng Việt',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
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
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
              ),
              onTap: () async {
                final localeProvider = context.read<LocaleProvider>();
                final recordProvider = context.read<RecordProvider>();
                final navigator = Navigator.of(context);
                final currentCurrency = localeProvider.currency;
                final currentCode = L10nConfig.currencyCodes[currentCurrency] ?? 'VND';

                final selected = await showCurrencySelectionPopup(context: context, currentCurrency: currentCode);

                if (selected != null) {
                  final newCurrency = AppCurrency.values.firstWhere((e) => L10nConfig.currencyCodes[e] == selected, orElse: () => AppCurrency.vnd);

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
                leading: const Icon(Icons.share_outlined, size: 20),
                title: Text(l10n.translate('share_app_label')),
                onTap: () {
                  final box = tileContext.findRenderObject() as RenderBox?;
                  final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
                  final message = l10n.translate('share_app_message').replaceAll('{android_url}', AppConfig.androidPlayStoreUrl);
                  Share.share(message, sharePositionOrigin: origin);
                },
              ),
            ),
            Consumer<NotificationProvider>(
              builder: (_, notifProvider, __) => SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined, size: 20),
                title: Text(l10n.translate('reminders_label')),
                value: notifProvider.enabled,
                activeThumbColor: const Color(0xFF6366F1),
                onChanged: (next) => _handleRemindersToggle(next, notifProvider),
              ),
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
