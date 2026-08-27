import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/dependencies/app_dependencies_scope.dart';

import '../../support/fake_auth_gateway.dart';
import '../../support/test_dependencies.dart';

void main() {
  testWidgets('makes shared dependencies available below the scope', (
    tester,
  ) async {
    final gateway = FakeAuthGateway();
    addTearDown(gateway.dispose);
    final dependencies = createTestDependencies(gateway);
    late Object resolvedClient;
    late Object resolvedGateway;

    await tester.pumpWidget(
      AppDependenciesScope(
        dependencies: dependencies,
        child: Builder(
          builder: (context) {
            final resolved = AppDependenciesScope.of(context);
            resolvedClient = resolved.supabaseClient;
            resolvedGateway = resolved.authGateway;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolvedClient, same(dependencies.supabaseClient));
    expect(resolvedGateway, same(gateway));
  });
}
