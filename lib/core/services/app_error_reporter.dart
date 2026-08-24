import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppErrorReporter {
  AppErrorReporter._();

  static String report(
    Object error,
    StackTrace? stackTrace, {
    required String context,
  }) {
    final referenceId = _newReferenceId();
    final safeError = _truncate(sanitizeForReport(error.toString()), 1200);
    final safeStack = _truncate(
      sanitizeForReport(stackTrace?.toString() ?? ''),
      5000,
    );

    debugPrint('[app-error][$referenceId][$context] $safeError\n$safeStack');

    if (kIsWeb && kReleaseMode) {
      unawaited(
        _send(
          referenceId: referenceId,
          context: context,
          error: safeError,
          stackTrace: safeStack,
        ),
      );
    }

    return referenceId;
  }

  static void reportFlutterError(FlutterErrorDetails details) {
    report(
      details.exception,
      details.stack,
      context: details.library ?? 'flutter',
    );
  }

  static Future<void> _send({
    required String referenceId,
    required String context,
    required String error,
    required String stackTrace,
  }) async {
    try {
      final endpoint = Uri.base.resolve('/api/client-errors');
      await http
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'referenceId': referenceId,
              'context': context,
              'error': error,
              'stackTrace': stackTrace,
              'path': Uri.base.toString(),
              'platform': defaultTargetPlatform.name,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (reportingError) {
      debugPrint('[app-error-reporting-failed] $reportingError');
    }
  }

  static String _newReferenceId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return timestamp.toRadixString(36).toUpperCase();
  }

  @visibleForTesting
  static String sanitizeForReport(String value) {
    return value
        .replaceAll(
          RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
          'Bearer [redacted]',
        )
        .replaceAll(
          RegExp(
            r'\b[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b',
          ),
          '[token]',
        )
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '[email]',
        );
  }

  static String _truncate(String value, int maximumLength) {
    if (value.length <= maximumLength) return value;
    return '${value.substring(0, maximumLength)}…';
  }
}
