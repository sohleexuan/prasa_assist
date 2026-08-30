import '../features/work_orders/controllers/work_orders_controller.dart';
import '../features/work_orders/data/sqlite_draft_work_order_repository.dart';
import '../features/work_orders/data/work_order_repository.dart';
import '../features/work_orders/models/work_order.dart';
import '../features/work_orders/repositories/hybrid_work_order_repository.dart';
import '../features/work_orders/repositories/work_order_data_exception.dart';

/// App-owned compatibility bridge between Module 2's current form controller
/// and its production hybrid repository.
///
/// Confirmed reads remain remote-first through [hybridRepository]. New and
/// edited local drafts remain owner-scoped in SQLite. The legacy controller
/// does not carry a confirmed record's expected version, so this bridge
/// deliberately refuses confirmed writes instead of issuing an unsafe update.
class ProductionWorkOrderRepository implements WorkOrderRepository {
  ProductionWorkOrderRepository({
    required this.hybridRepository,
    required this.draftRepository,
  });

  final HybridWorkOrderRepository hybridRepository;
  final SqliteDraftWorkOrderRepository draftRepository;

  @override
  Future<List<WorkOrder>> readAll() async {
    final drafts = await draftRepository.readAll();
    try {
      final confirmed = await hybridRepository.readAllWithProvenance();
      return List<WorkOrder>.unmodifiable([...drafts, ...confirmed.data]);
    } on WorkOrderOfflineException {
      if (drafts.isNotEmpty) return drafts;
      rethrow;
    }
  }

  @override
  Future<WorkOrder?> read(String workOrderId) async {
    final local = await draftRepository.read(workOrderId);
    if (local != null && local.status == WorkOrderStatus.draft) return local;
    return (await hybridRepository.readWithProvenance(workOrderId)).data;
  }

  @override
  Future<WorkOrder> create(WorkOrder workOrder) =>
      draftRepository.create(workOrder);

  @override
  Future<WorkOrder> update(WorkOrder workOrder) async {
    final local = await draftRepository.read(workOrder.workOrderId);
    if (local != null && local.status == WorkOrderStatus.draft) {
      return draftRepository.update(workOrder);
    }
    throw const WorkOrderValidationException(
      'Refresh the confirmed work order before changing it. '
      'A verified remote version is required.',
    );
  }
}

/// Exposes the app-owned production composition for app-level verification.
class ProductionWorkOrdersController extends WorkOrdersController {
  ProductionWorkOrdersController(this.productionRepository)
    : super(productionRepository);

  final ProductionWorkOrderRepository productionRepository;
}
