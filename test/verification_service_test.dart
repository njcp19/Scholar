import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/services/verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reviewCalls = <Map<String, dynamic>>[];
  final resubmitCalls = <Map<String, dynamic>>[];
  late VerificationService service;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/review_registration')) {
          reviewCalls.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('', 204, request: request);
        }
        if (request.url.path.endsWith('/rpc/resubmit_registration')) {
          resubmitCalls.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('', 204, request: request);
        }
        return http.Response('[]', 200, request: request);
      }),
    );
    service = VerificationService();
  });

  setUp(() {
    reviewCalls.clear();
    resubmitCalls.clear();
  });

  final registration = AppUser(
    id: 'scholar-1',
    fullName: 'Jamie Scholar',
    email: 'jamie@example.com',
  );
  test('approval accepts empty notes and sends null to the RPC', () async {
    await service.review(registration, VerificationStatus.approved, ' \t ');

    expect(reviewCalls, hasLength(1));
    expect(reviewCalls.single['p_notes'], isNull);
  });

  test('approval sends trimmed notes to the RPC when provided', () async {
    await service.review(
      registration,
      VerificationStatus.approved,
      '  Matched the official roster  ',
    );

    expect(reviewCalls.single['p_notes'], 'Matched the official roster');
  });

  test('resubmit sends null for scholarship reference', () async {
    await service.resubmit(
      declaredScholar: true,
      scholarshipName: 'School Merit Award',
      studentNumber: null,
      university: null,
      program: null,
      yearLevel: null,
    );

    expect(resubmitCalls, hasLength(1));
    expect(resubmitCalls.single['p_scholarship_reference'], isNull);
  });

  for (final decision in [
    VerificationStatus.rejected,
    VerificationStatus.needsInfo,
  ]) {
    test('${decision.name} still requires a reason', () async {
      await expectLater(
        service.review(registration, decision, ' \t '),
        throwsArgumentError,
      );
      expect(reviewCalls, isEmpty);
    });
  }
}
