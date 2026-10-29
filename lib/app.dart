import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'core/formatters.dart';
import 'core/json_util.dart';
import 'core/theme.dart';
import 'features/auth_screens.dart';
import 'features/main_screens.dart';
import 'features/manage_screens.dart';
import 'features/seller_parity_screens.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: app.isLoggedIn ? '/' : '/login',
    refreshListenable: app,
    // صفحة 404 عربية بدل الشاشة البيضاء
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('غير موجود')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('الصفحة غير موجودة'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('الرئيسية'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final public =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/privacy' ||
          loc == '/terms';
      if (!app.isLoggedIn && !public) return '/login';
      if (app.isLoggedIn && (loc == '/login' || loc == '/register')) {
        return app.needsPendingScreen ? '/pending' : '/';
      }
      // Web parity (SellerPendingStatus.vue): pending/rejected/no-store stay
      // on the status screen until approved.
      if (app.isLoggedIn && app.needsPendingScreen && loc != '/pending')
        return '/pending';
      if (app.isLoggedIn && !app.needsPendingScreen && loc == '/pending')
        return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/pending', builder: (_, __) => const PendingScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
      GoRoute(
        path: '/sections',
        builder: (_, __) => const SellerSectionsScreen(),
      ),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, s) => OrderDetailsScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/products/create',
        builder: (_, __) => const ProductEditScreen(),
      ),
      GoRoute(
        path: '/products/edit/:id',
        builder: (_, s) => ProductEditScreen(id: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/products/view/:id',
        builder: (_, s) => ProductViewScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stock/:type',
        builder: (_, s) =>
            StockAlertsScreen(type: s.pathParameters['type'] ?? 'low_stock'),
      ),
      GoRoute(
        path: '/accounting',
        builder: (_, __) => const AccountingScreen(),
      ),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(
        path: '/withdrawals',
        builder: (_, __) => const WithdrawalsScreen(),
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(
        path: '/promos',
        builder: (_, __) => ResourceListScreen(
          title: 'أكواد الخصم',
          loader: () => app.api.promoCodes(),
          itemTitle: (i) => J.str(i['promo_code']),
          itemSub: (i) =>
              '${i['discount']} ${Fmt.discountType(i['discount_type'])} • ${Fmt.dateRange(i['start_date'], i['end_date'])}',
          openAdd: (ctx) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => const PromoFormScreen()),
          ),
          openEdit: (ctx, i) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => PromoFormScreen(item: i)),
          ),
          onDelete: (i) => app.api.deletePromo(i['id']),
        ),
      ),
      GoRoute(
        path: '/flash',
        builder: (_, __) => ResourceListScreen(
          title: 'عروض فلاش',
          loader: () => app.api.flashSales(),
          itemTitle: (i) => J.str(i['title']),
          itemSub: (i) => Fmt.dateRange(i['start_at'], i['end_at']),
          openAdd: (ctx) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => const FlashFormScreen()),
          ),
          openEdit: (ctx, i) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => FlashFormScreen(item: i)),
          ),
          onDelete: (i) => app.api.deleteFlash(i['id']),
        ),
      ),
      GoRoute(
        path: '/bxgy',
        builder: (_, __) => ResourceListScreen(
          title: 'اشترِ واحصل',
          loader: () => app.api.bxgyOffers(),
          itemTitle: (i) => J.str(i['title']).isEmpty
              ? 'اشتر ${i['buy_qty']} احصل ${i['get_qty']}'
              : J.str(i['title']),
          itemSub: (i) => Fmt.dateRange(i['start_date'], i['end_date']),
          openAdd: (ctx) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => const BxgyFormScreen()),
          ),
          openEdit: (ctx, i) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => BxgyFormScreen(item: i)),
          ),
          onDelete: (i) => app.api.deleteBxgy(i['id']),
        ),
      ),
      GoRoute(
        path: '/category-discounts',
        builder: (_, __) => ResourceListScreen(
          title: 'خصم التصنيف',
          loader: () => app.api.categoryDiscounts(),
          itemTitle: (i) => J.str(
            i['title'] ??
                (i['category'] is Map
                    ? i['category']['name']
                    : i['category_id']),
          ),
          itemSub: (i) =>
              '${i['discount']} ${Fmt.discountType(i['discount_type'])}',
          openAdd: (ctx) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(
              builder: (_) => const CategoryDiscountFormScreen(),
            ),
          ),
          openEdit: (ctx, i) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(
              builder: (_) => CategoryDiscountFormScreen(item: i),
            ),
          ),
          onDelete: (i) => app.api.deleteCategoryDiscount(i['id']),
        ),
      ),
      GoRoute(
        path: '/delivery-offers',
        builder: (_, __) => ResourceListScreen(
          title: 'عروض التوصيل المجاني',
          loader: () => app.api.deliveryOffers(),
          itemTitle: (i) => J.str(i['title']),
          itemSub: (i) => '${J.str(i['type'])} • ممول من المتجر',
          openAdd: (ctx) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => const DeliveryOfferFormScreen()),
          ),
          openEdit: (ctx, i) => Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => DeliveryOfferFormScreen(item: i)),
          ),
          onDelete: (i) => app.api.deleteDeliveryOffer(i['id']),
        ),
      ),
      GoRoute(
        path: '/units',
        builder: (_, __) =>
            const NamedCrudScreen(title: 'الوحدات', kind: 'units'),
      ),
      GoRoute(path: '/bulk', builder: (_, __) => const BulkUploadScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/seller-orders',
        builder: (_, __) => const SellerOrdersNewScreen(),
      ),
      GoRoute(
        path: '/seller-orders/:id',
        builder: (_, s) =>
            SellerOrderNewDetailsScreen(id: s.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            SellerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsScreen(),
          ),
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
        ],
      ),
    ],
  );
}

class SellerShell extends StatelessWidget {
  const SellerShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  int get index {
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/account')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: index == 0
          ? AppBar(
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/brand/logo.webp',
                      height: 36,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.storeName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'سريع MART',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'الطلبات',
                  onPressed: () => context.push('/orders'),
                  icon: Badge(
                    isLabelVisible:
                        (app.dashboard['pending_order_count'] ?? 0) > 0,
                    label: Text('${app.dashboard['pending_order_count'] ?? 0}'),
                    backgroundColor: AppColors.orange,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: index,
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/products');
                case 2:
                  context.go('/account');
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'المنتجات',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerApp extends StatelessWidget {
  const SellerApp({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'سريع MART - تاجر',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          theme: buildSellerTheme(app.brand),
        );
      },
    );
  }
}
