import 'package:flutter/material.dart';

import '../controllers/incident_controller.dart';
import '../models/incident.dart';
import 'incident_report_page.dart';

/// Ordinary Module 1 edit entry page.
///
/// Status changes remain separate explicit actions on the Incident detail page.
class IncidentEditPage extends StatelessWidget {
  const IncidentEditPage({
    required this.controller,
    required this.incident,
    required this.currentStaffId,
    this.onSaved,
    this.onCancel,
    this.clock,
    super.key,
  });

  final IncidentController controller;
  final Incident incident;
  final String currentStaffId;
  final ValueChanged<Incident>? onSaved;
  final VoidCallback? onCancel;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return IncidentReportPage(
      controller: controller,
      reportedBy: currentStaffId,
      existingIncident: incident,
      onSaved: onSaved,
      onCancel: onCancel,
      clock: clock,
    );
  }
}
