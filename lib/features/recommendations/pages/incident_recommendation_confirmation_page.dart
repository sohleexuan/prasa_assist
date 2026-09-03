import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../incidents/incident_module.dart' hide VehicleCondition;
import '../data/dto/recommendation_record_dto.dart';
import '../domain/recommendation_rule_input.dart';
import '../integration/m1_incident_recommendation_adapter.dart';
import '../repositories/recommendation_data_exception.dart';
import '../services/incident_recommendation_submission_service.dart';

typedef IncidentRecommendationSubmittedCallback = void Function(
  RecommendationRecordDto record,
);

class IncidentRecommendationConfirmationPage extends StatefulWidget {
  const IncidentRecommendationConfirmationPage({
    required this.facts,
    required this.ownerUserId,
    required this.recommendationIdGenerator,
    required this.submissionService,
    required this.clock,
    this.onSubmitted,
    this.adapter = const M1IncidentRecommendationAdapter(),
    super.key,
  });

  final M1IncidentRecommendationFacts facts;
  final String ownerUserId;
  final String Function() recommendationIdGenerator;
  final IncidentRecommendationSubmissionService submissionService;
  final DateTime Function() clock;
  final IncidentRecommendationSubmittedCallback? onSubmitted;
  final M1IncidentRecommendationAdapter adapter;

  @override
  State<IncidentRecommendationConfirmationPage> createState() =>
      _IncidentRecommendationConfirmationPageState();
}

class _IncidentRecommendationConfirmationPageState
    extends State<IncidentRecommendationConfirmationPage> {
  late OperatingPeriod _operatingPeriod;
  var _breakdownConfirmed = false;
  var _operatingPeriodConfirmed = false;
  var _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _operatingPeriod =
        widget.adapter.operatingPeriodPrefill(widget.facts) ??
        OperatingPeriod.unknown;
  }

  bool get _isDemonstrationPrefill =>
      widget.adapter.operatingPeriodPrefill(widget.facts) != null;

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    title: 'Confirm recommendation facts',
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'AI recommends. Staff decides.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        _FactsCard(facts: widget.facts),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: 'Staff confirmation required',
          subtitle: 'Review the supplied facts before creating a pending recommendation.',
          leading: const Icon(Icons.fact_check_outlined),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                key: const Key('breakdown-confirmation-checkbox'),
                contentPadding: EdgeInsets.zero,
                value: _breakdownConfirmed,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _breakdownConfirmed = value ?? false;
                        _message = null;
                      }),
                title: const Text(
                  'I confirm the vehicle breakdown is verified.',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<OperatingPeriod>(
                key: const Key('operating-period-dropdown'),
                initialValue: _operatingPeriod,
                decoration: const InputDecoration(
                  labelText: 'Operating period',
                ),
                items: const [
                  DropdownMenuItem(
                    value: OperatingPeriod.unknown,
                    child: Text('Unknown'),
                  ),
                  DropdownMenuItem(
                    value: OperatingPeriod.peak,
                    child: Text('Peak'),
                  ),
                  DropdownMenuItem(
                    value: OperatingPeriod.offPeak,
                    child: Text('Off-peak'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _operatingPeriod = value ?? OperatingPeriod.unknown;
                        _message = null;
                      }),
              ),
              if (_isDemonstrationPrefill) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Demonstration data: Peak is a suggested prefill only. '
                  'Staff must still confirm it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              CheckboxListTile(
                key: const Key('operating-period-confirmation-checkbox'),
                contentPadding: EdgeInsets.zero,
                value: _operatingPeriodConfirmed,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _operatingPeriodConfirmed = value ?? false;
                        _message = null;
                      }),
                title: const Text('I confirm this operating period selection.'),
              ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const Key('submit-incident-recommendation'),
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(
            _submitting
                ? 'Creating pending recommendation…'
                : 'Create pending recommendation',
          ),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (_submitting) return;
    if (_operatingPeriod == OperatingPeriod.unknown) {
      setState(() {
        _message = 'Select and explicitly confirm an operating period.';
      });
      return;
    }
    if (!_breakdownConfirmed) {
      setState(() {
        _message = 'Staff must explicitly confirm the breakdown.';
      });
      return;
    }
    if (!_operatingPeriodConfirmed) {
      setState(() {
        _message = 'Staff must explicitly confirm the operating period.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final input = widget.adapter.toVerifiedInput(
        facts: widget.facts,
        confirmation: IncidentRecommendationStaffConfirmation(
          breakdownConfirmedByStaff: _breakdownConfirmed,
          operatingPeriod: _operatingPeriod,
          operatingPeriodConfirmedByStaff: _operatingPeriodConfirmed,
        ),
        evaluatedAt: widget.clock(),
      );
      final record = await widget.submissionService.submit(
        input: input,
        ownerUserId: widget.ownerUserId,
        recommendationId: widget.recommendationIdGenerator(),
        createdAt: widget.clock(),
      );
      if (!mounted) return;
      if (record == null) {
        setState(() {
          _message =
              'No pending recommendation could be created from these facts.';
        });
        return;
      }
      widget.onSubmitted?.call(record);
    } on RecommendationDataException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.safeMessage;
        });
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _message =
              error.message?.toString() ?? 'Invalid recommendation facts.';
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to create the pending recommendation. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts});

  final M1IncidentRecommendationFacts facts;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: 'Incident facts supplied by Module 1',
    leading: const Icon(Icons.description_outlined),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FactRow(label: 'Incident ID', value: facts.incidentId),
        _FactRow(label: 'Vehicle ID', value: facts.vehicleId ?? 'Not supplied'),
        _FactRow(label: 'Route ID', value: facts.routeId),
        _FactRow(label: 'Incident type', value: facts.incidentType),
        _FactRow(
          label: 'Data classification',
          value: facts.incidentDataClassification,
        ),
      ],
    ),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text('$label: $value'),
  );
}
