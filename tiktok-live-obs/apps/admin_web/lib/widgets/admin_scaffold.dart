import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final Widget body;
  final List<Widget>? actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.actions,
  });

  static const _navItems = [
    ('ダッシュボード', Icons.dashboard, '/'),
    ('ユーザー管理', Icons.people, '/users'),
    ('メッセージ配信', Icons.mail, '/messages'),
    ('端末管理', Icons.devices, '/devices'),
    ('操作ログ', Icons.history, '/logs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Side navigation
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 800,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(_navItems[i].$3),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Image.network(
                    'assets/logo.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('RK', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '管理',
                    style: TextStyle(fontSize: 9, color: Colors.white38),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final (label, icon, _) in _navItems)
                NavigationRailDestination(
                  icon: Icon(icon),
                  label: Text(label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161823),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ...?actions,
                    ],
                  ),
                ),
                // Body
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
