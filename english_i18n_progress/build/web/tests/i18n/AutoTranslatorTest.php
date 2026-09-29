<?php

/**
 * Plain-PHP tests for the English translation layer (no PHPUnit / Laravel needed).
 *
 *   php tests/i18n/AutoTranslatorTest.php
 *
 * Uses the real dictionary (lang/auto/en.php) and markup taken from the platform's Blade views.
 */

declare(strict_types=1);

$root = dirname(__DIR__, 2);
foreach (['Runs', 'UiLocale', 'Dictionary', 'JsLiterals', 'LtrFlipper', 'AutoTranslator'] as $class) {
    require_once $root . "/app/Support/Localization/$class.php";
}

use App\Support\Localization\AutoTranslator;
use App\Support\Localization\LtrFlipper;

$dict = require $root . '/lang/auto/en.php';
$t = new AutoTranslator($dict);

$passed = 0;
$failed = 0;
function check(string $name, bool $ok, string $details = ''): void
{
    global $passed, $failed;
    if ($ok) {
        $passed++;
        echo "  ok   $name\n";
    } else {
        $failed++;
        echo "  FAIL $name\n" . ($details !== '' ? "       $details\n" : '');
    }
}
function has(string $haystack, string $needle): bool
{
    return str_contains($haystack, $needle);
}

echo "Dictionary\n";
check('has at least 12,655 entries', count($dict) >= 12655, (string) count($dict));
check('id 6961 (JS regex ٠-٩) excluded', !isset($dict['٠-٩']));
check('trailing spaces kept', ($dict['تم إنهاء الجلسات النشطة و'] ?? '') === 'Active sessions and ');
$bad = array_filter($dict, fn ($v) => preg_match('/[\'"`\\\\<>&\n]|[\x{0600}-\x{06FF}]/u', $v));
check('no unsafe characters or Arabic in values', $bad === [], implode(' | ', array_slice($bad, 0, 3)));

echo "Error page (views/errors/404.blade.php)\n";
$page = <<<'HTML'
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <title>الصفحة غير موجودة</title>
    <meta name="description" content="الصفحة غير موجودة">
</head>
<body class="bg-slate-50 text-right font-sans">
    <main class="min-h-screen flex items-center justify-center">
        <div class="max-w-lg text-center">
            <h1 class="text-3xl font-bold">الصفحة غير موجودة</h1>
            <p class="mt-3 text-slate-600">الصفحة التي تبحث عنها غير موجودة، أو تم نقلها، أو لم تعد متاحة.</p>
            <a href="/" class="inline-flex items-center gap-2 ml-3 rounded-lg bg-blue-600 px-4 py-2 text-white">العودة إلى الرئيسية</a>
            <a href="/wallet" class="mr-3" title="اذهب إلى المحفظة">اذهب إلى المحفظة</a>
        </div>
    </main>
</body>
</html>
HTML;
$out = $t->translateOutput($page);
check('<html lang="en" dir="ltr">', has($out, '<html lang="en" dir="ltr">'));
check('title translated', has($out, '<title>Page not found</title>'));
check('meta description translated', has($out, 'content="Page not found"'));
check('long sentence with Arabic commas', has($out, 'The page you are looking for does not exist, has been moved, or is no longer available.'));
check('link text + title attribute', has($out, 'title="Go to wallet" data-i18n-ltr>Go to wallet</a>'));
check('href untouched', has($out, 'href="/wallet"'));
check('text-right -> text-left', has($out, 'class="bg-slate-50 text-left font-sans"'));
check('ml-3 -> mr-3 and mr-3 -> ml-3', has($out, 'gap-2 mr-3 rounded-lg') && has($out, 'class="ml-3"'));
check('no Arabic left', !AutoTranslator::hasArabic($out), $out);
check('idempotent (second pass changes nothing)', $t->translateOutput($out) === $out);

echo "Form (views/finance/expenses/create.blade.php)\n";
$form = <<<'HTML'
<form method="POST" action="/finance/expenses" class="space-y-6">
    <label for="title" class="block text-sm">عنوان المصروف</label>
    <input id="title" name="title" type="text" placeholder="مثال: دفعة طباعة مخططات تنفيذية" value="دفعة مخططات">
    <select name="expense_type" class="pr-3">
        <option value="">اختر التصنيف...</option>
        <option value="مصروف مشروع" selected>مصروف مشروع</option>
        <option value="office">مصروف مكتب</option>
    </select>
    <textarea name="notes" placeholder="أي ملاحظات إضافية للإدارة المالية...">ملاحظة كتبها المستخدم</textarea>
    <input type="submit" value="حفظ المصروف">
    <input type="submit" name="decision" value="اعتماد المصروف">
    <button type="submit" class="rounded-r-xl">حفظ المصروف</button>
</form>
HTML;
$out = $t->translateOutput($form);
check('label', has($out, '>Expense title</label>'));
check('placeholder', has($out, 'placeholder="Example: payment for printing construction drawings"'));
check('input value (user data) untouched', has($out, 'value="دفعة مخططات"'));
check('option text translated, option value kept', has($out, '<option value="مصروف مشروع" selected>Project expense</option>'));
check('textarea content untouched', has($out, '>ملاحظة كتبها المستخدم</textarea>'));
check('textarea placeholder translated', has($out, 'placeholder="Any additional notes for financial management..."'));
check('submit without name: value translated', has($out, '<input type="submit" value="Save expense">'));
check('submit with name: value kept (sent to server)', has($out, 'name="decision" value="اعتماد المصروف"'));
check('rounded-r-xl -> rounded-l-xl', has($out, 'class="rounded-l-xl"'));

echo "Dynamic fragments\n";
check('number between Arabic words', $t->translateText('3 مشروع منشور') === '3 published project', $t->translateText('3 مشروع منشور'));
check('sequence of known phrases around a value', $t->translateText('تم تحويل طلبك إلى استشارة رقم 55') === 'Your request was converted into consultation no. 55', $t->translateText('تم تحويل طلبك إلى استشارة رقم 55'));
check('short free text is not guessed word by word', $t->translateText('نص غير معروف') === 'نص غير معروف', $t->translateText('نص غير معروف'));
check('known phrase + value + known word', $t->translateText('تم إنشاء استشارة من طلبك رقم') === 'A consultation was created from your request No.' || !AutoTranslator::hasArabic($t->translateText('تم إنشاء استشارة من طلبك رقم')), $t->translateText('تم إنشاء استشارة من طلبك رقم'));
check('user sentence is not half-translated', $t->translateText('أريد تصميم منزل من طابقين في رام الله') === 'أريد تصميم منزل من طابقين في رام الله', $t->translateText('أريد تصميم منزل من طابقين في رام الله'));
check('different final punctuation', $t->translateText('الحالة:') === 'Status:', $t->translateText('الحالة:'));
check('list joined by Arabic comma', $t->translateText('الإشعارات، الاستشارات') === 'Notifications, Consultations', $t->translateText('الإشعارات، الاستشارات'));
check('unknown text stays as it is', $t->translateText('نص كتبه مستخدم ولا يوجد في القاموس') === 'نص كتبه مستخدم ولا يوجد في القاموس');
check('Latin tokens kept inside a phrase', has($t->translateText('يلزم إتمام توثيق الهوية KYC قبل السحب.'), 'KYC'));
check('whitespace around text kept', $t->translateText("\n        الإشعارات\n    ") === "\n        Notifications\n    ");
check('translate="no" is respected', has($t->translateOutput('<p><span translate="no">الإشعارات</span> الإشعارات</p>'), '<span translate="no">الإشعارات</span> Notifications'));

echo "JavaScript (inline <script> in the views)\n";
$js = <<<'HTML'
<script>
    const labels = { pending: 'قيد الانتظار', done: 'مكتملة' };
    let status = 'مقبول';
    if (row.status === 'مرفوض') { Swal.fire({ title: 'تم الإيداع بنجاح', icon: 'success' }); }
    switch (state) { case 'ملغاة': break; }
    if (['قيد التنفيذ', 'مكتملة'].includes(s)) { toast('تم الإيداع بنجاح'); }
    const map = { 'الإشعارات': 1 };
    const msg = `تم الإيداع بنجاح ${count}`;
    const re = /[٠-٩]+/g; // تم الإيداع بنجاح
    btn.textContent = open ? 'إغلاق التذكرة' : 'فتح المحادثة';
    fd.append('type', 'مصروف مشروع');
</script>
<script type="application/json" id="data">{"message":"تم الإيداع بنجاح"}</script>
HTML;
$out = $t->translateOutput($js);
check('object value translated', has($out, "pending: 'Pending'"));
check('status assignment protected', has($out, "let status = 'مقبول'"));
check('=== comparison protected', has($out, "row.status === 'مرفوض'"));
check('Swal title translated', has($out, "title: 'Deposit successful'"));
check('switch case protected', has($out, "case 'ملغاة'"));
check('array used with includes() protected', has($out, "['قيد التنفيذ', 'مكتملة'].includes"));
check('value also compared elsewhere is protected everywhere', has($out, "done: 'مكتملة'"));
check('object key protected', has($out, "{ 'الإشعارات': 1 }"));
check('template literal static part translated', has($out, 'Deposit successful ${count}`'));
check('regex literal untouched', has($out, '/[٠-٩]+/g'));
check('comment untouched', has($out, '// تم الإيداع بنجاح'));
check('ternary strings translated', has($out, "open ? 'Close ticket' : 'Open conversation'"));
check('FormData value protected', has($out, "fd.append('type', 'مصروف مشروع')"));
check('JSON data script untouched', has($out, '{"message":"تم الإيداع بنجاح"}'));

echo "Alpine / inline handlers\n";
$alpine = '<div x-data="{ tab: \'الملفات\', label: \'تشغيل الفيديو\' }"><button @click="tab = \'الملفات\'" :class="tab === \'الملفات\' ? \'ml-2\' : \'\'" x-text="label"></button>'
    . '<a onclick="return confirm(\'هل تريد حذف هذا العمل؟\')" data-status="مكتملة">حذف نهائي</a></div>';
$out = $t->translateOutput($alpine);
check('x-data display value translated', has($out, "label: 'Play video'"));
check('value compared in :class protected in x-data and @click', has($out, "tab: 'الملفات'") && has($out, "tab = 'الملفات'"));
check(':class physical classes flipped', has($out, "'mr-2'"));
check('confirm() text translated', has($out, "confirm('Do you want to delete this work?')"));
check('data-* untouched', has($out, 'data-status="مكتملة"'));

echo "Right-to-left -> left-to-right\n";
$css = '<style>.card{margin-left:12px;padding:4px 8px 4px 16px;border-right:3px solid red;text-align:right;direction:rtl;border-radius:8px 0 0 8px}'
    . '.center{position:absolute;left:50%;transform:translateX(-50%)} @media (min-width:768px){.side{right:0;float:left}}</style>';
$out = $t->translateOutput($css);
check('margin-left -> margin-right', has($out, 'margin-right:12px'));
check('4-value padding mirrored', has($out, 'padding:4px 16px 4px 8px'));
check('border-right -> border-left', has($out, 'border-left:3px solid red'));
check('text-align, direction', has($out, 'text-align:left;direction:ltr'));
check('border-radius mirrored', has($out, 'border-radius:0 8px 8px 0'));
check('centred element keeps left:50%', has($out, 'left:50%;transform:translateX(-50%)'));
check('rules inside @media flipped', has($out, '.side{left:0;float:right}'));
check('style block flipped only once', $t->translateOutput($out) === $out);
check('style attribute', has($t->translateOutput('<div style="margin-right: 8px; float: right">x</div>'), 'style="margin-left: 8px; float: left"'));
check('dir="rtl" -> ltr', has($t->translateOutput('<div dir="rtl">x</div>'), 'dir="ltr"'));
check('Tailwind variants and negatives', LtrFlipper::flipClasses('md:ml-4 -mr-2 hover:pl-1 lg:text-right border-l-4 rounded-tl-lg space-x-reverse') === 'md:mr-4 -ml-2 hover:pr-1 lg:text-left border-r-4 rounded-tr-lg');
check('centred left-1/2 kept', LtrFlipper::flipClasses('absolute left-1/2 -translate-x-1/2') === 'absolute left-1/2 -translate-x-1/2');

echo "JSON responses\n";
$json = $t->translateJson([
    'status' => 'مقبول',
    'message' => 'المبلغ غير صالح.',
    'errors' => ['amount' => ['أدخل مبلغًا موجبًا.']],
    'data' => ['type' => 'مصروف مشروع', 'title' => 'فيديو المشروع', 'items' => [['label' => 'الإشعارات', 'value' => 'الإشعارات']]],
]);
check('message', $json['message'] === 'Invalid amount.');
check('validation errors', $json['errors']['amount'][0] === 'Enter a positive amount.');
check('nested title/label', $json['data']['title'] === 'Project video' && $json['data']['items'][0]['label'] === 'Notifications');
check('status/type/value never translated', $json['status'] === 'مقبول' && $json['data']['type'] === 'مصروف مشروع' && $json['data']['items'][0]['value'] === 'الإشعارات');

echo "Safety\n";
$broken = new AutoTranslator(function () { throw new RuntimeException('dictionary missing'); });
check('dictionary failure -> original Arabic output', $broken->translateOutput('<p>الإشعارات</p>') === '<p dir="ltr">الإشعارات</p>' || $broken->translateOutput('<p>الإشعارات</p>') === '<p>الإشعارات</p>');
$invalid = "<p>\xC3\x28 الإشعارات</p>";
check('invalid UTF-8 does not crash', is_string($t->translateOutput($invalid)));
check('XML output: text only', $t->translateOutput('<?xml version="1.0"?><urlset><title>الإشعارات</title></urlset>') === '<?xml version="1.0"?><urlset><title>Notifications</title></urlset>');
check('plain-text mail', $t->translateOutput("مرحبًا،\nتم استلام دفعتك بنجاح") === "Hello,\nYour payment was received successfully", $t->translateOutput("مرحبًا،\nتم استلام دفعتك بنجاح"));
check('broken HTML does not crash', is_string($t->translateOutput('<div class="ml-2" <p>الإشعارات</div <<>>')));
$arOnly = new AutoTranslator($dict, false);
check('flip can be disabled', $arOnly->translateOutput('<div class="ml-2">الإشعارات</div>') === '<div class="ml-2">Notifications</div>');

echo "Performance\n";
$big = str_repeat($page . $form . $js . $alpine, 40);
$start = microtime(true);
$t->translateOutput($big);
$ms = (microtime(true) - $start) * 1000;
check(sprintf('%d KB page translated in %.0f ms (< 1500)', strlen($big) / 1024, $ms), $ms < 1500);

echo "\n$passed passed, $failed failed\n";
exit($failed === 0 ? 0 : 1);
