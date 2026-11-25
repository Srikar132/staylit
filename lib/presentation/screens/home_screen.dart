import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/screens/blocks_screen.dart';
import 'package:staylit/presentation/screens/focus_screen.dart';
import 'package:staylit/presentation/screens/group_screen.dart';
import 'package:staylit/presentation/screens/usage_stats_screen.dart';
import 'package:staylit/presentation/widgets/design/black_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Lazily built so tabs the user never opens don't pay init/network cost.
  // Once built, kept alive by IndexedStack (index null -> not built yet).
  static const _screenBuilders = <WidgetBuilder>[
    _buildFocus,
    _buildGroup,
    _buildBlocks,
    _buildUsage,
  ];
  final List<Widget?> _screens = List.filled(_screenBuilders.length, null);

  // Same order as _screenBuilders.
  static const _navItems = <BottomNavItem>[
    BottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Focus',
    ),
    BottomNavItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Groups',
    ),
    BottomNavItem(
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield_rounded,
      label: 'Blocks',
    ),
    BottomNavItem(
      icon: Icons.bar_chart_rounded,
      selectedIcon: Icons.bar_chart_rounded,
      label: 'Usage',
    ),
  ];

  static Widget _buildFocus(BuildContext _) => const FocusScreen();
  static Widget _buildGroup(BuildContext _) => const GroupScreen();
  static Widget _buildBlocks(BuildContext _) => const BlocksScreen();
  static Widget _buildUsage(BuildContext _) => const UsageStatsScreen();

  @override
  Widget build(BuildContext context) {
    _screens[_selectedIndex] ??= _screenBuilders[_selectedIndex](context);
    final palette = context.palette;

    return Scaffold(
      // The near-black behind the content shows through the content's rounded
      // bottom corners, which is what makes the nav bar read as a separate bar.
      backgroundColor: palette.ink,
      // Keyboard viewInsets are a single global window value - every
      // Scaffold in the tree reacts to them by default, not just the one
      // actually hosting the focused field. Modal sheets opened above this
      // (FocusTimeBottomSheet, BlockAppsSheet) already handle their own
      // keyboard inset manually, so this base Scaffold reacting too was
      // redundant - it made the tab behind the sheet visibly shift/resize
      // whenever a text field inside the sheet got focus. Tabs that do need
      // resize-avoidance for their own inline fields (UsageStatsScreen) have
      // their own nested Scaffold, so they're unaffected by this.
      resizeToAvoidBottomInset: false,
      body: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.card),
        ),
        child: ColoredBox(
          color: palette.canvas,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              for (var i = 0; i < _screens.length; i++)
                _screens[i] ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BlackBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
        items: _navItems,
      ),
    );
  }
}
