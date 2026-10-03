import 'package:conquest/profile/storage_lease.dart';
import 'package:conquest/profile/storage_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Web Lock rejects a second owner and storage opener before any DB writes',
    () async {
      final first = await WebWriterLease.acquire();
      try {
        expect(first.isHeld, isTrue);
        await expectLater(
          WebWriterLease.acquire(),
          throwsA(isA<StorageAlreadyOwned>()),
        );
        await expectLater(
          openStorageConnection(),
          throwsA(isA<StorageAlreadyOwned>()),
        );
        expect(first.isHeld, isTrue);
      } finally {
        await first.release();
      }
      expect(first.isHeld, isFalse);
      final next = await WebWriterLease.acquire();
      expect(next.isHeld, isTrue);
      await next.release();
      await next.release();
    },
  );

  test(
    'storage asset preflight rejects HTML fallback and accepts WASM/JS MIME',
    () async {
      await expectLater(
        verifyStorageAsset(Uri.parse('data:text/html,<html>fallback</html>'), {
          'application/wasm',
        }),
        throwsA(isA<StorageUnavailable>()),
      );
      await verifyStorageAsset(Uri.parse('data:application/wasm,fixture'), {
        'application/wasm',
      });
      await verifyStorageAsset(Uri.parse('data:text/javascript,fixture'), {
        'text/javascript',
      });
    },
  );

  test(
    'missing deployed assets fail visibly and release writer ownership',
    () async {
      await expectLater(
        openStorageConnection(),
        throwsA(isA<StorageUnavailable>()),
      );
      final retry = await WebWriterLease.acquire();
      await retry.release();
    },
  );
}
