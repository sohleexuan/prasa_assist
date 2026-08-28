import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../controllers/deployment_controller.dart';
import '../controllers/route_catalog_controller.dart';
import '../data/dto/local_deployment_draft.dart';
import '../data/dto/local_deployment_record.dart';
import '../models/deployment_prefill.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../utils/deployment_date_time_formatter.dart';
import '../widgets/deployment_status_chip.dart';
import '../widgets/route_catalog_selector.dart';

class DeploymentFormScreen extends StatefulWidget {
  const DeploymentFormScreen({
    required this.controller,
    required this.routeCatalogController,
    required this.currentUserId,
    this.existingDeployment,
    this.existingLocalWorkItem,
    this.prefill,
    this.onSaved,
    this.onLocalSaved,
    this.onCancel,
    this.deploymentIdGenerator,
    this.clock,
    super.key,
  });

  final DeploymentController controller;
  final RouteCatalogController routeCatalogController;
  final String currentUserId;
  final ServiceDeployment? existingDeployment;
  final LocalDeploymentRecord? existingLocalWorkItem;
  final DeploymentPrefill? prefill;
  final ValueChanged<ServiceDeployment>? onSaved;
  final ValueChanged<LocalDeploymentRecord>? onLocalSaved;
  final VoidCallback? onCancel;
  final String Function()? deploymentIdGenerator;
  final DateTime Function()? clock;

  @override
  State<DeploymentFormScreen> createState() => _DeploymentFormScreenState();
}

class _DeploymentFormScreenState extends State<DeploymentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _deploymentIdController;
  late final TextEditingController _routeIdController;
  late final TextEditingController _routeNameController;
  late final TextEditingController _vehicleIdsController;
  late final TextEditingController _purposeController;
  late final TextEditingController _incidentIdController;
  late final TextEditingController _recommendationIdController;
  late DateTime _startTime;
  late DateTime _endTime;

  bool _showValidation = false;
  bool _isSubmitting = false;
  String? _timeError;
  String? _submissionError;

  bool get _isEditMode =>
      widget.existingDeployment != null || widget.existingLocalWorkItem != null;

  bool get _isLocalMode =>
      widget.controller.supportsLocalDrafts &&
      widget.existingDeployment == null;

  bool get _isReadOnly {
    final status = widget.existingDeployment?.status;
    return status == DeploymentStatus.active ||
        status == DeploymentStatus.completed ||
        status == DeploymentStatus.cancelled;
  }

  bool get _canSchedule =>
      !_isReadOnly &&
      !_isLocalMode &&
      (widget.existingDeployment == null ||
          widget.existingDeployment!.status == DeploymentStatus.draft);

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final now = _now.toLocal();
    final existing = widget.existingDeployment;
    final localWork = widget.existingLocalWorkItem;
    final localDraft = localWork?.draft;
    final prefill = existing == null ? widget.prefill : null;
    final generatedId = _isLocalMode
        ? localWork?.localId ?? 'Assigned after publication'
        : widget.deploymentIdGenerator?.call() ??
              'DEP-${now.microsecondsSinceEpoch}';

    _deploymentIdController = TextEditingController(
      text: existing?.deploymentId ?? generatedId,
    );
    _routeIdController = TextEditingController(
      text: existing?.routeId ?? localDraft?.routeId ?? prefill?.routeId ?? '',
    );
    _routeNameController = TextEditingController(
      text:
          existing?.routeName ??
          localDraft?.routeName ??
          prefill?.routeName ??
          '',
    );
    _vehicleIdsController = TextEditingController(
      text:
          existing?.vehicleIds.join(', ') ??
          localDraft?.vehicleIds.join(', ') ??
          '',
    );
    _purposeController = TextEditingController(
      text:
          existing?.purpose ??
          localDraft?.purpose ??
          prefill?.suggestedPurpose ??
          '',
    );
    _incidentIdController = TextEditingController(
      text:
          existing?.incidentId ??
          localDraft?.incidentId ??
          prefill?.incidentId ??
          '',
    );
    _recommendationIdController = TextEditingController(
      text:
          existing?.sourceRecommendationId ??
          localDraft?.recommendationId ??
          prefill?.recommendationId ??
          '',
    );
    _startTime =
        (existing?.startTime ??
                localDraft?.startTime ??
                prefill?.suggestedStartTime)
            ?.toLocal() ??
        _toMinute(now);
    _endTime =
        (existing?.endTime ?? localDraft?.endTime ?? prefill?.suggestedEndTime)
            ?.toLocal() ??
        _startTime.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _deploymentIdController.dispose();
    _routeIdController.dispose();
    _routeNameController.dispose();
    _vehicleIdsController.dispose();
    _purposeController.dispose();
    _incidentIdController.dispose();
    _recommendationIdController.dispose();
    // The DeploymentController is supplied and owned by the parent.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: widget.existingLocalWorkItem != null
          ? 'Edit Local Draft'
          : _isEditMode
          ? 'Edit Deployment'
          : 'New Deployment',
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
                _PrototypeNotice(
                  isPersistent: widget.controller.capabilities.isPersistent,
                  isLocalDraft: _isLocalMode,
                ),
                if (_isReadOnly) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ReadOnlyNotice(status: widget.existingDeployment!.status),
                ],
                if (_isSubmitting) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(
                    key: ValueKey('deployment-form-progress'),
                  ),
                ],
                if (_submissionError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SubmissionError(message: _submissionError!),
                ],
                const SizedBox(height: AppSpacing.md),
                _FormSection(
                  title: 'Deployment',
                  icon: Icons.assignment_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const ValueKey('deployment-id-field'),
                        controller: _deploymentIdController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Deployment ID',
                          helperText: 'Generated automatically and read-only',
                          prefixIcon: Icon(Icons.tag),
                        ),
                        validator: _isLocalMode ? null : _requiredDeploymentId,
                      ),
                      if (widget.existingDeployment != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            const Text('Current status'),
                            DeploymentStatusChip(
                              status: widget.existingDeployment!.status,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _FormSection(
                  title: 'Route and vehicles',
                  icon: Icons.route_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RouteCatalogSelector(
                        controller: widget.routeCatalogController,
                        enabled: !_isReadOnly && !_isSubmitting,
                        onRouteSelected: (route) {
                          if (_isReadOnly || _isSubmitting) {
                            return;
                          }
                          setState(() {
                            _routeIdController.text = route.routeShortName;
                            _routeNameController.text = route.routeLongName;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('route-id-field'),
                        controller: _routeIdController,
                        readOnly: _isReadOnly,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Route ID',
                          helperText: 'Enter manually or select above',
                          prefixIcon: const Icon(Icons.signpost_outlined),
                        ),
                        validator: (value) =>
                            _requiredText(value, 'Route ID is required.'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('route-name-field'),
                        controller: _routeNameController,
                        readOnly: _isReadOnly,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Route name',
                          prefixIcon: Icon(Icons.alt_route_outlined),
                        ),
                        validator: (value) =>
                            _requiredText(value, 'Route name is required.'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('vehicle-ids-field'),
                        controller: _vehicleIdsController,
                        readOnly: _isReadOnly,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Vehicle IDs',
                          hintText: 'ABC 1230, DEF 4567',
                          helperText:
                              widget.controller.capabilities.isPersistent
                              ? 'Enter actual vehicle IDs separated by commas. '
                                    'Availability is not verified automatically.'
                              : 'Enter actual vehicle IDs separated by commas. '
                                    'Availability is not verified in this prototype.',
                          prefixIcon: const Icon(Icons.directions_bus_outlined),
                        ),
                        validator: _validateVehicleInput,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _selectedVehicleCountLabel,
                        key: const ValueKey('selected-vehicle-count'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!_isEditMode &&
                          widget.prefill?.suggestedVehicleCount != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _SuggestedVehicleNotice(
                          count: widget.prefill!.suggestedVehicleCount!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _FormSection(
                  title: 'Service window',
                  icon: Icons.schedule_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DateTimeControls(
                        prefix: 'start',
                        label: 'Start',
                        value: _startTime,
                        enabled: !_isReadOnly && !_isSubmitting,
                        onPickDate: () => _pickDate(isStart: true),
                        onPickTime: () => _pickTime(isStart: true),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _DateTimeControls(
                        prefix: 'end',
                        label: 'End',
                        value: _endTime,
                        enabled: !_isReadOnly && !_isSubmitting,
                        onPickDate: () => _pickDate(isStart: false),
                        onPickTime: () => _pickTime(isStart: false),
                      ),
                      if (_timeError != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _timeError!,
                          key: const ValueKey('service-window-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _FormSection(
                  title: 'Operational purpose',
                  icon: Icons.description_outlined,
                  child: TextFormField(
                    key: const ValueKey('purpose-field'),
                    controller: _purposeController,
                    readOnly: _isReadOnly,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      alignLabelWithHint: true,
                      hintText: 'Explain why this deployment is required',
                    ),
                    validator: (value) =>
                        _requiredText(value, 'Purpose is required.'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _FormSection(
                  title: 'Linked records',
                  icon: Icons.link_outlined,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('incident-id-field'),
                        controller: _incidentIdController,
                        readOnly: _isReadOnly,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Incident ID (optional)',
                          prefixIcon: Icon(Icons.warning_amber_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('recommendation-id-field'),
                        controller: _recommendationIdController,
                        readOnly: _isReadOnly,
                        decoration: const InputDecoration(
                          labelText: 'Recommendation ID (optional)',
                          helperText: 'Recommendations pre-fill data only. Staff decides.',
                          prefixIcon: Icon(Icons.lightbulb_outline),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    final buttons = <Widget>[];
    if (!_isReadOnly) {
      buttons.add(
        FilledButton.icon(
          key: ValueKey(
            _isEditMode ? 'save-changes-button' : 'save-draft-button',
          ),
          onPressed: _isSubmitting ? null : () => _submit(schedule: false),
          icon: const Icon(Icons.save_outlined),
          label: Text(
            _isEditMode
                ? 'Save Changes'
                : _isLocalMode
                ? 'Save Local Draft'
                : 'Save Draft',
          ),
        ),
      );
      if (_canSchedule) {
        buttons.addAll([
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('schedule-deployment-button'),
            onPressed: _isSubmitting ? null : () => _submit(schedule: true),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Schedule Deployment'),
          ),
        ]);
      }
    }
    if (buttons.isNotEmpty) {
      buttons.add(const SizedBox(height: AppSpacing.sm));
    }
    buttons.add(
      TextButton(
        key: const ValueKey('cancel-deployment-button'),
        onPressed: _isSubmitting ? null : widget.onCancel,
        child: const Text('Cancel'),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons,
    );
  }

  Future<void> _submit({required bool schedule}) async {
    if (_isSubmitting || _isReadOnly) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _showValidation = true;
      _submissionError = null;
      _timeError = _endTime.isAfter(_startTime)
          ? null
          : 'End time must be after start time.';
    });

    final fieldsAreValid = _formKey.currentState?.validate() ?? false;
    if (!fieldsAreValid || _timeError != null) {
      return;
    }
    if (!_isLocalMode && widget.currentUserId.trim().isEmpty) {
      setState(() {
        _submissionError = 'Current user ID is required.';
      });
      return;
    }

    final existing = widget.existingDeployment;
    if (_isLocalMode) {
      final draft = LocalDeploymentDraft(
        routeId: _routeIdController.text,
        routeName: _routeNameController.text,
        vehicleIds: _parseVehicleIds(),
        startTime: _startTime,
        endTime: _endTime,
        purpose: _purposeController.text,
        incidentId: _optionalText(_incidentIdController.text),
        recommendationId: _optionalText(_recommendationIdController.text),
      );
      setState(() {
        _isSubmitting = true;
      });
      final existingLocal = widget.existingLocalWorkItem;
      final saved = existingLocal == null
          ? await widget.controller.createLocalDraft(draft)
          : await widget.controller.updateLocalDraft(
              existingLocal.localId,
              draft,
            );
      if (!mounted) {
        return;
      }
      if (!saved) {
        _finishWithControllerError();
        return;
      }
      final localRecord = widget.controller.selectedLocalWorkItem;
      setState(() {
        _isSubmitting = false;
        _submissionError = null;
      });
      if (localRecord != null) {
        widget.onLocalSaved?.call(localRecord);
      }
      return;
    }
    final timestamp = _now;
    final deployment = ServiceDeployment(
      deploymentId: _deploymentIdController.text.trim(),
      routeId: _routeIdController.text.trim(),
      routeName: _routeNameController.text.trim(),
      vehicleIds: _parseVehicleIds(),
      startTime: _startTime,
      endTime: _endTime,
      status: existing?.status ?? DeploymentStatus.draft,
      purpose: _purposeController.text.trim(),
      createdBy: existing?.createdBy ?? widget.currentUserId.trim(),
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
      version: existing?.version ?? 1,
      incidentId: _optionalText(_incidentIdController.text),
      sourceRecommendationId: _optionalText(_recommendationIdController.text),
    );
    final modelErrors = deployment.validate();
    if (modelErrors.isNotEmpty) {
      setState(() {
        _submissionError = modelErrors.join('\n');
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final saved = existing == null
        ? await widget.controller.createDeployment(deployment)
        : await widget.controller.updateDeployment(deployment);
    if (!mounted) {
      return;
    }
    if (!saved) {
      _finishWithControllerError();
      return;
    }

    if (schedule) {
      final persistedDeployment = widget.controller.selectedDeployment;
      final scheduled = await widget.controller.changeStatus(
        persistedDeployment?.deploymentId ?? deployment.deploymentId,
        DeploymentStatus.scheduled,
      );
      if (!mounted) {
        return;
      }
      if (!scheduled) {
        _finishWithControllerError();
        return;
      }
    }

    final finalDeployment = widget.controller.selectedDeployment;
    setState(() {
      _isSubmitting = false;
      _submissionError = null;
    });
    if (finalDeployment != null) {
      widget.onSaved?.call(finalDeployment);
    }
  }

  void _finishWithControllerError() {
    setState(() {
      _isSubmitting = false;
      _submissionError =
          widget.controller.errorMessage ?? 'Unable to save deployment.';
    });
  }

  String? _requiredDeploymentId(String? value) {
    return _requiredText(value, 'Deployment ID is required.');
  }

  String? _requiredText(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  String? _validateVehicleInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'At least one vehicle must be selected.';
    }
    final vehicleIds = value.split(',').map((id) => id.trim()).toList();
    if (vehicleIds.any((id) => id.isEmpty)) {
      return 'Vehicle IDs cannot be empty.';
    }
    final normalizedIds = vehicleIds.map((id) => id.toLowerCase()).toList();
    if (normalizedIds.toSet().length != normalizedIds.length) {
      return 'Vehicle IDs cannot contain duplicates.';
    }
    if (normalizedIds.contains('b1023')) {
      return 'Unavailable Bus B1023 cannot be a replacement vehicle.';
    }
    return null;
  }

  List<String> _parseVehicleIds() {
    return _vehicleIdsController.text
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  int get _selectedVehicleCount => _vehicleIdsController.text
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .length;

  String get _selectedVehicleCountLabel {
    final count = _selectedVehicleCount;
    return '$count ${count == 1 ? 'vehicle' : 'vehicles'} selected';
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final currentValue = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) {
      return;
    }
    setState(() {
      final updated = DateTime(
        date.year,
        date.month,
        date.day,
        currentValue.hour,
        currentValue.minute,
      );
      if (isStart) {
        _startTime = updated;
      } else {
        _endTime = updated;
      }
      _refreshTimeError();
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final currentValue = isStart ? _startTime : _endTime;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (!mounted || time == null) {
      return;
    }
    setState(() {
      final updated = DateTime(
        currentValue.year,
        currentValue.month,
        currentValue.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _startTime = updated;
      } else {
        _endTime = updated;
      }
      _refreshTimeError();
    });
  }

  void _refreshTimeError() {
    if (_showValidation) {
      _timeError = _endTime.isAfter(_startTime)
          ? null
          : 'End time must be after start time.';
    }
  }

  DateTime _toMinute(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      body: child,
    );
  }
}

class _DateTimeControls extends StatelessWidget {
  const _DateTimeControls({
    required this.prefix,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String prefix;
  final String label;
  final DateTime value;
  final bool enabled;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label service date and time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: ValueKey('$prefix-date-button'),
            onPressed: enabled ? onPickDate : null,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(formatDeploymentLocalDate(value)),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: ValueKey('$prefix-time-button'),
            onPressed: enabled ? onPickTime : null,
            icon: const Icon(Icons.access_time),
            label: Text(formatDeploymentLocalTime(value)),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          ),
        ],
      ),
    );
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice({
    required this.isPersistent,
    required this.isLocalDraft,
  });

  final bool isPersistent;
  final bool isLocalDraft;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: isLocalDraft
          ? 'Local draft, not published to Supabase'
          : isPersistent
          ? 'Authenticated shared deployment data'
          : 'Prototype data, not live operations',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.developmentContainer,
          borderRadius: AppRadius.medium,
          border: Border.all(color: AppColors.developmentBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.science_outlined,
                color: AppColors.onDevelopmentContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isLocalDraft
                      ? 'Local draft — stored on this device, not published'
                      : isPersistent
                      ? 'Authenticated shared deployment data'
                      : 'Prototype data — not live operations',
                  style: const TextStyle(
                    color: AppColors.onDevelopmentContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedVehicleNotice extends StatelessWidget {
  const _SuggestedVehicleNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Recommended vehicle count guidance',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppRadius.medium,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Recommendation suggests $count '
                  '${count == 1 ? 'vehicle' : 'vehicles'}. '
                  'Staff must select the actual vehicles.',
                  key: const ValueKey('suggested-vehicle-count'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.status});

  final DeploymentStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: AppRadius.medium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.onWarningContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${status.displayLabel} deployments are operational or '
                'terminal records and cannot be edited here.',
                key: const ValueKey('read-only-deployment-message'),
                style: const TextStyle(
                  color: AppColors.onWarningContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: AppRadius.medium,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  key: const ValueKey('deployment-form-error'),
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
