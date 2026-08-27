import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/data/sources/deployment_remote_data_source.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';
import 'package:prasa_assist/features/deployments/repositories/persistent_deployment_repository.dart';

void main() {
  final changedAt = DateTime.utc(2026, 8, 27, 12);

  group('PersistentDeploymentRepository', () {
    test('gets and maps all records', () async {
      final source = _FakeDeploymentRemoteDataSource(
        seedData: [
          _record(),
          _record(code: 'DEP-121', status: 'draft'),
        ],
      );
      final repository = _repository(source);

      final deployments = await repository.getAll();

      expect(deployments, hasLength(2));
      expect(deployments.map((item) => item.deploymentId), [
        'DEP-120',
        'DEP-121',
      ]);
      expect(deployments.first.version, 2);
      expect(() => deployments.add(_deployment()), throwsUnsupportedError);
    });

    test('returns an empty list for an empty source', () async {
      final repository = _repository(_FakeDeploymentRemoteDataSource());

      expect(await repository.getAll(), isEmpty);
    });

    test(
      'gets an existing record and returns null for a missing code',
      () async {
        final repository = _repository(
          _FakeDeploymentRemoteDataSource(seedData: [_record()]),
        );

        expect((await repository.getById('DEP-120'))!.routeId, '300');
        expect(await repository.getById('MISSING'), isNull);
      },
    );

    test(
      'creates a valid deployment and returns the persisted record',
      () async {
        final source = _FakeDeploymentRemoteDataSource();
        final repository = _repository(source);

        final created = await repository.create(_deployment(version: 1));

        expect(created.deploymentId, 'DEP-120');
        expect(created.version, 1);
        expect(source.insertCallCount, 1);
        expect((await source.fetchByCode('DEP-120'))!.status, 'draft');
      },
    );

    test(
      'does not automatically schedule a Recommendation-linked create',
      () async {
        final source = _FakeDeploymentRemoteDataSource();
        final repository = _repository(source);

        final created = await repository.create(
          _deployment(
            status: DeploymentStatus.draft,
            recommendationId: 'REC-0088',
          ),
        );

        expect(created.status, DeploymentStatus.draft);
        expect(source.lastInserted!.status, 'draft');
        expect(source.transitionCallCount, 0);
      },
    );

    test('propagates a safe duplicate create failure', () async {
      final repository = _repository(
        _FakeDeploymentRemoteDataSource(seedData: [_record()]),
      );

      await expectLater(
        repository.create(_deployment()),
        throwsA(isA<DeploymentDuplicateException>()),
      );
    });

    test(
      'updates using expected version and returns the latest version',
      () async {
        final source = _FakeDeploymentRemoteDataSource(seedData: [_record()]);
        final repository = _repository(source);
        final current = await repository.getById('DEP-120');

        final updated = await repository.update(
          current!.copyWith(purpose: 'Updated by staff'),
        );

        expect(source.lastUpdateExpectedVersion, 2);
        expect(updated.purpose, 'Updated by staff');
        expect(updated.version, 3);
        expect((await repository.getById('DEP-120'))!.version, 3);
      },
    );

    test(
      'propagates optimistic version conflict without changing data',
      () async {
        final source = _FakeDeploymentRemoteDataSource(
          seedData: [_record(version: 3)],
        );
        final repository = _repository(source);

        await expectLater(
          repository.update(_deployment(version: 2)),
          throwsA(isA<DeploymentConflictException>()),
        );

        expect((await repository.getById('DEP-120'))!.version, 3);
        expect((await repository.getById('DEP-120'))!.purpose, _purpose);
      },
    );

    for (final status in [DeploymentStatus.draft, DeploymentStatus.cancelled]) {
      test(
        'deletes a ${status.displayLabel} record using its version',
        () async {
          final source = _FakeDeploymentRemoteDataSource(
            seedData: [_record(status: status.name, version: 5)],
          );
          final repository = _repository(source);

          await repository.delete('DEP-120');

          expect(await repository.getById('DEP-120'), isNull);
          expect(source.lastDeleteExpectedVersion, 5);
        },
      );
    }

    for (final status in [
      DeploymentStatus.scheduled,
      DeploymentStatus.active,
      DeploymentStatus.completed,
    ]) {
      test('rejects deleting a ${status.displayLabel} record', () async {
        final source = _FakeDeploymentRemoteDataSource(
          seedData: [_record(status: status.name)],
        );
        final repository = _repository(source);

        await expectLater(
          repository.delete('DEP-120'),
          throwsA(isA<DeploymentValidationException>()),
        );

        expect(source.deleteCallCount, 0);
        expect(await repository.getById('DEP-120'), isNotNull);
      });
    }

    final legalTransitions = <DeploymentStatus, List<DeploymentStatus>>{
      DeploymentStatus.draft: [
        DeploymentStatus.scheduled,
        DeploymentStatus.cancelled,
      ],
      DeploymentStatus.scheduled: [
        DeploymentStatus.active,
        DeploymentStatus.cancelled,
      ],
      DeploymentStatus.active: [
        DeploymentStatus.completed,
        DeploymentStatus.cancelled,
      ],
    };
    for (final entry in legalTransitions.entries) {
      for (final target in entry.value) {
        test('atomically transitions ${entry.key.displayLabel} to '
            '${target.displayLabel}', () async {
          final source = _FakeDeploymentRemoteDataSource(
            seedData: [_record(status: entry.key.name, version: 4)],
          );
          final repository = _repository(source);

          final result = await repository.transitionStatus(
            'DEP-120',
            target,
            changedByLabel: 'Control Centre Staff',
            changedAt: changedAt,
          );

          expect(result.status, target);
          expect(result.version, 5);
          expect(result.updatedAt, changedAt);
          expect(source.transitionCallCount, 1);
          expect(source.ordinaryUpdateCallCount, 0);
          expect(source.lastTransitionFromStatus, entry.key.name);
          expect(source.lastTransitionToStatus, target.name);
          expect(source.lastTransitionExpectedVersion, 4);
          expect(source.lastChangedByLabel, 'Control Centre Staff');
        });
      }
    }

    test('rejects every illegal transition before atomic persistence', () async {
      for (final current in DeploymentStatus.values) {
        for (final target in DeploymentStatus.values) {
          if (current.canTransitionTo(target)) {
            continue;
          }
          final source = _FakeDeploymentRemoteDataSource(
            seedData: [_record(status: current.name)],
          );
          final repository = _repository(source);

          await expectLater(
            repository.transitionStatus(
              'DEP-120',
              target,
              changedByLabel: 'Operations Staff',
              changedAt: changedAt,
            ),
            throwsA(isA<DeploymentValidationException>()),
            reason:
                '${current.displayLabel} -> ${target.displayLabel} is illegal',
          );
          expect(source.transitionCallCount, 0);
        }
      }
    });

    test('Completed and Cancelled remain terminal', () async {
      for (final terminal in [
        DeploymentStatus.completed,
        DeploymentStatus.cancelled,
      ]) {
        final source = _FakeDeploymentRemoteDataSource(
          seedData: [_record(status: terminal.name)],
        );
        final repository = _repository(source);

        await expectLater(
          repository.transitionStatus(
            'DEP-120',
            DeploymentStatus.draft,
            changedByLabel: 'Operations Staff',
          ),
          throwsA(isA<DeploymentValidationException>()),
        );
        expect(source.transitionCallCount, 0);
      }
    });

    test(
      'does not report success after an atomic transition failure',
      () async {
        final source =
            _FakeDeploymentRemoteDataSource(
                seedData: [_record(status: 'scheduled')],
              )
              ..transitionError = const DeploymentConflictException(
                'Deployment changed elsewhere. Reload and try again.',
              );
        final repository = _repository(source);

        await expectLater(
          repository.transitionStatus(
            'DEP-120',
            DeploymentStatus.active,
            changedByLabel: 'Operations Staff',
            changedAt: changedAt,
          ),
          throwsA(isA<DeploymentConflictException>()),
        );

        final unchanged = await repository.getById('DEP-120');
        expect(unchanged!.status, DeploymentStatus.scheduled);
        expect(unchanged.version, 2);
      },
    );

    test('propagates offline failure without suppressing it', () async {
      final source = _FakeDeploymentRemoteDataSource()
        ..fetchAllError = const DeploymentOfflineException(
          'Deployment data is unavailable while offline.',
        );

      await expectLater(
        _repository(source).getAll(),
        throwsA(
          isA<DeploymentOfflineException>().having(
            (error) => error.message,
            'message',
            contains('offline'),
          ),
        ),
      );
    });

    test(
      'propagates permission failure without exposing diagnostics',
      () async {
        final source = _FakeDeploymentRemoteDataSource(seedData: [_record()])
          ..deleteError = const DeploymentPermissionException(
            'You do not have permission to delete this deployment.',
            cause: 'secret-token-must-not-be-in-the-message',
          );

        await expectLater(
          _repository(source).delete('DEP-120'),
          throwsA(
            isA<DeploymentPermissionException>()
                .having(
                  (error) => error.message,
                  'safe message',
                  isNot(contains('secret-token')),
                )
                .having((error) => error.cause, 'diagnostic cause', isNotNull),
          ),
        );
      },
    );

    test('propagates mapping failures from invalid remote results', () async {
      final source = _FakeDeploymentRemoteDataSource()
        ..fetchAllError = const DeploymentMappingException(
          'Deployment record contains invalid data.',
        );

      await expectLater(
        _repository(source).getAll(),
        throwsA(isA<DeploymentMappingException>()),
      );
    });

    test('wraps untyped source errors as safe unknown data failures', () async {
      final source = _FakeDeploymentRemoteDataSource()
        ..fetchAllError = StateError('provider implementation details');

      await expectLater(
        _repository(source).getAll(),
        throwsA(
          isA<DeploymentUnknownDataException>().having(
            (error) => error.message,
            'message',
            'Unable to access deployment data.',
          ),
        ),
      );
    });
  });
}

const _purpose = 'Replace unavailable Bus B1023 during peak hour';

PersistentDeploymentRepository _repository(DeploymentRemoteDataSource source) =>
    PersistentDeploymentRepository(
      dataSource: source,
      clock: () => DateTime.utc(2026, 8, 27, 12),
    );

DeploymentRecordDto _record({
  String code = 'DEP-120',
  String status = 'draft',
  int version = 2,
  String purpose = _purpose,
  String? recommendationId = 'REC-0088',
}) => DeploymentRecordDto(
  storageId: 'storage-$code',
  deploymentCode: code,
  routeId: '300',
  routeName: 'Route 300',
  vehicleIds: const ['ABC 1230', 'DEF 4567'],
  startTime: DateTime.utc(2026, 8, 27, 8),
  endTime: DateTime.utc(2026, 8, 27, 10),
  status: status,
  purpose: purpose,
  createdByLabel: 'Demo Operations Staff',
  createdAt: DateTime.utc(2026, 8, 27, 7, 30),
  updatedAt: DateTime.utc(2026, 8, 27, 7, 45),
  version: version,
  incidentId: 'INC-2026-0142',
  recommendationId: recommendationId,
);

ServiceDeployment _deployment({
  DeploymentStatus status = DeploymentStatus.draft,
  int version = 1,
  String? recommendationId = 'REC-0088',
}) => ServiceDeployment(
  deploymentId: 'DEP-120',
  routeId: '300',
  routeName: 'Route 300',
  vehicleIds: const ['ABC 1230', 'DEF 4567'],
  startTime: DateTime.utc(2026, 8, 27, 8),
  endTime: DateTime.utc(2026, 8, 27, 10),
  status: status,
  purpose: _purpose,
  createdBy: 'Demo Operations Staff',
  createdAt: DateTime.utc(2026, 8, 27, 7, 30),
  updatedAt: DateTime.utc(2026, 8, 27, 7, 45),
  version: version,
  incidentId: 'INC-2026-0142',
  sourceRecommendationId: recommendationId,
);

class _FakeDeploymentRemoteDataSource implements DeploymentRemoteDataSource {
  _FakeDeploymentRemoteDataSource({
    Iterable<DeploymentRecordDto> seedData = const [],
  }) : _records = <String, DeploymentRecordDto>{
         for (final record in seedData) record.deploymentCode: record,
       };

  final Map<String, DeploymentRecordDto> _records;

  Object? fetchAllError;
  Object? fetchByCodeError;
  Object? insertError;
  Object? updateError;
  Object? transitionError;
  Object? deleteError;

  int insertCallCount = 0;
  int ordinaryUpdateCallCount = 0;
  int transitionCallCount = 0;
  int deleteCallCount = 0;
  int? lastUpdateExpectedVersion;
  int? lastTransitionExpectedVersion;
  int? lastDeleteExpectedVersion;
  String? lastTransitionFromStatus;
  String? lastTransitionToStatus;
  String? lastChangedByLabel;
  DeploymentRecordDto? lastInserted;

  @override
  Future<List<DeploymentRecordDto>> fetchAll() async {
    _throwIfPresent(fetchAllError);
    return List<DeploymentRecordDto>.unmodifiable(_records.values);
  }

  @override
  Future<DeploymentRecordDto?> fetchByCode(String deploymentCode) async {
    _throwIfPresent(fetchByCodeError);
    return _records[deploymentCode];
  }

  @override
  Future<DeploymentRecordDto> insert(DeploymentRecordDto record) async {
    insertCallCount++;
    _throwIfPresent(insertError);
    if (_records.containsKey(record.deploymentCode)) {
      throw DeploymentDuplicateException(
        'Deployment ${record.deploymentCode} already exists.',
      );
    }
    final inserted = _copyRecord(
      record,
      storageId: 'storage-${record.deploymentCode}',
    );
    _records[record.deploymentCode] = inserted;
    lastInserted = inserted;
    return inserted;
  }

  @override
  Future<DeploymentRecordDto> update(
    DeploymentRecordDto record, {
    required int expectedVersion,
  }) async {
    ordinaryUpdateCallCount++;
    lastUpdateExpectedVersion = expectedVersion;
    _throwIfPresent(updateError);
    final current = _records[record.deploymentCode];
    if (current == null) {
      throw DeploymentNotFoundException(
        'Deployment ${record.deploymentCode} does not exist.',
      );
    }
    _verifyVersion(current, expectedVersion);
    final updated = _copyRecord(
      record,
      storageId: current.storageId,
      version: current.version + 1,
    );
    _records[record.deploymentCode] = updated;
    return updated;
  }

  @override
  Future<DeploymentRecordDto> transitionStatus(
    String deploymentCode, {
    required String fromStatus,
    required String toStatus,
    required String changedByLabel,
    required DateTime changedAt,
    required int expectedVersion,
  }) async {
    transitionCallCount++;
    lastTransitionFromStatus = fromStatus;
    lastTransitionToStatus = toStatus;
    lastTransitionExpectedVersion = expectedVersion;
    lastChangedByLabel = changedByLabel;
    _throwIfPresent(transitionError);
    final current = _records[deploymentCode];
    if (current == null) {
      throw DeploymentNotFoundException(
        'Deployment $deploymentCode does not exist.',
      );
    }
    _verifyVersion(current, expectedVersion);
    if (current.status != fromStatus) {
      throw const DeploymentConflictException(
        'Deployment status changed elsewhere. Reload and try again.',
      );
    }
    final transitioned = _copyRecord(
      current,
      status: toStatus,
      updatedAt: changedAt,
      version: current.version + 1,
    );
    _records[deploymentCode] = transitioned;
    return transitioned;
  }

  @override
  Future<void> delete(
    String deploymentCode, {
    required int expectedVersion,
  }) async {
    deleteCallCount++;
    lastDeleteExpectedVersion = expectedVersion;
    _throwIfPresent(deleteError);
    final current = _records[deploymentCode];
    if (current == null) {
      throw DeploymentNotFoundException(
        'Deployment $deploymentCode does not exist.',
      );
    }
    _verifyVersion(current, expectedVersion);
    _records.remove(deploymentCode);
  }

  void _verifyVersion(DeploymentRecordDto current, int expectedVersion) {
    if (current.version != expectedVersion) {
      throw const DeploymentConflictException(
        'Deployment changed elsewhere. Reload and try again.',
      );
    }
  }

  void _throwIfPresent(Object? error) {
    if (error != null) {
      throw error;
    }
  }
}

DeploymentRecordDto _copyRecord(
  DeploymentRecordDto record, {
  String? storageId,
  String? status,
  DateTime? updatedAt,
  int? version,
}) => DeploymentRecordDto(
  storageId: storageId ?? record.storageId,
  deploymentCode: record.deploymentCode,
  routeId: record.routeId,
  routeName: record.routeName,
  vehicleIds: record.vehicleIds,
  startTime: record.startTime,
  endTime: record.endTime,
  status: status ?? record.status,
  purpose: record.purpose,
  createdByLabel: record.createdByLabel,
  createdAt: record.createdAt,
  updatedAt: updatedAt ?? record.updatedAt,
  version: version ?? record.version,
  incidentId: record.incidentId,
  recommendationId: record.recommendationId,
);
