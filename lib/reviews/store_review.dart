import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ReviewRequester {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class _AppleReviewRequester implements ReviewRequester {
  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();
  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

final storeReviewPrompterProvider = FutureProvider<StoreReviewPrompter?>((
  ref,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final prompter = StoreReviewPrompter(
    preferences: await SharedPreferences.getInstance(),
    requester: _AppleReviewRequester(),
  );
  await prompter.initialize();
  return prompter;
});

/// Requests honest feedback after enough play, independently of match outcome.
/// The OS decides whether to display its sheet; an API call is only an attempt.
class StoreReviewPrompter {
  StoreReviewPrompter({
    required this.preferences,
    required this.requester,
    DateTime Function()? clock,
    Future<void> Function()? settle,
  }) : _clock = clock ?? DateTime.now,
       _settle =
           settle ?? (() => Future<void>.delayed(const Duration(seconds: 2)));

  static const _firstOpened = 'storeReview.firstOpened';
  static const _completed = 'storeReview.completedMatches';
  static const _attempts = 'storeReview.attempts';
  final SharedPreferences preferences;
  final ReviewRequester requester;
  final DateTime Function() _clock;
  final Future<void> Function() _settle;
  Future<void> _queue = Future<void>.value();

  Future<void> initialize() => _serialize(() async {
    if (!preferences.containsKey(_firstOpened)) {
      if (!await preferences.setInt(
        _firstOpened,
        _clock().millisecondsSinceEpoch,
      )) {
        throw StateError('Could not save review eligibility');
      }
    }
  });

  Future<void> recordCompletedMatch({
    required bool Function() canRequest,
  }) => _serialize(() async {
    final count = (preferences.getInt(_completed) ?? 0) + 1;
    if (!await preferences.setInt(_completed, count)) return;
    final now = _clock();
    final firstOpened = preferences.getInt(_firstOpened);
    if (firstOpened == null ||
        count < 3 ||
        now.difference(DateTime.fromMillisecondsSinceEpoch(firstOpened)) <
            const Duration(days: 7))
      return;
    final attempts =
        (preferences.getStringList(_attempts) ?? [])
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .where((date) => now.difference(date) < const Duration(days: 365))
            .toList()
          ..sort();
    if (attempts.length >= 3 ||
        (attempts.isNotEmpty &&
            now.difference(attempts.last) < const Duration(days: 120)))
      return;
    if (!canRequest()) return;
    await _settle();
    if (!canRequest() || !await requester.isAvailable() || !canRequest())
      return;
    // Persist before invoking StoreKit so concurrent callbacks or restarts
    // cannot repeatedly request a sheet. No rating or review text is stored.
    if (!await preferences.setStringList(
      _attempts,
      [
        ...attempts,
        _clock(),
      ].map((date) => date.toUtc().toIso8601String()).toList(),
    ))
      return;
    if (canRequest()) await requester.requestReview();
  });

  Future<void> _serialize(Future<void> Function() action) {
    _queue = _queue.then((_) => action()).catchError((Object error) {
      // Review requests are optional and must never break a result screen.
      debugPrint('Store review request unavailable: ${error.runtimeType}');
    });
    return _queue;
  }
}
