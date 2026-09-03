import 'package:flutter/widgets.dart';

import 'service_deployment_page.dart';

@Deprecated('Use ServiceDeploymentPage directly.')
class DeploymentDemoApp extends StatelessWidget {
  const DeploymentDemoApp({this.clock, this.deploymentIdGenerator, super.key});

  final DateTime Function()? clock;
  final String Function(int sequence)? deploymentIdGenerator;

  @override
  Widget build(BuildContext context) {
    return ServiceDeploymentPage(
      clock: clock,
      deploymentIdGenerator: deploymentIdGenerator,
    );
  }
}
