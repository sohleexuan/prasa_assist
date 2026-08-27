import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../controllers/work_orders_controller.dart';
import '../models/work_order.dart';

class WorkOrderFormPage extends StatefulWidget {
  const WorkOrderFormPage({
    required this.controller,
    this.workOrder,
    super.key,
  });

  final WorkOrdersController controller;
  final WorkOrder? workOrder;

  @override
  State<WorkOrderFormPage> createState() => _WorkOrderFormPageState();
}

class _WorkOrderFormPageState extends State<WorkOrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vehicleId;
  late final TextEditingController _taskType;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late WorkOrderPriority _priority;
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;
  bool _saving = false;
  String? _scheduleError;

  bool get _isEditing => widget.workOrder != null;

  @override
  void initState() {
    super.initState();
    final workOrder = widget.workOrder;
    _vehicleId = TextEditingController(text: workOrder?.vehicleId);
    _taskType = TextEditingController(text: workOrder?.taskType);
    _description = TextEditingController(text: workOrder?.description);
    _notes = TextEditingController(text: workOrder?.notes);
    _priority = workOrder?.priority ?? WorkOrderPriority.medium;
    _scheduledStart = workOrder?.scheduledStart;
    _scheduledEnd = workOrder?.scheduledEnd;
  }

  @override
  void dispose() {
    _vehicleId.dispose();
    _taskType.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: _isEditing ? 'Edit work order' : 'Create work order',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'AI recommends. Staff decides.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Review all local demonstration details before saving.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('vehicleIdField'),
                  controller: _vehicleId,
                  decoration: const InputDecoration(labelText: 'Vehicle ID'),
                  validator: _required('Vehicle ID'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('taskTypeField'),
                  controller: _taskType,
                  decoration: const InputDecoration(labelText: 'Task type'),
                  validator: _required('Task type'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('descriptionField'),
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                  validator: _required('Description'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<WorkOrderPriority>(
                  key: const Key('priorityField'),
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    for (final priority in WorkOrderPriority.values)
                      DropdownMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _DateTimeField(
                  label: 'Scheduled start',
                  value: _scheduledStart,
                  onSelect: () => _selectDateTime(isStart: true),
                  onClear: _scheduledStart == null
                      ? null
                      : () => setState(() => _scheduledStart = null),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DateTimeField(
                  label: 'Scheduled end',
                  value: _scheduledEnd,
                  onSelect: () => _selectDateTime(isStart: false),
                  onClear: _scheduledEnd == null
                      ? null
                      : () => setState(() => _scheduledEnd = null),
                ),
                if (_scheduleError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _scheduleError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('notesField'),
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final buttons = [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        key: const Key('saveWorkOrderButton'),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Review and save'),
                      ),
                    ];
                    return compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buttons.last,
                              const SizedBox(height: AppSpacing.sm),
                              buttons.first,
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              buttons.first,
                              const SizedBox(width: AppSpacing.sm),
                              buttons.last,
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String label) {
    return (value) =>
        value == null || value.trim().isEmpty ? '$label is required.' : null;
  }

  bool _validateSchedule() {
    String? error;
    if ((_scheduledStart == null) != (_scheduledEnd == null)) {
      error = 'Provide both scheduled start and scheduled end.';
    } else if (_scheduledStart != null &&
        _scheduledEnd!.isBefore(_scheduledStart!)) {
      error = 'Scheduled end cannot be earlier than scheduled start.';
    }
    setState(() => _scheduleError = error);
    return error == null;
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final current = isStart ? _scheduledStart : _scheduledEnd;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _scheduledStart = selected;
      } else {
        _scheduledEnd = selected;
      }
      _scheduleError = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_validateSchedule()) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.controller.updateEligible(
          original: widget.workOrder!,
          vehicleId: _vehicleId.text,
          taskType: _taskType.text,
          description: _description.text,
          priority: _priority,
          scheduledStart: _scheduledStart,
          scheduledEnd: _scheduledEnd,
          notes: _notes.text,
        );
      } else {
        await widget.controller.createDraft(
          vehicleId: _vehicleId.text,
          taskType: _taskType.text,
          description: _description.text,
          priority: _priority,
          scheduledStart: _scheduledStart,
          scheduledEnd: _scheduledEnd,
          notes: _notes.text,
          createdBy: 'Current operations staff',
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the work order.')),
      );
      setState(() => _saving = false);
    }
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onSelect,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onSelect;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSelect,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              value == null ? 'Select $label' : '$label: ${_format(value!)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'Clear $label',
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
          ),
        ],
      ],
    );
  }

  String _format(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
