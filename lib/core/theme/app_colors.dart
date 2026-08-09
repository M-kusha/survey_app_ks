import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.participated,
    required this.notParticipated,
    required this.pending,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  final Color info;
  final Color infoContainer;

  final Color participated;
  final Color notParticipated;
  final Color pending;

  static const light = AppColors(
    success: Color(0xFF1B873F),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCF5E3),
    warning: Color(0xFFB25E02),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFF0DB),
    info: Color(0xFF3A6EA5),
    infoContainer: Color(0xFFE3EDF9),
    participated: Color(0xFF1B873F),
    notParticipated: Color(0xFFB3261E),
    pending: Color(0xFF8A8F98),
  );

  static const dark = AppColors(
    success: Color(0xFF5CD98A),
    onSuccess: Color(0xFF00391A),
    successContainer: Color(0xFF16351F),
    warning: Color(0xFFFFB870),
    onWarning: Color(0xFF3D2200),
    warningContainer: Color(0xFF3A2A14),
    info: Color(0xFF8FBCEB),
    infoContainer: Color(0xFF1B2A3A),
    participated: Color(0xFF5CD98A),
    notParticipated: Color(0xFFFF8A80),
    pending: Color(0xFF9BA1AA),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? participated,
    Color? notParticipated,
    Color? pending,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      participated: participated ?? this.participated,
      notParticipated: notParticipated ?? this.notParticipated,
      pending: pending ?? this.pending,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      participated: Color.lerp(participated, other.participated, t)!,
      notParticipated: Color.lerp(notParticipated, other.notParticipated, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
