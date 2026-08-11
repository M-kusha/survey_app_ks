import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

enum AppCheckStartupFailure { configuration, offline, provider }

AppCheckStartupFailure classifyAppCheckStartupError(Object error) {
  if (error is StateError || error is UnsupportedError) {
    return AppCheckStartupFailure.configuration;
  }
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code.contains('invalid') ||
        code.contains('unauthorized') ||
        code.contains('not-authorized') ||
        code.contains('failed-precondition')) {
      return AppCheckStartupFailure.configuration;
    }
    if (code.contains('network') || code.contains('unavailable')) {
      return AppCheckStartupFailure.offline;
    }
  }
  return error is TimeoutException
      ? AppCheckStartupFailure.offline
      : AppCheckStartupFailure.provider;
}

class AppCheckStartupGate extends StatefulWidget {
  const AppCheckStartupGate({
    super.key,
    required this.activate,
    required this.child,
    this.onActivated,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 400),
  }) : assert(maxAttempts > 0);

  final Future<void> Function() activate;
  final VoidCallback? onActivated;
  final Widget child;
  final int maxAttempts;
  final Duration retryDelay;

  @override
  State<AppCheckStartupGate> createState() => _AppCheckStartupGateState();
}

class _AppCheckStartupGateState extends State<AppCheckStartupGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _running = false;
  bool _announced = false;
  AppCheckStartupFailure? _failure;
  Timer? _timer;
  Completer<bool>? _delay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_runCycle());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_ready &&
        !_running &&
        _failure != AppCheckStartupFailure.configuration) {
      unawaited(_runCycle());
    }
  }

  Future<void> _runCycle() async {
    if (_running || _ready || !mounted) return;
    setState(() {
      _running = true;
      _failure = null;
    });

    for (var attempt = 0; attempt < widget.maxAttempts && mounted; attempt++) {
      try {
        await widget.activate();
        if (!mounted) return;
        _ready = true;
        break;
      } catch (error) {
        final kind = classifyAppCheckStartupError(error);
        if (kind == AppCheckStartupFailure.configuration ||
            attempt + 1 == widget.maxAttempts) {
          _failure = kind;
          break;
        }
        final continued = await _waitBeforeRetry(attempt + 1);
        if (!continued) return;
      }
    }

    if (!mounted) return;
    setState(() => _running = false);
    if (_ready && !_announced) {
      _announced = true;
      widget.onActivated?.call();
    }
  }

  Future<bool> _waitBeforeRetry(int multiplier) {
    final delay = Completer<bool>();
    _delay = delay;
    _timer = Timer(widget.retryDelay * multiplier, () {
      if (!delay.isCompleted) delay.complete(true);
    });
    return delay.future;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    final delay = _delay;
    if (delay != null && !delay.isCompleted) delay.complete(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final failure = _failure;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: failure == null
                  ? Column(
                      key: const Key('app-check-loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text('app_check_starting'.tr()),
                      ],
                    )
                  : _FailureView(
                      failure: failure,
                      running: _running,
                      retry: _runCycle,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.failure,
    required this.running,
    required this.retry,
  });

  final AppCheckStartupFailure failure;
  final bool running;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final configuration = failure == AppCheckStartupFailure.configuration;
    return Column(
      key: Key('app-check-failure-${failure.name}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (configuration
                  ? 'app_check_configuration_title'
                  : 'app_check_unavailable_title')
              .tr(),
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          (configuration
                  ? 'app_check_configuration_body'
                  : 'app_check_unavailable_body')
              .tr(),
          textAlign: TextAlign.center,
        ),
        if (!configuration) ...[
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('app-check-retry'),
            onPressed: running ? null : retry,
            child: Text('retry'.tr()),
          ),
        ],
      ],
    );
  }
}
