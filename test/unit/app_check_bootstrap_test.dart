import 'dart:async';

import 'package:echomeet/core/security/app_check_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'simultaneous activation shares one call and success stays cached',
    () async {
      final release = Completer<void>();
      var calls = 0;
      final coordinator = AppCheckActivationCoordinator(() {
        calls += 1;
        return release.future;
      });

      final first = coordinator.activate();
      final second = coordinator.activate();

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      release.complete();
      await Future.wait([first, second]);
      await coordinator.activate();

      expect(coordinator.isActivated, isTrue);
      expect(calls, 1);
    },
  );

  test('failure clears in-flight state so a later call can retry', () async {
    final failure = StateError('temporary provider failure');
    var calls = 0;
    final coordinator = AppCheckActivationCoordinator(() async {
      calls += 1;
      if (calls == 1) throw failure;
    });

    await expectLater(coordinator.activate(), throwsA(same(failure)));
    expect(coordinator.isActivated, isFalse);

    await coordinator.activate();
    await coordinator.activate();

    expect(coordinator.isActivated, isTrue);
    expect(calls, 2);
  });
}
