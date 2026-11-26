import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/providers/app_management_provide.dart'
    show installedAppsProvider, pickerAppsProvider;
import 'package:staylit/presentation/providers/app_limit_sync_provider.dart';
import 'package:staylit/presentation/providers/home_tab_provider.dart';
import 'package:staylit/presentation/providers/usage_stats_provider.dart';
import 'package:staylit/presentation/providers/scroll_damage_sync_provider.dart';
import 'package:staylit/presentation/screens/blocks_screen.dart';
import 'package:staylit/presentation/screens/focus_screen.dart';
import 'package:staylit/presentation/screens/group_screen.dart';
import 'package:staylit/presentation/screens/progress_screen.dart';
import 'package:staylit/presentation/widgets/design/black_bottom_nav.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// When the app went to the background; null while in the foreground.
  DateTime? _pausedAt;

  /// Installed-app lists are cached for the session. Rescan after the app has
  /// been away this long, which is when an install/uninstall may have happened.
  static const _appListStaleAfter = Duration(minutes: 2);

  // Tab indexes whose content shows today's phone usage.
  static const _focusTab = 0;
  static const _progressTab = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      // Previous value stays visible while it reloads - no spinner flash.
      ref.invalidate(todayUsageStatsProvider);
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= _appListStaleAfter) {
        ref.invalidate(installedAppsProvider);
        ref.invalidate(pickerAppsProvider);
      }
    }
  }

  void _selectTab(int index) {
    // Usage stats are only read once per provider lifetime; refresh when the
    // user lands on a tab that shows them.
    if (index != _selectedIndex &&
        (index == _focusTab || index == _progressTab)) {
      ref.invalidate(todayUsageStatsProvider);
    }
    setState(() => _selectedIndex = index);
  }

  // Lazily built so tabs the user never opens don't pay init/network cost.
  // Once built, kept alive by IndexedStack (index null -> not built yet).
  static const _screenBuilders = <WidgetBuilder>[
    _buildFocus,
    _buildGroup,
    _buildBlocks,
    _buildProgress,
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
      selectedIcon: Icons.groups,
      label: 'Groups',
    ),
    BottomNavItem(
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield_rounded,
      label: 'Blocks',
    ),
    BottomNavItem(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Progress',
    ),
  ];

  static Widget _buildFocus(BuildContext _) => const FocusScreen();
  static Widget _buildGroup(BuildContext _) => const GroupScreen();
  static Widget _buildBlocks(BuildContext _) => const BlocksScreen();
  static Widget _buildProgress(BuildContext _) => const ProgressScreen();

  @override
  Widget build(BuildContext context) {
    // A tab can ask the shell to switch (e.g. Home -> Blocks).
    ref.listen<int?>(homeTabRequestProvider, (_, tab) {
      if (tab == null) return;
      _selectTab(tab);
      ref.read(homeTabRequestProvider.notifier).clear();
    });

    // Keeps the native Scroll damage counter and Firestore in step (no UI).
    ref.watch(scrollDamageSyncProvider);

    // Keeps native app-limit enforcement in step with Firestore (no UI), whichever tab is open.
    ref.watch(appLimitSyncProvider);

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
      // resize-avoidance for their own inline fields have their own nested
      // Scaffold, so they're unaffected by this.
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
        onSelected: _selectTab,
        items: _navItems,
      ),
    );
  }
}
