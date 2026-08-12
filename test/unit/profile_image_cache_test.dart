import 'dart:typed_data';

import 'package:echomeet/core/profile/profile_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const avatar = 'profile_images/user_1/avatar.jpg';
  final bytes = Uint8List.fromList(List.filled(64, 7));

  setUp(() async {
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
    final big = Uint8List(ProfileImageCache.maxMemoryBytes ~/ 2 + 1024);
    for (var index = 0; index < 3; index++) {
      await ProfileImageCache.resolve(
        storedReference: 'profile_images/user_$index/avatar.jpg',
        revision: 1,
        fetch: () async => big,
      );
    }

    expect(
      ProfileImageCache.peek('profile_images/user_0/avatar.jpg', 1),
      isNull,
    );
    expect(
      ProfileImageCache.peek('profile_images/user_2/avatar.jpg', 1),
      isNotNull,
    );
  });
}
