import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:access_law_office/app.dart';
import 'package:access_law_office/state/app_state.dart';

void main() {
  testWidgets('Launch screen shows brand and dual entry', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const AccessLawApp(),
      ),
    );
    await tester.pump();
    // Bootstrap splash
    expect(find.text('Access Law Firm'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Join Virtual Lobby'), findsOneWidget);
    expect(find.text('Staff sign in'), findsOneWidget);
  });
}