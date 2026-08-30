import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v4.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/sqlite_draft_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/data/sources/sqlite_work_order_local_data_source.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';

import '../../../support/sqlite_test_database.dart';

void main() {
  test(
    'controller saves recommendation linkage through SQLite v4 drafts',
    () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final localDataSource = SqliteWorkOrderLocalDataSource(
        database: database,
        userScope: LocalUserScope(_ownerUserId),
        localIdGenerator: () => 'work-order-local-1',
        clock: () => DateTime.utc(2026, 8, 29, 9),
      );
      final controller = WorkOrdersController(
        SqliteDraftWorkOrderRepository(localDataSource),
        now: () => DateTime.utc(2026, 8, 29, 9),
      );
      addTearDown(controller.dispose);

      expect(
        await database.query(AppDatabaseMigrationV4.workOrderRecordsTable),
        isEmpty,
      );

      final saved = await controller.createDraft(
        incidentId: 'INC-1',
        recommendationId: 'REC-1',
        vehicleId: 'B1023',
        taskType: 'Vehicle inspection',
        description: 'Inspect the confirmed breakdown.',
        priority: WorkOrderPriority.high,
        createdBy: 'Current operations staff',
      );

      expect(saved.incidentId, 'INC-1');
      expect(saved.recommendationId, 'REC-1');
      final rows = await database.query(
        AppDatabaseMigrationV4.workOrderRecordsTable,
      );
      expect(rows, hasLength(1));
      expect(rows.single['incident_id'], 'INC-1');
      expect(rows.single['recommendation_id'], 'REC-1');
    },
  );
}

const _ownerUserId = '11111111-1111-4111-8111-111111111111';
