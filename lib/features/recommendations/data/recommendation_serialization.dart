import 'dart:convert';

import '../domain/recommendation_action.dart';
import '../domain/recommendation_confidence.dart';
import '../domain/recommendation_evidence.dart';

abstract final class RecommendationSerialization {
  static List<Map<String, Object?>> encodeActions(
    Iterable<RecommendationAction> actions,
  ) => actions
      .map((action) {
        return switch (action) {
          InspectOrRepairVehicleAction() => {
            'type': 'inspect_or_repair_vehicle',
            'vehicleId': action.vehicleId,
          },
          DeployReplacementBusesAction() => {
            'type': 'deploy_replacement_buses',
            'routeId': action.routeId,
            'busCount': action.busCount,
          },
        };
      })
      .toList(growable: false);

  static List<RecommendationAction> decodeActions(String json) {
    final values = _maps(json, 'actions');
    return List.unmodifiable(
      values.map((value) {
        return switch (value['type']) {
          'inspect_or_repair_vehicle' => InspectOrRepairVehicleAction(
            vehicleId: _text(value, 'vehicleId'),
          ),
          'deploy_replacement_buses' => DeployReplacementBusesAction(
            routeId: _text(value, 'routeId'),
            busCount: _integer(value, 'busCount'),
          ),
          _ => throw const FormatException('Unknown recommendation action.'),
        };
      }),
    );
  }

  static List<Map<String, Object?>> encodeEvidence(
    Iterable<RecommendationEvidence> evidence,
  ) => evidence
      .map(
        (item) => <String, Object?>{
          'ruleId': item.ruleId,
          'description': item.description,
          'dataClassification': item.dataClassification.name,
          'contribution': item.contribution,
        },
      )
      .toList(growable: false);

  static List<RecommendationEvidence> decodeEvidence(String json) =>
      List.unmodifiable(
        _maps(json, 'evidence').map(
          (value) => RecommendationEvidence(
            ruleId: _text(value, 'ruleId'),
            description: _text(value, 'description'),
            dataClassification: EvidenceDataClassification.values.byName(
              _text(value, 'dataClassification'),
            ),
            contribution: _integer(value, 'contribution'),
          ),
        ),
      );

  static Map<String, Object?> encodeConfidence(
    RecommendationConfidence confidence,
  ) => {
    'factors': confidence.factors
        .map(
          (item) => {
            'factorId': item.factorId,
            'description': item.description,
            'weight': item.weight,
            'isSupported': item.isSupported,
          },
        )
        .toList(growable: false),
    'penalties': confidence.penalties
        .map(
          (item) => {
            'penaltyId': item.penaltyId,
            'description': item.description,
            'amount': item.amount,
          },
        )
        .toList(growable: false),
  };

  static RecommendationConfidence decodeConfidence(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) throw const FormatException('Invalid confidence.');
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    final factors = map['factors'];
    final penalties = map['penalties'];
    if (factors is! List || penalties is! List) {
      throw const FormatException('Invalid confidence details.');
    }
    return RecommendationConfidence(
      factors: factors
          .map((value) {
            final item = _map(value, 'factor');
            final supported = item['isSupported'];
            if (supported is! bool) {
              throw const FormatException('Invalid factor.');
            }
            return RecommendationConfidenceFactor(
              factorId: _text(item, 'factorId'),
              description: _text(item, 'description'),
              weight: _number(item, 'weight'),
              isSupported: supported,
            );
          })
          .toList(growable: false),
      penalties: penalties
          .map((value) {
            final item = _map(value, 'penalty');
            return RecommendationConfidencePenalty(
              penaltyId: _text(item, 'penaltyId'),
              description: _text(item, 'description'),
              amount: _number(item, 'amount'),
            );
          })
          .toList(growable: false),
    );
  }

  static List<Map<String, Object?>> _maps(String json, String name) {
    final decoded = jsonDecode(json);
    if (decoded is! List || decoded.isEmpty) {
      throw FormatException('$name must be a non-empty list.');
    }
    return decoded.map((value) => _map(value, name)).toList(growable: false);
  }

  static Map<String, Object?> _map(Object? value, String name) {
    if (value is! Map) throw FormatException('Invalid $name item.');
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String _text(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key.');
    }
    return value.trim();
  }

  static int _integer(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('Invalid $key.');
    return value;
  }

  static double _number(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! num) throw FormatException('Invalid $key.');
    return value.toDouble();
  }
}
