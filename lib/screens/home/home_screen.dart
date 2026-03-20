import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import '../../configs/app_config.dart';
import 'tabs/chat_tab.dart';
import 'tabs/records_tab.dart';
import 'tabs/test_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final FocusNode _recordingFocusNode = FocusNode();
  late final TabController _tabController;

  // Dev mode toggle logic
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Check if the app was opened from a widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) _handleWidgetClick(uri);
    });

    // Listen for clicks while the app is in the background
    HomeWidget.widgetClicked.listen(_handleWidgetClick);
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
      AppConfig().toggleDevMode().then((_) {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Developer mode ${AppConfig().devMode ? 'enabled' : 'disabled'}'), duration: const Duration(seconds: 2)));
        }
      });
    }
  }

  Widget _buildAppBarTitle() {
    return GestureDetector(
      onTap: _handleTitleTap,
      child: Column(
        children: [
          Text(AppConfig().appName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          Text(
            'Expense Tracker ${AppConfig().devMode ? '(dev)' : ''}',
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            const Tab(icon: Icon(Icons.receipt_long), text: 'Records'),
            if (AppConfig().devMode) const Tab(icon: Icon(Icons.science_outlined), text: 'Test'),
          ],
        ),
      ),
      drawer: _buildAppDrawer(context),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            ChatTab(focusNode: _recordingFocusNode),
            const RecordsTab(),
            if (AppConfig().devMode) const TestTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
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
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  Text('Personal finance copilot', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat'),
            onTap: () {
              _tabController.animateTo(0);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Records'),
            onTap: () {
              _tabController.animateTo(1);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Test'),
            onTap: () {
              _tabController.animateTo(2);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
