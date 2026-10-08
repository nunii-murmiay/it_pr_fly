import 'package:flutter_application_1/core/permissions.dart';
import 'package:flutter_application_1/models/role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Права ролей зоомагазина', () {
    test('покупатель видит каталог, но не управляет им', () {
      expect(Permissions.can(Role.reader, AppOperation.viewCatalog), isTrue);
      expect(Permissions.can(Role.reader, AppOperation.manageCatalog), isFalse);
    });

    test('покупатель не оформляет продажу и не удаляет навсегда', () {
      expect(Permissions.can(Role.reader, AppOperation.createSale), isFalse);
      expect(Permissions.can(Role.reader, AppOperation.hardDelete), isFalse);
    });

    test('менеджер ведёт каталог и продаёт, но не стирает запись', () {
      expect(
        Permissions.can(Role.librarian, AppOperation.manageCatalog),
        isTrue,
      );
      expect(Permissions.can(Role.librarian, AppOperation.createSale), isTrue);
      expect(Permissions.can(Role.librarian, AppOperation.hardDelete), isFalse);
      expect(
        Permissions.can(Role.librarian, AppOperation.restoreDeleted),
        isFalse,
      );
    });

    test('только администратор удаляет навсегда и восстанавливает', () {
      expect(Permissions.can(Role.admin, AppOperation.hardDelete), isTrue);
      expect(Permissions.can(Role.admin, AppOperation.restoreDeleted), isTrue);
      expect(Permissions.can(Role.admin, AppOperation.manageCustomers), isTrue);
      // Касса — раздел менеджера, у админа его нет (п.10).
      expect(Permissions.can(Role.admin, AppOperation.createSale), isFalse);
    });

    test('админ не открывает кассу менеджера', () {
      expect(
        Permissions.redirectForPath(
          path: '/sales',
          authenticated: true,
          role: Role.admin,
        ),
        '/denied',
      );
    });

    test('гость уходит на вход с обратным адресом', () {
      expect(
        Permissions.redirectForPath(
          path: '/products',
          authenticated: false,
          role: null,
        ),
        '/login?from=%2Fproducts',
      );
    });

    test('покупатель не открывает форму клиента', () {
      expect(
        Permissions.redirectForPath(
          path: '/customers/new',
          authenticated: true,
          role: Role.reader,
        ),
        '/denied',
      );
    });

    test('менеджер остаётся в каталоге брендов', () {
      expect(
        Permissions.redirectForPath(
          path: '/brands',
          authenticated: true,
          role: Role.librarian,
        ),
        isNull,
      );
    });
  });
}
