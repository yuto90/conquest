import 'dart:async';

import 'package:conquest/reviews/store_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReviewRequester implements ReviewRequester {
  bool available = true;
  int requests = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<void> requestReview() async => requests++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late FakeReviewRequester requester;
  late DateTime now;
  late StoreReviewPrompter prompter;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    requester = FakeReviewRequester();
    now = DateTime.utc(2026, 10, 2);
    prompter = StoreReviewPrompter(
      preferences: preferences,
      requester: requester,
      clock: () => now,
      settle: () async {},
    );
    await prompter.initialize();
  });

  Future<void> complete({bool visible = true}) =>
      prompter.recordCompletedMatch(canRequest: () => visible);

  test(
    'waits for seven days and three completed matches across launches',
    () async {
      await complete();
      await complete();
      await complete();
      expect(requester.requests, 0);
      now = now.add(const Duration(days: 7));
      prompter = StoreReviewPrompter(
        preferences: preferences,
        requester: requester,
        clock: () => now,
        settle: () async {},
      );
      await prompter.initialize();
      await complete();
      expect(requester.requests, 1);
    },
  );

  test('three matches are still required after the age threshold', () async {
    now = now.add(const Duration(days: 8));
    await complete();
    await complete();
    expect(requester.requests, 0);
    await complete();
    expect(requester.requests, 1);
  });

  test(
    'rechecks result visibility after the delay without consuming quota',
    () async {
      now = now.add(const Duration(days: 8));
      await complete();
      await complete();
      var visible = true;
      final settled = Completer<void>();
      prompter = StoreReviewPrompter(
        preferences: preferences,
        requester: requester,
        clock: () => now,
        settle: () => settled.future,
      );
      final pending = prompter.recordCompletedMatch(canRequest: () => visible);
      await Future<void>.delayed(Duration.zero);
      visible = false;
      settled.complete();
      await pending;
      expect(requester.requests, 0);
      await complete();
      expect(requester.requests, 1);
    },
  );

  test(
    'enforces cooldown and at most three attempts in a rolling year',
    () async {
      now = now.add(const Duration(days: 8));
      await complete();
      await complete();
      await complete();
      await complete();
      expect(requester.requests, 1);
      for (var i = 0; i < 2; i++) {
        now = now.add(const Duration(days: 120));
        await complete();
      }
      expect(requester.requests, 3);
      now = now.add(const Duration(days: 120));
      await complete();
      expect(requester.requests, 3);
      now = now.add(const Duration(days: 6));
      await complete();
      expect(requester.requests, 4);
    },
  );

  test('unavailable StoreKit does not consume an attempt', () async {
    now = now.add(const Duration(days: 8));
    requester.available = false;
    await complete();
    await complete();
    await complete();
    requester.available = true;
    await complete();
    expect(requester.requests, 1);
  });

  test(
    'concurrent completion notifications cannot make duplicate requests',
    () async {
      now = now.add(const Duration(days: 8));
      await Future.wait(List.generate(8, (_) => complete()));
      expect(requester.requests, 1);
    },
  );
}
