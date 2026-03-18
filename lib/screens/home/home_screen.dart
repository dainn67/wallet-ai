import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Records'),
              Tab(icon: Icon(Icons.science_outlined), text: 'Test'),
            ],
          ),
        ),
        drawer: _buildAppDrawer(context),
        body: const SafeArea(
          child: TabBarView(
            children: [
              Placeholder(fallbackHeight: 100, color: Colors.blue),
              Placeholder(fallbackHeight: 100, color: Colors.green),
              Placeholder(fallbackHeight: 100, color: Colors.orange),
            ],
          ),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
            ),
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
              final controller = DefaultTabController.of(context);
              controller.animateTo(0);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Records'),
            onTap: () {
              final controller = DefaultTabController.of(context);
              controller.animateTo(1);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Test'),
            onTap: () {
              final controller = DefaultTabController.of(context);
              controller.animateTo(2);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
