import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/controllers/recommendation_controller.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/models/recommendation_read_result.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_hybrid_operations.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';

void main() {
  test('load retains repository read provenance', () async {
    final provenance = RecommendationReadProvenance(
      source: RecommendationReadSource.cachedSqlite,
      retrievedAtUtc: DateTime.utc(2026, 9, 4, 2),
      warningMessage: 'Cached recommendation data is not live.',
    );
    final controller = RecommendationController(_Repository(provenance));
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.readProvenance, same(provenance));
    expect(controller.readProvenance?.isCached, isTrue);
  });
}

class _Repository
    implements RecommendationRepository, RecommendationHybridOperations {
  _Repository(this.provenance);

  final RecommendationReadProvenance provenance;

  @override
  Future<RecommendationReadResult<List<RecommendationRecordDto>>>
  readAllWithProvenance() async =>
      RecommendationReadResult(data: const [], provenance: provenance);

  @override
  Future<List<RecommendationRecordDto>> readAll() async => const [];

  @override
  Future<RecommendationRecordDto?> readById(String id) async => null;

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) =>
      throw UnimplementedError();
}
