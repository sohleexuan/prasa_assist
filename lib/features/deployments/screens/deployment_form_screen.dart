import 'package:flutter/material.dart';

import '../controllers/deployment_controller.dart';
import '../models/deployment_prefill.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../widgets/deployment_status_chip.dart';

class DeploymentFormScreen extends StatefulWidget {
  const DeploymentFormScreen({
    required this.controller,
    required this.currentUserId,
    this.existingDeployment,
    this.prefill,
    this.onSaved,
    this.onCancel,
    this.deploymentIdGenerator,
    this.clock,
    super.key,
  });

  final DeploymentController controller;
  final String currentUserId;
  final ServiceDeployment? existingDeployment;
  final DeploymentPrefill? prefill;
  final ValueChanged<ServiceDeployment>? onSaved;
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

  bool get _isEditMode => widget.existingDeployment != null;

  bool get _isReadOnly {
    final status = widget.existingDeployment?.status;
    return status == DeploymentStatus.active ||
        status == DeploymentStatus.completed ||
        status == DeploymentStatus.cancelled;
  }

  bool get _canSchedule =>
      !_isReadOnly &&
      (widget.existingDeployment == null ||
          widget.existingDeployment!.status == DeploymentStatus.draft);

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final now = _now;
    final existing = widget.existingDeployment;
    final prefill = existing == null ? widget.prefill : null;
    final generatedId =
        widget.deploymentIdGenerator?.call() ??
        'DEP-${now.microsecondsSinceEpoch}';

    _deploymentIdController = TextEditingController(
      text: existing?.deploymentId ?? generatedId,
    );
    _routeIdController = TextEditingController(
      text: existing?.routeId ?? prefill?.routeId ?? '',
    );
    _routeNameController = TextEditingController(
      text: existing?.routeName ?? prefill?.routeName ?? '',
    );
    _vehicleIdsController = TextEditingController(
      text: existing?.vehicleIds.join(', ') ?? '',
    );
    _purposeController = TextEditingController(
      text: existing?.purpose ?? prefill?.suggestedPurpose ?? '',
    );
    _incidentIdController = TextEditingController(
      text: existing?.incidentId ?? prefill?.incidentId ?? '',
    );
    _recommendationIdController = TextEditingController(
      text: existing?.sourceRecommendationId ?? prefill?.recommendationId ?? '',
    );
    _startTime =
        existing?.startTime ?? prefill?.suggestedStartTime ?? _toMinute(now);
    _endTime =
        existing?.endTime ??
        prefill?.suggestedEndTime ??
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17203A),
        foregroundColor: Colors.white,
        title: Text(
          _isEditMode ? 'Edit Deployment' : 'New Deployment',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _showValidation
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PrototypeNotice(),
                  if (_isReadOnly) ...[
                    const SizedBox(height: 12),
                    _ReadOnlyNotice(status: widget.existingDeployment!.status),
                  ],
                  if (_isSubmitting) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      key: ValueKey('deployment-form-progress'),
                    ),
                  ],
                  if (_submissionError != null) ...[
                    const SizedBox(height: 12),
                    _SubmissionError(message: _submissionError!),
                  ],
                  const SizedBox(height: 16),
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
                          validator: _requiredDeploymentId,
                        ),
                        if (_isEditMode) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
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
                  const SizedBox(height: 12),
                  _FormSection(
                    title: 'Route and vehicles',
                    icon: Icons.route_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          key: const ValueKey('route-id-field'),
                          controller: _routeIdController,
                          readOnly: _isReadOnly,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Route ID',
                            helperText: 'Prototype entry — not connected to GTFS route data',
                            prefixIcon: Icon(Icons.signpost_outlined),
                          ),
                          validator: (value) =>
                              _requiredText(value, 'Route ID is required.'),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('vehicle-ids-field'),
                          controller: _vehicleIdsController,
                          readOnly: _isReadOnly,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Vehicle IDs',
                            hintText: 'ABC 1230, DEF 4567',
                            helperText:
                                'Enter actual vehicle IDs separated by commas. '
                                'Availability is not verified in this prototype.',
                            prefixIcon: Icon(Icons.directions_bus_outlined),
                          ),
                          validator: _validateVehicleInput,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedVehicleCountLabel,
                          key: const ValueKey('selected-vehicle-count'),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF5636C7),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (!_isEditMode &&
                            widget.prefill?.suggestedVehicleCount != null) ...[
                          const SizedBox(height: 10),
                          _SuggestedVehicleNotice(
                            count: widget.prefill!.suggestedVehicleCount!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        _DateTimeControls(
                          prefix: 'end',
                          label: 'End',
                          value: _endTime,
                          enabled: !_isReadOnly && !_isSubmitting,
                          onPickDate: () => _pickDate(isStart: false),
                          onPickTime: () => _pickTime(isStart: false),
                        ),
                        if (_timeError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _timeError!,
                            key: const ValueKey('service-window-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
                  const SizedBox(height: 20),
                  _buildActions(),
                ],
              ),
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
          label: Text(_isEditMode ? 'Save Changes' : 'Save Draft'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF6D4AFF),
          ),
        ),
      );
      if (_canSchedule) {
        buttons.addAll([
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('schedule-deployment-button'),
            onPressed: _isSubmitting ? null : () => _submit(schedule: true),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Schedule Deployment'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ]);
      }
    }
    if (buttons.isNotEmpty) {
      buttons.add(const SizedBox(height: 10));
    }
    buttons.add(
      TextButton(
        key: const ValueKey('cancel-deployment-button'),
        onPressed: _isSubmitting ? null : widget.onCancel,
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
    if (widget.currentUserId.trim().isEmpty) {
      setState(() {
        _submissionError = 'Current user ID is required.';
      });
      return;
    }

    final existing = widget.existingDeployment;
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
      final scheduled = await widget.controller.changeStatus(
        deployment.deploymentId,
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
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF6D4AFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF17203A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
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
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: ValueKey('$prefix-date-button'),
            onPressed: enabled ? onPickDate : null,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(_formatDate(value)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: ValueKey('$prefix-time-button'),
            onPressed: enabled ? onPickTime : null,
            icon: const Icon(Icons.access_time),
            label: Text(_formatTime(value)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Prototype data, not live operations',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8D0FF)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: Color(0xFF5636C7)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Prototype data — not live operations',
                  style: TextStyle(
                    color: Color(0xFF402596),
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
          color: const Color(0xFFF7F5FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8D0FF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Color(0xFF5636C7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommendation suggests $count '
                  '${count == 1 ? 'vehicle' : 'vehicles'}. '
                  'Staff must select the actual vehicles.',
                  key: const ValueKey('suggested-vehicle-count'),
                  style: const TextStyle(color: Color(0xFF402596)),
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
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF9A3412)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${status.displayLabel} deployments are operational or '
                'terminal records and cannot be edited here.',
                key: const ValueKey('read-only-deployment-message'),
                style: const TextStyle(
                  color: Color(0xFF7C2D12),
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
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFF991B1B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  key: const ValueKey('deployment-form-error'),
                  style: const TextStyle(color: Color(0xFF7F1D1D)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
