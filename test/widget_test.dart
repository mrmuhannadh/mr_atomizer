import 'package:flutter_test/flutter_test.dart';
import 'package:jira_manager/main.dart';

void main() {
  testWidgets('Jira Notifier app starts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const JiraNotifierApp(
        connected: false,
        onboarded: false,
      ),
    );

    await tester.pump();

    expect(find.byType(JiraNotifierApp), findsOneWidget);
  });
}