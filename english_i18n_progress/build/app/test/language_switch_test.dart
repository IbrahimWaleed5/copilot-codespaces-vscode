import 'package:fapp/i18n/i18n.dart';
import 'package:fapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('المحفظة'.tr())),
        body: const LanguageSwitchTile(),
      );
}

void main() {
  testWidgets('switches Arabic <-> English live, keeps open screens, saves choice', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.load();
    expect(AppLanguage.instance.isArabic, isTrue);

    await tester.pumpWidget(const MyApp());
    expect(find.text('الإشعارات'), findsWidgets);
    expect(find.text('3 مشروع منشور'), findsOneWidget);
    final ctx = tester.element(find.text('الإشعارات').first);
    expect(Directionality.of(ctx), TextDirection.rtl);

    // open a second screen, switch language there
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const SecondPage()));
    await tester.pumpAndSettle();
    expect(find.text('المحفظة'), findsWidgets);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(AppLanguage.instance.isEnglish, isTrue);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Language'))), TextDirection.ltr);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');

    // back to the first screen: it was rebuilt in English too
    Navigator.of(tester.element(find.text('Language'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('3 published project'), findsOneWidget);
    expect(find.text('Save expense'), findsOneWidget);
    expect(find.text('Status: مقبول'), findsOneWidget); // value stays as data

    // headers for API calls
    expect(AppLanguage.instance.headers['Accept-Language'], 'en');

    // and back to Arabic
    await AppLanguage.instance.setLanguage('ar');
    await tester.pumpAndSettle();
    expect(find.text('الإشعارات'), findsWidgets);
    expect(Directionality.of(tester.element(find.text('الإشعارات').first)), TextDirection.rtl);
  });
}
