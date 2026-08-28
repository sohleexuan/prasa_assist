import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/data/mappers/deployment_mapper.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';

void main() {
  const mapper = DeploymentMapper();

  group('DeploymentMapper', () {
    test('maps a DTO to the domain model', () {
      final domain = mapper.toDomain(_dto());

      expect(domain.deploymentId, 'DEP-120');
      expect(domain.routeId, '300');
      expect(domain.vehicleIds, ['ABC 1230', 'DEF 4567']);
      expect(domain.status, DeploymentStatus.scheduled);
      expect(domain.createdBy, 'Demo Operations Staff');
      expect(domain.version, 4);
    });

    test('maps a valid domain model to a DTO without inventing storage ID', () {
      final dto = mapper.toDto(_deployment());

      expect(dto.storageId, isNull);
      expect(dto.deploymentCode, 'DEP-120');
      expect(dto.status, 'scheduled');
      expect(dto.createdByLabel, 'Demo Operations Staff');
      expect(dto.version, 4);
    });

    test('maps every supported status using persistence values only', () {
      final expectedValues = <DeploymentStatus, String>{
        DeploymentStatus.draft: 'draft',
        DeploymentStatus.scheduled: 'scheduled',
        DeploymentStatus.active: 'active',
        DeploymentStatus.completed: 'completed',
        DeploymentStatus.cancelled: 'cancelled',
      };

      for (final entry in expectedValues.entries) {
        final dto = mapper.toDto(_deployment(status: entry.key));
        expect(dto.status, entry.value);
        expect(mapper.toDomain(_dto(status: entry.value)).status, entry.key);
      }

      expect(expectedValues.values, isNot(contains('Complete')));
      expect(expectedValues.values, isNot(contains('Cancel')));
    });

    test('preserves optional Incident and Recommendation links', () {
      final withLinks = mapper.toDomain(_dto());
      final withoutLinks = mapper.toDto(
        _deployment(incidentId: null, recommendationId: null),
      );

      expect(withLinks.incidentId, 'INC-2026-0142');
      expect(withLinks.sourceRecommendationId, 'REC-0088');
      expect(withoutLinks.incidentId, isNull);
      expect(withoutLinks.recommendationId, isNull);
    });

    test('preserves timestamp instants and normalizes DTO values to UTC', () {
      final localStart = DateTime.parse('2026-08-27T08:00:00+08:00');
      final dto = mapper.toDto(_deployment(startTime: localStart));
      final restored = mapper.toDomain(dto);

      expect(dto.startTime.isUtc, isTrue);
      expect(dto.startTime.isAtSameMomentAs(localStart), isTrue);
      expect(restored.startTime, dto.startTime);
    });

    test('preserves optimistic concurrency version in both directions', () {
      expect(mapper.toDto(_deployment(version: 7)).version, 7);
      expect(mapper.toDomain(_dto(version: 9)).version, 9);
    });

    test('rejects an invalid domain model before producing a DTO', () {
      expect(
        () => mapper.toDto(_deployment(version: 0)),
        throwsA(
          isA<DeploymentValidationException>().having(
            (error) => error.message,
            'message',
            contains('Version must be at least 1'),
          ),
        ),
      );
    });

    test('rejects a structurally valid DTO with invalid domain timing', () {
      final invalidRecord = DeploymentRecordDto(
        deploymentCode: 'DEP-120',
        routeId: '300',
        routeName: 'Route 300',
        vehicleIds: const ['ABC 1230'],
        startTime: DateTime.utc(2026, 8, 27, 10),
        endTime: DateTime.utc(2026, 8, 27, 8),
        status: 'draft',
        purpose: 'Replacement service',
        createdByLabel: 'Operations Staff',
        createdAt: DateTime.utc(2026, 8, 27, 7),
        updatedAt: DateTime.utc(2026, 8, 27, 7, 30),
        version: 1,
      );

      expect(
        () => mapper.toDomain(invalidRecord),
        throwsA(
          isA<DeploymentMappingException>().having(
            (error) => error.message,
            'message',
            contains('End time must be after start time'),
          ),
        ),
      );
    });
  });
}

DeploymentRecordDto _dto({String status = 'scheduled', int version = 4}) {
  return DeploymentRecordDto(
    storageId: 'storage-120',
    deploymentCode: 'DEP-120',
    routeId: '300',
    routeName: 'Route 300',
    vehicleIds: const ['ABC 1230', 'DEF 4567'],
    startTime: DateTime.utc(2026, 8, 27, 8),
    endTime: DateTime.utc(2026, 8, 27, 10),
    status: status,
    purpose: 'Replace unavailable Bus B1023 during peak hour',
    createdByLabel: 'Demo Operations Staff',
    createdAt: DateTime.utc(2026, 8, 27, 7, 30),
    updatedAt: DateTime.utc(2026, 8, 27, 7, 45),
    version: version,
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}

ServiceDeployment _deployment({
  DeploymentStatus status = DeploymentStatus.scheduled,
  DateTime? startTime,
  int version = 4,
  Object? incidentId = 'INC-2026-0142',
  Object? recommendationId = 'REC-0088',
}) {
  return ServiceDeployment(
    deploymentId: 'DEP-120',
    routeId: '300',
    routeName: 'Route 300',
    vehicleIds: const ['ABC 1230', 'DEF 4567'],
    startTime: startTime ?? DateTime.utc(2026, 8, 27, 8),
    endTime: DateTime.utc(2026, 8, 27, 10),
    status: status,
    purpose: 'Replace unavailable Bus B1023 during peak hour',
    createdBy: 'Demo Operations Staff',
    createdAt: DateTime.utc(2026, 8, 27, 7, 30),
    updatedAt: DateTime.utc(2026, 8, 27, 7, 45),
    version: version,
    incidentId: incidentId as String?,
    sourceRecommendationId: recommendationId as String?,
  );
}
