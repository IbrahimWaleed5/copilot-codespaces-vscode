# Translation guide — Alwaleed Engineering Platform (Arabic → English UI)

You translate short Arabic UI phrases from a Laravel web platform for engineering services
(clients request consultations, engineering offices/engineers bid on projects, wallet & payments,
KYC identity verification, support tickets, admin/finance back-office, AI assistant, meetings, BIM).

Each input item: {"id": 123, "f": "source file (context only)", "ar": "Arabic phrase"}.
Output: ONE JSON object mapping every id (as a string) to its English translation:
{"123": "English text", "124": "..."}  — include EVERY id from the chunk, nothing else.

## Hard rules (the text is injected into HTML attributes and JavaScript strings)
1. NEVER use these characters: ' " ` \ < > & and never a newline.
   - Apostrophe → use ’ (e.g. “don’t”, “client’s”). Quotes → use “ ”.
   - Instead of & write “and”.
2. Keep every Latin token, number, code and placeholder EXACTLY as in the Arabic
   (e.g. :attribute, :count, KYC, PDF, 2FA, 20MB, USD, BIM, LiveKit, CONS-…). Arabic-Indic digits ٠-٩ → 0-9.
3. Match the phrase’s form:
   - Phrase ends with ":" → keep ":"; ends with "؟" → "?"; ends with "…" or "..." → keep "…"/"...".
   - Ends with "." → end with "."; no final punctuation in Arabic → none in English.
   - Arabic comma "،" → ",", "؛" → ";".
4. Fragments: many items are pieces of a longer sentence (text was split around dynamic values).
   Translate them as fragments that still read naturally when joined, e.g.
   "تمت الإجابة على" → "Answered:" is WRONG; use "was answered on" / "answered" fitting the fragment.
   A fragment starting with و ("and") → start with lowercase “and …”. Do not add periods to fragments.
5. Style: concise, professional product English (American spelling). Short labels/buttons/headings
   (1–5 words, no final period) → capitalize only the first word (Sentence case), except proper nouns.
   Full sentences → normal sentence case.
6. Never leave Arabic in the output. Transliterate person names (إبراهيم → Ibrahim).
7. Don’t explain, don’t add notes. Same meaning, no additions or omissions.

## Glossary (use consistently)
منصة الوليد الهندسية → Alwaleed Engineering Platform | الوليد → Alwaleed | مكتب الوليد → Alwaleed Office
استشارة / الاستشارات → consultation / Consultations | طلب استشارة → consultation request (button: Request a consultation)
مهندس / المهندسون → engineer / Engineers | م. (before a name) → Eng. | مكتب هندسي / المكاتب الهندسية → engineering office / Engineering offices
العميل → client | صاحب المشروع → project owner | لوحة التحكم → Dashboard | الإشعارات → Notifications
المحفظة → wallet | محفظة الوليد → Alwaleed Wallet | الرصيد → balance | شحن الرصيد → top up | سحب → withdrawal
تحويل (مالي) → transfer | تحويل عملة → currency conversion | الدفعات → payments (دفعات المشروع → project installments)
عرض سعر / عروض الأسعار → quote / Quotes | مقارنة العروض → quote comparison | سوق المشاريع → Project Marketplace
المناقصات → tenders | الباقات → packages/plans | الاشتراك → subscription | العمولة → commission
توثيق الهوية → identity verification (KYC) | التوثيق الاحترافي → professional verification
الدعم الفني → Technical support | تذكرة → ticket | النزاع → dispute | الاسترداد → refund
قيد المراجعة → Under review | بانتظار → Awaiting / Pending | مقبول / معتمد → Approved | مرفوض → Rejected
ملغي → Cancelled | مكتمل → Completed | نشط / فعال → Active | معلق → Suspended/On hold (by context)
المخططات → drawings | التسليمات → deliverables | المراحل → phases | الجدول الزمني → timeline | جدول الكميات → bill of quantities (BOQ)
العقد → contract | الاجتماعات → meetings | المساعد الذكي → AI assistant | المدير المالي → financial manager
مدير المنصة → platform admin | الإدارة → management/admin (by context) | الموظف → employee | الصلاحيات → permissions
شيكل → ILS (shekel) | دينار → JOD | ريال → SAR | دولار → USD
