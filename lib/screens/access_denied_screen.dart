import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Доступ запрещён')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'У вашей роли нет доступа к этому разделу',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  user == null
                      ? 'Войдите в систему.'
                      : 'Текущая роль: ${user.role.label} (${user.fullName}). '
                          'Клиентская проверка маршрута — удобство UI; '
                          'сервер всё равно отклонит запрещённую операцию (403).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/products'),
                  child: const Text('В каталог'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
