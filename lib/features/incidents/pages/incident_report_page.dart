import 'package:flutter/material.dart';

import '../../../core/routes/bundled_route_catalog_repository.dart';
import '../../../core/routes/route_catalog.dart';
import '../../../core/routes/route_catalog_repository.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/malaysia_time.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/staff/staff_profile.dart';
import '../controllers/incident_controller.dart';
import '../data/dto/local_incident_draft.dart';
import '../models/delay_estimate.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../services/delay_estimator.dart';
import '../services/incident_report_factory.dart';
import '../widgets/incident_data_notice.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({
    required this.controller,
    required this.reportedBy,
    this.onSaved,
    this.onCancel,
    this.clock,
    this.incidentIdGenerator,
    this.existingIncident,
    this.routeCatalogRepository,
    super.key,
  });

  final IncidentController controller;
  final String reportedBy;
  final ValueChanged<Incident>? onSaved;
  final VoidCallback? onCancel;
  final DateTime Function()? clock;
  final IncidentIdGenerator? incidentIdGenerator;
  final Incident? existingIncident;
  final RouteCatalogRepository? routeCatalogRepository;

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DelayEstimator _estimator = const DelayEstimator();
  final IncidentReportFactory _factory = const IncidentReportFactory();

  late final TextEditingController _incidentIdController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _routeIdController;
  late final TextEditingController _routeNameController;
  late final TextEditingController _vehicleIdController;
  late final TextEditingController _locationController;
  late DateTime _reportedAt;

  IncidentType _incidentType = IncidentType.vehicleBreakdown;
  IncidentSeverity _severity = IncidentSeverity.medium;
  VehicleCondition _vehicleCondition = VehicleCondition.unknown;
  DisruptionScope _disruptionScope = DisruptionScope.unknown;
  bool _showValidation = false;
  bool _isSubmitting = false;
  String? _reportedAtError;
  String? _submissionError;
  RouteCatalogSnapshot? _routeCatalogCache;
  Future<RouteCatalogSnapshot>? _routeCatalogLoad;
  _IncidentRouteLookupState _routeLookupState =
      _IncidentRouteLookupState.initial;
  String? _routeLookupMessage;
  int _routeLookupRequest = 0;

  bool get _isEditMode => widget.existingIncident != null;

  bool get _isReadOnly => widget.existingIncident?.status.isTerminal ?? false;

  bool get _canEdit => !_isSubmitting && !_isReadOnly;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  DelayEstimate get _preview => _estimator.estimate(
    incidentType: _incidentType,
    severity: _severity,
    vehicleCondition: _vehicleCondition,
    disruptionScope: _disruptionScope,
    reportedAt: MalaysiaTime.instantToWallClock(_reportedAt),
  );

  @override
  void initState() {
    super.initState();
    final now = _now;
    final existing = widget.existingIncident;
    _reportedAt = existing?.reportedAt.toUtc() ?? _toMinute(now.toUtc());
    _incidentType = existing?.incidentType ?? IncidentType.vehicleBreakdown;
    _severity = existing?.severity ?? IncidentSeverity.medium;
    _vehicleCondition = existing?.vehicleCondition ?? VehicleCondition.unknown;
    _disruptionScope = existing?.disruptionScope ?? DisruptionScope.unknown;
    final generator =
        widget.incidentIdGenerator ?? IncidentReportFactory.defaultId;
    _incidentIdController = TextEditingController(
      text: existing?.incidentId ?? generator(now),
    );
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _routeIdController = TextEditingController(text: existing?.routeId ?? '');
    _routeIdController.addListener(_handleRouteIdChanged);
    _routeNameController = TextEditingController(
      text: existing?.routeName ?? '',
    );
    _vehicleIdController = TextEditingController(
      text: existing?.vehicleId ?? '',
    );
    _locationController = TextEditingController(text: existing?.location ?? '');
  }

  @override
  void dispose() {
    _routeIdController.removeListener(_handleRouteIdChanged);
    _incidentIdController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _routeIdController.dispose();
    _routeNameController.dispose();
    _vehicleIdController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: _isEditMode ? 'Edit Incident' : 'Report Incident',
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          autovalidateMode: _showValidation
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IncidentDataNotice(
                  isPersistent: widget.controller.capabilities.isPersistent,
                ),
                if (_isReadOnly) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppSectionCard(
                    title:
                        '${widget.existingIncident!.status.displayLabel} Incident',
                    subtitle: 'This terminal Incident is read-only and cannot be edited.',
                    leading: const Icon(Icons.lock_outline),
                  ),
                ],
                if (_isSubmitting) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(
                    key: ValueKey('incident-report-progress'),
                  ),
                ],
                if (_submissionError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SubmissionError(message: _submissionError!),
                ],
                const SizedBox(height: AppSpacing.md),
                AppSectionCard(
                  title: _isEditMode ? 'Incident identity' : 'Report identity',
                  subtitle: _isEditMode
                      ? 'Identity, status, audit history, and data source are preserved.'
                      : 'A new report always begins with Reported status.',
                  leading: const Icon(Icons.assignment_outlined),
                  body: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('incident-id-field'),
                        controller: _incidentIdController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Incident ID',
                          helperText: 'Read-only Incident identity',
                          prefixIcon: Icon(Icons.tag),
                        ),
                        validator: (value) => _required(
                          value,
                          'Incident ID could not be generated.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _isEditMode ? 'Current status' : 'Initial status',
                            ),
                            AppStatusChip(
                              label:
                                  widget
                                      .existingIncident
                                      ?.status
                                      .displayLabel ??
                                  IncidentStatus.reported.displayLabel,
                              tone: AppStatusTone.information,
                            ),
                            AppStatusChip(
                              label:
                                  widget
                                      .existingIncident
                                      ?.dataSource
                                      .displayLabel ??
                                  IncidentDataSource.staffEntered.displayLabel,
                              tone: AppStatusTone.neutral,
                            ),
                            Text(
                              'Reporter: ${_reporterLabel()}',
                              key: const ValueKey('incident-reporter-label'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSectionCard(
                  title: 'Incident information',
                  leading: const Icon(Icons.warning_amber_outlined),
                  body: Column(
                    children: [
                      DropdownButtonFormField<IncidentType>(
                        key: const ValueKey('incident-type-field'),
                        initialValue: _incidentType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Incident Type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final type in IncidentType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.displayLabel),
                            ),
                        ],
                        onChanged: !_canEdit
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _incidentType = value);
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('incident-title-field'),
                        controller: _titleController,
                        enabled: _canEdit,
                        maxLength: 100,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Short operational summary',
                        ),
                        validator: _validateTitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('incident-description-field'),
                        controller: _descriptionController,
                        enabled: _canEdit,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                          hintText: 'Describe what staff observed',
                        ),
                        validator: _validateDescription,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSectionCard(
                  title: 'Affected service',
                  subtitle:
                      'Route names can be checked against cached government '
                      'static data. Staff may still correct them manually.',
                  leading: const Icon(Icons.route_outlined),
                  body: Column(
                    children: [
                      _ResponsivePair(
                        first: TextFormField(
                          key: const ValueKey('incident-route-id-field'),
                          controller: _routeIdController,
                          enabled: _canEdit,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Route ID',
                            hintText: '300',
                          ),
                          validator: (value) =>
                              _required(value, 'Route ID is required.'),
                        ),
                        second: TextFormField(
                          key: const ValueKey('incident-route-name-field'),
                          controller: _routeNameController,
                          enabled: _canEdit,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Route Name (optional)',
                            helperText: 'Editable after lookup',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const ValueKey('incident-route-lookup-button'),
                          onPressed:
                              _canEdit &&
                                  _routeLookupState !=
                                      _IncidentRouteLookupState.loading &&
                                  normalizeRouteId(_routeIdController.text)
                                      .isNotEmpty
                              ? _lookUpRoute
                              : null,
                          icon:
                              _routeLookupState ==
                                  _IncidentRouteLookupState.loading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    key: ValueKey(
                                      'incident-route-lookup-progress',
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_outlined),
                          label: Text(
                            _routeLookupState ==
                                    _IncidentRouteLookupState.loading
                                ? 'Looking Up Route…'
                                : 'Look Up Route',
                          ),
                        ),
                      ),
                      if (_routeLookupMessage != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _routeLookupMessage!,
                            key: ValueKey(
                              'incident-route-lookup-${_routeLookupState.name}',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color:
                                      _routeLookupState ==
                                          _IncidentRouteLookupState.unavailable
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('incident-vehicle-id-field'),
                        controller: _vehicleIdController,
                        enabled: _canEdit,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: _incidentType.requiresVehicleId
                              ? 'Vehicle ID'
                              : 'Vehicle ID (optional)',
                          hintText: 'B1023',
                          prefixIcon: const Icon(Icons.directions_bus_outlined),
                        ),
                        validator: _validateVehicleId,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('incident-location-field'),
                        controller: _locationController,
                        enabled: _canEdit,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'Staff-observed location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) =>
                            _required(value, 'Location is required.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSectionCard(
                  title: 'Time and operational conditions',
                  leading: const Icon(Icons.schedule_outlined),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReportedAtControl(
                        value: _reportedAt,
                        enabled: _canEdit,
                        errorText: _reportedAtError,
                        onPickDate: _pickDate,
                        onPickTime: _pickTime,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ResponsivePair(
                        first: DropdownButtonFormField<IncidentSeverity>(
                          key: const ValueKey('incident-severity-field'),
                          initialValue: _severity,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Severity',
                          ),
                          items: [
                            for (final value in IncidentSeverity.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.displayLabel),
                              ),
                          ],
                          onChanged: !_canEdit
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _severity = value);
                                  }
                                },
                        ),
                        second: DropdownButtonFormField<VehicleCondition>(
                          key: const ValueKey(
                            'incident-vehicle-condition-field',
                          ),
                          initialValue: _vehicleCondition,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Condition',
                          ),
                          items: [
                            for (final value in VehicleCondition.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.displayLabel),
                              ),
                          ],
                          onChanged: !_canEdit
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _vehicleCondition = value);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<DisruptionScope>(
                        key: const ValueKey('incident-disruption-scope-field'),
                        initialValue: _disruptionScope,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Disruption Scope',
                        ),
                        items: [
                          for (final value in DisruptionScope.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(value.displayLabel),
                            ),
                        ],
                        onChanged: !_canEdit
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _disruptionScope = value);
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DelayPreview(estimate: _preview),
                const SizedBox(height: AppSpacing.lg),
                if (!_isReadOnly) ...[
                  FilledButton.icon(
                    key: ValueKey(
                      _isEditMode
                          ? 'submit-incident-edit-button'
                          : 'submit-incident-report-button',
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _isEditMode ? 'Save Changes' : 'Save Incident Report',
                    ),
                  ),
                  if (!_isEditMode &&
                      widget.controller.supportsLocalDrafts) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const ValueKey('save-local-incident-draft-button'),
                      onPressed: _isSubmitting
                          ? null
                          : () => _submit(localDraft: true),
                      icon: const Icon(Icons.save_as_outlined),
                      label: const Text('Save Local Draft'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextButton(
                  key: const ValueKey('cancel-incident-report-button'),
                  onPressed: _isSubmitting ? null : widget.onCancel,
                  child: Text(_isReadOnly ? 'Close' : 'Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _reporterLabel() {
    final reporter = widget.existingIncident?.reportedBy ?? widget.reportedBy;
    if (reporter.trim().isEmpty) return 'Unavailable';
    return safeStaffDisplayLabel(reporter);
  }

  Future<void> _submit({bool localDraft = false}) async {
    if (_isSubmitting || _isReadOnly) {
      return;
    }
    FocusScope.of(context).unfocus();
    final now = _now.toUtc();
    setState(() {
      _showValidation = true;
      _submissionError = null;
      _reportedAtError = _reportedAt.isAfter(now)
          ? 'Reported time cannot be in the future.'
          : null;
    });

    final fieldsAreValid = _formKey.currentState?.validate() ?? false;
    if (!fieldsAreValid || _reportedAtError != null) {
      return;
    }
    if (widget.reportedBy.trim().isEmpty) {
      setState(() {
        _submissionError = _isEditMode
            ? 'A staff identity is required before editing an incident.'
            : 'A staff identity is required before reporting an incident.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    final existing = widget.existingIncident;
    final incident = existing == null
        ? _factory.create(
            incidentId: _incidentIdController.text,
            incidentType: _incidentType,
            title: _titleController.text,
            description: _descriptionController.text,
            routeId: _routeIdController.text,
            routeName: _routeNameController.text,
            vehicleId: _vehicleIdController.text,
            location: _locationController.text,
            reportedAt: _reportedAt,
            severity: _severity,
            vehicleCondition: _vehicleCondition,
            disruptionScope: _disruptionScope,
            reportedBy: safeStaffDisplayLabel(widget.reportedBy),
            createdAt: now,
          )
        : existing.copyWith(
            incidentType: _incidentType,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            routeId: normalizeRouteId(_routeIdController.text),
            routeName: _optionalText(_routeNameController.text),
            vehicleId: _optionalText(_vehicleIdController.text),
            location: _locationController.text.trim(),
            reportedAt: _reportedAt,
            severity: _severity,
            vehicleCondition: _vehicleCondition,
            disruptionScope: _disruptionScope,
            delayEstimate: _preview,
          );
    final succeeded = existing == null
        ? localDraft
              ? await widget.controller.createLocalDraft(
                  LocalIncidentDraft(incident),
                )
              : await widget.controller.createIncident(incident)
        : await widget.controller.updateIncident(incident);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _submissionError = succeeded
          ? null
          : widget.controller.errorMessage ??
                (localDraft
                    ? 'Unable to save the local Incident draft.'
                    : _isEditMode
                    ? 'Unable to save Incident changes.'
                    : 'Unable to save the incident report.');
    });
    if (succeeded) {
      if (localDraft) {
        widget.onCancel?.call();
      } else {
        final savedIncident = widget.controller.selectedIncident;
        if (savedIncident != null) {
          widget.onSaved?.call(savedIncident);
        }
      }
    }
  }

  void _handleRouteIdChanged() {
    _routeLookupRequest++;
    if (!mounted) {
      return;
    }
    setState(() {
      _routeLookupState = _IncidentRouteLookupState.initial;
      _routeLookupMessage = null;
    });
  }

  Future<void> _lookUpRoute() async {
    final normalizedRouteId = normalizeRouteId(_routeIdController.text);
    if (normalizedRouteId.isEmpty || !_canEdit) {
      return;
    }
    if (_routeIdController.text != normalizedRouteId) {
      _routeIdController.value = TextEditingValue(
        text: normalizedRouteId,
        selection: TextSelection.collapsed(offset: normalizedRouteId.length),
      );
    }
    final request = ++_routeLookupRequest;
    setState(() {
      _routeLookupState = _IncidentRouteLookupState.loading;
      _routeLookupMessage = null;
    });

    try {
      final catalog = await _loadRouteCatalog();
      if (!mounted ||
          request != _routeLookupRequest ||
          normalizeRouteId(_routeIdController.text) != normalizedRouteId) {
        return;
      }
      final route = catalog.routeByShortName(normalizedRouteId);
      if (route == null) {
        setState(() {
          _routeLookupState = _IncidentRouteLookupState.notFound;
          _routeLookupMessage =
              'No cached government route was found for $normalizedRouteId. '
              'You can enter Route Name manually.';
        });
        return;
      }
      _routeNameController.text = route.routeLongName;
      setState(() {
        _routeLookupState = _IncidentRouteLookupState.found;
        _routeLookupMessage =
            '${route.routeShortName}: ${route.routeLongName} '
            '(cached government static data).';
      });
    } catch (_) {
      _routeCatalogLoad = null;
      if (!mounted ||
          request != _routeLookupRequest ||
          normalizeRouteId(_routeIdController.text) != normalizedRouteId) {
        return;
      }
      setState(() {
        _routeLookupState = _IncidentRouteLookupState.unavailable;
        _routeLookupMessage =
            'Route lookup is unavailable. Retry, or enter Route Name manually.';
      });
    }
  }

  Future<RouteCatalogSnapshot> _loadRouteCatalog() {
    final cached = _routeCatalogCache;
    if (cached != null) {
      return Future.value(cached);
    }
    final pending = _routeCatalogLoad;
    if (pending != null) {
      return pending;
    }
    final repository =
        widget.routeCatalogRepository ?? const BundledRouteCatalogRepository();
    final load = repository.loadCatalog().then((catalog) {
      _routeCatalogCache = catalog;
      return catalog;
    });
    _routeCatalogLoad = load;
    return load;
  }

  Future<void> _pickDate() async {
    final nowWallClock = MalaysiaTime.instantToWallClock(_now);
    final reportedWallClock = MalaysiaTime.instantToWallClock(_reportedAt);
    final date = await showDatePicker(
      context: context,
      initialDate: reportedWallClock,
      firstDate: DateTime(nowWallClock.year - 1),
      lastDate: DateTime(
        nowWallClock.year,
        nowWallClock.month,
        nowWallClock.day,
      ),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _reportedAt = MalaysiaTime.wallClockToUtc(
        DateTime(
          date.year,
          date.month,
          date.day,
          reportedWallClock.hour,
          reportedWallClock.minute,
        ),
      );
      _reportedAtError = null;
    });
  }

  Future<void> _pickTime() async {
    final reportedWallClock = MalaysiaTime.instantToWallClock(_reportedAt);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(reportedWallClock),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _reportedAt = MalaysiaTime.wallClockToUtc(
        DateTime(
          reportedWallClock.year,
          reportedWallClock.month,
          reportedWallClock.day,
          time.hour,
          time.minute,
        ),
      );
      _reportedAtError = null;
    });
  }

  String? _validateTitle(String? value) {
    final length = value?.trim().length ?? 0;
    if (length < 3 || length > 100) {
      return 'Title must be between 3 and 100 characters.';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if ((value?.trim().length ?? 0) < 10) {
      return 'Description must contain at least 10 characters.';
    }
    return null;
  }

  String? _validateVehicleId(String? value) {
    if (_incidentType.requiresVehicleId && (value?.trim().isEmpty ?? true)) {
      return 'Vehicle ID is required for this incident type.';
    }
    return null;
  }

  static String? _optionalText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _required(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  static DateTime _toMinute(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }
}

enum _IncidentRouteLookupState {
  initial,
  loading,
  found,
  notFound,
  unavailable,
}

class _DelayPreview extends StatelessWidget {
  const _DelayPreview({required this.estimate});

  final DelayEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Explainable Delay Preview',
      subtitle:
          'PrasaAssist demonstration rules—not an official Prasarana model. '
          'Staff must review the estimate before deciding any action.',
      leading: const Icon(Icons.timer_outlined),
      trailing: AppStatusChip(
        label: estimate.impactLevel.displayLabel,
        tone: _impactTone(estimate.impactLevel),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${estimate.estimatedDelayMinutes} minutes',
            key: const ValueKey('incident-delay-preview'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final reason in estimate.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxs),
                    child: Icon(Icons.check_circle_outline, size: 16),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(reason)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static AppStatusTone _impactTone(OperationalImpactLevel impact) =>
      switch (impact) {
        OperationalImpactLevel.minor => AppStatusTone.success,
        OperationalImpactLevel.moderate => AppStatusTone.information,
        OperationalImpactLevel.major => AppStatusTone.warning,
        OperationalImpactLevel.severe => AppStatusTone.error,
      };
}

class _ReportedAtControl extends StatelessWidget {
  const _ReportedAtControl({
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime value;
  final bool enabled;
  final String? errorText;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reported Time', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        _ResponsivePair(
          first: OutlinedButton.icon(
            key: const ValueKey('incident-reported-date-button'),
            onPressed: enabled ? onPickDate : null,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(MalaysiaTime.formatDate(value)),
          ),
          second: OutlinedButton.icon(
            key: const ValueKey('incident-reported-time-button'),
            onPressed: enabled ? onPickTime : null,
            icon: const Icon(Icons.schedule_outlined),
            label: Text(MalaysiaTime.formatTime(value)),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            key: const ValueKey('incident-reported-at-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            const SizedBox(height: AppSpacing.sm),
            second,
          ],
        );
      },
    );
  }
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AppSectionCard(
        title: 'Unable to save incident',
        subtitle: message,
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
