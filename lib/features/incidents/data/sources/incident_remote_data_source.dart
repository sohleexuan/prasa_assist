import '../dto/incident_record_dto.dart';

abstract interface class IncidentRemoteDataSource {
  Future<List<IncidentRecordDto>> fetchAll();

  Future<IncidentRecordDto?> fetchByCode(String incidentCode);

  Future<IncidentRecordDto> insert(IncidentRecordDto record);

  Future<IncidentRecordDto> update(
    IncidentRecordDto record, {
    required int expectedVersion,
  });

  Future<IncidentRecordDto> transitionStatus(
    String incidentCode, {
    required String toStatus,
    String? note,
    required int expectedVersion,
  });
}
