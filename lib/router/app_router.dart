import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_notifier.dart';
import '../features/auth/presentation/login_details_screen.dart';
import '../features/auth/presentation/login_flow_models.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/verify_otp_screen.dart';
import '../features/auth/presentation/welcome_login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/kyc/kyc_screen.dart';
import '../features/matches/matches_list_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_pay_screen.dart';
import '../features/orders/orders_list_screen.dart';
import '../features/profile/profile_hub_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shipments/send_or_shop_screen.dart';
import '../features/shipments/available_shipments_screen.dart';
import '../features/shipments/shipment_carriers_screen.dart';
import '../features/shipments/shipment_detail_screen.dart';
import '../features/shipments/shipments_list_screen.dart';
import '../features/shell/app_shell_screen.dart';
import '../features/trips/available_trips_screen.dart';
import '../features/trips/travel_earn_screen.dart';
import '../features/trips/trip_detail_screen.dart';
import '../features/trips/trips_list_screen.dart';

bool _isLoginPath(String loc) => loc == '/login' || loc.startsWith('/login/');

/// Builds the app router once [auth] has finished [AuthNotifier.bootstrap].
GoRouter buildAppRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: auth.isLoggedIn ? '/dashboard' : '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggingIn = _isLoginPath(loc);
      final signingUp = loc == '/signup';
      final authed = auth.isLoggedIn;

      if (!authed && !loggingIn && !signingUp) return '/login';
      if (authed && (loggingIn || signingUp)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const WelcomeLoginScreen(),
        routes: [
          GoRoute(
            path: 'details',
            builder: (context, state) {
              final initialEmail =
                  state.extra is bool ? state.extra as bool : true;
              return LoginDetailsScreen(initialEmail: initialEmail);
            },
          ),
          GoRoute(
            path: 'verify',
            redirect: (context, state) {
              if (state.extra is! VerifyOtpExtra) return '/login';
              return null;
            },
            builder: (context, state) =>
                VerifyOtpScreen(extra: state.extra as VerifyOtpExtra),
          ),
        ],
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse/orders',
                builder: (context, state) =>
                    const AvailableShipmentsScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse/trips',
                builder: (context, state) =>
                    const AvailableTripsScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const ProfileHubScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/shipments/create',
        builder: (context, state) => const SendOrShopScreen(),
      ),
      GoRoute(
        path: '/trips/create',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return TravelEarnScreen(
            initialFromCity: q['fromCity'],
            initialFromCountryCode: q['fromCountryCode'],
            initialToCity: q['toCity'],
            initialToCountryCode: q['toCountryCode'],
          );
        },
      ),
      GoRoute(
        path: '/my-shipments',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('My orders'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: const ShipmentsListScreen(),
        ),
      ),
      GoRoute(
        path: '/my-trips',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('My trips'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: const TripsListScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) => const KycScreen(),
      ),
      GoRoute(
        path: '/matches',
        builder: (context, state) => const MatchesListScreen(),
      ),
      GoRoute(
        path: '/shipment/:id',
        builder: (context, state) => ShipmentDetailScreen(
          shipmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/shipment/:id/carriers',
        builder: (context, state) => ShipmentCarriersScreen(
          shipmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) => TripDetailScreen(
          tripId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/order/:id/pay',
        builder: (context, state) => OrderPayScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersListScreen(),
      ),
      GoRoute(
        path: '/trips/available',
        redirect: (context, state) => '/browse/trips',
      ),
      GoRoute(
        path: '/shipments/available',
        redirect: (context, state) => '/browse/orders',
      ),
    ],
  );
}
