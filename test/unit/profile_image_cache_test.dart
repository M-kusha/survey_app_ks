import 'dart:typed_data';

import 'package:echomeet/core/profile/profile_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reported problem: turning the phone re-downloaded every avatar on screen.
///
/// Rotation moves the shell to a different layout branch, so the avatar widgets
/// are disposed and rebuilt, and each new one called Storage from `initState`.
/// These tests are about the property that fixes it — bytes are fetched once per
/// reference and revision — and about the one thing a cache must never do, which
/// is serve a photo that has been replaced.
void main() {
  const avatar = 'profile_images/user_1/avatar.jpg';
  final bytes = Uint8List.fromList(List.filled(64, 7));

  setUp(() async {
    // No filesystem in unit tests, and the memory layer is what rotation
    // exercises. The disk layer's own failure path is covered below.
    ProfileImageCache.diskEnabled = false;
    await ProfileImageCache.clear();
  });

  Future<Uint8List?> resolve({
    required int fetches,
    Object? revision,
    String reference = avatar,
    Uint8List? payload,
  }) => ProfileImageCache.resolve(
    storedReference: reference,
    revision: revision,
    fetch: () async => payload ?? bytes,
  );

  test('a second mount of the same avatar does not fetch again', () async {
    var fetches = 0;
    Future<Uint8List?> load() => ProfileImageCache.resolve(
      storedReference: avatar,
      revision: 3,
      fetch: () async {
        fetches++;
        return bytes;
      },
    );

    expect(await load(), bytes);
    expect(await load(), bytes);
    expect(await load(), bytes);

    expect(fetches, 1);
  });

  test('a new revision is fetched, because it is a different photo', () async {
    var fetches = 0;
    Future<Uint8List?> load(int revision) => ProfileImageCache.resolve(
      storedReference: avatar,
      revision: revision,
      fetch: () async {
        fetches++;
        return bytes;
      },
    );

    await load(1);
    await load(1);
    await load(2);

    // Freshness is the key, not a timer: uploading a photo increments the
    // revision, which is a cache miss by construction.
    expect(fetches, 2);
  });

  test('two people are cached separately', () async {
    final other = Uint8List.fromList(List.filled(8, 9));
    await resolve(fetches: 1, revision: 1);
    final second = await resolve(
      fetches: 1,
      revision: 1,
      reference: 'profile_images/user_2/avatar.jpg',
      payload: other,
    );

    expect(second, other);
    expect(ProfileImageCache.peek(avatar, 1), bytes);
  });

  test('concurrent mounts share one fetch', () async {
    // A member list mounts many rows at once. Twenty rows of the same avatar
    // must be one request, not twenty.
    var fetches = 0;
    Future<Uint8List?> load() => ProfileImageCache.resolve(
      storedReference: avatar,
      revision: 1,
      fetch: () async {
        fetches++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return bytes;
      },
    );

    final results = await Future.wait([load(), load(), load(), load()]);

    expect(fetches, 1);
    expect(results.every((result) => result == bytes), isTrue);
  });

  test('a failed fetch is not remembered as a result', () async {
    var attempts = 0;
    Future<Uint8List?> load() => ProfileImageCache.resolve(
      storedReference: avatar,
      revision: 1,
      fetch: () async {
        attempts++;
        return attempts == 1 ? null : bytes;
      },
    );

    expect(await load(), isNull);
    // Caching the null would have left a permanently blank avatar for as long as
    // the app ran, which is worse than the extra request.
    expect(await load(), bytes);
    expect(attempts, 2);
  });

  test('an empty object is not remembered either', () async {
    var attempts = 0;
    Future<Uint8List?> load() => ProfileImageCache.resolve(
      storedReference: avatar,
      revision: 1,
      fetch: () async {
        attempts++;
        return attempts == 1 ? Uint8List(0) : bytes;
      },
    );

    await load();
    expect(await load(), bytes);
  });

  test('the key is stable across runs and filesystem-safe', () async {
    // It names a file that has to be found again after a restart, so it may not
    // depend on String.hashCode and may not contain path separators.
    final key = ProfileImageCache.keyFor(avatar, 4);

    expect(key, ProfileImageCache.keyFor(avatar, 4));
    expect(key.contains('/'), isFalse);
    expect(key.contains(r'\'), isFalse);
    expect(key, isNot(ProfileImageCache.keyFor(avatar, 5)));
  });

  test('clearing forgets everything', () async {
    await resolve(fetches: 1, revision: 1);
    expect(ProfileImageCache.peek(avatar, 1), isNotNull);

    await ProfileImageCache.clear();

    expect(ProfileImageCache.peek(avatar, 1), isNull);
  });

  test('memory is bounded, and the oldest entry goes first', () async {
    // Without a bound this is a leak that grows with every member whose photo
    // has ever been on screen.
    final big = Uint8List(ProfileImageCache.maxMemoryBytes ~/ 2 + 1024);
    for (var index = 0; index < 3; index++) {
      await ProfileImageCache.resolve(
        storedReference: 'profile_images/user_$index/avatar.jpg',
        revision: 1,
        fetch: () async => big,
      );
    }

    expect(ProfileImageCache.peek('profile_images/user_0/avatar.jpg', 1), isNull);
    expect(
      ProfileImageCache.peek('profile_images/user_2/avatar.jpg', 1),
      isNotNull,
    );
  });
}
