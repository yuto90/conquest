import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> runProfileIo(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var done = false;
  Object? failure;
  StackTrace? trace;
  await tester.runAsync(() async {
    unawaited(
      action().then<void>(
        (_) => done = true,
        onError: (Object error, StackTrace stack) {
          failure = error;
          trace = stack;
          done = true;
        },
      ),
    );
  });
  for (var attempt = 0; !done && attempt < 1000; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  if (!done) throw TimeoutException('Profile I/O did not finish');
  if (failure case final error?) Error.throwWithStackTrace(error, trace!);
}
