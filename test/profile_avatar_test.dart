import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  const imageBytes = <int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1f,
    0x15,
    0xc4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0b,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9c,
    0x63,
    0x60,
    0x00,
    0x02,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0xa5,
    0xf6,
    0x45,
    0x40,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4e,
    0x44,
    0xae,
    0x42,
    0x60,
    0x82,
  ];

  final userWithoutSelfie = AppUser(
    id: 'student-1',
    fullName: 'Jamie Park',
    email: 'jamie@example.edu',
  );

  Widget app(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('shows initials when the user has no selfie', (tester) async {
    await tester.pumpWidget(
      app(ProfileAvatar(user: userWithoutSelfie, size: 52)),
    );

    expect(find.text('JP'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the selfie when loading succeeds', (tester) async {
    final user = AppUser(
      id: 'student-1',
      fullName: 'Jamie Park',
      email: 'jamie@example.edu',
      selfiePath: 'student-1/selfie.jpg',
    );

    await tester.pumpWidget(
      app(
        ProfileAvatar(
          user: user,
          size: 52,
          loadImage: (_) async => Uint8List.fromList(imageBytes),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows initials when loading fails', (tester) async {
    final user = AppUser(
      id: 'student-1',
      fullName: 'Jamie Park',
      email: 'jamie@example.edu',
      selfiePath: 'student-1/selfie.jpg',
    );

    await tester.pumpWidget(
      app(
        ProfileAvatar(
          user: user,
          size: 52,
          loadImage: (_) async => throw StateError('unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('JP'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
