import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/services/app_error_reporter.dart';

void main() {
  test('production configuration keeps defensive browser headers', () {
    final config =
        jsonDecode(File('vercel.json').readAsStringSync())
            as Map<String, dynamic>;
    final rules = (config['headers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final catchAll = rules.singleWhere((rule) => rule['source'] == '/(.*)');
    final headers = <String, String>{
      for (final header
          in (catchAll['headers'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
        header['key'] as String: header['value'] as String,
    };

    expect(
      headers['Content-Security-Policy'],
      contains("frame-ancestors 'none'"),
    );
    expect(headers['Content-Security-Policy'], contains("object-src 'none'"));
    expect(headers['X-Content-Type-Options'], 'nosniff');
    expect(headers['X-Frame-Options'], 'DENY');
    expect(headers['Strict-Transport-Security'], contains('max-age=63072000'));
    expect(headers['Permissions-Policy'], contains('microphone=()'));
  });

  test('error reports remove common credentials and personal email', () {
    const jwt =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MCJ9.'
        'abcdefghijklmnopqrstuvwx1234567890';
    final safe = AppErrorReporter.sanitizeForReport(
      'login lil.chapeu@gmail.com Bearer secret-access-token $jwt',
    );

    expect(safe, isNot(contains('lil.chapeu@gmail.com')));
    expect(safe, isNot(contains('secret-access-token')));
    expect(safe, isNot(contains(jwt)));
    expect(safe, contains('[email]'));
    expect(safe, contains('[token]'));
  });
}
