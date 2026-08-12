import 'package:echomeet/login/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.init();
  });

  test('a remembered email survives signing out', () async {
    await UserPreferences.setUserEmail('someone@example.com');
    await UserPreferences.setFullName('Someone');
    await UserPreferences.setRememberMe(true);

    await UserPreferences.endSession();

    expect(UserPreferences.getEmail(), 'someone@example.com');
    expect(UserPreferences.getFullName(), 'Someone');
    expect(UserPreferences.getRememberMe(), isTrue);
  });

  test('nothing is kept when remember me was never ticked', () async {
    await UserPreferences.setUserEmail('someone@example.com');
    await UserPreferences.setFullName('Someone');
    await UserPreferences.setRememberMe(false);

    await UserPreferences.endSession();

    expect(UserPreferences.getEmail(), isNull);
    expect(UserPreferences.getFullName(), isNull);
    expect(UserPreferences.getRememberMe(), isFalse);
  });

  test('clearSession still forgets everything', () async {
    await UserPreferences.setUserEmail('someone@example.com');
    await UserPreferences.setFullName('Someone');
    await UserPreferences.setRememberMe(true);

    await UserPreferences.clearSession();

    expect(UserPreferences.getEmail(), isNull);
    expect(UserPreferences.getRememberMe(), isFalse);
  });

  test('the biometric preference is independent of the session', () async {
    await UserPreferences.setBiometricAuthEnabled(true);
    await UserPreferences.setRememberMe(false);

    await UserPreferences.endSession();

    expect(UserPreferences.getBiometricAuthEnabled(), isTrue);
  });
}
