import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pop the current route if the navigator stack allows it; otherwise go to
/// dashboard (shell home). Use for AppBar leading and [PopScope] on pushed
/// full-screen routes.
void ziproPopOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/dashboard');
  }
}

/// Leading control for full-screen routes: back when stack allows, else home.
Widget ziproLeadingBackOrHome(BuildContext context) {
  final canPop = context.canPop();
  return IconButton(
    icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
    tooltip: canPop ? 'Back' : 'Home',
    onPressed: () => ziproPopOrHome(context),
  );
}

/// Android / predictive back: when [canPop] is false on this scope, [GoRouter]
/// would not pop — we run [ziproPopOrHome] instead. Wrap [Scaffold]s on
/// full-screen pushed routes.
class ZiproPopScope extends StatelessWidget {
  const ZiproPopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ziproPopOrHome(context);
        }
      },
      child: child,
    );
  }
}
