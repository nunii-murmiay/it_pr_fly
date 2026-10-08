import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../state/auth_notifier.dart';

class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool Function(AuthNotifier auth) visible;

  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.visible,
  });
}

class AppShell extends StatelessWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  static const _catalogPaths = {
    '/products',
    '/suppliers',
    '/brands',
    '/categories',
    '/customers',
  };

  static final _all = <_NavItem>[
    _NavItem(
      path: '/products',
      label: 'Товары',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      visible: (_) => true,
    ),
    _NavItem(
      path: '/my-purchases',
      label: 'Мои покупки',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
      visible: (a) => a.can(AppOperation.viewOwnPurchases),
    ),
    _NavItem(
      path: '/sales',
      label: 'Касса',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      visible: (a) => a.can(AppOperation.createSale),
    ),
    _NavItem(
      path: '/suppliers',
      label: 'Поставщики',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      visible: (a) => a.can(AppOperation.manageCatalog),
    ),
    _NavItem(
      path: '/brands',
      label: 'Бренды',
      icon: Icons.sell_outlined,
      selectedIcon: Icons.sell,
      visible: (a) => a.can(AppOperation.manageCatalog),
    ),
    _NavItem(
      path: '/categories',
      label: 'Категории',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
      visible: (a) => a.can(AppOperation.manageCatalog),
    ),
    _NavItem(
      path: '/customers',
      label: 'Клиенты',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      visible: (a) => a.can(AppOperation.manageCustomers),
    ),
    _NavItem(
      path: '/users',
      label: 'Пользователи',
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      visible: (a) => a.can(AppOperation.manageUsers),
    ),
    _NavItem(
      path: '/stats',
      label: 'Статистика',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      visible: (a) => a.can(AppOperation.viewStats),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    AuthNotifier? auth;
    try {
      auth = context.watch<AuthNotifier>();
    } on ProviderNotFoundException {
      auth = null;
    }

    final items =
        auth == null
            ? _all.where((n) => _catalogPaths.contains(n.path)).toList()
            : _all.where((n) => n.visible(auth!)).toList();

    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < Breakpoints.phone;
    final desktop = width >= Breakpoints.desktop;
    final manyOnPhone = phone && items.length > 5;

    var index = items.indexWhere((n) => location.startsWith(n.path));
    if (index < 0) index = 0;

    final page = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.contentMax),
        child: child,
      ),
    );

    final user = auth?.user;

    return Scaffold(
      body: Column(
        children: [
          if (auth != null)
            Material(
              color: theme.colorScheme.surfaceContainerHighest,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          user == null
                              ? 'ЗооМаг'
                              : '${user.fullName} · ${user.role.label}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Выйти',
                        onPressed: () async {
                          await auth!.logout();
                          if (context.mounted) context.go('/login');
                        },
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                if (!phone && items.isNotEmpty)
                  NavigationRail(
                    selectedIndex: index.clamp(0, items.length - 1),
                    onDestinationSelected: (i) => context.go(items[i].path),
                    extended: desktop,
                    labelType: NavigationRailLabelType.none,
                    leading: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: desktop ? 24 : 12,
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: desktop ? 24 : 18,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.pets,
                              size: desktop ? 28 : 20,
                              color: const Color(0xFF0F766E),
                              semanticLabel: 'ЗооМаг',
                            ),
                          ),
                          if (desktop) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'ЗооМаг',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    destinations: [
                      for (final n in items)
                        NavigationRailDestination(
                          icon: Tooltip(message: n.label, child: Icon(n.icon)),
                          selectedIcon: Icon(n.selectedIcon),
                          label: Text(n.label),
                        ),
                    ],
                  ),
                if (!phone) const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          !phone || items.isEmpty
              ? null
              : manyOnPhone
              ? _ManyDestinationsBar(
                items: items,
                index: index.clamp(0, items.length - 1),
                onSelected: (i) => context.go(items[i].path),
              )
              : NavigationBar(
                selectedIndex: index.clamp(0, items.length - 1),
                onDestinationSelected: (i) => context.go(items[i].path),
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                height: 64,
                destinations: [
                  for (final n in items)
                    NavigationDestination(
                      icon: Tooltip(message: n.label, child: Icon(n.icon)),
                      label: n.label,
                    ),
                ],
              ),
    );
  }
}

class _ManyDestinationsBar extends StatelessWidget {
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  const _ManyDestinationsBar({
    required this.items,
    required this.index,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final selected = i == index;
              final color =
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant;
              return InkWell(
                onTap: () => onSelected(i),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: item.label,
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: color,
                        ),
                      ),
                      if (selected)
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
