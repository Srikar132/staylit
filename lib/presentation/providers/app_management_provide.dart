// Simple FutureProvider that calls your static method
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:staylit/data/models/installed_app_model.dart';
import 'package:staylit/services/native_service.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';

/// Installed apps from the native bridge. Deliberately NOT autoDispose: the
/// native package scan is slow, so it runs once per session and is reused by
/// every sheet. `HomeScreen` invalidates it after the app has been in the
/// background for a while (installs/uninstalls), so it never goes stale.
final installedAppsProvider = FutureProvider<List<InstalledApp>>((ref) async {
  // You can add logic here to filter system apps if needed
  final apps = await NativeService.getInstalledApps();
  return apps;
});

/// Apps (with icons) for the limit picker in the Blocks tab. Same lifetime
/// rules as [installedAppsProvider]: scanned once, invalidated by `HomeScreen`.
final pickerAppsProvider = FutureProvider<List<AppInfo>>((ref) {
  return InstalledApps.getInstalledApps(true, true);
});

// 2. Family Provider for Icons (Caches icons individually)
final appIconProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  packageName,
) async {
  return await NativeService.getAppIcon(packageName);
});

// 3. Search Query State
final appSearchQueryProvider = StateProvider<String>((ref) => '');

// 4. Filtered & Grouped Apps (The Brain)
final groupedAppsProvider = Provider<Map<String, List<InstalledApp>>>((ref) {
  final appsAsync = ref.watch(installedAppsProvider);
  final query = ref.watch(appSearchQueryProvider).toLowerCase();

  // Popular apps to prioritize at the top
  const popularApps = [
    'instagram',
    'youtube',
    'facebook',
    'whatsapp',
    'twitter',
    'snapchat',
    'tiktok',
    'telegram',
    'discord',
    'reddit',
    'netflix',
    'spotify',
    'twitch',
    'pinterest',
    'linkedin',
  ];

  return appsAsync.maybeWhen(
    data: (apps) {
      // Filter by search query and exclude Staylit app itself
      final filtered = apps.where((app) {
        final matchesSearch = app.appName.toLowerCase().contains(query);
        // Exclude Staylit app from the list
        final isNotPace =
            !app.packageName.toLowerCase().contains('staylit') &&
            app.appName.toLowerCase() != 'staylit';
        // Allow all apps including YouTube which might be marked as system app
        return matchesSearch && isNotPace;
      }).toList();

      // Sort apps: popular apps first, then alphabetically. Popularity is
      // precomputed once per app here - the comparator below runs O(n log n)
      // times during sort, and this whole provider recomputes on every
      // keystroke (see appSearchQueryProvider), so redoing toLowerCase()
      // and 15x .any() checks inside the comparator itself was real,
      // avoidable synchronous cost on every recompute.
      final isPopular = <String, bool>{
        for (final app in filtered)
          app.packageName: popularApps.any(
            (popular) =>
                app.appName.toLowerCase().contains(popular) ||
                app.packageName.toLowerCase().contains(popular),
          ),
      };

      filtered.sort((a, b) {
        final aIsPopular = isPopular[a.packageName]!;
        final bIsPopular = isPopular[b.packageName]!;

        if (aIsPopular && !bIsPopular) return -1;
        if (!aIsPopular && bIsPopular) return 1;
        return a.appName.compareTo(b.appName);
      });

      // Group by Category
      final Map<String, List<InstalledApp>> grouped = {};
      for (final app in filtered) {
        // You can map raw categories to nicer names here if needed
        String categoryName = app.category.isEmpty ? "Other" : app.category;
        grouped.putIfAbsent(categoryName, () => []).add(app);
      }
      return grouped;
    },
    orElse: () => {},
  );
});

// 5. Allowed Apps Provider (Non-blocked apps)
final allowedAppsProvider =
    Provider.family<AsyncValue<List<InstalledApp>>, String>((ref, userId) {
      final appsAsync = ref.watch(installedAppsProvider);
      final blockedAppsAsync = ref.watch(
        permanentlyBlockedAppsProvider(userId),
      );

      return appsAsync.when(
        data: (apps) {
          return blockedAppsAsync.when(
            data: (blockedPackages) {
              // Filter out blocked apps and system apps
              final allowed = apps.where((app) {
                final isNotBlocked = !blockedPackages.contains(app.packageName);
                final isNotSystem = !app.isSystemApp;
                return isNotBlocked && isNotSystem;
              }).toList();

              // Sort alphabetically
              allowed.sort((a, b) => a.appName.compareTo(b.appName));

              return AsyncValue.data(allowed);
            },
            loading: () => const AsyncValue.loading(),
            error: (err, stack) => AsyncValue.error(err, stack),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    });
