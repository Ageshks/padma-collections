import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:padma/data/models/models.dart';
import 'package:padma/data/repositories/category_repository.dart';
import 'package:padma/data/repositories/order_repository.dart';
import 'package:padma/data/repositories/product_repository.dart';
import 'package:padma/data/repositories/user_repository.dart';
import 'package:padma/modules/admin/admin_shell_view.dart';

void main() {
  setUp(() {
    Get.put<ProductRepository>(_LayoutProductRepository());
    Get.put<OrderRepository>(_LayoutOrderRepository());
    Get.put<CategoryRepository>(_LayoutCategoryRepository());
    Get.put<UserRepository>(_LayoutUserRepository());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('dashboard metrics fit phone and tablet widths', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (Size size, int columns) in <(Size, int)>[
      (const Size(320, 568), 2),
      (const Size(390, 844), 2),
      (const Size(768, 1024), 3),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(GetMaterialApp(home: const AdminDashboardView()));
      await tester.pumpAndSettle();

      expect(find.text('Padma Collections Overview'), findsOneWidget);
      final GridView grid = tester.widget<GridView>(find.byType(GridView));
      final SliverGridDelegateWithFixedCrossAxisCount delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, columns, reason: 'Viewport: $size');
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');
    }
  });
}

class _LayoutProductRepository extends ProductRepository {
  @override
  Stream<List<ProductModel>> watchAllProducts() =>
      Stream<List<ProductModel>>.value(const <ProductModel>[]);
}

class _LayoutOrderRepository extends OrderRepository {
  @override
  Stream<List<OrderModel>> watchAllOrders() =>
      Stream<List<OrderModel>>.value(const <OrderModel>[]);
}

class _LayoutCategoryRepository extends CategoryRepository {
  @override
  Stream<List<CategoryModel>> watchAllCategories() =>
      Stream<List<CategoryModel>>.value(const <CategoryModel>[]);
}

class _LayoutUserRepository extends UserRepository {
  @override
  Stream<List<UserModel>> watchCustomers({bool includeAdmins = false}) =>
      Stream<List<UserModel>>.value(const <UserModel>[]);
}
