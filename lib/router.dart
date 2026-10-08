import 'package:go_router/go_router.dart';

import 'core/permissions.dart';
import 'models/brand_query.dart';
import 'models/category_query.dart';
import 'models/customer_query.dart';
import 'models/product_query.dart';
import 'models/supplier_query.dart';
import 'screens/access_denied_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_purchases_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/purchase_receipt_screen.dart';
import 'screens/register_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/users_screen.dart';
import 'sections/brands.dart' deferred as brands;
import 'sections/categories.dart' deferred as categories;
import 'sections/customers.dart' deferred as customers;
import 'sections/suppliers.dart' deferred as suppliers;
import 'state/auth_notifier.dart';
import 'widgets/deferred_page.dart';
import 'widgets/shop_shell.dart';

export 'widgets/shop_shell.dart';

GoRouter createRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: '/products',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.isRestoring) return null;
      return Permissions.redirectForPath(
        path: state.uri.path,
        authenticated: auth.isAuthenticated,
        role: auth.user?.role,
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/denied',
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      ShellRoute(
        builder:
            (context, state, child) =>
                AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/products',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return ProductListScreen(
                initialQuery: ProductQuery(
                  search: q['search'] ?? '',
                  categoryId: q['categoryId'],
                  brandId: q['brandId'],
                  supplierId: q['supplierId'],
                  priceFrom: double.tryParse(q['priceFrom'] ?? ''),
                  priceTo: double.tryParse(q['priceTo'] ?? ''),
                  sortField: q['sort'] ?? 'name',
                  sortAscending: q['asc'] != 'false',
                  page: int.tryParse(q['page'] ?? '') ?? 1,
                  size: int.tryParse(q['size'] ?? '') ?? 10,
                  includeDeleted: q['includeDeleted'] == 'true',
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'new',
                builder: (c, s) => const ProductFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (c, s) => ProductFormScreen(id: s.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/my-purchases',
            builder: (context, state) => const MyPurchasesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder:
                    (context, state) => PurchaseReceiptScreen(
                      saleId: state.pathParameters['id']!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              final query = SupplierQuery(
                search: q['search'] ?? '',
                country: q['country'],
                sortField: q['sort'] ?? 'name',
                sortAscending: q['asc'] != 'false',
                page: int.tryParse(q['page'] ?? '') ?? 1,
                size: int.tryParse(q['size'] ?? '') ?? 10,
                includeDeleted: q['includeDeleted'] == 'true',
              );
              return DeferredPage(
                loadLibrary: suppliers.loadLibrary,
                builder:
                    (_) => suppliers.SupplierListScreen(initialQuery: query),
              );
            },
            routes: [
              GoRoute(
                path: 'new',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: suppliers.loadLibrary,
                      builder: (_) => suppliers.SupplierFormScreen(),
                    ),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: suppliers.loadLibrary,
                      builder:
                          (_) => suppliers.SupplierFormScreen(
                            id: s.pathParameters['id'],
                          ),
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/brands',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              final query = BrandQuery(
                search: q['search'] ?? '',
                sortField: q['sort'] ?? 'name',
                sortAscending: q['asc'] != 'false',
                page: int.tryParse(q['page'] ?? '') ?? 1,
                size: int.tryParse(q['size'] ?? '') ?? 10,
                includeDeleted: q['includeDeleted'] == 'true',
              );
              return DeferredPage(
                loadLibrary: brands.loadLibrary,
                builder: (_) => brands.BrandListScreen(initialQuery: query),
              );
            },
            routes: [
              GoRoute(
                path: 'new',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: brands.loadLibrary,
                      builder: (_) => brands.BrandFormScreen(),
                    ),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: brands.loadLibrary,
                      builder:
                          (_) => brands.BrandFormScreen(
                            id: s.pathParameters['id'],
                          ),
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              final query = CategoryQuery(
                search: q['search'] ?? '',
                page: int.tryParse(q['page'] ?? '') ?? 1,
                size: int.tryParse(q['size'] ?? '') ?? 10,
                includeDeleted: q['includeDeleted'] == 'true',
              );
              return DeferredPage(
                loadLibrary: categories.loadLibrary,
                builder:
                    (_) => categories.CategoryListScreen(initialQuery: query),
              );
            },
            routes: [
              GoRoute(
                path: 'new',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: categories.loadLibrary,
                      builder: (_) => categories.CategoryFormScreen(),
                    ),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: categories.loadLibrary,
                      builder:
                          (_) => categories.CategoryFormScreen(
                            id: s.pathParameters['id'],
                          ),
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              final query = CustomerQuery(
                search: q['search'] ?? '',
                cardLevel: q['level'],
                sortField: q['sort'] ?? 'fullName',
                sortAscending: q['asc'] != 'false',
                page: int.tryParse(q['page'] ?? '') ?? 1,
                size: int.tryParse(q['size'] ?? '') ?? 10,
                includeDeleted: q['includeDeleted'] == 'true',
              );
              return DeferredPage(
                loadLibrary: customers.loadLibrary,
                builder:
                    (_) => customers.CustomerListScreen(initialQuery: query),
              );
            },
            routes: [
              GoRoute(
                path: 'new',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: customers.loadLibrary,
                      builder: (_) => customers.CustomerFormScreen(),
                    ),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (c, s) => DeferredPage(
                      loadLibrary: customers.loadLibrary,
                      builder:
                          (_) => customers.CustomerFormScreen(
                            id: s.pathParameters['id'],
                          ),
                    ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
