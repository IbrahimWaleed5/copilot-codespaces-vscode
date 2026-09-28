// Run: dart run test/translator_check.dart   (pure Dart, no Flutter needed)
import 'dart:io';

import '../lib/i18n/en_dictionary.dart';
import '../lib/i18n/translator.dart';

void main() {
  final t = ArabicTranslator(kEnglishDictionary);
  var failed = 0;
  void check(String input, String expected) {
    final got = t.translate(input);
    final ok = got == expected;
    if (!ok) failed++;
    stdout.writeln(
      '${ok ? 'ok  ' : 'FAIL'} $input -> $got${ok ? '' : '   (expected: $expected)'}',
    );
  }

  check('الإشعارات', 'Notifications');
  check('  الإشعارات  ', '  Notifications  ');
  check('الحالة:', 'Status:');
  check('الإشعارات، الاستشارات', 'Notifications, Consultations');
  check('3 مشروع منشور', '3 published project');
  check(
    'تم تحويل طلبك إلى استشارة رقم 55',
    'Your request was converted into consultation no. 55',
  );
  check(
    'يلزم إتمام توثيق الهوية KYC قبل السحب.',
    'KYC identity verification must be completed before withdrawal.',
  );
  check('نص غير معروف', 'نص غير معروف');
  check(
    'أريد تصميم منزل من طابقين في رام الله',
    'أريد تصميم منزل من طابقين في رام الله',
  );
  check('Hello', 'Hello');
  check('', '');
  check(
    'الصفحة التي تبحث عنها غير موجودة، أو تم نقلها، أو لم تعد متاحة.',
    'The page you are looking for does not exist, has been moved, or is no longer available.',
  );
  check('(قيد المراجعة)', '(Under review)');
  final sw = Stopwatch()..start();
  for (var i = 0; i < 2000; i++) {
    ArabicTranslator(kEnglishDictionary)
        .translate('تم تحويل طلبك إلى استشارة رقم $i');
  }
  stdout.writeln('2000 uncached translations: ${sw.elapsedMilliseconds} ms');
  stdout.writeln(failed == 0 ? 'ALL PASSED' : '$failed FAILED');
  exit(failed == 0 ? 0 : 1);
}
