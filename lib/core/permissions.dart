import '../models/role.dart';

enum AppOperation {
  viewCatalog,
  viewOwnPurchases,
  manageCatalog,
  manageCustomers,
  createSale,
  hardDelete,
  restoreDeleted,
  manageUsers,
  viewStats,
}

class Permissions {
  const Permissions._();

  static bool can(Role role, AppOperation op) {
    return switch (op) {
      AppOperation.viewCatalog => true,
      AppOperation.viewOwnPurchases => role == Role.reader,
      AppOperation.manageCatalog => role.atLeast(Role.librarian),
      AppOperation.manageCustomers => role.atLeast(Role.librarian),
      // Касса — только менеджер (у админа этого раздела нет — п.10).
      AppOperation.createSale => role == Role.librarian,
      AppOperation.hardDelete => role.atLeast(Role.admin),
      AppOperation.restoreDeleted => role.atLeast(Role.admin),
      AppOperation.manageUsers => role.atLeast(Role.admin),
      AppOperation.viewStats => role.atLeast(Role.admin),
    };
  }

  static String? redirectForPath({
    required String path,
    required bool authenticated,
    required Role? role,
  }) {
    final isAuthRoute =
        path.startsWith('/login') || path.startsWith('/register');

    if (!authenticated) {
      if (isAuthRoute || path.startsWith('/denied')) return null;
      final from = Uri.encodeComponent(path);
      return '/login?from=$from';
    }

    if (isAuthRoute) return '/products';

    if (path.startsWith('/my-purchases')) {
      if (role != Role.reader) return '/denied';
      return null;
    }
    if (path.startsWith('/users') || path.startsWith('/stats')) {
      if (role == null || !role.atLeast(Role.admin)) return '/denied';
      return null;
    }
    // Продажи — уникальный раздел менеджера.
    if (path.startsWith('/sales')) {
      if (role != Role.librarian) return '/denied';
      return null;
    }
    if (path.startsWith('/customers') ||
        path.startsWith('/suppliers') ||
        path.startsWith('/brands') ||
        path.startsWith('/categories') ||
        path.contains('/new') ||
        path.contains('/edit')) {
      if (role == null || !role.atLeast(Role.librarian)) return '/denied';
      return null;
    }
    return null;
  }
}
