import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/models/installed_app_model.dart';
import 'package:staylit/presentation/providers/app_management_provide.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';
import 'package:staylit/presentation/providers/parental_control_provider.dart';
import 'package:staylit/presentation/widgets/design/app_icon_badge.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';
import 'package:staylit/widgets/parental_control_dialogs.dart';

/// When parental mode is on, unblocking needs the parental password. Returns
/// true when it is fine to go ahead (mode off, or the password was right).
Future<bool> _mayUnblock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String description,
}) async {
  final doc = await FirebaseFirestore.instance
      .collection('parental_controls')
      .doc(userId)
      .get();
  final enabled = doc.exists && (doc.data()?['isEnabled'] as bool? ?? false);
  if (!enabled) return true;
  if (!context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final errorColor = context.palette.error;
  final service = ref.read(parentalControlServiceProvider);
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => VerifyPasswordDialog(
      title: 'Parental mode',
      description: description,
      onVerify: (password) =>
          service.verifyPassword(userId: userId, password: password),
    ),
  );

  if (verified != true) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Incorrect password, or cancelled'),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 2),
      ),
    );
    return false;
  }
  return true;
}

/// Pick the apps to block during every focus session.
class BlockAppsSheet extends ConsumerStatefulWidget {
  const BlockAppsSheet({super.key});

  @override
  ConsumerState<BlockAppsSheet> createState() => _BlockAppsSheetState();
}

class _BlockAppsSheetState extends ConsumerState<BlockAppsSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  // Collapsing a category removes its app rows from the flat row list below.
  final Set<String> _collapsedCategories = {};

  @override
  void initState() {
    super.initState();
    // appSearchQueryProvider is global, so a stale query would survive
    // close/reopen. Riverpod forbids writing during initState; defer.
    Future.microtask(() {
      if (mounted) ref.read(appSearchQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    // Re-filtering the full app list per keystroke made typing laggy.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(appSearchQueryProvider.notifier).state = val;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  // Flat row list so ListView.builder only builds on-screen rows. Memoized:
  // build() reruns on every keyboard-inset frame.
  Map<String, List<InstalledApp>>? _rowsCacheKey;
  List<_Row> _cachedRows = const [];

  List<_Row> _rowsFor(Map<String, List<InstalledApp>> groupedApps) {
    if (identical(groupedApps, _rowsCacheKey)) return _cachedRows;
    final rows = <_Row>[];
    for (final entry in groupedApps.entries) {
      rows.add(_HeaderRow(category: entry.key, apps: entry.value));
      if (!_collapsedCategories.contains(entry.key)) {
        rows.addAll(entry.value.map(_AppRow.new));
      }
    }
    _rowsCacheKey = groupedApps;
    _cachedRows = rows;
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final groupedApps = ref.watch(groupedAppsProvider);
    final isLoading = ref.watch(installedAppsProvider).isLoading;
    final rows = _rowsFor(groupedApps);

    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      // Fixed height: shrinking with the keyboard forced a full repaint per
      // frame. Only the list yields to the keyboard (trailing spacer).
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        children: [
          const BottomSheetDragHandle(),
          _buildHeader(context),
          _buildSearchBar(context),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No apps found',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            Expanded(
              child: RepaintBoundary(
                child: ListView.builder(
                  scrollCacheExtent: ScrollCacheExtent.pixels(500),
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.xxxl,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return switch (row) {
                      _HeaderRow() => _CategoryHeader(
                        key: ValueKey('header-${row.category}'),
                        category: row.category,
                        apps: row.apps,
                        isExpanded: !_collapsedCategories.contains(
                          row.category,
                        ),
                        onToggle: () => setState(() {
                          if (!_collapsedCategories.add(row.category)) {
                            _collapsedCategories.remove(row.category);
                          }
                          _rowsCacheKey = null;
                        }),
                      ),
                      _AppRow() => _AppListTile(
                        key: ValueKey(row.app.packageName),
                        app: row.app,
                      ),
                    };
                  },
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: keyboardHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(child: Text('Apps to block', style: textTheme.displaySmall)),
          IconCircleButton(
            icon: Icons.close_rounded,
            semanticLabel: 'Close',
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: palette.onCanvas),
        decoration: InputDecoration(
          hintText: 'Search apps',
          prefixIcon: Icon(Icons.search_rounded, color: palette.onCanvasMuted),
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flat row model
// ---------------------------------------------------------------------------
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  final String category;
  final List<InstalledApp> apps;
  const _HeaderRow({required this.category, required this.apps});
}

class _AppRow extends _Row {
  final InstalledApp app;
  const _AppRow(this.app);
}

// ---------------------------------------------------------------------------
// Category header: name, how many are blocked, "block all", expand/collapse.
// ---------------------------------------------------------------------------
class _CategoryHeader extends ConsumerWidget {
  final String category;
  final List<InstalledApp> apps;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CategoryHeader({
    super.key,
    required this.category,
    required this.apps,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider).value;
    final blockedSet =
        (user != null
                ? ref.watch(permanentlyBlockedAppsProvider(user.uid))
                : const AsyncValue<List<String>>.data([]))
            .maybeWhen(
              data: (apps) => Set<String>.from(apps),
              orElse: () => <String>{},
            );

    final blockedCount = apps
        .where((app) => blockedSet.contains(app.packageName))
        .length;
    final areAllBlocked = apps.isNotEmpty && blockedCount == apps.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: isExpanded ? 0 : -0.25,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: palette.onCanvasMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(category, style: textTheme.titleMedium)),
              if (blockedCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$blockedCount',
                    style: textTheme.labelMedium?.copyWith(
                      color: palette.accentText,
                    ),
                  ),
                ),
              Switch(
                value: areAllBlocked,
                onChanged: (value) async {
                  if (user == null) return;
                  if (!value &&
                      areAllBlocked &&
                      !await _mayUnblock(
                        context,
                        ref,
                        userId: user.uid,
                        description: 'Enter your password to unblock apps',
                      )) {
                    return;
                  }

                  final notifier = ref.read(
                    blockedContentNotifierProvider.notifier,
                  );
                  for (final app in apps) {
                    final blocked = blockedSet.contains(app.packageName);
                    if (value && !blocked) {
                      await notifier.addPermanentlyBlockedApp(
                        user.uid,
                        app.packageName,
                      );
                    } else if (!value && blocked) {
                      await notifier.removePermanentlyBlockedApp(
                        user.uid,
                        app.packageName,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One app: icon, name, switch. Tapping the row toggles it too.
// ---------------------------------------------------------------------------
class _AppListTile extends ConsumerWidget {
  final InstalledApp app;

  const _AppListTile({super.key, required this.app});

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool block,
    bool wasBlocked,
  ) async {
    if (!block &&
        wasBlocked &&
        !await _mayUnblock(
          context,
          ref,
          userId: userId,
          description: 'Enter your password to unblock ${app.appName}',
        )) {
      return;
    }
    final notifier = ref.read(blockedContentNotifierProvider.notifier);
    if (block) {
      await notifier.addPermanentlyBlockedApp(userId, app.packageName);
    } else {
      await notifier.removePermanentlyBlockedApp(userId, app.packageName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final user = ref.watch(currentUserProvider).value;
    final isBlocked =
        (user != null
                ? ref.watch(permanentlyBlockedAppsProvider(user.uid))
                : const AsyncValue<List<String>>.data([]))
            .maybeWhen(
              data: (apps) => apps.contains(app.packageName),
              orElse: () => false,
            );
    final icon = ref.watch(appIconProvider(app.packageName)).value;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: isBlocked ? palette.accentSoft : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: user == null
                ? null
                : () => _set(context, ref, user.uid, !isBlocked, isBlocked),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  AppIconBadge(name: app.appName, icon: icon, size: 40),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      app.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Switch(
                    value: isBlocked,
                    onChanged: user == null
                        ? null
                        : (value) =>
                              _set(context, ref, user.uid, value, isBlocked),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
