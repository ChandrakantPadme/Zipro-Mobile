import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../kyc/kyc_status_provider.dart';

/// Bottom navigation: Home, discovery feeds, account hub.
class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_NavDest>[
    _NavDest(
      '/dashboard',
      'Dashboard',
      Icons.grid_view_outlined,
      Icons.grid_view_rounded,
      requiresKycVerified: false,
    ),
    _NavDest(
      '/browse/orders',
      'Live orders',
      Icons.inventory_2_outlined,
      Icons.inventory_2,
    ),
    _NavDest(
      '/browse/trips',
      'Active trips',
      Icons.flight_outlined,
      Icons.flight,
    ),
    _NavDest(
      '/account',
      'Account',
      Icons.person_outline,
      Icons.person,
      requiresKycVerified: false,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kyc = ref.watch(kycGateProvider);
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[currentIndex].label),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          final dest = _destinations[index];
          final blocked = dest.requiresKycVerified && !kyc.isVerified;
          if (blocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your KYC documents are being reviewed. You can use the app again once verified.',
                ),
              ),
            );
            return;
          }
          navigationShell.goBranch(index);
        },
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: Icon(_destinations[i].iconOutlined),
              selectedIcon: Icon(
                _destinations[i].iconSelected,
                color: AppColors.primary,
              ),
              label: _destinations[i].shortLabel,
            ),
        ],
      ),
    );
  }
}

class _NavDest {
  const _NavDest(
    this.path,
    this.label,
    this.iconOutlined,
    this.iconSelected, {
    this.requiresKycVerified = true,
  });

  final String path;
  final String label;
  final IconData iconOutlined;
  final IconData iconSelected;
  final bool requiresKycVerified;

  String get shortLabel {
    if (label == 'Live orders') return 'Orders';
    if (label == 'Active trips') return 'Trips';
    if (label == 'Account') return 'Account';
    return label;
  }
}
