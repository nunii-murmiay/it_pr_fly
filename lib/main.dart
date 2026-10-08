import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/auth_api.dart';
import 'core/auth_session.dart';
import 'core/catalog_cache.dart';
import 'core/config.dart';
import 'repositories/api_brand_repository.dart';
import 'repositories/api_category_repository.dart';
import 'repositories/api_customer_repository.dart'
    show ApiCustomerRepository, ApiSalesRepository;
import 'repositories/api_product_repository.dart';
import 'repositories/api_supplier_repository.dart';
import 'repositories/brand_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/supplier_repository.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/brand_list_notifier.dart';
import 'state/category_list_notifier.dart';
import 'state/customer_list_notifier.dart';
import 'state/product_list_notifier.dart';
import 'state/supplier_list_notifier.dart';
import 'widgets/inactivity_watcher.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey, // ignore: deprecated_member_use
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(PetShopApp(prefs: prefs));
}

class PetShopApp extends StatefulWidget {
  const PetShopApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<PetShopApp> createState() => _PetShopAppState();
}

class _PetShopAppState extends State<PetShopApp> {
  late final AuthNotifier _auth;
  late final AuthApi _authApi;
  late final AuthSession _session;
  late final GoRouter _router;
  late final SupabaseClient _client;
  Timer? _maxSessionTimer;

  late final ApiProductRepository _productRepo;
  late final ApiSupplierRepository _supplierRepo;
  late final ApiBrandRepository _brandRepo;
  late final ApiCategoryRepository _categoryRepo;
  late final ApiCustomerRepository _customerRepo;
  late final ApiSalesRepository _salesRepo;
  late final CatalogCache _catalog;

  @override
  void initState() {
    super.initState();

    _client = Supabase.instance.client;
    _authApi = AuthApi(_client);
    _auth = AuthNotifier(widget.prefs, _authApi);
    _session = AuthSession(_auth);
    _productRepo = ApiProductRepository(_client, _session);
    _supplierRepo = ApiSupplierRepository(_client, _session);
    _brandRepo = ApiBrandRepository(_client, _session);
    _categoryRepo = ApiCategoryRepository(_client, _session);
    _customerRepo = ApiCustomerRepository(_client, _session);
    _salesRepo = ApiSalesRepository(_client, _session);
    _catalog = CatalogCache(
      brands: _brandRepo,
      categories: _categoryRepo,
      suppliers: _supplierRepo,
    );

    _router = createRouter(_auth);

    _auth.restore().then((_) {
      if (_auth.isAuthenticated) _armMaxSessionTimer();
    });
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      _armMaxSessionTimer();
    } else {
      _maxSessionTimer?.cancel();
    }
  }

  void _armMaxSessionTimer() {
    _maxSessionTimer?.cancel();
    final started = widget.prefs.getInt('auth_session_started');
    var remaining = AuthNotifier.maxSessionDuration;
    if (started != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - started;
      remaining =
          AuthNotifier.maxSessionDuration - Duration(milliseconds: elapsed);
      if (remaining.isNegative) remaining = Duration.zero;
    }
    _maxSessionTimer = Timer(remaining, () async {
      if (!_auth.isAuthenticated) return;
      await _auth.logout(
        message:
            'Сессия завершена: истекло максимальное время входа '
            '(${AuthNotifier.maxSessionDuration.inHours} ч).',
      );
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Достигнут лимит длительности сессии')),
      );
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _maxSessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SupabaseClient>.value(value: _client),
        Provider<AuthApi>.value(value: _authApi),
        Provider<AuthSession>.value(value: _session),
        ChangeNotifierProvider<AuthNotifier>.value(value: _auth),
        Provider<ProductRepository>.value(value: _productRepo),
        Provider<SupplierRepository>.value(value: _supplierRepo),
        Provider<BrandRepository>.value(value: _brandRepo),
        Provider<CategoryRepository>.value(value: _categoryRepo),
        Provider<CustomerRepository>.value(value: _customerRepo),
        Provider<ApiSalesRepository>.value(value: _salesRepo),
        Provider<CatalogCache>.value(value: _catalog),
        ChangeNotifierProvider(
          create: (_) => ProductListNotifier(_productRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => SupplierListNotifier(_supplierRepo),
        ),
        ChangeNotifierProvider(create: (_) => BrandListNotifier(_brandRepo)),
        ChangeNotifierProvider(
          create: (_) => CategoryListNotifier(_categoryRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomerListNotifier(_customerRepo),
        ),
      ],
      child: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) {
          final app = MaterialApp.router(
            title: 'Зоомагазин «Лапки и Хвостики»',
            scaffoldMessengerKey: rootMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F766E),
                primary: const Color(0xFF0F766E),
                secondary: const Color(0xFFD97706),
                brightness: Brightness.light,
              ),
              cardTheme: const CardThemeData(
                elevation: 1,
                margin: EdgeInsets.zero,
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 2,
              ),
            ),
            routerConfig: _router,
            builder: (context, child) {
              if (_auth.isRestoring) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return child ?? const SizedBox.shrink();
            },
          );

          if (!_auth.isAuthenticated) return app;

          return InactivityWatcher(
            timeout: AuthNotifier.inactivityTimeout,
            warningBefore: AuthNotifier.inactivityWarning,
            onActivity: () => _auth.touchActivity(),
            onWarning: (remaining) {
              rootMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    'Сессия завершится через ${remaining.inSeconds} с '
                    'из‑за отсутствия активности',
                  ),
                  duration: remaining,
                ),
              );
            },
            onTimeout: () async {
              await _auth.logout(
                message:
                    'Сессия завершена из‑за отсутствия активности (3 минуты).',
              );
              rootMessengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('Вы вышли из системы по неактивности'),
                ),
              );
            },
            child: app,
          );
        },
      ),
    );
  }
}
