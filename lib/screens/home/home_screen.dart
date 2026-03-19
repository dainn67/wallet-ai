import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Check if the app was opened from a widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) {
        _handleWidgetClick(uri);
      }
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
      _tabController.animateTo(0);
      _recordingFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
      appBar: AppBar(
        title: Column(
          children: [
            Text('Wallet AI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            Text(
              'Always active',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Records'),
            Tab(icon: Icon(Icons.science_outlined), text: 'Test'),
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
            const TestTab(),
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
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Wallet AI',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  Text('Personal finance copilot', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 12)),
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
