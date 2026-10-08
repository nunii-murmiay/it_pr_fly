import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../models/role.dart';
import '../state/auth_notifier.dart';

/// Роль для тестов виджетов. В приложении роль берётся из [AuthNotifier].
class AccessScope extends InheritedWidget {
  final Role role;

  const AccessScope({super.key, required this.role, required super.child});

  static Role? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AccessScope>()?.role;
  }

  @override
  bool updateShouldNotify(AccessScope oldWidget) => role != oldWidget.role;
}

/// Прячет дочерний виджет, если роли не хватает на операцию.
class RoleGate extends StatelessWidget {
  final AppOperation operation;
  final Widget child;

  const RoleGate({super.key, required this.operation, required this.child});

  @override
  Widget build(BuildContext context) {
    final role = _currentRole(context);
    if (role == null || !Permissions.can(role, operation)) {
      return const SizedBox.shrink();
    }
    return child;
  }

  Role? _currentRole(BuildContext context) {
    try {
      final auth = Provider.of<AuthNotifier>(context);
      if (auth.user != null) return auth.user!.role;
    } on ProviderNotFoundException {
      return AccessScope.maybeOf(context);
    }
    return AccessScope.maybeOf(context);
  }
}
