@props(['standalone' => false])
@php
    $supportBotRoute = request()->route();

    $supportBotRouteParameters = collect(
        $supportBotRoute?->parameters() ?? []
    )->mapWithKeys(function ($value, $key) {
        if ($value instanceof \Illuminate\Database\Eloquent\Model) {
            return [
                (string) $key => (string) $value->getKey(),
            ];
        }

        if (is_scalar($value) || $value === null) {
            return [
                (string) $key => $value === null
                    ? ''
                    : (string) $value,
            ];
        }

        return [];
    })->all();

    $supportBotFrontend = [
        'pageContext' => [
            'route' => $supportBotRoute?->getName(),
            'path' => request()->path(),
            'parameters' => $supportBotRouteParameters,
        ],
        'routes' => [
            'start' => route('support-bot.start'),
            'send' => route('support-bot.send'),
            'analyzeFile' => auth()->check() ? route('support-bot.analyze-file') : null,
            'messagesTemplate' => route(
                'support-bot.messages',
                ['ticket' => '__TICKET__']
            ),
            'resolveTemplate' => route(
                'support-bot.resolve',
                ['ticket' => '__TICKET__']
            ),
            'transferTemplate' => route(
                'support-bot.transfer',
                ['ticket' => '__TICKET__']
            ),
            'guestAsk' => route('support-bot.guest.ask'),
            'history' => auth()->check() ? route('support-bot.conversations') : null,
            'renameTemplate' => auth()->check() ? route('support-bot.conversations.rename', ['ticket' => '__TICKET__']) : null,
            'archiveTemplate' => auth()->check() ? route('support-bot.conversations.archive', ['ticket' => '__TICKET__']) : null,
            'premium' => auth()->check() ? route('ai.premium.index') : route('login'),
            'login' => route('login'),
            'register' => route('register'),
            'home' => route('home'),
            'assistantPage' => route('smart-assistant.index'),
            'assistantSettings' => auth()->check() ? route('assistant.settings.show') : null,
            'assistantSettingsUpdate' => auth()->check() ? route('assistant.settings.update') : null,
        ],
        'authenticated' => auth()->check(),
        'standalone' => (bool) $standalone,
    ];
@endphp

<div id="supportBotWidget" class="support-bot-widget {{ $standalone ? 'is-standalone' : '' }}">
    <button
        type="button"
        id="supportBotToggle"
        class="support-bot-toggle {{ $standalone ? 'd-none' : '' }}"
        aria-label="فتح مساعد منصة الوليد الهندسية"
    >
        <span class="support-bot-toggle-icon">AI</span>
        <span id="supportBotUnread" class="support-bot-unread d-none">1</span>
    </button>

    <section
        id="supportBotPanel"
        class="support-bot-panel {{ $standalone ? 'is-open' : '' }}"
        aria-hidden="{{ $standalone ? 'false' : 'true' }}"
    >
        <header class="support-bot-header">
            @if($standalone)
            <div class="support-bot-minimal-top">
                <button type="button" id="supportBotHistoryBtnHome" class="support-bot-home-menu" aria-label="فتح القائمة">
                    <span></span><span></span><span></span>
                </button>
                <div class="support-bot-home-tabs" role="group" aria-label="وضع المساعد">
                    <button type="button" class="support-bot-home-tab" data-home-mode="work">العمل</button>
                    <button type="button" class="support-bot-home-tab is-active" data-home-mode="chat">الدردشة</button>
                </div>
                <div class="support-bot-home-spacer" aria-hidden="true"></div>
            </div>
            @endif
            <div class="support-bot-topline">
                <button type="button" id="supportBotClose" class="support-bot-close" aria-label="إغلاق">
                    <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 18 18 6M6 6l12 12"/></svg>
                </button>

                <div class="support-bot-top-actions">
                    @auth
                        <button type="button" id="supportBotHistoryBtn" class="support-bot-ghost-btn">
                            <span>☰</span><span>المحادثات</span>
                        </button>
                        <button type="button" id="supportBotNewBtn" class="support-bot-account-btn">
                            <span>＋ محادثة جديدة</span>
                        </button>
                    @else
                        <a href="{{ route('login') }}" class="support-bot-ghost-btn"><span>☰</span><span>المحادثات</span></a>
                        <a href="{{ route('login') }}" class="support-bot-login-link">تسجيل الدخول</a>
                        <a href="{{ route('register') }}" class="support-bot-account-btn">
                            <span>إنشاء حساب</span><span class="support-bot-credit-badge">+100</span>
                        </a>
                    @endauth
                </div>
            </div>

            <div class="support-bot-brand-row">
                <div class="support-bot-brand-wrap">
                    <div class="support-bot-ai-avatar">
                        <div><img src="{{ asset('images/Mainlogo.png') }}" alt="منصة الوليد الهندسية"></div>
                        <span></span>
                    </div>
                    <div class="support-bot-brand-copy">
                        <div class="support-bot-title-row">
                            <h3>مساعد منصة الوليد الهندسية</h3>
                            <span class="support-bot-pro-chip">Pro v2</span>
                        </div>
                        <p id="supportBotStatus"><span class="support-bot-live-dot"></span> المساعد الذكي متاح وجاهز</p>
                    </div>
                </div>

                <button type="button" id="supportBotVoiceCallBtn" class="support-bot-voice-call-btn">
                    <span class="support-bot-mic-icon">🎙</span>
                    <span>محادثة صوتية</span>
                </button>
            </div>

            <div class="support-bot-account-banner">
                @auth
                    <div class="support-bot-account-state">
                        <span class="support-bot-info-dot">AI</span>
                        <span id="supportBotPlanLabel">AI</span>
                        <small>•</small>
                        <strong id="supportBotCreditLabel">جاري تحميل الرصيد...</strong>
                    </div>
                    <a href="{{ route('ai.premium.index') }}" class="support-bot-banner-action">إدارة الباقة والرصيد</a>
                @else
                    <div class="support-bot-account-state">
                        <span class="support-bot-alert-icon">!</span>
                        <span>وضع الزائر: احفظ محادثاتك بعد التسجيل</span>
                    </div>
                    <span class="support-bot-banner-action static">100 Credit هدية</span>
                @endauth
            </div>

            @auth
                <div class="support-bot-usage-limits" id="supportBotUsageLimits" aria-label="حدود استخدام AI">
                    <span><b>5س</b><strong id="supportBotLimit5h">—</strong></span>
                    <span><b>7أ</b><strong id="supportBotLimit7d">—</strong></span>
                    <span><b>شهر</b><strong id="supportBotLimitMonth">—</strong></span>
                </div>
            @endauth

            <div class="support-bot-modebar" id="supportBotModeBar">
                <div class="support-bot-mode-group" role="group" aria-label="وضع المساعد">
                    <button type="button" class="support-bot-mode-btn is-active" data-ai-mode="chat">
                        <span>⚡</span><span>سريع</span><b id="supportBotChatCost">1</b>
                    </button>
                    @auth
                        <button type="button" class="support-bot-mode-btn" data-ai-mode="thinking">
                            <span>🧠</span><span>تفكير وتحليل</span><b id="supportBotThinkingCost">3</b>
                        </button>
                        <button type="button" class="support-bot-mode-btn" data-ai-mode="work">
                            <span>🛠</span><span>عمل متقدم</span><b id="supportBotWorkCost">8</b>
                        </button>
                    @endauth
                    <button type="button" class="support-bot-engineering-chip" data-support-prompt="ساعدني في حسابات إنشائية لمشروعي">📐 حسابات إنشائية</button>
                    <button type="button" class="support-bot-engineering-chip" data-support-prompt="اشرح لي متطلبات كود البناء المناسبة لمشروعي">📋 كود البناء</button>
                    <button type="button" class="support-bot-engineering-chip" data-support-prompt="ساعدني في تحليل الكميات وجداول الكميات للمشروع">📊 تحليل كميات</button>
                </div>
                <div class="support-bot-mode-meta">
                    <span id="supportBotModeCost">التكلفة النهائية حسب استهلاك Gemini</span>
                </div>
            </div>
        </header>

        @auth
        <aside id="supportBotHistory" class="support-bot-history" aria-hidden="true">
            <button type="button" id="supportBotHistoryBackdrop" class="support-bot-history-backdrop" aria-label="إغلاق القائمة الجانبية"></button>
            <div class="support-bot-history-drawer">
                <div class="support-bot-history-head">
                    <div>
                        <strong>مركز المساعد الذكي</strong>
                        <span>المحادثات، الاشتراك، الخطط والاستخدام</span>
                    </div>
                    <button type="button" id="supportBotHistoryClose" aria-label="إغلاق القائمة الجانبية">×</button>
                </div>

                <nav class="support-bot-ai-nav" aria-label="إدارة AI">
                    <div class="support-bot-ai-nav-title">حساب AI</div>
                    <div class="support-bot-ai-nav-grid">
                        <a href="{{ route('ai.premium.index') }}#ai-overview" class="support-bot-ai-nav-item"><span>🏠</span><b>نظرة عامة</b></a>
                        <a href="{{ route('ai.premium.index') }}#ai-subscription" class="support-bot-ai-nav-item"><span>⭐</span><b>اشتراك AI</b></a>
                        <a href="{{ route('ai.premium.index') }}#ai-usage" class="support-bot-ai-nav-item"><span>📊</span><b>Usage</b></a>
                        <a href="{{ route('ai.premium.index') }}#ai-plans" class="support-bot-ai-nav-item"><span>💎</span><b>الخطط</b></a>
                        <a href="{{ route('ai.premium.index') }}#ai-credits" class="support-bot-ai-nav-item"><span>➕</span><b>شراء Credits</b></a>
                        <a href="{{ route('ai.premium.index') }}#ai-file-analysis" class="support-bot-ai-nav-item"><span>📄</span><b>تحليل الملفات</b></a>
                        <a href="{{ route('ai.premium.index') }}#ai-orders" class="support-bot-ai-nav-item"><span>🧾</span><b>طلبات الشراء</b></a>
                        @if(auth()->user()->role === 'admin' && Route::has('ai.admin.index'))
                            <a href="{{ route('ai.admin.index') }}" class="support-bot-ai-nav-item admin"><span>⚙️</span><b>إدارة AI</b></a>
                        @endif
                        <button type="button" id="supportBotSettingsBtn" class="support-bot-ai-nav-item as-button"><span>⚙️</span><b>الإعدادات</b></button>
                    </div>
                </nav>

                <div class="support-bot-history-section-title">
                    <span>💬</span><strong>محادثاتك</strong><small>اختر محادثة للمتابعة</small>
                </div>
                <div class="support-bot-history-search">
                    <input id="supportBotHistorySearch" type="search" placeholder="بحث في المحادثات..." autocomplete="off">
                </div>
                <div id="supportBotHistoryList" class="support-bot-history-list">
                    <div class="support-bot-loading">جاري تحميل المحادثات...</div>
                </div>
            </div>
        </aside>

        <aside id="supportBotSettingsPanel" class="support-bot-settings-panel" aria-hidden="true">
            <button type="button" id="supportBotSettingsBackdrop" class="support-bot-settings-backdrop" aria-label="إغلاق الإعدادات"></button>

            <div class="support-bot-settings-dialog" dir="rtl">
                <aside class="support-bot-settings-sidebar">
                    <div class="support-bot-settings-brand">
                        <div class="support-bot-settings-brand-icon">AI</div>
                        <div>
                            <small>ALWALEED AI</small>
                            <strong>إعدادات المساعد</strong>
                        </div>
                    </div>

                    <div class="support-bot-settings-plan-mini">
                        <span>الباقة الحالية</span>
                        <strong data-settings-plan>AI</strong>
                        <small data-settings-credit>جاري تحميل الرصيد...</small>
                    </div>

                    <div class="support-bot-settings-menu">
                        <div class="support-bot-settings-divider">الحساب والتجربة</div>
                        <button type="button" class="support-bot-settings-menu-item is-active" data-settings-section="general"><span class="support-bot-settings-menu-icon">⚙️</span><span>عام</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="account"><span class="support-bot-settings-menu-icon">👤</span><span>الحساب والأمان</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="privacy"><span class="support-bot-settings-menu-icon">🔐</span><span>الخصوصية</span></button>

                        <div class="support-bot-settings-divider">الاشتراك والاستخدام</div>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="billing"><span class="support-bot-settings-menu-icon">💳</span><span>الباقة والفوترة</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="usage"><span class="support-bot-settings-menu-icon">📊</span><span>الاستخدام والحدود</span></button>

                        <div class="support-bot-settings-divider">المساعد الذكي</div>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="capabilities"><span class="support-bot-settings-menu-icon">✨</span><span>القدرات</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="memory"><span class="support-bot-settings-menu-icon">🧠</span><span>الذاكرة</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="reflect"><span class="support-bot-settings-menu-icon">🪞</span><span>تحسين الإجابة</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="focus"><span class="support-bot-settings-menu-icon">🎯</span><span>التركيز</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="code"><span class="support-bot-settings-menu-icon">&lt;/&gt;</span><span>البرمجة</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="cowork"><span class="support-bot-settings-menu-icon">👥</span><span>مساحة العمل</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="chrome"><span class="support-bot-settings-menu-icon">🌐</span><span>سياق الصفحة</span></button>

                        <div class="support-bot-settings-divider">التخصيص والأدوات</div>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="skills"><span class="support-bot-settings-menu-icon">🧩</span><span>المهارات</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="connectors"><span class="support-bot-settings-menu-icon">🔗</span><span>ربط المنصة</span></button>
                        <button type="button" class="support-bot-settings-menu-item" data-settings-section="plugins"><span class="support-bot-settings-menu-icon">🛠</span><span>الأدوات والإضافات</span></button>
                    </div>
                </aside>

                <main class="support-bot-settings-content">
                    <div class="support-bot-settings-content-head">
                        <div>
                            <span class="support-bot-settings-kicker">إعدادات المساعد الذكي</span>
                            <h4 id="supportBotSettingsHeading">عام</h4>
                            <p id="supportBotSettingsSubheading">ملخص حسابك وتجربة استخدام المساعد.</p>
                        </div>
                        <button type="button" id="supportBotSettingsClose" class="support-bot-settings-close" aria-label="إغلاق الإعدادات">×</button>
                    </div>

                    <div class="support-bot-settings-sections">
                        <section class="support-bot-settings-section is-active" data-settings-pane="general">
                            <div class="support-bot-settings-summary-grid">
                                <div class="support-bot-settings-summary-card"><span>الباقة</span><strong data-settings-plan>AI</strong><small>المزايا والحدود حسب اشتراكك الحالي</small></div>
                                <div class="support-bot-settings-summary-card"><span>الرصيد المتاح</span><strong data-settings-credit>—</strong><small>يتحدث تلقائيًا بعد كل استخدام</small></div>
                                <div class="support-bot-settings-summary-card"><span>حد 5 ساعات</span><strong data-settings-limit="five_hours">—</strong><small>نافذة متحركة وليست إعادة ضبط ثابتة</small></div>
                                <div class="support-bot-settings-summary-card"><span>حد 7 أيام</span><strong data-settings-limit="seven_days">—</strong><small>يحمي حسابك من الاستهلاك المفاجئ</small></div>
                            </div>

                            <div class="support-bot-settings-block">
                                <div class="support-bot-settings-block-title">
                                    <div><strong>اللغة</strong><p>اختر لغة واجهة المساعد والإعدادات.</p></div>
                                    <button type="button" id="supportBotLanguageOpen" class="support-bot-settings-action secondary"><span id="supportBotCurrentLanguage">العربية</span><b>تغيير</b></button>
                                </div>
                            </div>

                            <div class="support-bot-settings-block">
                                <div class="support-bot-settings-block-title">
                                    <div><strong>تجربة المساعد</strong><p>واجهة داكنة، حفظ للمحادثات، ملفات، صوت، أوضاع تفكير وعمل متقدم حسب باقتك.</p></div>
                                    <span class="support-bot-settings-status good">مفعّل</span>
                                </div>
                            </div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="account">
                            <div class="support-bot-settings-profile-card">
                                <div class="support-bot-settings-avatar">{{ mb_strtoupper(mb_substr(auth()->user()->name ?? 'U', 0, 1)) }}</div>
                                <div><strong>{{ auth()->user()->name }}</strong><span>{{ auth()->user()->email }}</span></div>
                                <span class="support-bot-settings-status {{ auth()->user()->email_verified_at ? 'good' : 'warn' }}">{{ auth()->user()->email_verified_at ? 'البريد موثق' : 'البريد غير موثق' }}</span>
                            </div>
                            <div class="support-bot-settings-grid-2">
                                <a href="{{ route('profile.edit') }}" class="support-bot-settings-link-card"><span>👤</span><div><strong>الملف الشخصي</strong><small>الاسم، البريد، الهاتف وبيانات الحساب.</small></div><b>←</b></a>
                                <a href="{{ route('profile.password.edit') }}" class="support-bot-settings-link-card"><span>🔑</span><div><strong>كلمة المرور</strong><small>تغيير كلمة المرور وتأمين الوصول للحساب.</small></div><b>←</b></a>
                                <a href="{{ route('profile.security') }}" class="support-bot-settings-link-card"><span>🛡️</span><div><strong>الأمان والتحقق بخطوتين</strong><small>2FA وأجهزة الدخول وإعدادات الحماية.</small></div><b>←</b></a>
                                <a href="{{ route('profile.account-status') }}" class="support-bot-settings-link-card"><span>✅</span><div><strong>حالة الحساب</strong><small>راجع حالة الحساب والتحقق والمتطلبات.</small></div><b>←</b></a>
                            </div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="privacy">
                            <div class="support-bot-settings-notice"><span>🔐</span><div><strong>الخصوصية داخل AlWaleed AI</strong><p>مفاتيح مزودي الذكاء الاصطناعي تبقى على الخادم ولا يتم إرسالها للمتصفح. إعداداتك وملفاتك مرتبطة بحسابك فقط حسب صلاحيات المنصة.</p></div></div>
                            <div class="support-bot-settings-grid-2">
                                <div class="support-bot-settings-feature-card"><span>📎</span><strong>ملفات المحادثة</strong><p>تستخدم فقط لتنفيذ طلبك وتخضع لصلاحيات حسابك.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🧠</span><strong>الذاكرة</strong><p>يمكنك تعطيلها بالكامل من قسم الذاكرة.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🌐</span><strong>سياق الصفحة</strong><p>يمكن إيقاف إرسال معلومات الصفحة الحالية من قسم سياق الصفحة.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🔌</span><strong>ربط المنصة</strong><p>أنت تختار أي أجزاء من بيانات المنصة يسمح للمساعد باستخدامها.</p></div>
                            </div>
                            <a href="{{ route('profile.security') }}" class="support-bot-settings-action">فتح إعدادات الأمان</a>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="billing">
                            <div class="support-bot-settings-plan-card">
                                <div><span>اشتراكك الحالي</span><strong data-settings-plan>AI</strong><small data-settings-credit>—</small></div>
                                <a href="{{ route('ai.premium.index') }}#ai-subscription" class="support-bot-settings-action">إدارة الاشتراك</a>
                            </div>
                            <div class="support-bot-settings-grid-2">
                                <div class="support-bot-settings-feature-card"><span>💳</span><strong>الباقات</strong><p>Free وPlus وPro وBusiness، وكل باقة تفتح أدوات وحدودًا أعلى.</p></div>
                                <div class="support-bot-settings-feature-card"><span>⚡</span><strong>الرصيد الإضافي</strong><p>يزيد استخدام باقتك الحالية ولا يفتح مزايا باقة أعلى.</p></div>
                            </div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="usage">
                            <div class="support-bot-settings-usage-hero">
                                <div><span>الرصيد المتاح الآن</span><strong data-settings-credit>—</strong><small>الاستخدام يُحدّث مباشرة بعد اكتمال كل عملية AI.</small></div>
                                <a href="{{ route('ai.premium.index') }}#ai-usage" class="support-bot-settings-action">السجل الكامل</a>
                            </div>
                            <div class="support-bot-settings-usage-list">
                                <div class="support-bot-settings-usage-row"><div class="support-bot-settings-usage-copy"><strong>آخر 5 ساعات</strong><span data-settings-limit-detail="five_hours">—</span></div><div class="support-bot-settings-progress"><i data-settings-limit-bar="five_hours"></i></div><b data-settings-limit="five_hours">—</b></div>
                                <div class="support-bot-settings-usage-row"><div class="support-bot-settings-usage-copy"><strong>آخر 7 أيام</strong><span data-settings-limit-detail="seven_days">—</span></div><div class="support-bot-settings-progress"><i data-settings-limit-bar="seven_days"></i></div><b data-settings-limit="seven_days">—</b></div>
                                <div class="support-bot-settings-usage-row"><div class="support-bot-settings-usage-copy"><strong>الدورة الشهرية</strong><span data-settings-limit-detail="month">—</span></div><div class="support-bot-settings-progress"><i data-settings-limit-bar="month"></i></div><b data-settings-limit="month">—</b></div>
                            </div>
                            <div class="support-bot-settings-notice compact"><span>ℹ️</span><div><strong>كيف تعمل الحدود؟</strong><p>حدا 5 ساعات و7 أيام متحركان. الرصيد الشهري يتجدد حسب دورة اشتراكك، وليس بالضرورة في أول الشهر.</p></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="capabilities">
                            <div class="support-bot-settings-notice"><span>✨</span><div><strong>قدرات حسابك الحالية</strong><p>القدرات الفعلية تعتمد على باقتك. المزايا غير المتاحة لا يمكن تجاوزها من الواجهة أو الطلب المباشر.</p></div></div>
                            <div id="supportBotCapabilitiesTags" class="support-bot-settings-tags"></div>
                            <div class="support-bot-settings-grid-3">
                                <div class="support-bot-settings-feature-card"><span>💬</span><strong>محادثة</strong><p>أسئلة وإجابات وحفظ سجل المحادثات.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🧠</span><strong>تفكير وتحليل</strong><p>تحليل أعمق حسب مستوى الباقة.</p></div>
                                <div class="support-bot-settings-feature-card"><span>📎</span><strong>ملفات وصور</strong><p>حجم الملف الأقصى تحدده الباقة.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🎙️</span><strong>الصوت</strong><p>إملاء ومحادثة صوتية عندما تكون متاحة.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🛠️</span><strong>عمل متقدم</strong><p>للبرمجة والتحليل والمخرجات المنظمة.</p></div>
                                <div class="support-bot-settings-feature-card"><span>🔗</span><strong>بيانات المنصة</strong><p>مشاريع واستشارات وبيانات مصرح بها فقط.</p></div>
                            </div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="memory">
                            <div class="support-bot-settings-block"><div class="support-bot-settings-block-title"><div><strong>استخدام الذاكرة</strong><p>يسمح للمساعد باستخدام سياق آمن من محادثاتك السابقة عندما يكون ذلك مفيدًا.</p></div><label class="support-bot-settings-switch"><input type="checkbox" id="supportBotMemoryToggle" checked><span></span></label></div></div>
                            <div class="support-bot-settings-block">
                                <strong>ملاحظة شخصية للمساعد</strong><p>أضف تفضيلًا يساعد على تحسين الردود. لا تضع كلمات مرور أو بيانات حساسة.</p>
                                <textarea id="supportBotMemoryNote" class="support-bot-settings-textarea" rows="5" maxlength="2000" placeholder="مثال: أفضل الردود المنظمة والمختصرة، واستخدم العربية في الشرح..."></textarea>
                                <div class="support-bot-settings-inline-actions"><button type="button" id="supportBotMemoryNoteSave" class="support-bot-settings-action">حفظ الملاحظة</button><small>الحد الأقصى 2000 حرف</small></div>
                            </div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="reflect">
                            <div class="support-bot-settings-block"><div class="support-bot-settings-block-title"><div><strong>تحسين الإجابة قبل عرضها</strong><p>يسمح للمساعد بمراجعة الرد وإظهار اقتراحات أو صياغة أوضح عند الحاجة.</p></div><label class="support-bot-settings-switch"><input type="checkbox" id="supportBotReflectToggle" checked><span></span></label></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="focus">
                            <div class="support-bot-settings-block"><div class="support-bot-settings-block-title"><div><strong>وضع التركيز</strong><p>يقلل العناصر الثانوية أثناء المحادثة ويعطي الأولوية للمهمة الحالية.</p></div><label class="support-bot-settings-switch"><input type="checkbox" id="supportBotFocusToggle"><span></span></label></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="code">
                            <div class="support-bot-settings-block"><div class="support-bot-settings-block-title"><div><strong>مساعد البرمجة</strong><p>مراجعة الأكواد، شرح الأخطاء، بناء الملفات واقتراح تعديلات منظمة عندما تطلب ذلك.</p></div><label class="support-bot-settings-switch"><input type="checkbox" id="supportBotCodeToggle" checked><span></span></label></div></div>
                            <div class="support-bot-settings-notice compact"><span>&lt;/&gt;</span><div><strong>حسب الباقة</strong><p>الأدوات المتقدمة مثل Work والتحليل البرمجي الكبير قد تتطلب Pro أو Business.</p></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="cowork">
                            <div class="support-bot-settings-block"><div class="support-bot-settings-block-title"><div><strong>مساحة العمل الجماعي</strong><p>ينظم المساعد الأهداف والخطة والمهام والمخرجات بحيث تكون قابلة للمشاركة والتنفيذ داخل الفريق.</p></div><label class="support-bot-settings-switch"><input type="checkbox" id="supportBotCoworkToggle"><span></span></label></div></div>
                            <div class="support-bot-settings-notice compact"><span>👥</span><div><strong>ميزة Business</strong><p>إذا كانت غير متاحة في باقتك سيطلب النظام الترقية بدل تنفيذها.</p></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="chrome">
                            <div class="support-bot-settings-block"><div class="support-bot-settings-block-title"><div><strong>استخدام سياق الصفحة الحالية</strong><p>يسمح للمساعد بمعرفة اسم الصفحة والمسار وبعض السياق الحالي داخل منصة الوليد فقط، بدون صلاحيات إضافية.</p></div><label class="support-bot-settings-switch"><input type="checkbox" id="supportBotBrowserContextToggle" checked><span></span></label></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="skills">
                            <div class="support-bot-settings-block"><strong>المهارات المتخصصة</strong><p>اختر المهارات التي تريد أن تكون متاحة للمساعد في حسابك.</p><div id="supportBotSkillsList" class="support-bot-settings-catalog"></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="connectors">
                            <div class="support-bot-settings-block"><strong>ربط بيانات منصة الوليد</strong><p>حدد الأجزاء التي يسمح للمساعد باستخدامها كسياق، مثل المشاريع أو الاستشارات أو أجزاء الحساب المصرح بها.</p><div id="supportBotConnectorsList" class="support-bot-settings-catalog"></div></div>
                        </section>

                        <section class="support-bot-settings-section" data-settings-pane="plugins">
                            <div class="support-bot-settings-block"><strong>الأدوات والإضافات</strong><p>تتحكم فعليًا في وظائف مثل الصوت وتحليل الملفات وبعض الأدوات الداخلية.</p><div id="supportBotPluginsList" class="support-bot-settings-catalog"></div></div>
                        </section>
                    </div>
                </main>
            </div>
        </aside>

        <div id="supportBotLanguageModal" class="support-bot-language-modal" aria-hidden="true">
            <button type="button" id="supportBotLanguageBackdrop" class="support-bot-language-backdrop" aria-label="إغلاق نافذة اللغة"></button>
            <div class="support-bot-language-card">
                <div class="support-bot-language-head">
                    <strong>Choose your language</strong>
                    <button type="button" id="supportBotLanguageClose" aria-label="إغلاق نافذة اللغة">×</button>
                </div>
                <div class="support-bot-language-grid">
                    <button type="button" class="support-bot-language-option is-active" data-language-code="ar" data-language-name="العربية"><b>العربية</b><span>Arabic</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="en_US" data-language-name="English (United States)"><b>English (United States)</b><span>English (United States)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="fr_FR" data-language-name="Français (France)"><b>Français (France)</b><span>French (France)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="de_DE" data-language-name="Deutsch (Deutschland)"><b>Deutsch (Deutschland)</b><span>German (Germany)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="hi_IN" data-language-name="हिन्दी (भारत)"><b>हिन्दी (भारत)</b><span>Hindi (India)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="id_ID" data-language-name="Indonesia (Indonesia)"><b>Indonesia (Indonesia)</b><span>Indonesian (Indonesia)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="it_IT" data-language-name="Italiano (Italia)"><b>Italiano (Italia)</b><span>Italian (Italy)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="ja_JP" data-language-name="日本語 (日本)"><b>日本語 (日本)</b><span>Japanese (Japan)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="ko_KR" data-language-name="한국어 (대한민국)"><b>한국어 (대한민국)</b><span>Korean (South Korea)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="pt_BR" data-language-name="Português (Brasil)"><b>Português (Brasil)</b><span>Portuguese (Brazil)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="es_419" data-language-name="Español (Latinoamérica)"><b>Español (Latinoamérica)</b><span>Spanish (Latin America)</span></button>
                    <button type="button" class="support-bot-language-option" data-language-code="es_ES" data-language-name="Español (España)"><b>Español (España)</b><span>Spanish (Spain)</span></button>
                </div>
            </div>
        </div>
        @endauth

        <div id="supportBotVoiceOverlay" class="support-bot-voice-overlay" aria-hidden="true">
            <div class="support-bot-voice-card">
                <button type="button" id="supportBotVoiceClose" class="support-bot-voice-close" aria-label="إنهاء المحادثة الصوتية">×</button>
                <div class="support-bot-voice-orb" id="supportBotVoiceOrb"><span>🎙️</span></div>
                <h4>محادثة صوتية مع المساعد الذكي</h4>
                <p id="supportBotVoiceStatus">اضغط بدء وتحدث بشكل طبيعي</p>
                <div class="support-bot-voice-live-text" id="supportBotVoiceLiveText"></div>
                <div class="support-bot-voice-actions">
                    <button type="button" id="supportBotVoiceStart">بدء الاستماع</button>
                    <button type="button" id="supportBotVoiceEnd" class="danger">إنهاء</button>
                </div>
                <small>التكلفة النهائية تحسب من استهلاك Gemini الفعلي بعد كل طلب.</small>
            </div>
        </div>

        @if($standalone)
        <section id="supportBotHomeHero" class="support-bot-home-hero" aria-label="واجهة مساعد منصة الوليد الهندسية">
            <div class="support-bot-home-orb" aria-hidden="true"><span></span></div>
            <h1>مساعد منصة الوليد الهندسية</h1>
            <p>اسأل، خطط، وأنجز بثقة</p>
            <div class="support-bot-home-links">
                <button type="button" data-support-prompt="حلل لي أحدث اتجاهات إعادة الإعمار بعد النزاعات من منظور هندسي وعملي.">
                    <span class="support-bot-home-arrow">›</span><strong>اتجاهات إعادة الإعمار بعد النزاعات</strong><span class="support-bot-home-link-icon orb">✦</span>
                </button>
                <button type="button" data-support-prompt="ساعدني في صياغة رسالة بريد إلكتروني هندسية احترافية.">
                    <span class="support-bot-home-arrow">›</span><strong>Gmail · تواصل</strong><span class="support-bot-home-link-icon">✉</span>
                </button>
                <button type="button" data-support-prompt="أريد تحليل ملف هندسي؛ ساعدني في تحديد ما أحتاج رفعه وتحليله.">
                    <span class="support-bot-home-arrow">›</span><strong>Google Drive · تواصل</strong><span class="support-bot-home-link-icon">△</span>
                </button>
            </div>
        </section>
        @endif

        <div id="supportBotMessages" class="support-bot-messages">
            <div class="support-bot-loading">جاري تحميل المحادثة...</div>
        </div>

        <div id="supportBotActions" class="support-bot-actions"></div>

        <div id="supportBotSuggestions" class="support-bot-suggestions" aria-label="أسئلة مقترحة">
            <p>أسئلة مقترحة للبدء السريع:</p>
            <div>
                <button type="button" data-support-prompt="احسب لي تسليح كمرة مستمرة واشرح لي خطوات الحساب">📐 حساب تسليح كمرة مستمرة</button>
                <button type="button" data-support-prompt="ما أهم متطلبات كود البناء السعودي التي يجب أن أراعيها؟">📋 متطلبات كود البناء السعودي</button>
                <button type="button" data-support-prompt="أنشئ تقرير حالة المشروع Word وPDF واحفظه في ملفات المشروع">📄 تقرير المشروع</button>
                <button type="button" data-support-prompt="أنشئ BOQ من بيانات المشروع بصيغة Excel">📊 BOQ Generator</button>
                <button type="button" data-support-prompt="جهز عرض سعر فني ومالي Word وPDF">💼 عرض سعر</button>
                <button type="button" data-support-prompt="أنشئ محضر آخر اجتماع Word وPDF">📝 محضر اجتماع</button>
                <button type="button" data-support-prompt="حوّل محضر الاجتماع الأخير إلى مهام للمشروع">✅ محضر → مهام</button>
                <button type="button" data-support-prompt="أنشئ BOQ للمشروع واعتمده داخل المشروع">🛡️ اعتماد BOQ</button>
                <button type="button" data-support-prompt="أنشئ لي ملف Flutter Dart كامل وجاهز للاستبدال">💻 ملف برمجي</button>
                <button type="button" data-support-prompt="جهز لي ZIP ملفات استبدال للكود مع الحفاظ على مسارات المشروع">🗂️ ZIP استبدال</button>
                <button type="button" data-support-prompt="ولد لي صورة واجهة فيلا مودرن بتصميم معماري فاخر">✨ توليد صورة AI</button>
            </div>
        </div>

        <div id="supportBotDropOverlay" class="support-bot-drop-overlay" aria-hidden="true">
            <div><strong>أفلت أي ملف هنا</strong><span>صور، فيديو، صوت، PDF، Office، ملفات برمجية، مضغوطة وأي امتداد آخر. سيُضاف للمحادثة ولن يُرسل حتى تضغط إرسال.</span></div>
        </div>

        <form id="supportBotForm" class="support-bot-form">
            @csrf
            @auth
            <div id="supportBotAttachmentPreview" class="support-bot-attachment-preview d-none" aria-live="polite"></div>
            {{-- AI design services. Shown only for what the server confirmed is available (media_capabilities). --}}
            <div id="supportBotGenModes" class="aw-gen-modes d-none" role="group" aria-label="خدمات التصميم بالذكاء الاصطناعي">
                <button type="button" class="aw-gen-chip d-none" data-gen-mode="image" aria-pressed="false"><span aria-hidden="true">🖼️</span><span class="aw-gen-full">توليد صورة</span><span class="aw-gen-short">صورة</span></button>
                <button type="button" class="aw-gen-chip d-none" data-gen-mode="edit_image" aria-pressed="false"><span aria-hidden="true">🪄</span><span class="aw-gen-full">تحويل / تعديل صورة</span><span class="aw-gen-short">تعديل صورة</span></button>
                <button type="button" class="aw-gen-chip d-none" data-gen-mode="video" aria-pressed="false"><span aria-hidden="true">🎬</span><span class="aw-gen-full">توليد فيديو</span><span class="aw-gen-short">فيديو</span></button>
            </div>
            @endauth
            <div class="support-bot-composer-shell">
                <div class="support-bot-composer-inline">
                    @auth
                        <input id="supportBotFileInput" type="file" hidden>
                        <button type="button" id="supportBotAttach" class="support-bot-attach" title="إرفاق ملف أو مخطط" aria-label="إرفاق ملف أو مخطط">＋</button>
                    @endauth
                    <div class="support-bot-textarea-wrap">
                        <textarea
                            id="supportBotInput"
                            name="message"
                            rows="1"
                            maxlength="5000"
                            placeholder="اسأل أي شيء..."
                            required
                        ></textarea>
                    </div>
                    <div class="support-bot-effort-wrap">
                        <button type="button" id="supportBotEffortBtn" class="support-bot-effort-btn">
                            <span id="supportBotEffortBtnLabel">Fast</span><span>⌄</span>
                        </button>
                        <div id="supportBotEffortPopup" class="support-bot-effort-popup" aria-hidden="true">
                            <div class="support-bot-effort-head">
                                <strong id="supportBotEffortLabel">إجابة سريعة</strong>
                                <small id="supportBotEffortCost">حسب الاستهلاك</small>
                            </div>
                            <div id="supportBotProfileList" class="support-bot-profile-list"></div>
                        </div>
                    </div>
                    <button type="button" id="supportBotVoice" class="support-bot-voice-btn" title="تسجيل صوتي" aria-label="تسجيل صوتي">🎙</button>
                    <button type="submit" id="supportBotSend" class="support-bot-send-btn" aria-label="إرسال">
                        <span class="support-bot-send-arrow">↑</span>
                    </button>
                </div>
            </div>
            <div class="support-bot-mobile-indicator" aria-hidden="true"></div>
        </form>
    </section>
</div>

{{-- Hotfix 9.6.1: render component CSS directly; do not depend on parent @stack --}}
<style>
@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800&display=swap');

html.support-bot-open, html.support-bot-open body { overflow: hidden !important; }
.d-none { display:none !important; }

.support-bot-widget {
    --sb-bg:var(--awl-bg-080d18, #080d18);
    --sb-bg-2:#0b101d;
    --sb-surface:var(--awl-bg-0d1527, #0d1527);
    --sb-card:var(--awl-bg-10192e, #10192e);
    --sb-card-2:#121b2d;
    --sb-border:var(--awl-bd-ffffff-080, rgba(255,255,255,.08));
    --sb-text:var(--awl-fg-f1f5f9, #f1f5f9);
    --sb-muted:var(--awl-fg-94a3b8, #94a3b8);
    --sb-cyan:#06b6d4;
    --sb-blue:#2563eb;
    --sb-emerald:#10b981;
    position:fixed;
    left:24px;
    bottom:24px;
    z-index:9999;
    direction:rtl;
    font-family:'Cairo',Almarai,system-ui,sans-serif;
    color:var(--sb-text);
}
.support-bot-widget *, .support-bot-widget *::before, .support-bot-widget *::after { box-sizing:border-box; }
.support-bot-toggle {
    width:60px;height:60px;border:1px solid rgba(59,130,246,.28);border-radius:18px;
    background:linear-gradient(145deg,var(--awl-bg-123469, #123469),var(--awl-bg-0d1f43, #0d1f43));color:var(--awl-fg-bfdbfe, #bfdbfe);cursor:pointer;
    display:grid;place-items:center;box-shadow:0 16px 36px var(--awl-sh-020617-380, rgba(2,6,23,.38)),0 0 22px rgba(37,99,235,.18);
    position:relative;transition:.18s ease;
}
.support-bot-toggle:hover { transform:translateY(-2px) scale(1.03); }
.support-bot-toggle-icon { font-size:16px;font-weight:900;letter-spacing:.04em; }
.support-bot-unread { position:absolute;top:-5px;right:-5px;min-width:20px;height:20px;border-radius:999px;background:#ef4444;color:var(--awl-fg-ffffff, #fff);font-size:10px;display:grid;place-items:center;border:2px solid var(--awl-bd-080d18, #080d18); }

.support-bot-panel {
    position:absolute;left:0;bottom:76px;width:430px;max-width:calc(100vw - 24px);height:min(760px,calc(100dvh - 110px));
    display:none;flex-direction:column;overflow:hidden;border-radius:0;background:linear-gradient(180deg,var(--awl-bg-0b101d, #0b101d) 0%,var(--awl-bg-0c1424, #0c1424) 44%,var(--awl-bg-080c16, #080c16) 100%);
    border:1px solid var(--sb-border);box-shadow:0 30px 90px var(--awl-sh-000000-480, rgba(0,0,0,.48));isolation:isolate;
}
.support-bot-panel::before,.support-bot-panel::after { content:"";position:absolute;pointer-events:none;border-radius:50%;filter:blur(58px);opacity:.9;z-index:-1; }
.support-bot-panel::before { width:260px;height:260px;right:-100px;top:-110px;background:rgba(37,99,235,.16); }
.support-bot-panel::after { width:230px;height:230px;left:-110px;top:35%;background:rgba(6,182,212,.10); }
.support-bot-panel.is-open { display:flex; }

.support-bot-header { flex:0 0 auto;background:var(--awl-bg-0b101d-920, rgba(11,16,29,.92));backdrop-filter:blur(16px);border-bottom:1px solid var(--awl-bd-ffffff-070, rgba(255,255,255,.07));padding:12px 14px 9px;display:flex;flex-direction:column;gap:10px; }
.support-bot-topline { display:flex;align-items:center;justify-content:space-between;gap:10px; }
.support-bot-close { width:32px;height:32px;min-width:32px;border-radius:999px;border:1px solid var(--awl-bd-ffffff-060, rgba(255,255,255,.06));background:var(--awl-bg-ffffff-055, rgba(255,255,255,.055));color:var(--awl-fg-94a3b8, #94a3b8);display:grid;place-items:center;cursor:pointer;transition:.18s ease;padding:0; }
.support-bot-close:hover { background:var(--awl-bg-ffffff-110, rgba(255,255,255,.11));color:var(--awl-fg-ffffff, #fff); }
.support-bot-close svg { width:16px;height:16px;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round; }
.support-bot-top-actions { display:flex;align-items:center;gap:7px;min-width:0; }
.support-bot-login-link,.support-bot-ghost-btn,.support-bot-account-btn { text-decoration:none;border:0;cursor:pointer;font-family:inherit;font-size:10.5px;font-weight:800;white-space:nowrap;transition:.18s ease; }
.support-bot-login-link { color:var(--awl-fg-cbd5e1, #cbd5e1);padding:6px 8px;border-radius:8px; }
.support-bot-login-link:hover { color:var(--awl-fg-ffffff, #fff);background:var(--awl-bg-ffffff-050, rgba(255,255,255,.05)); }
.support-bot-ghost-btn { display:inline-flex;align-items:center;gap:5px;color:var(--awl-fg-cbd5e1, #cbd5e1);background:var(--awl-bg-ffffff-045, rgba(255,255,255,.045));border:1px solid var(--awl-bd-ffffff-070, rgba(255,255,255,.07));border-radius:10px;padding:7px 9px; }
.support-bot-ghost-btn:hover { background:var(--awl-bg-ffffff-080, rgba(255,255,255,.08));color:var(--awl-fg-ffffff, #fff); }
.support-bot-account-btn { display:inline-flex;align-items:center;gap:6px;color:var(--awl-fg-ffffff, #fff);background:linear-gradient(90deg,#2563eb,#4f46e5);border:1px solid rgba(96,165,250,.22);border-radius:9px;padding:7px 10px;box-shadow:0 5px 14px rgba(30,64,175,.22); }
.support-bot-account-btn:hover { filter:brightness(1.08); }
.support-bot-credit-badge { font:700 9px ui-monospace,SFMono-Regular,Menlo,monospace;background:rgba(96,165,250,.22);padding:1px 4px;border-radius:5px; }

.support-bot-brand-row { display:flex;align-items:center;justify-content:space-between;gap:10px;padding-top:1px; }
.support-bot-brand-wrap { display:flex;align-items:center;gap:10px;min-width:0; }
.support-bot-ai-avatar { position:relative;width:40px;height:40px;min-width:40px;border-radius:12px;padding:1.5px;background:linear-gradient(45deg,#2563eb,#0891b2,#10b981);box-shadow:0 0 20px -3px rgba(37,99,235,.35); }
.support-bot-ai-avatar>div { width:100%;height:100%;border-radius:10px;background:var(--awl-bg-0b1220, #0b1220);display:grid;place-items:center;font-weight:900;font-size:15px;color:var(--awl-fg-7dd3fc, #7dd3fc); }
.support-bot-ai-avatar>div img{width:28px;height:28px;object-fit:contain;filter:drop-shadow(0 4px 8px rgba(37,99,235,.35))}
.support-bot-ai-avatar>span { position:absolute;right:-2px;bottom:-2px;width:12px;height:12px;border-radius:50%;background:#10b981;border:2px solid var(--awl-bd-0b101d, #0b101d); }
.support-bot-brand-copy { min-width:0; }
.support-bot-title-row { display:flex;align-items:center;gap:6px;min-width:0; }
.support-bot-title-row h3 { margin:0;color:var(--awl-fg-ffffff, #fff);font-size:13px;font-weight:800;line-height:1.5;white-space:nowrap;overflow:hidden;text-overflow:ellipsis; }
.support-bot-pro-chip { flex:0 0 auto;font-size:9px;color:var(--awl-fg-67e8f9, #67e8f9);background:rgba(6,182,212,.14);border:1px solid rgba(6,182,212,.2);padding:2px 5px;border-radius:6px; }
.support-bot-brand-copy p { margin:2px 0 0;color:var(--awl-fg-94a3b8, #94a3b8);font-size:10px;display:flex;align-items:center;gap:5px;white-space:nowrap; }
.support-bot-live-dot { width:6px;height:6px;border-radius:50%;background:#34d399;display:inline-block;animation:supportBotSubtlePulse 2.5s infinite ease-in-out; }
@keyframes supportBotSubtlePulse { 50%{opacity:.62;transform:scale(.92)} }
.support-bot-voice-call-btn { flex:0 0 auto;display:inline-flex;align-items:center;gap:5px;border:1px solid rgba(6,182,212,.28);background:var(--awl-bg-083344-400, rgba(8,51,68,.4));color:var(--awl-fg-67e8f9, #67e8f9);border-radius:999px;padding:7px 9px;font-family:inherit;font-size:9.5px;font-weight:700;cursor:pointer;transition:.18s ease; }
.support-bot-voice-call-btn:hover { background:var(--awl-bg-08485b-520, rgba(8,72,91,.52)); }
.support-bot-mic-icon { color:var(--awl-fg-22d3ee, #22d3ee);animation:supportBotSubtlePulse 1.6s infinite ease-in-out; }

.support-bot-account-banner { display:flex;align-items:center;justify-content:space-between;gap:8px;background:linear-gradient(90deg,var(--awl-bg-172554-420, rgba(23,37,84,.42)),var(--awl-bg-0f172a-600, rgba(15,23,42,.6)),var(--awl-bg-172554-420, rgba(23,37,84,.42)));border:1px solid rgba(59,130,246,.14);border-radius:12px;padding:7px 9px;font-size:10px; }
.support-bot-account-state { display:flex;align-items:center;gap:5px;min-width:0;color:var(--awl-fg-cbd5e1, #cbd5e1);white-space:nowrap;overflow:hidden;text-overflow:ellipsis; }
.support-bot-account-state strong { color:var(--awl-fg-7dd3fc, #7dd3fc);font-size:10px;overflow:hidden;text-overflow:ellipsis; }
.support-bot-account-state small { color:#64748b; }
.support-bot-usage-limits { display:flex;gap:6px;align-items:center; }
.support-bot-usage-limits span { flex:1;min-width:0;display:flex;align-items:center;justify-content:center;gap:5px;padding:5px 7px;border-radius:10px;background:var(--awl-bg-081426-820, rgba(8,20,38,.82));border:1px solid var(--awl-bd-ffffff-070, rgba(255,255,255,.07));font-size:9px;color:var(--awl-fg-94a3b8, #94a3b8); }
.support-bot-usage-limits b { color:var(--awl-fg-cbd5e1, #cbd5e1);font-weight:800; }
.support-bot-usage-limits strong { color:var(--awl-fg-67e8f9, #67e8f9);font-weight:900;white-space:nowrap;overflow:hidden;text-overflow:ellipsis; }
.support-bot-alert-icon,.support-bot-info-dot { width:14px;height:14px;min-width:14px;border-radius:50%;display:grid;place-items:center;font-weight:900;font-size:8px; }
.support-bot-alert-icon { color:var(--awl-fg-fbbf24, #fbbf24);background:rgba(245,158,11,.1); }
.support-bot-info-dot { color:var(--awl-fg-93c5fd, #93c5fd);background:rgba(37,99,235,.15);font-size:6px; }
.support-bot-banner-action { text-decoration:none;color:var(--awl-fg-22d3ee, #22d3ee);font-weight:900;background:var(--awl-bg-083344-420, rgba(8,51,68,.42));border:1px solid rgba(6,182,212,.18);padding:4px 7px;border-radius:7px;white-space:nowrap;font-size:9px; }
.support-bot-banner-action.static { cursor:default; }

.support-bot-modebar { display:flex;align-items:center;gap:8px;min-width:0;overflow:hidden; }
.support-bot-mode-group { display:flex;align-items:center;gap:7px;overflow-x:auto;scrollbar-width:none;padding-bottom:1px;flex:1; }
.support-bot-mode-group::-webkit-scrollbar { display:none; }
.support-bot-mode-btn,.support-bot-engineering-chip { flex:0 0 auto;border-radius:999px;font-family:inherit;white-space:nowrap;cursor:pointer;transition:.18s ease; }
.support-bot-mode-btn { display:inline-flex;align-items:center;gap:5px;border:1px solid var(--awl-bd-ffffff-070, rgba(255,255,255,.07));background:var(--awl-bg-ffffff-035, rgba(255,255,255,.035));color:var(--awl-fg-cbd5e1, #cbd5e1);padding:6px 9px;font-size:9.5px;font-weight:800; }
.support-bot-mode-btn b { color:var(--awl-fg-67e8f9, #67e8f9);font-size:9px; }
.support-bot-mode-btn.is-active { color:var(--awl-fg-ffffff, #fff);background:linear-gradient(90deg,#2563eb,#0891b2);border-color:rgba(34,211,238,.42);box-shadow:0 0 18px -4px rgba(37,99,235,.35); }
.support-bot-mode-btn.is-active b { color:var(--awl-fg-fde68a, #fde68a); }
.support-bot-engineering-chip { border:1px solid var(--awl-bd-ffffff-070, rgba(255,255,255,.07));background:var(--awl-bg-ffffff-035, rgba(255,255,255,.035));color:var(--awl-fg-cbd5e1, #cbd5e1);padding:6px 9px;font-size:9.5px;font-weight:700; }
.support-bot-engineering-chip:hover { background:var(--awl-bg-ffffff-075, rgba(255,255,255,.075));color:var(--awl-fg-ffffff, #fff); }
.support-bot-mode-meta { flex:0 0 auto;color:#64748b;font-size:8.5px;white-space:nowrap; }

.support-bot-messages { flex:1 1 auto;min-height:0;overflow-y:auto;padding:14px;background:transparent;scrollbar-width:thin;scrollbar-color:rgba(255,255,255,.12) transparent; }
.support-bot-messages::-webkit-scrollbar { width:4px; }
.support-bot-messages::-webkit-scrollbar-track { background:transparent; }
.support-bot-messages::-webkit-scrollbar-thumb { background:rgba(255,255,255,.12);border-radius:999px; }
.support-bot-loading { text-align:center;color:#64748b;padding:20px 10px;font-size:11px; }
.support-message-row { display:flex;flex-direction:column;margin-bottom:13px;max-width:94%; }
.support-message-row.customer { margin-right:auto;align-items:flex-start; }
.support-message-row.bot,.support-message-row.employee,.support-message-row.admin { margin-left:auto;align-items:flex-start; }
.support-message-row.system { max-width:100%;margin-inline:auto;align-items:center; }
.support-message { width:fit-content;max-width:100%;padding:13px 14px;border-radius:17px;line-height:1.8;font-size:12.5px;word-break:break-word;white-space:pre-wrap;box-shadow:0 10px 24px var(--awl-sh-000000-160, rgba(0,0,0,.16)); }
.support-message-row.customer .support-message { background:linear-gradient(135deg,#2563eb,var(--awl-bg-0f766e, #0f766e));color:var(--awl-fg-ffffff, #fff);border:1px solid rgba(96,165,250,.18);border-top-left-radius:5px; }
.support-message-row.bot .support-message,.support-message-row.employee .support-message,.support-message-row.admin .support-message { background:var(--awl-bg-10192e-960, rgba(16,25,46,.96));color:var(--awl-fg-f1f5f9, #f1f5f9);border:1px solid var(--awl-bd-ffffff-090, rgba(255,255,255,.09));border-top-right-radius:5px;position:relative;overflow:hidden; }
.support-message-row.bot .support-message::before { content:"";position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent,rgba(6,182,212,.45),transparent); }
.support-message-row.system .support-message { max-width:96%;text-align:center;background:var(--awl-bg-78350f-160, rgba(120,53,15,.16));color:var(--awl-fg-fde68a, #fde68a);border:1px solid rgba(245,158,11,.22);font-size:11px;border-radius:13px; }
.support-message-meta { display:block;margin-top:6px;font-size:9px;color:#64748b;opacity:1; }
.support-message-row.customer .support-message-meta { color:var(--awl-fg-ffffff-660, rgba(255,255,255,.66)); }
.support-message-content { white-space:normal; }
.support-message-content p { margin:0 0 8px; }.support-message-content p:last-child{margin-bottom:0}
.support-message-content pre { direction:ltr;text-align:left;overflow:auto;background:var(--awl-bg-071426, #071426);color:var(--awl-fg-e2e8f0, #e2e8f0);padding:10px;border-radius:10px;margin:8px 0;font-size:11px;border:1px solid var(--awl-bd-ffffff-060, rgba(255,255,255,.06)); }
.support-message-content code { direction:ltr;background:var(--awl-bg-0f172a-500, rgba(15,23,42,.5));padding:1px 4px;border-radius:4px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
.support-message-content ul,.support-message-content ol { margin:7px 0;padding-inline-start:22px; }
.support-message-tools { display:flex;gap:4px;margin-top:10px;padding-top:8px;border-top:1px solid var(--awl-bd-ffffff-055, rgba(255,255,255,.055)); }
.support-message-tool { border:0;background:transparent;color:var(--awl-fg-94a3b8, #94a3b8);font-family:inherit;font-size:9.5px;cursor:pointer;padding:4px 6px;border-radius:6px; }
.support-message-tool:hover { background:var(--awl-bg-ffffff-060, rgba(255,255,255,.06));color:var(--awl-fg-ffffff, #fff); }

.support-bot-actions { display:flex;gap:7px;flex-wrap:wrap;padding:0 14px 8px;background:transparent; }
.support-bot-actions:empty { display:none; }
.support-bot-action { border:1px solid rgba(6,182,212,.24);background:var(--awl-bg-0f172a-550, rgba(15,23,42,.55));color:var(--awl-fg-a5f3fc, #a5f3fc);border-radius:999px;padding:7px 11px;cursor:pointer;font-family:inherit;font-size:10px; }
.support-bot-action.primary { color:var(--awl-fg-ffffff, #fff);background:var(--awl-bg-0f766e, #0f766e);border-color:#14b8a6; }.support-bot-action.danger{color:var(--awl-fg-fecaca, #fecaca);border-color:rgba(239,68,68,.35)}
.support-bot-action:disabled { opacity:.55;cursor:not-allowed; }

.support-bot-suggestions { flex:0 0 auto;padding:4px 14px 8px; }
.support-bot-suggestions.is-hidden { display:none; }
.support-bot-suggestions p { margin:0 0 6px;color:#64748b;font-size:9.5px;font-weight:800; }
.support-bot-suggestions>div { display:flex;gap:6px;flex-wrap:wrap; }
.support-bot-suggestions button { border:1px solid var(--awl-bd-ffffff-070, rgba(255,255,255,.07));background:var(--awl-bg-1e293b-550, rgba(30,41,59,.55));color:var(--awl-fg-cbd5e1, #cbd5e1);border-radius:11px;padding:6px 9px;font-family:inherit;font-size:9.5px;cursor:pointer;transition:.18s ease; }
.support-bot-suggestions button:hover { color:var(--awl-fg-ffffff, #fff);background:var(--awl-bg-1e293b-800, rgba(30,41,59,.8)); }

.support-bot-form { flex:0 0 auto;padding:10px 12px 9px;background:var(--awl-bg-0b101e-950, rgba(11,16,30,.95));backdrop-filter:blur(16px);border-top:1px solid var(--awl-bd-ffffff-075, rgba(255,255,255,.075)); }
.support-bot-composer-shell { background:var(--awl-bg-121b2d, #121b2d);border:1px solid var(--awl-bd-ffffff-100, rgba(255,255,255,.1));border-radius:17px;padding:5px;box-shadow:0 16px 34px var(--awl-sh-000000-250, rgba(0,0,0,.25));transition:.18s ease; }
.support-bot-composer-shell:focus-within { border-color:rgba(6,182,212,.5); }
.support-bot-textarea-wrap { padding:2px 5px 4px; }
.support-bot-form textarea { width:100%;min-height:42px;max-height:110px;resize:none;border:0!important;outline:0!important;box-shadow:none!important;background:transparent!important;color:var(--awl-fg-ffffff, #fff)!important;padding:5px 4px;font:400 12px/1.7 'Cairo',sans-serif; }
.support-bot-form textarea::placeholder { color:#64748b; }
.support-bot-composer-toolbar { display:flex;align-items:center;justify-content:space-between;gap:8px;padding:5px 2px 1px;border-top:1px solid var(--awl-bd-ffffff-050, rgba(255,255,255,.05)); }
.support-bot-composer-tools { display:flex;align-items:center;gap:5px; }
.support-bot-voice-btn,.support-bot-attach { width:34px;height:34px;border-radius:11px;border:1px solid rgba(59,130,246,.18);display:grid;place-items:center;padding:0;cursor:pointer;font-size:15px;transition:.18s ease; }
.support-bot-voice-btn { background:rgba(37,99,235,.14);color:var(--awl-fg-60a5fa, #60a5fa); }.support-bot-attach{background:var(--awl-bg-ffffff-040, rgba(255,255,255,.04));color:var(--awl-fg-cbd5e1, #cbd5e1);border-color:var(--awl-bd-ffffff-070, rgba(255,255,255,.07))}
.support-bot-voice-btn:hover,.support-bot-attach:hover { filter:brightness(1.22); }
.support-bot-voice-btn.is-listening { background:rgba(127,29,29,.8);color:var(--awl-fg-fecaca, #fecaca);border-color:var(--awl-bd-f87171-450, rgba(248,113,113,.45));animation:supportBotPulse 1.05s infinite ease-in-out; }
.support-bot-attach.has-file { background:rgba(16,185,129,.14);color:var(--awl-fg-6ee7b7, #6ee7b7);border-color:rgba(16,185,129,.3); }
@keyframes supportBotPulse { 50%{transform:scale(1.06);box-shadow:0 0 0 8px rgba(239,68,68,.08)} }
.support-bot-send-btn { height:34px;border:0;border-radius:11px;padding:0 13px;background:linear-gradient(90deg,#059669,#0d9488,#0891b2);color:var(--awl-fg-ffffff, #fff);font-family:inherit;font-size:10.5px;font-weight:900;display:inline-flex;align-items:center;gap:6px;cursor:pointer;box-shadow:0 0 16px -2px rgba(16,185,129,.3); }
.support-bot-send-btn:hover { filter:brightness(1.08); }.support-bot-send-btn:disabled{opacity:.55;cursor:not-allowed}.support-bot-send-arrow{font-size:14px}
.support-bot-mobile-indicator { display:none;width:128px;height:4px;background:var(--awl-bg-ffffff-180, rgba(255,255,255,.18));border-radius:999px;margin:8px auto 0; }

.support-bot-history { position:absolute;inset:0;z-index:20;display:none;direction:rtl; }
.support-bot-history.is-open { display:block; }
.support-bot-history-backdrop { position:absolute;inset:0;border:0;background:var(--awl-bg-020617-580, rgba(2,6,23,.58));backdrop-filter:blur(3px);cursor:pointer; }
.support-bot-history-drawer { position:absolute;top:0;bottom:0;right:0;width:min(360px,88%);display:flex;flex-direction:column;background:var(--awl-bg-071426, #071426);color:var(--awl-fg-eef6ff, #eef6ff);border-left:1px solid rgba(96,165,250,.16);box-shadow:-22px 0 58px var(--awl-sh-000000-380, rgba(0,0,0,.38));animation:supportBotDrawerIn .2s ease-out; }
@keyframes supportBotDrawerIn { from{transform:translateX(24px);opacity:.4} to{transform:none;opacity:1} }
.support-bot-history-head { display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px;border-bottom:1px solid rgba(96,165,250,.15);background:var(--awl-bg-0a172b, #0a172b); }
.support-bot-history-head div { display:flex;flex-direction:column;gap:3px; }.support-bot-history-head strong{font-size:14px}.support-bot-history-head span{font-size:9.5px;color:var(--awl-fg-8fa8c7, #8fa8c7)}
.support-bot-history-head button { width:32px;height:32px;border:0;border-radius:999px;background:var(--awl-bg-ffffff-050, rgba(255,255,255,.05));color:var(--awl-fg-ffffff, #fff);font-size:23px;cursor:pointer;line-height:1; }
.support-bot-ai-nav { padding:10px 10px 8px;border-bottom:1px solid rgba(96,165,250,.10);background:linear-gradient(180deg,var(--awl-bg-08182d, #08182d),var(--awl-bg-071426, #071426)); }
.support-bot-ai-nav-title { margin:0 2px 7px;color:var(--awl-fg-67e8f9, #67e8f9);font-size:9px;font-weight:900;letter-spacing:.02em; }
.support-bot-ai-nav-grid { display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px; }
.support-bot-ai-nav-item { min-width:0;display:flex;align-items:center;gap:7px;text-decoration:none;color:var(--awl-fg-dbeafe, #dbeafe);background:var(--awl-bg-0d1b31, #0d1b31);border:1px solid rgba(96,165,250,.11);border-radius:11px;padding:8px 9px;transition:.15s ease; }
.support-bot-ai-nav-item:hover { color:var(--awl-fg-ffffff, #fff);background:var(--awl-bg-102847, #102847);border-color:rgba(59,130,246,.42);transform:translateY(-1px); }
.support-bot-ai-nav-item span { width:20px;height:20px;min-width:20px;display:grid;place-items:center;border-radius:7px;background:rgba(37,99,235,.12);font-size:11px; }
.support-bot-ai-nav-item b { min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:9.5px;font-weight:900; }
.support-bot-ai-nav-item.admin { border-color:rgba(168,85,247,.18);background:rgba(88,28,135,.10); }
.support-bot-history-section-title { display:flex;align-items:center;gap:6px;padding:10px 11px 0;color:var(--awl-fg-eef6ff, #eef6ff); }
.support-bot-history-section-title strong { font-size:10.5px; }.support-bot-history-section-title small{margin-inline-start:auto;color:#64748b;font-size:8.5px}.support-bot-history-section-title span{font-size:11px}
.support-bot-history-search { padding:8px 10px 0;background:var(--awl-bg-071426, #071426); }.support-bot-history-search input{width:100%;border:1px solid rgba(96,165,250,.16);background:var(--awl-bg-0b1b31, #0b1b31);color:var(--awl-fg-eef6ff, #eef6ff);border-radius:11px;padding:9px 10px;outline:none;font:inherit;font-size:10.5px}.support-bot-history-search input:focus{border-color:#3b82f6}
.support-bot-history-list { padding:10px;overflow:auto;flex:1; }
.support-bot-history-item { position:relative;width:100%;text-align:right;border:1px solid rgba(96,165,250,.11);background:var(--awl-bg-0d1b31, #0d1b31);color:var(--awl-fg-eef6ff, #eef6ff);border-radius:13px;padding:11px 74px 11px 11px;margin-bottom:8px;cursor:pointer;outline:none;transition:.15s ease; }
.support-bot-history-item:hover,.support-bot-history-item:focus { background:var(--awl-bg-10223d, #10223d);border-color:rgba(96,165,250,.25); }.support-bot-history-item.is-active{border-color:#3b82f6;background:var(--awl-bg-102847, #102847)}.support-bot-history-item strong{display:block;font-size:11px;margin-bottom:4px}.support-bot-history-item span{display:block;color:var(--awl-fg-8fa8c7, #8fa8c7);font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.support-bot-history-item-actions { position:absolute;right:8px;top:8px;display:flex;gap:4px; }.support-bot-history-icon-btn{width:27px;height:27px;border:0;border-radius:8px;background:var(--awl-bg-ffffff-060, rgba(255,255,255,.06));color:var(--awl-fg-9fb5d2, #9fb5d2);cursor:pointer;padding:0;font-size:12px}.support-bot-history-icon-btn:hover{background:rgba(59,130,246,.18);color:var(--awl-fg-ffffff, #fff)}.support-bot-history-icon-btn.danger:hover{background:rgba(239,68,68,.16);color:var(--awl-fg-fca5a5, #fca5a5)}

.support-bot-voice-overlay { position:absolute;inset:0;z-index:24;display:none;align-items:center;justify-content:center;padding:18px;background:var(--awl-bg-020817-910, rgba(2,8,23,.91));backdrop-filter:blur(16px); }
.support-bot-voice-overlay.is-open { display:flex; }.support-bot-voice-card{position:relative;width:min(440px,100%);text-align:center;border:1px solid rgba(96,165,250,.18);border-radius:26px;background:linear-gradient(180deg,var(--awl-bg-0d1b31, #0d1b31),var(--awl-bg-081426, #081426));color:var(--awl-fg-eef6ff, #eef6ff);padding:30px 20px 22px;box-shadow:0 25px 70px var(--awl-sh-000000-400, rgba(0,0,0,.4))}.support-bot-voice-close{position:absolute;top:10px;left:12px;border:0;background:transparent;color:var(--awl-fg-9fb5d2, #9fb5d2);font-size:27px;cursor:pointer}.support-bot-voice-orb{width:118px;height:118px;margin:0 auto 17px;border-radius:50%;display:grid;place-items:center;font-size:38px;background:radial-gradient(circle at 30% 30%,#38bdf8,#2563eb 55%,#312e81);box-shadow:0 0 0 14px rgba(59,130,246,.07),0 25px 60px rgba(37,99,235,.28);transition:.2s ease}.support-bot-voice-orb.is-listening{animation:supportVoiceOrb 1.2s ease-in-out infinite}.support-bot-voice-orb.is-speaking{background:radial-gradient(circle at 30% 30%,#c084fc,#7c3aed 55%,#312e81);animation:supportVoiceOrb .8s ease-in-out infinite}@keyframes supportVoiceOrb{50%{transform:scale(1.08);box-shadow:0 0 0 26px rgba(59,130,246,.06),0 25px 75px rgba(37,99,235,.35)}}.support-bot-voice-card h4{margin:0;font-size:17px}.support-bot-voice-card p{margin:7px 0 0;color:var(--awl-fg-9fb5d2, #9fb5d2);font-size:10px}.support-bot-voice-live-text{min-height:50px;margin:14px 0;padding:11px;border-radius:13px;background:var(--awl-bg-ffffff-040, rgba(255,255,255,.04));color:var(--awl-fg-dbeafe, #dbeafe);font-size:11px;line-height:1.7}.support-bot-voice-actions{display:flex;justify-content:center;gap:7px}.support-bot-voice-actions button{border:0;border-radius:999px;padding:9px 16px;background:#2563eb;color:var(--awl-fg-ffffff, #fff);font-family:inherit;font-weight:900;cursor:pointer}.support-bot-voice-actions button.danger{background:#7f1d1d}.support-bot-voice-card small{display:block;margin-top:12px;color:var(--awl-fg-7087a5, #7087a5);font-size:8.5px}

.support-bot-widget.is-standalone { position:fixed;inset:0;z-index:30;background:var(--awl-bg-080d18, #080d18); }
.support-bot-widget.is-standalone .support-bot-panel { position:fixed;inset:0;width:100%;height:100dvh;max-width:none;max-height:none;border-radius:0;border:0;box-shadow:none; }
.support-bot-widget.is-standalone .support-bot-header { padding-left:max(16px,calc((100vw - 1180px)/2));padding-right:max(16px,calc((100vw - 1180px)/2)); }
.support-bot-widget.is-standalone .support-bot-messages,.support-bot-widget.is-standalone .support-bot-actions,.support-bot-widget.is-standalone .support-bot-suggestions,.support-bot-widget.is-standalone .support-bot-form { padding-left:max(16px,calc((100vw - 900px)/2));padding-right:max(16px,calc((100vw - 900px)/2)); }
.support-bot-widget.is-standalone .support-message-row { max-width:min(86%,790px); }.support-bot-widget.is-standalone .support-bot-history-drawer{width:min(390px,88vw)}

@media (max-width:700px) {
    .support-bot-widget { left:0;right:0;bottom:0; }
    .support-bot-toggle { position:fixed;left:12px;bottom:12px; }
    .support-bot-panel { position:fixed;inset:0;width:100%;height:100dvh;max-width:none;max-height:none;border:0;border-radius:0; }
    .support-bot-header { padding:10px 12px 8px;gap:9px; }
    .support-bot-brand-row { gap:7px; }.support-bot-ai-avatar{width:38px;height:38px;min-width:38px}.support-bot-title-row h3{font-size:12px}.support-bot-pro-chip{font-size:8px}.support-bot-brand-copy p{font-size:9px}
    .support-bot-voice-call-btn { padding:6px 8px;font-size:8.8px; }.support-bot-account-banner{padding:6px 8px;font-size:9.2px}.support-bot-mode-meta{display:none}
    .support-bot-messages { padding:12px; }.support-message-row{max-width:94%}.support-message{font-size:12px;padding:12px 13px}.support-bot-suggestions{padding:3px 12px 7px}.support-bot-suggestions>div{flex-wrap:nowrap;overflow-x:auto;scrollbar-width:none}.support-bot-suggestions>div::-webkit-scrollbar{display:none}.support-bot-suggestions button{flex:0 0 auto}
    .support-bot-form { padding:8px 12px 7px; }.support-bot-mobile-indicator{display:block}.support-bot-history-drawer{width:88%}
    .support-bot-top-actions{gap:5px}.support-bot-account-btn,.support-bot-ghost-btn{padding:6px 7px;font-size:9px}.support-bot-login-link{font-size:9px;padding:5px}
    .support-bot-widget.is-standalone .support-bot-header,.support-bot-widget.is-standalone .support-bot-messages,.support-bot-widget.is-standalone .support-bot-actions,.support-bot-widget.is-standalone .support-bot-suggestions,.support-bot-widget.is-standalone .support-bot-form { padding-left:12px;padding-right:12px; }
}
@media (max-width:390px) {
    .support-bot-top-actions .support-bot-ghost-btn span:last-child{display:none}
    .support-bot-title-row h3{max-width:172px}.support-bot-voice-call-btn span:last-child{display:none}.support-bot-voice-call-btn{width:33px;height:33px;justify-content:center;padding:0}.support-bot-account-state span:not(.support-bot-alert-icon):not(.support-bot-info-dot){max-width:170px;overflow:hidden;text-overflow:ellipsis}.support-bot-banner-action{font-size:8px;padding:4px 5px}
}


/* ===== Phase 9.3 — ChatGPT-like exact assistant layout ===== */
.support-message-row.customer{margin-left:auto!important;margin-right:0!important;align-items:flex-end!important}
.support-message-row.bot,.support-message-row.employee,.support-message-row.admin{margin-right:auto!important;margin-left:0!important;align-items:flex-start!important}
.support-message-row.customer .support-message{background:var(--awl-bg-0f2f5a, #0f2f5a)!important;border-color:rgba(59,130,246,.28)!important;border-top-left-radius:17px!important;border-top-right-radius:5px!important}
.support-message-row.bot .support-message,.support-message-row.employee .support-message,.support-message-row.admin .support-message{background:var(--awl-bg-101a2d, #101a2d)!important;border-color:var(--awl-bd-94a3b8-120, rgba(148,163,184,.12))!important;border-top-right-radius:17px!important;border-top-left-radius:5px!important}

.support-bot-attachment-preview{margin-bottom:8px;animation:supportAttachmentIn .18s ease-out}
@keyframes supportAttachmentIn{from{opacity:0;transform:translateY(5px) scale(.98)}to{opacity:1;transform:none}}
.support-bot-drop-overlay{position:absolute;inset:0;z-index:35;display:none;place-items:center;padding:24px;background:var(--awl-bg-020817-860, rgba(2,8,23,.86));backdrop-filter:blur(10px);border:2px dashed rgba(96,165,250,.7)}
.support-bot-drop-overlay.is-active{display:grid}
.support-bot-drop-overlay>div{max-width:420px;text-align:center;padding:28px;border-radius:22px;background:var(--awl-bg-0b1628, #0b1628);border:1px solid rgba(96,165,250,.28);box-shadow:0 24px 60px var(--awl-sh-000000-350, rgba(0,0,0,.35))}
.support-bot-drop-overlay strong{display:block;color:var(--awl-fg-ffffff, #fff);font-size:20px;margin-bottom:8px}.support-bot-drop-overlay span{display:block;color:var(--awl-fg-9fb2ce, #9fb2ce);font-size:12px;line-height:1.8}
.support-bot-file-preview-card{position:relative;display:flex;align-items:center;gap:10px;padding:9px 38px 9px 10px;border-radius:14px;background:var(--awl-bg-0f1b31, #0f1b31);border:1px solid rgba(96,165,250,.18);overflow:hidden}
.support-bot-file-preview-card>img{width:58px;height:58px;flex:0 0 58px;object-fit:cover;border-radius:10px;border:1px solid var(--awl-bd-ffffff-080, rgba(255,255,255,.08));background:var(--awl-bg-08111f, #08111f)}
.support-bot-file-preview-icon{width:50px;height:50px;flex:0 0 50px;border-radius:12px;display:grid;place-items:center;background:linear-gradient(145deg,#ef4444,#b91c1c);color:var(--awl-fg-ffffff, white);font:900 10px ui-monospace,SFMono-Regular,Menlo,monospace;box-shadow:0 7px 20px rgba(239,68,68,.18)}
.support-bot-file-preview-card.csv .support-bot-file-preview-icon{background:linear-gradient(145deg,#10b981,var(--awl-bg-047857, #047857))}
.support-bot-file-preview-card.text .support-bot-file-preview-icon,.support-bot-file-preview-card.file .support-bot-file-preview-icon{background:linear-gradient(145deg,#3b82f6,#1d4ed8)}
.support-bot-file-preview-info{min-width:0;flex:1;display:flex;flex-direction:column;gap:3px}
.support-bot-file-preview-info strong{font-size:10.5px;color:var(--awl-fg-f8fafc, #f8fafc);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.support-bot-file-preview-info span{font-size:8.5px;color:var(--awl-fg-8fa8c7, #8fa8c7);direction:ltr;text-align:right}
.support-bot-file-preview-progress{height:4px;border-radius:999px;background:var(--awl-bg-94a3b8-160, rgba(148,163,184,.16));overflow:hidden;margin-top:2px}
.support-bot-file-preview-progress i{display:block;height:100%;width:0;background:linear-gradient(90deg,#2563eb,#38bdf8);border-radius:inherit;transition:width .18s ease;box-shadow:0 0 12px rgba(59,130,246,.45)}
.support-bot-file-preview-card.is-uploading .support-bot-file-preview-progress i{min-width:7%;background-size:24px 24px;background-image:linear-gradient(45deg,var(--awl-bg-ffffff-180, rgba(255,255,255,.18)) 25%,transparent 25%,transparent 50%,var(--awl-bg-ffffff-180, rgba(255,255,255,.18)) 50%,var(--awl-bg-ffffff-180, rgba(255,255,255,.18)) 75%,transparent 75%,transparent);animation:supportUploadStripe .7s linear infinite}
@keyframes supportUploadStripe{to{background-position:24px 0}}
.support-bot-file-preview-card.is-done{border-color:rgba(16,185,129,.35)}
.support-bot-file-preview-card.is-done .support-bot-file-preview-progress i{background:#10b981}
.support-bot-file-preview-card.is-error{border-color:rgba(239,68,68,.35)}
.support-bot-file-preview-card.is-error .support-bot-file-preview-progress i{background:#ef4444}
.support-bot-file-preview-remove{position:absolute;top:8px;left:8px;width:24px;height:24px;border:0;border-radius:8px;background:var(--awl-bg-ffffff-070, rgba(255,255,255,.07));color:var(--awl-fg-cbd5e1, #cbd5e1);cursor:pointer;font-size:16px;line-height:1}
.support-bot-file-preview-remove:hover{background:rgba(239,68,68,.18);color:var(--awl-fg-ffffff, #fff)}

.support-message-attachment{margin-top:10px;min-width:min(360px,70vw);max-width:100%;display:flex;align-items:center;gap:10px;padding:8px;border-radius:13px;background:var(--awl-bg-0b172a, #0b172a);border:1px solid rgba(96,165,250,.17);white-space:normal}
.support-message-attachment>img{width:min(310px,64vw);max-height:230px;object-fit:cover;border-radius:11px;border:1px solid var(--awl-bd-ffffff-080, rgba(255,255,255,.08));cursor:zoom-in;background:var(--awl-bg-07111f, #07111f)}
.support-message-attachment.image{display:block;padding:7px}
.support-message-attachment.image .support-message-attachment-info{padding:7px 4px 3px}
.support-message-attachment-icon{width:48px;height:48px;flex:0 0 48px;border-radius:11px;display:grid;place-items:center;background:linear-gradient(145deg,#ef4444,#b91c1c);color:var(--awl-fg-ffffff, #fff);font:900 9px ui-monospace,SFMono-Regular,Menlo,monospace}
.support-message-attachment.csv .support-message-attachment-icon{background:linear-gradient(145deg,#10b981,var(--awl-bg-047857, #047857))}
.support-message-attachment.document .support-message-attachment-icon{background:linear-gradient(145deg,#2563eb,#1d4ed8)}
.support-message-attachment.sheet .support-message-attachment-icon{background:linear-gradient(145deg,#10b981,var(--awl-bg-047857, #047857))}
.support-message-attachment.archive .support-message-attachment-icon{background:linear-gradient(145deg,#8b5cf6,#6d28d9)}
.support-message-attachment.has-download{cursor:pointer;transition:transform .16s ease,border-color .16s ease}
.support-message-attachment.has-download:hover{transform:translateY(-1px);border-color:rgba(96,165,250,.42)}
.support-message-attachment-info{min-width:0;flex:1;display:flex;flex-direction:column;gap:3px}
.support-message-attachment-info strong{font-size:10px;color:var(--awl-fg-f8fafc, #f8fafc);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.support-message-attachment-info span{font-size:8px;color:var(--awl-fg-94a3b8, #94a3b8);direction:ltr;text-align:right}
.support-message-attachment-info .support-message-attachment-state{direction:rtl;text-align:right;color:var(--awl-fg-6ee7b7, #6ee7b7);font-size:8px;font-weight:800}.support-message-attachment.is-error .support-message-attachment-state{color:var(--awl-fg-fca5a5, #fca5a5)}.support-message-attachment.is-done{border-color:rgba(16,185,129,.26)}.support-message-attachment.is-error{border-color:rgba(239,68,68,.30)}
.support-message-attachment-progress{height:4px;background:var(--awl-bg-94a3b8-160, rgba(148,163,184,.16));border-radius:999px;overflow:hidden;margin-top:3px}
.support-message-attachment-progress i{display:block;width:45%;height:100%;border-radius:999px;background:linear-gradient(90deg,#2563eb,#38bdf8);animation:supportMessageUpload 1.1s ease-in-out infinite alternate}
@keyframes supportMessageUpload{to{width:92%}}

.support-bot-ai-nav-item.as-button{font:inherit;text-align:inherit;display:flex;width:100%;background:var(--awl-bg-080f1c-720, rgba(8,15,28,.72))}
.support-bot-settings-panel,.support-bot-language-modal{position:absolute;inset:0;display:none;z-index:60}
.support-bot-settings-panel.is-open,.support-bot-language-modal.is-open{display:block}
.support-bot-settings-backdrop,.support-bot-language-backdrop{position:absolute;inset:0;border:0;background:var(--awl-bg-020617-780, rgba(2,6,23,.78));backdrop-filter:blur(14px)}
.support-bot-settings-dialog{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:min(1180px,calc(100% - 34px));height:min(780px,calc(100% - 34px));display:grid;grid-template-columns:286px minmax(0,1fr);direction:rtl;background:var(--awl-bg-07111f, #07111f);border:1px solid rgba(96,165,250,.16);border-radius:24px;overflow:hidden;box-shadow:0 40px 110px var(--awl-sh-000000-580, rgba(0,0,0,.58))}
.support-bot-settings-sidebar{background:linear-gradient(180deg,var(--awl-bg-091426, #091426) 0%,var(--awl-bg-07101d, #07101d) 100%);padding:20px 14px 16px;border-left:1px solid var(--awl-bd-94a3b8-100, rgba(148,163,184,.10));overflow:auto;scrollbar-width:thin}
.support-bot-settings-brand{display:flex;align-items:center;gap:11px;padding:2px 8px 12px}.support-bot-settings-brand-icon{width:42px;height:42px;border-radius:14px;display:grid;place-items:center;background:linear-gradient(135deg,#2563eb,#0ea5e9);box-shadow:0 10px 28px rgba(37,99,235,.2);font-size:13px;font-weight:1000;color:var(--awl-fg-ffffff, #fff)}.support-bot-settings-brand small{display:block;color:var(--awl-fg-5fa9ff, #5fa9ff);font-size:9px;font-weight:900;letter-spacing:.12em}.support-bot-settings-brand strong{display:block;color:var(--awl-fg-f8fbff, #f8fbff);font-size:19px;font-weight:1000;margin-top:2px}
.support-bot-settings-plan-mini{margin:4px 6px 14px;padding:12px 13px;border:1px solid rgba(96,165,250,.13);background:rgba(37,99,235,.07);border-radius:15px}.support-bot-settings-plan-mini span,.support-bot-settings-plan-mini small{display:block;color:var(--awl-fg-8090aa, #8090aa);font-size:9px}.support-bot-settings-plan-mini strong{display:block;margin:3px 0;color:var(--awl-fg-dbeafe, #dbeafe);font-size:13px;font-weight:1000}
.support-bot-settings-menu{display:flex;flex-direction:column;gap:3px}.support-bot-settings-divider{margin:12px 10px 5px;color:#55647b;font-size:9px;font-weight:1000}.support-bot-settings-menu-item{width:100%;display:flex;align-items:center;gap:10px;border:1px solid transparent;background:transparent;color:var(--awl-fg-c7d2e3, #c7d2e3);padding:9px 10px;border-radius:11px;font:800 11px/1.2 inherit;cursor:pointer;text-align:right;transition:.18s}.support-bot-settings-menu-item:hover{background:var(--awl-bg-ffffff-040, rgba(255,255,255,.04));color:var(--awl-fg-ffffff, #fff)}.support-bot-settings-menu-item.is-active{background:linear-gradient(90deg,rgba(37,99,235,.16),rgba(14,165,233,.08));border-color:rgba(96,165,250,.18);color:var(--awl-fg-ffffff, #fff)}.support-bot-settings-menu-item span:not(.support-bot-settings-menu-icon){flex:1}.support-bot-settings-menu-icon{width:24px;height:24px;display:grid;place-items:center;border-radius:8px;background:var(--awl-bg-ffffff-035, rgba(255,255,255,.035));font-size:11px;color:var(--awl-fg-93c5fd, #93c5fd)}
.support-bot-settings-content{min-width:0;padding:24px 26px 28px;background:radial-gradient(circle at 15% 5%,rgba(37,99,235,.06),transparent 32%),var(--awl-bg-09111e, #09111e);overflow:auto;scrollbar-width:thin}.support-bot-settings-content-head{position:sticky;top:-24px;z-index:3;display:flex;align-items:flex-start;justify-content:space-between;gap:14px;margin:-24px -26px 22px;padding:22px 26px 17px;background:var(--awl-bg-09111e-940, rgba(9,17,30,.94));border-bottom:1px solid var(--awl-bd-94a3b8-080, rgba(148,163,184,.08));backdrop-filter:blur(16px)}.support-bot-settings-kicker{display:block;color:var(--awl-fg-60a5fa, #60a5fa);font-size:9px;font-weight:1000;margin-bottom:4px}.support-bot-settings-content-head h4{margin:0;color:var(--awl-fg-ffffff, #fff);font-size:24px;font-weight:1000}.support-bot-settings-content-head p{margin:5px 0 0;color:var(--awl-fg-7f8da4, #7f8da4);font-size:11px;line-height:1.7}.support-bot-settings-close{width:38px;height:38px;flex:0 0 38px;border-radius:12px;border:1px solid var(--awl-bd-94a3b8-120, rgba(148,163,184,.12));background:var(--awl-bg-0d1828, #0d1828);color:var(--awl-fg-dbe6f7, #dbe6f7);font-size:22px;line-height:1;cursor:pointer}.support-bot-settings-close:hover{background:var(--awl-bg-132238, #132238)}
.support-bot-settings-section{display:none;max-width:860px;margin:0 auto}.support-bot-settings-section.is-active{display:block;animation:supportSettingsFade .16s ease}@keyframes supportSettingsFade{from{opacity:.35;transform:translateY(4px)}to{opacity:1;transform:none}}
.support-bot-settings-summary-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:14px}.support-bot-settings-summary-card{min-height:110px;padding:15px;border:1px solid var(--awl-bd-94a3b8-100, rgba(148,163,184,.10));background:linear-gradient(145deg,var(--awl-bg-0d1c33-900, rgba(13,28,51,.9)),var(--awl-bg-081425-900, rgba(8,20,37,.9)));border-radius:16px}.support-bot-settings-summary-card span{display:block;color:var(--awl-fg-7d8ca4, #7d8ca4);font-size:9px;font-weight:900}.support-bot-settings-summary-card strong{display:block;margin:8px 0 4px;color:var(--awl-fg-f8fbff, #f8fbff);font-size:18px;font-weight:1000;overflow-wrap:anywhere}.support-bot-settings-summary-card small{display:block;color:#62728b;font-size:8.5px;line-height:1.55}
.support-bot-settings-block,.support-bot-settings-plan-card,.support-bot-settings-profile-card,.support-bot-settings-usage-hero,.support-bot-settings-notice{border:1px solid rgba(148,163,184,.10);background:rgba(8,20,37,.78);border-radius:17px;padding:16px 17px;margin-bottom:12px}.support-bot-settings-block-title,.support-bot-settings-plan-card,.support-bot-settings-profile-card,.support-bot-settings-usage-hero{display:flex;align-items:center;justify-content:space-between;gap:14px}.support-bot-settings-block strong,.support-bot-settings-plan-card strong,.support-bot-settings-profile-card strong,.support-bot-settings-usage-hero strong{color:#f6f9ff;font-size:13px;font-weight:1000}.support-bot-settings-block p,.support-bot-settings-plan-card p,.support-bot-settings-profile-card p,.support-bot-settings-usage-hero p{margin:4px 0 0;color:#8290a6;font-size:10px;line-height:1.75}
.support-bot-settings-action{text-decoration:none;border:0;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:7px;background:linear-gradient(135deg,#2563eb,#1d4ed8);color:var(--awl-fg-ffffff, #fff);padding:9px 13px;border-radius:10px;font-weight:900;font-size:10px;white-space:nowrap}.support-bot-settings-action.secondary{background:var(--awl-bg-0d1b2f, #0d1b2f);border:1px solid rgba(96,165,250,.14)}.support-bot-settings-action:hover{filter:brightness(1.08)}
.support-bot-settings-status{display:inline-flex;align-items:center;padding:6px 9px;border-radius:999px;font-size:9px;font-weight:1000;white-space:nowrap}.support-bot-settings-status.good{color:var(--awl-fg-6ee7b7, #6ee7b7);background:rgba(16,185,129,.10);border:1px solid rgba(16,185,129,.16)}.support-bot-settings-status.warn{color:var(--awl-fg-fcd34d, #fcd34d);background:rgba(245,158,11,.09);border:1px solid rgba(245,158,11,.15)}
.support-bot-settings-profile-card{justify-content:flex-start}.support-bot-settings-profile-card>div:nth-child(2){min-width:0;flex:1}.support-bot-settings-profile-card span:not(.support-bot-settings-status){display:block;margin-top:3px;color:var(--awl-fg-7c8aa0, #7c8aa0);font-size:10px;overflow-wrap:anywhere}.support-bot-settings-avatar{width:46px;height:46px;flex:0 0 46px;display:grid;place-items:center;border-radius:14px;background:linear-gradient(135deg,#1d4ed8,#0284c7);font-size:18px;font-weight:1000;color:var(--awl-fg-ffffff, #fff)}
.support-bot-settings-grid-2,.support-bot-settings-grid-3{display:grid;gap:10px;margin-bottom:12px}.support-bot-settings-grid-2{grid-template-columns:repeat(2,minmax(0,1fr))}.support-bot-settings-grid-3{grid-template-columns:repeat(3,minmax(0,1fr))}
.support-bot-settings-link-card,.support-bot-settings-feature-card{min-width:0;display:flex;align-items:center;gap:11px;text-decoration:none;padding:14px;border:1px solid var(--awl-bd-94a3b8-100, rgba(148,163,184,.10));background:var(--awl-bg-081425-640, rgba(8,20,37,.64));border-radius:15px;color:var(--awl-fg-ffffff, #fff)}.support-bot-settings-link-card:hover{border-color:rgba(96,165,250,.22);background:rgba(37,99,235,.06)}.support-bot-settings-link-card>span,.support-bot-settings-feature-card>span{width:34px;height:34px;flex:0 0 34px;display:grid;place-items:center;border-radius:10px;background:var(--awl-bg-0d1c31, #0d1c31)}.support-bot-settings-link-card>div{min-width:0;flex:1}.support-bot-settings-link-card strong,.support-bot-settings-feature-card strong{display:block;color:var(--awl-fg-f2f6fc, #f2f6fc);font-size:11px;font-weight:1000}.support-bot-settings-link-card small,.support-bot-settings-feature-card p{display:block;margin:3px 0 0;color:var(--awl-fg-738198, #738198);font-size:9px;line-height:1.55}.support-bot-settings-link-card>b{color:var(--awl-fg-60a5fa, #60a5fa)}.support-bot-settings-feature-card{display:block}.support-bot-settings-feature-card>span{margin-bottom:9px}.support-bot-settings-feature-card p{font-size:9.5px}
.support-bot-settings-notice{display:flex;align-items:flex-start;gap:12px;background:rgba(37,99,235,.05);border-color:rgba(96,165,250,.13)}.support-bot-settings-notice.compact{padding:13px 14px}.support-bot-settings-notice>span{width:35px;height:35px;flex:0 0 35px;display:grid;place-items:center;border-radius:11px;background:rgba(37,99,235,.09)}.support-bot-settings-notice strong{display:block;color:var(--awl-fg-dbeafe, #dbeafe);font-size:11px}.support-bot-settings-notice p{margin:3px 0 0;color:var(--awl-fg-7e8da5, #7e8da5);font-size:9.5px;line-height:1.75}
.support-bot-settings-plan-card>div,.support-bot-settings-usage-hero>div{min-width:0}.support-bot-settings-plan-card span,.support-bot-settings-usage-hero span{display:block;color:#77869d;font-size:9px}.support-bot-settings-plan-card strong,.support-bot-settings-usage-hero strong{display:block;margin:4px 0;font-size:22px;color:#dbeafe}.support-bot-settings-plan-card small,.support-bot-settings-usage-hero small{display:block;color:#687891;font-size:9px}
.support-bot-settings-usage-list{display:flex;flex-direction:column;gap:9px;margin-bottom:12px}.support-bot-settings-usage-row{display:grid;grid-template-columns:180px minmax(120px,1fr) 90px;align-items:center;gap:13px;padding:14px 15px;border:1px solid var(--awl-bd-94a3b8-100, rgba(148,163,184,.10));background:var(--awl-bg-081425-640, rgba(8,20,37,.64));border-radius:15px}.support-bot-settings-usage-copy strong{display:block;color:var(--awl-fg-f4f7fb, #f4f7fb);font-size:11px}.support-bot-settings-usage-copy span{display:block;margin-top:3px;color:#66758c;font-size:9px}.support-bot-settings-usage-row>b{font-size:11px;color:var(--awl-fg-cfe1ff, #cfe1ff);text-align:left}.support-bot-settings-progress{height:7px;border-radius:999px;background:var(--awl-bg-0d1b2d, #0d1b2d);overflow:hidden}.support-bot-settings-progress i{display:block;width:0;height:100%;border-radius:999px;background:linear-gradient(90deg,#2563eb,#38bdf8);transition:width .28s ease}
.support-bot-settings-tags{display:flex;flex-wrap:wrap;gap:7px;margin:0 0 12px}.support-bot-settings-tags span{padding:7px 10px;border-radius:999px;border:1px solid rgba(96,165,250,.15);background:var(--awl-bg-0b1729, #0b1729);color:var(--awl-fg-cfe1ff, #cfe1ff);font-size:9px;font-weight:900}
.support-bot-settings-catalog{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;margin-top:14px}.support-bot-settings-catalog-item{display:flex;align-items:flex-start;gap:9px;padding:12px;border:1px solid var(--awl-bd-94a3b8-110, rgba(148,163,184,.11));border-radius:13px;background:var(--awl-bg-0a1627, #0a1627);color:var(--awl-fg-ffffff, #fff);cursor:pointer}.support-bot-settings-catalog-item input{margin-top:3px;accent-color:#2563eb}.support-bot-settings-catalog-item b{display:block;font-size:10px}.support-bot-settings-catalog-item small{display:block;margin-top:3px;color:var(--awl-fg-718098, #718098);font-size:8.5px;line-height:1.55}.support-bot-settings-textarea{width:100%;margin:12px 0 9px;border:1px solid var(--awl-bd-94a3b8-140, rgba(148,163,184,.14));background:var(--awl-bg-071323, #071323);color:var(--awl-fg-ffffff, #fff);border-radius:13px;padding:12px;resize:vertical;outline:none;font:inherit;font-size:11px;line-height:1.7}.support-bot-settings-textarea:focus{border-color:#3b82f6;box-shadow:0 0 0 3px rgba(59,130,246,.07)}.support-bot-settings-inline-actions{display:flex;align-items:center;gap:10px}.support-bot-settings-inline-actions small{color:#617089;font-size:8.5px}
.support-bot-settings-switch{position:relative;width:48px;height:28px;display:inline-block;flex:0 0 48px}.support-bot-settings-switch input{position:absolute;opacity:0}.support-bot-settings-switch span{position:absolute;inset:0;border-radius:999px;background:var(--awl-bg-263348, #263348);transition:.2s}.support-bot-settings-switch span::after{content:'';position:absolute;top:4px;right:4px;width:20px;height:20px;border-radius:50%;background:var(--awl-bg-ffffff, #fff);transition:.2s}.support-bot-settings-switch input:checked + span{background:#2563eb}.support-bot-settings-switch input:checked + span::after{transform:translateX(-20px)}
@media (max-width:980px){.support-bot-settings-dialog{width:calc(100% - 20px);height:calc(100% - 20px);grid-template-columns:240px minmax(0,1fr)}.support-bot-settings-summary-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.support-bot-settings-grid-3{grid-template-columns:repeat(2,minmax(0,1fr))}.support-bot-settings-usage-row{grid-template-columns:150px 1fr 78px}}
@media (max-width:720px){.support-bot-settings-dialog{width:100%;height:100%;border-radius:0;border:0;grid-template-columns:1fr;grid-template-rows:auto minmax(0,1fr)}.support-bot-settings-sidebar{max-height:235px;border-left:0;border-bottom:1px solid var(--awl-bd-94a3b8-100, rgba(148,163,184,.10));padding:12px}.support-bot-settings-brand{padding-bottom:6px}.support-bot-settings-brand strong{font-size:16px}.support-bot-settings-plan-mini{display:none}.support-bot-settings-menu{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:4px}.support-bot-settings-divider{grid-column:1/-1;margin:7px 7px 2px}.support-bot-settings-menu-item{padding:8px 9px}.support-bot-settings-content{padding:18px 13px 24px}.support-bot-settings-content-head{top:-18px;margin:-18px -13px 15px;padding:15px 13px 12px}.support-bot-settings-content-head h4{font-size:20px}.support-bot-settings-summary-grid,.support-bot-settings-grid-2,.support-bot-settings-grid-3{grid-template-columns:1fr 1fr}.support-bot-settings-usage-row{grid-template-columns:1fr 74px}.support-bot-settings-progress{grid-column:1/-1;grid-row:2}.support-bot-settings-block-title,.support-bot-settings-plan-card,.support-bot-settings-profile-card,.support-bot-settings-usage-hero{align-items:flex-start;flex-wrap:wrap}}
@media (max-width:480px){.support-bot-settings-summary-grid,.support-bot-settings-grid-2,.support-bot-settings-grid-3{grid-template-columns:1fr}.support-bot-settings-catalog{grid-template-columns:1fr}.support-bot-settings-sidebar{max-height:220px}.support-bot-settings-menu-item{font-size:10px}.support-bot-settings-content{padding-left:11px;padding-right:11px}.support-bot-settings-usage-row{grid-template-columns:1fr 62px}.support-bot-settings-profile-card .support-bot-settings-status{width:100%;justify-content:center}}

/* Emergency layout guard: keeps the assistant isolated from page/theme CSS. */
.support-bot-widget,.support-bot-widget *{box-sizing:border-box}
.support-bot-widget img{max-width:100%;height:auto}
.support-bot-widget button,.support-bot-widget input,.support-bot-widget textarea,.support-bot-widget select{font:inherit}
.support-bot-panel{font-size:14px;line-height:1.5}
.support-bot-widget:not(.is-standalone) .support-bot-panel{max-width:min(430px,calc(100vw - 24px));max-height:min(760px,calc(100dvh - 24px))}
.support-bot-widget.is-standalone .support-bot-panel{max-width:none!important;max-height:none!important}
.support-message-attachment.image{max-width:min(420px,78vw)!important;overflow:hidden}
.support-message-attachment.image>img{display:block;width:100%!important;max-width:100%!important;max-height:340px!important;object-fit:contain!important}
.support-bot-ai-avatar img{display:block;width:100%;height:100%;object-fit:contain}

/* Desktop: persistent ChatGPT-like sidebar on the left */
@media (min-width: 980px){
  .support-bot-widget.is-standalone .support-bot-panel{padding-left:292px;background:linear-gradient(180deg,var(--awl-bg-07101d, #07101d) 0%,var(--awl-bg-081425, #081425) 55%,var(--awl-bg-07101d, #07101d) 100%)}
  .support-bot-widget.is-standalone .support-bot-history{display:block!important;pointer-events:auto;left:0;right:auto;width:292px;z-index:25;background:var(--awl-bg-071426, #071426);border-right:1px solid rgba(96,165,250,.12)}
  .support-bot-widget.is-standalone .support-bot-history-backdrop{display:none!important}
  .support-bot-widget.is-standalone .support-bot-history-drawer{position:absolute!important;left:0!important;right:auto!important;top:0!important;bottom:0!important;width:292px!important;transform:none!important;animation:none!important;box-shadow:none!important;border-left:0!important;border-right:1px solid rgba(96,165,250,.12);background:linear-gradient(180deg,var(--awl-bg-071426, #071426),var(--awl-bg-06101f, #06101f))}
  .support-bot-widget.is-standalone .support-bot-history-head{padding:16px 14px 12px;background:var(--awl-bg-071426, #071426)}
  .support-bot-widget.is-standalone .support-bot-history-head button{display:none}
  .support-bot-widget.is-standalone .support-bot-ai-nav-grid{grid-template-columns:1fr;gap:4px}
  .support-bot-widget.is-standalone .support-bot-ai-nav-item{background:transparent;border-color:transparent;padding:8px 9px}
  .support-bot-widget.is-standalone .support-bot-ai-nav-item:hover{background:var(--awl-bg-0d1b31, #0d1b31);border-color:rgba(96,165,250,.12);transform:none}
  .support-bot-widget.is-standalone .support-bot-history-list{padding:8px 10px 110px}
  .support-bot-widget.is-standalone .support-bot-history-item{padding:9px 62px 9px 9px;border-color:transparent;background:transparent;border-radius:10px;margin-bottom:3px}
  .support-bot-widget.is-standalone .support-bot-history-item:hover,.support-bot-widget.is-standalone .support-bot-history-item.is-active{background:var(--awl-bg-0d1b31, #0d1b31);border-color:rgba(96,165,250,.12)}
  .support-bot-widget.is-standalone .support-bot-header{padding:12px 28px 10px;border-bottom-color:rgba(96,165,250,.12);background:var(--awl-bg-06101f-940, rgba(6,16,31,.94))}
  .support-bot-widget.is-standalone .support-bot-top-actions #supportBotHistoryBtn{display:none}
  .support-bot-widget.is-standalone .support-bot-messages{padding:24px max(26px,calc((100vw - 292px - 920px)/2));}
  .support-bot-widget.is-standalone .support-bot-actions,.support-bot-widget.is-standalone .support-bot-suggestions,.support-bot-widget.is-standalone .support-bot-form{padding-left:max(26px,calc((100vw - 292px - 920px)/2));padding-right:max(26px,calc((100vw - 292px - 920px)/2))}
  .support-bot-widget.is-standalone .support-message-row{max-width:min(78%,760px)}
  .support-bot-widget.is-standalone .support-message{font-size:13px;padding:13px 15px}
  .support-bot-widget.is-standalone .support-bot-form{padding-top:10px;padding-bottom:13px;background:var(--awl-bg-060e1c-970, rgba(6,14,28,.97))}
}

@media (max-width:979px){
  .support-bot-history-drawer{right:auto!important;left:0!important;border-left:0!important;border-right:1px solid rgba(96,165,250,.16)!important;box-shadow:22px 0 58px var(--awl-sh-000000-380, rgba(0,0,0,.38))!important}
  @keyframes supportBotDrawerIn{from{transform:translateX(-24px);opacity:.4}to{transform:none;opacity:1}}
}

@media (max-width:700px){
  .support-bot-header{padding-top:max(10px,env(safe-area-inset-top));}
  .support-bot-account-banner{display:none}
  .support-bot-brand-row{padding-top:1px}
  .support-bot-modebar{padding-top:1px}
  .support-bot-engineering-chip{display:none}
  .support-bot-messages{padding-top:16px;padding-bottom:20px}
  .support-message-row{max-width:92%}
  .support-message-attachment{min-width:min(300px,76vw)}
  .support-message-attachment>img{width:min(280px,72vw)}
  .support-bot-form{padding-bottom:max(8px,env(safe-area-inset-bottom))}
}


/* ===== Phase 9.7 — ChatGPT-like composer ===== */
.support-bot-modebar{display:none!important}
.support-bot-widget.is-standalone .support-bot-panel{background:var(--awl-bg-101010, #101010)!important}
.support-bot-widget.is-standalone .support-bot-header{background:var(--awl-bg-101010, #101010)!important;border-bottom-color:var(--awl-bd-ffffff-060, rgba(255,255,255,.06))!important}
.support-bot-widget.is-standalone .support-message-row.customer .support-message{background:var(--awl-bg-2f2f2f, #2f2f2f)!important;border-color:transparent!important;box-shadow:none!important;border-radius:20px!important}
.support-bot-widget.is-standalone .support-message-row.bot .support-message,
.support-bot-widget.is-standalone .support-message-row.employee .support-message,
.support-bot-widget.is-standalone .support-message-row.admin .support-message{background:transparent!important;border-color:transparent!important;box-shadow:none!important}
.support-bot-widget.is-standalone .support-bot-form{background:var(--awl-bg-080808, #080808)!important}
.support-bot-composer-shell{position:relative;background:var(--awl-bg-262a31, #262a31)!important;border:1px solid rgba(37,99,235,.18)!important;border-radius:28px!important;padding:8px 10px!important;box-shadow:0 16px 34px var(--awl-sh-000000-280, rgba(0,0,0,.28))!important}
.support-bot-composer-shell:focus-within{border-color:rgba(96,165,250,.34)!important}
.support-bot-composer-inline{display:flex;align-items:center;gap:8px;direction:ltr}
.support-bot-textarea-wrap{flex:1;min-width:0;padding:0!important}
.support-bot-form textarea{font-size:14px!important;min-height:42px!important;max-height:120px!important;color:var(--awl-fg-ffffff, #fff)!important;background:transparent!important;padding:10px 4px 8px!important;line-height:1.45!important}
.support-bot-voice-btn,.support-bot-attach{width:36px!important;height:36px!important;border-radius:999px!important;background:transparent!important;border:0!important;color:var(--awl-fg-e8e8e8, #e8e8e8)!important;font-size:18px!important;flex:0 0 auto}
.support-bot-voice-btn.is-listening{background:var(--awl-bg-17345f, #17345f)!important;color:var(--awl-fg-9bd2ff, #9bd2ff)!important}
.support-bot-effort-wrap{position:relative;flex:0 0 auto}
.support-bot-effort-btn{height:36px;border:0;border-radius:999px;background:var(--awl-bg-343941, #343941);color:var(--awl-fg-d9dee6, #d9dee6);padding:0 13px;display:inline-flex;align-items:center;gap:4px;font:600 12px 'Cairo',sans-serif;cursor:pointer}
.support-bot-effort-popup{position:absolute;right:0;bottom:46px;width:260px;padding:12px 14px 10px;border-radius:22px;background:var(--awl-bg-20252d, #20252d);border:1px solid var(--awl-bd-ffffff-080, rgba(255,255,255,.08));box-shadow:0 22px 48px var(--awl-sh-000000-450, rgba(0,0,0,.45));display:none;z-index:35;direction:ltr}
.support-bot-effort-popup.is-open{display:block}
.support-bot-effort-head{display:flex;align-items:center;justify-content:space-between;gap:10px;color:var(--awl-fg-ffffff, #fff);margin-bottom:5px}.support-bot-effort-head strong{font-size:15px}.support-bot-effort-head small{font-size:10px;color:var(--awl-fg-a6a6a6, #a6a6a6)}
.support-bot-effort-control{display:flex;align-items:center;gap:7px}.support-bot-effort-control input{width:100%;accent-color:#3b82f6}.support-bot-effort-control span{font-size:14px;opacity:.65}
.support-bot-send-btn{width:40px!important;height:40px!important;border-radius:999px!important;padding:0!important;background:linear-gradient(135deg,#4c8dff,#2f67ff)!important;display:grid!important;place-items:center!important;box-shadow:none!important;flex:0 0 auto}
.support-bot-send-arrow{font-size:21px!important;font-weight:700;line-height:1}
@media(max-width:700px){.support-bot-effort-popup{width:min(260px,72vw)}.support-bot-effort-btn{padding:0 11px;font-size:11.5px}.support-bot-composer-shell{padding:8px!important}}

/* ===== AlWaleed AI Home 2026-09-13 ===== */
.support-bot-widget.is-standalone .support-bot-panel{background:radial-gradient(circle at 50% 34%,rgba(37,99,235,.12),transparent 28rem),linear-gradient(180deg,var(--awl-bg-020814, #020814) 0%,var(--awl-bg-041020, #041020) 52%,var(--awl-bg-020814, #020814) 100%)!important}
.support-bot-widget.is-standalone .support-bot-header{background:transparent!important;border:0!important;padding:18px 24px 6px!important}
.support-bot-widget.is-standalone .support-bot-topline,
.support-bot-widget.is-standalone .support-bot-brand-row,
.support-bot-widget.is-standalone .support-bot-account-banner{display:none!important}
.support-bot-minimal-top{display:none}.support-bot-widget.is-standalone .support-bot-minimal-top{display:grid;grid-template-columns:52px minmax(210px,320px) 52px;align-items:center;justify-content:center;gap:12px;width:min(100%,760px);margin:0 auto;direction:ltr}
.support-bot-home-spacer{width:48px;height:48px}.support-bot-home-menu{width:48px;height:48px;border-radius:999px;border:1px solid rgba(59,130,246,.45);background:var(--awl-bg-0a1830-820, rgba(10,24,48,.82));display:grid;place-content:center;gap:4px;cursor:pointer;box-shadow:0 0 22px rgba(37,99,235,.15)}
.support-bot-home-menu span{display:block;width:20px;height:2px;border-radius:3px;background:var(--awl-bg-e5eef9, #e5eef9)}.support-bot-home-tabs{height:50px;padding:3px;display:grid;grid-template-columns:1fr 1fr;border-radius:28px;background:var(--awl-bg-0a1830-850, rgba(10,24,48,.85));border:1px solid rgba(96,165,250,.32);box-shadow:0 0 26px rgba(37,99,235,.12)}
.support-bot-home-tab{border:1px solid transparent;border-radius:24px;background:transparent;color:var(--awl-fg-9fb1cb, #9fb1cb);font:700 15px 'Cairo',sans-serif;cursor:pointer;transition:.18s ease}.support-bot-home-tab.is-active{color:var(--awl-fg-ffffff, #fff);border-color:#2fa8ff;background:rgba(29,78,216,.32);box-shadow:0 0 22px rgba(59,130,246,.35)}
.support-bot-widget.is-standalone .support-bot-home-hero{flex:1;min-height:0;overflow:auto;display:flex;flex-direction:column;align-items:center;padding:68px 28px 40px;color:#fff}.support-bot-widget.is-standalone:not(.is-home) .support-bot-home-hero{display:none!important}
.support-bot-home-orb{width:68px;height:68px;border-radius:999px;background:radial-gradient(circle at 32% 28%,var(--awl-bg-f7fbff, #f7fbff) 0 8%,#64dcff 32%,#5b6fff 67%,#d97bff 100%);border:1px solid var(--awl-bd-bfe7ff-800, rgba(191,231,255,.8));box-shadow:0 0 24px rgba(56,189,248,.7),0 0 58px rgba(37,99,235,.55);display:grid;place-items:center}.support-bot-home-orb span{width:24px;height:24px;border-radius:999px;background:linear-gradient(135deg,#8df3ff,#6b5cff);box-shadow:inset 0 0 12px rgba(255,255,255,.5)}
.support-bot-home-hero h1{margin:28px 0 7px;font-size:clamp(24px,3vw,34px);line-height:1.25;font-weight:900;text-align:center}.support-bot-home-hero>p{margin:0;color:#90a9cc;font-size:15px}.support-bot-home-links{width:min(720px,100%);margin-top:clamp(72px,11vh,120px);display:grid;gap:10px}.support-bot-home-links button{width:100%;border:0;background:transparent;color:var(--awl-fg-f1f5f9, #f1f5f9);display:grid;grid-template-columns:40px 1fr 40px;align-items:center;gap:15px;padding:10px 2px;border-radius:18px;cursor:pointer;direction:ltr}.support-bot-home-links button:hover{background:rgba(59,130,246,.06)}.support-bot-home-links strong{font-size:15px;font-weight:500;text-align:right;direction:rtl}.support-bot-home-arrow,.support-bot-home-link-icon{width:36px;height:36px;border-radius:999px;display:grid;place-items:center;background:var(--awl-bg-10213a, #10213a);color:var(--awl-fg-e5eef9, #e5eef9);font-size:25px}.support-bot-home-link-icon{font-size:17px;color:var(--awl-fg-7dd3fc, #7dd3fc);border:1px solid rgba(56,189,248,.22);background:var(--awl-bg-0a1830, #0a1830)}.support-bot-home-link-icon.orb{box-shadow:0 0 15px rgba(37,99,235,.3)}
.support-bot-widget.is-standalone.is-home .support-bot-messages{display:none!important}.support-bot-widget.is-standalone.is-home .support-bot-actions{display:none!important}.support-bot-widget.is-standalone .support-bot-suggestions{display:none!important}
.support-bot-widget.is-standalone .support-bot-form{background:linear-gradient(180deg,var(--awl-bg-020814-000, rgba(2,8,20,0)),var(--awl-bg-020814, #020814) 34%)!important;padding-top:18px!important}.support-bot-widget.is-standalone .support-bot-composer-shell{background:var(--awl-bg-0d1f38-880, rgba(13,31,56,.88))!important;border:1px solid rgba(59,130,246,.48)!important;box-shadow:0 0 28px rgba(37,99,235,.13)!important}.support-bot-widget.is-standalone .support-bot-form textarea::placeholder{color:var(--awl-fg-8195b3, #8195b3)!important}
@media(max-width:700px){.support-bot-widget.is-standalone .support-bot-header{padding:14px 14px 4px!important}.support-bot-widget.is-standalone .support-bot-minimal-top{grid-template-columns:46px minmax(185px,1fr) 46px;gap:8px}.support-bot-home-menu,.support-bot-home-spacer{width:44px;height:44px}.support-bot-home-tabs{height:44px}.support-bot-home-tab{font-size:13px}.support-bot-widget.is-standalone .support-bot-home-hero{padding:56px 18px 26px}.support-bot-home-orb{width:60px;height:60px}.support-bot-home-hero h1{font-size:23px}.support-bot-home-links{margin-top:74px}.support-bot-home-links strong{font-size:13px}.support-bot-home-links{gap:6px}}
@media(min-width:980px){.support-bot-widget.is-standalone .support-bot-history{display:none!important;inset:0!important;width:auto!important;background:transparent!important}.support-bot-widget.is-standalone .support-bot-history.is-open{display:block!important}.support-bot-widget.is-standalone .support-bot-history-backdrop{display:block!important;background:var(--awl-bg-020814-520, rgba(2,8,20,.52))!important;backdrop-filter:blur(5px)}.support-bot-widget.is-standalone .support-bot-history-drawer{width:min(360px,88vw)!important;box-shadow:24px 0 68px var(--awl-sh-000000-450, rgba(0,0,0,.45))!important}.support-bot-widget.is-standalone .support-bot-history-head button{display:grid!important}}


/* ===== 2026-09-13 Direct Chat responsive layout ===== */
.support-bot-widget.is-standalone .support-bot-panel{background:linear-gradient(180deg,var(--awl-bg-020814, #020814) 0%,var(--awl-bg-06142a, #06142a) 55%,var(--awl-bg-020814, #020814) 100%)!important}
.support-bot-widget.is-standalone:not(.is-home) .support-bot-messages{display:block!important;flex:1!important;min-height:0!important}
.support-bot-widget.is-standalone .support-message-row.customer .support-message{background:linear-gradient(135deg,#164c8f,var(--awl-bg-123b73, #123b73))!important;border:1px solid rgba(59,130,246,.24)!important;color:var(--awl-fg-ffffff, #fff)!important;border-radius:18px!important}
.support-bot-widget.is-standalone .support-message-row.bot .support-message{color:var(--awl-fg-e7edf8, #e7edf8)!important}
.support-bot-widget.is-standalone .support-bot-form{background:linear-gradient(180deg,var(--awl-bg-020814-000, rgba(2,8,20,0)),var(--awl-bg-020814, #020814) 34%)!important}

@media (max-width: 700px){
  html.support-bot-open,html.support-bot-open body{overflow:hidden!important;height:100dvh!important}
  .support-bot-widget.is-standalone .support-bot-panel{height:100dvh!important;min-height:100dvh!important;overflow:hidden!important;padding:0!important}
  .support-bot-widget.is-standalone .support-bot-header{flex:0 0 auto!important;padding:max(8px,env(safe-area-inset-top)) 24px 10px!important;background:var(--awl-bg-020814, #020814)!important;border-bottom:1px solid rgba(37,99,235,.18)!important}
  .support-bot-widget.is-standalone .support-bot-minimal-top{display:grid!important;grid-template-columns:40px minmax(0,1fr)!important;gap:14px!important;width:100%!important;max-width:none!important;justify-content:stretch!important}
  .support-bot-widget.is-standalone .support-bot-home-spacer{display:none!important}
  .support-bot-widget.is-standalone .support-bot-home-menu{width:40px!important;height:40px!important;grid-column:1!important;grid-row:1!important}
  .support-bot-widget.is-standalone .support-bot-home-tabs{height:40px!important;grid-column:2!important;grid-row:1!important;max-width:none!important}
  .support-bot-widget.is-standalone .support-bot-home-tab{font-size:13px!important}
  .support-bot-widget.is-standalone .support-bot-messages{padding:22px 28px 18px!important;overscroll-behavior:contain!important;scroll-behavior:auto!important}
  .support-bot-widget.is-standalone .support-message-row{max-width:94%!important;margin-bottom:18px!important}
  .support-bot-widget.is-standalone .support-message-row.customer{margin-left:auto!important}
  .support-bot-widget.is-standalone .support-message-row.customer .support-message{max-width:88%!important;margin-left:auto!important;padding:11px 14px!important}
  .support-bot-widget.is-standalone .support-message-row.bot .support-message{max-width:100%!important;padding:6px 2px!important;background:transparent!important}
  .support-bot-widget.is-standalone .support-message-content{font-size:13px!important;line-height:1.85!important}
  .support-bot-widget.is-standalone .support-bot-form{flex:0 0 auto!important;padding:10px 24px max(14px,env(safe-area-inset-bottom))!important}
  .support-bot-widget.is-standalone .support-bot-composer-shell{min-height:58px!important;border-radius:28px!important;padding:8px 10px!important;background:var(--awl-bg-0b1e38-960, rgba(11,30,56,.96))!important;border-color:rgba(59,130,246,.62)!important;box-shadow:0 0 28px rgba(37,99,235,.13)!important}
  .support-bot-widget.is-standalone .support-bot-form textarea{font-size:13px!important;min-height:40px!important}
  .support-bot-widget.is-standalone .support-bot-send-btn{width:40px!important;height:40px!important}
  .support-bot-widget.is-standalone .support-bot-attach{width:36px!important;height:36px!important}
}

@media (min-width: 980px){
  .support-bot-widget.is-standalone .support-bot-panel{padding-left:274px!important;overflow:hidden!important;background:var(--awl-bg-05070b, #05070b)!important}
  .support-bot-widget.is-standalone .support-bot-header{height:0!important;min-height:0!important;padding:0!important;border:0!important;overflow:hidden!important}
  .support-bot-widget.is-standalone .support-bot-minimal-top{display:none!important}
  .support-bot-widget.is-standalone .support-bot-history{display:block!important;pointer-events:auto!important;position:absolute!important;left:0!important;right:auto!important;top:0!important;bottom:0!important;width:274px!important;z-index:25!important;background:var(--awl-bg-080b11, #080b11)!important}
  .support-bot-widget.is-standalone .support-bot-history-backdrop{display:none!important}
  .support-bot-widget.is-standalone .support-bot-history-drawer{display:flex!important;flex-direction:column!important;position:absolute!important;left:0!important;right:auto!important;top:0!important;bottom:0!important;width:274px!important;transform:none!important;border:0!important;border-right:1px solid var(--awl-bd-ffffff-080, rgba(255,255,255,.08))!important;border-radius:0!important;background:var(--awl-bg-080b11, #080b11)!important;box-shadow:none!important}
  .support-bot-widget.is-standalone .support-bot-history-head{padding:18px 14px 12px!important;background:var(--awl-bg-080b11, #080b11)!important}
  .support-bot-widget.is-standalone .support-bot-history-head button{display:none!important}
  .support-bot-widget.is-standalone .support-bot-ai-nav-grid{grid-template-columns:1fr!important;gap:3px!important}
  .support-bot-widget.is-standalone .support-bot-ai-nav-item{background:transparent!important;border-color:transparent!important;padding:9px 10px!important}
  .support-bot-widget.is-standalone .support-bot-ai-nav-item:hover{background:var(--awl-bg-17191d, #17191d)!important;transform:none!important}
  .support-bot-widget.is-standalone .support-bot-history-list{padding-bottom:90px!important}
  .support-bot-widget.is-standalone .support-bot-history-item{background:transparent!important;border-color:transparent!important;border-radius:9px!important;margin-bottom:2px!important}
  .support-bot-widget.is-standalone .support-bot-history-item:hover,.support-bot-widget.is-standalone .support-bot-history-item.is-active{background:var(--awl-bg-17191d, #17191d)!important}
  .support-bot-widget.is-standalone .support-bot-messages{width:min(860px,calc(100vw - 330px))!important;margin:0 auto!important;padding:46px 28px 30px!important}
  .support-bot-widget.is-standalone .support-bot-form{width:min(860px,calc(100vw - 330px))!important;margin:0 auto!important;padding:10px 0 24px!important;background:var(--awl-bg-05070b, #05070b)!important}
  .support-bot-widget.is-standalone .support-bot-composer-shell{background:var(--awl-bg-232323, #232323)!important;border-color:var(--awl-bd-343434, #343434)!important;box-shadow:none!important}
  .support-bot-widget.is-standalone .support-message-row.customer .support-message{background:var(--awl-bg-17447e, #17447e)!important}
  .support-bot-widget.is-standalone .support-message-row.bot .support-message{background:transparent!important}
}


/* ===== 2026-09-13 Unified AI UI: navy mobile + ChatGPT-like desktop ===== */
.support-bot-widget.is-standalone,
.support-bot-widget.is-standalone .support-bot-panel{
  --aw-bg:var(--awl-bg-020814, #020814);
  --aw-bg-2:#041020;
  --aw-sidebar:#06101f;
  --aw-sidebar-hover:#0c1b31;
  --aw-card:var(--awl-bg-0b1e38, #0b1e38);
  --aw-border:rgba(59,130,246,.34);
  --aw-border-soft:var(--awl-bd-94a3b8-120, rgba(148,163,184,.12));
  --aw-text:var(--awl-fg-f3f7ff, #f3f7ff);
  --aw-muted:var(--awl-fg-8da3c1, #8da3c1);
  --aw-blue:#3b82f6;
  --aw-blue-2:#2563eb;
  background:
    radial-gradient(circle at 50% -12%,rgba(37,99,235,.10),transparent 34rem),
    linear-gradient(180deg,var(--aw-bg) 0%,var(--aw-bg-2) 52%,var(--aw-bg) 100%)!important;
  color:var(--aw-text)!important;
}
.support-bot-widget.is-standalone .support-message-content{
  color:var(--awl-fg-edf4ff, #edf4ff)!important;
}
.support-bot-widget.is-standalone .support-message-row.customer .support-message{
  background:linear-gradient(135deg,var(--awl-bg-123a6d, #123a6d),var(--awl-bg-0f315f, #0f315f))!important;
  border:1px solid rgba(59,130,246,.28)!important;
  color:var(--awl-fg-ffffff, #fff)!important;
  box-shadow:0 10px 30px var(--awl-sh-000000-100, rgba(0,0,0,.10))!important;
}
.support-bot-widget.is-standalone .support-message-row.bot .support-message{
  background:transparent!important;
  border:0!important;
  box-shadow:none!important;
  color:var(--awl-fg-edf4ff, #edf4ff)!important;
}
.support-bot-widget.is-standalone .support-message-tool{
  color:var(--awl-fg-91a6c3, #91a6c3)!important;
}
.support-bot-widget.is-standalone .support-message-tool:hover{
  color:var(--awl-fg-d9e8ff, #d9e8ff)!important;
  background:rgba(59,130,246,.08)!important;
}
.support-bot-widget.is-standalone .support-bot-form{
  background:linear-gradient(180deg,var(--awl-bg-020814-000, rgba(2,8,20,0)),var(--awl-bg-020814-940, rgba(2,8,20,.94)) 26%,var(--awl-bg-020814, #020814) 48%)!important;
}
.support-bot-widget.is-standalone .support-bot-composer-shell{
  background:var(--awl-bg-091c34-960, rgba(9,28,52,.96))!important;
  border:1px solid rgba(59,130,246,.60)!important;
  box-shadow:0 0 30px rgba(37,99,235,.11),0 18px 42px var(--awl-sh-000000-180, rgba(0,0,0,.18))!important;
}
.support-bot-widget.is-standalone .support-bot-composer-shell:focus-within{
  border-color:rgba(96,165,250,.88)!important;
  box-shadow:0 0 0 3px rgba(59,130,246,.08),0 0 34px rgba(37,99,235,.14)!important;
}
.support-bot-widget.is-standalone .support-bot-form textarea{
  color:var(--awl-fg-f8fbff, #f8fbff)!important;
}
.support-bot-widget.is-standalone .support-bot-form textarea::placeholder{
  color:var(--awl-fg-8297b6, #8297b6)!important;
}

/* Phone/tablet: same compact top bar as the supplied mobile design */
@media (max-width:979px){
  .support-bot-widget.is-standalone .support-bot-panel{
    padding:0!important;
    min-height:100dvh!important;
    height:100dvh!important;
    overflow:hidden!important;
  }
  .support-bot-widget.is-standalone .support-bot-header{
    display:block!important;
    height:auto!important;
    min-height:0!important;
    overflow:visible!important;
    padding:max(10px,env(safe-area-inset-top)) 16px 10px!important;
    background:var(--awl-bg-020814, #020814)!important;
    border-bottom:1px solid rgba(37,99,235,.20)!important;
  }
  .support-bot-widget.is-standalone .support-bot-minimal-top{
    display:grid!important;
    grid-template-columns:42px minmax(0,1fr)!important;
    align-items:center!important;
    gap:10px!important;
    width:100%!important;
    max-width:none!important;
    margin:0!important;
  }
  .support-bot-widget.is-standalone .support-bot-home-spacer{
    display:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-home-menu{
    grid-column:1!important;
    grid-row:1!important;
    width:42px!important;
    height:42px!important;
    border-radius:999px!important;
    background:var(--awl-bg-07162b, #07162b)!important;
    border:1px solid rgba(59,130,246,.68)!important;
    color:var(--awl-fg-e8f1ff, #e8f1ff)!important;
  }
  .support-bot-widget.is-standalone .support-bot-home-tabs{
    grid-column:2!important;
    grid-row:1!important;
    width:100%!important;
    max-width:none!important;
    height:42px!important;
    margin:0!important;
    padding:3px!important;
    background:var(--awl-bg-07162b, #07162b)!important;
    border:1px solid rgba(59,130,246,.54)!important;
    border-radius:24px!important;
  }
  .support-bot-widget.is-standalone .support-bot-home-tab{
    min-width:0!important;
    font-size:13px!important;
    color:var(--awl-fg-91a5c1, #91a5c1)!important;
  }
  .support-bot-widget.is-standalone .support-bot-home-tab.is-active{
    color:var(--awl-fg-ffffff, #fff)!important;
    background:linear-gradient(180deg,var(--awl-bg-17467e, #17467e),var(--awl-bg-10335f, #10335f))!important;
    border-color:#4291ff!important;
    box-shadow:0 0 18px rgba(59,130,246,.28)!important;
  }
  .support-bot-widget.is-standalone .support-bot-account-banner,
  .support-bot-widget.is-standalone .support-bot-modebar,
  .support-bot-widget.is-standalone .support-bot-brand,
  .support-bot-widget.is-standalone .support-bot-voice-call-btn{
    display:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-messages{
    flex:1!important;
    min-height:0!important;
    padding:20px 22px 18px!important;
    overscroll-behavior-y:contain!important;
    scroll-behavior:auto!important;
  }
  .support-bot-widget.is-standalone .support-message-row{
    max-width:96%!important;
    margin-bottom:18px!important;
  }
  .support-bot-widget.is-standalone .support-message-row.customer{
    margin-left:auto!important;
  }
  .support-bot-widget.is-standalone .support-message-row.customer .support-message{
    max-width:88%!important;
    margin-left:auto!important;
    padding:10px 14px!important;
    border-radius:18px!important;
  }
  .support-bot-widget.is-standalone .support-message-row.bot .support-message{
    max-width:100%!important;
    padding:6px 0!important;
  }
  .support-bot-widget.is-standalone .support-message-content{
    font-size:13.5px!important;
    line-height:1.85!important;
  }
  .support-bot-widget.is-standalone .support-bot-form{
    flex:0 0 auto!important;
    width:100%!important;
    margin:0!important;
    padding:9px 14px max(13px,env(safe-area-inset-bottom))!important;
  }
  .support-bot-widget.is-standalone .support-bot-composer-shell{
    width:100%!important;
    min-height:58px!important;
    border-radius:30px!important;
    padding:8px 10px!important;
  }
}

/* Desktop: ChatGPT-like workspace, same navy/blue palette */
@media (min-width:980px){
  .support-bot-widget.is-standalone .support-bot-panel{
    padding-left:280px!important;
    overflow:hidden!important;
    background:
      radial-gradient(circle at 66% 5%,rgba(37,99,235,.07),transparent 34rem),
      var(--awl-bg-020814, #020814)!important;
  }
  .support-bot-widget.is-standalone .support-bot-header{
    height:0!important;
    min-height:0!important;
    padding:0!important;
    border:0!important;
    overflow:hidden!important;
  }
  .support-bot-widget.is-standalone .support-bot-minimal-top{
    display:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-history{
    display:block!important;
    pointer-events:auto!important;
    position:absolute!important;
    inset:0 auto 0 0!important;
    width:280px!important;
    z-index:25!important;
    background:var(--aw-sidebar)!important;
    border-right:1px solid var(--awl-bd-94a3b8-100, rgba(148,163,184,.10))!important;
  }
  .support-bot-widget.is-standalone .support-bot-history-backdrop{
    display:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-history-drawer{
    display:flex!important;
    flex-direction:column!important;
    position:absolute!important;
    inset:0 auto 0 0!important;
    width:280px!important;
    transform:none!important;
    border:0!important;
    border-radius:0!important;
    background:var(--aw-sidebar)!important;
    box-shadow:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-history-head{
    padding:18px 14px 12px!important;
    background:var(--aw-sidebar)!important;
  }
  .support-bot-widget.is-standalone .support-bot-history-head button{
    display:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-ai-nav-grid{
    grid-template-columns:1fr!important;
    gap:3px!important;
  }
  .support-bot-widget.is-standalone .support-bot-ai-nav-item,
  .support-bot-widget.is-standalone .support-bot-history-item{
    background:transparent!important;
    border-color:transparent!important;
    border-radius:10px!important;
  }
  .support-bot-widget.is-standalone .support-bot-ai-nav-item:hover,
  .support-bot-widget.is-standalone .support-bot-history-item:hover,
  .support-bot-widget.is-standalone .support-bot-history-item.is-active{
    background:var(--aw-sidebar-hover)!important;
    transform:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-messages{
    width:min(880px,calc(100vw - 350px))!important;
    margin:0 auto!important;
    padding:52px 28px 34px!important;
    overscroll-behavior-y:contain!important;
  }
  .support-bot-widget.is-standalone .support-bot-form{
    width:min(880px,calc(100vw - 350px))!important;
    margin:0 auto!important;
    padding:10px 0 24px!important;
    background:linear-gradient(180deg,var(--awl-bg-020814-000, rgba(2,8,20,0)),var(--awl-bg-020814, #020814) 35%)!important;
  }
  .support-bot-widget.is-standalone .support-bot-composer-shell{
    background:var(--awl-bg-0b1e38, #0b1e38)!important;
    border-color:rgba(59,130,246,.46)!important;
    box-shadow:0 14px 38px var(--awl-sh-000000-200, rgba(0,0,0,.20))!important;
  }
  .support-bot-widget.is-standalone .support-message-row.customer .support-message{
    background:var(--awl-bg-123866, #123866)!important;
  }
}


/* ===== Mobile menu stability fix 2026-09-13 ===== */
@media (max-width:979px){
  .support-bot-widget.is-standalone .support-bot-home-menu{
    flex:0 0 42px!important;
    min-width:42px!important;
    max-width:42px!important;
    width:42px!important;
    min-height:42px!important;
    max-height:42px!important;
    height:42px!important;
    padding:0!important;
    place-content:center!important;
    overflow:hidden!important;
    transform:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-home-menu span{
    flex:0 0 auto!important;
    display:block!important;
    width:18px!important;
    min-width:18px!important;
    max-width:18px!important;
    height:2px!important;
    min-height:2px!important;
    max-height:2px!important;
    margin:0!important;
    padding:0!important;
    transform:none!important;
  }
  .support-bot-widget.is-standalone .support-bot-history-drawer{
    width:min(310px,calc(100vw - 52px))!important;
    min-width:0!important;
    max-width:310px!important;
    right:auto!important;
    left:0!important;
    box-sizing:border-box!important;
  }
  .support-bot-widget.is-standalone .support-bot-history.is-open{
    width:100%!important;
    max-width:100vw!important;
    overflow:hidden!important;
  }
}



/* V6 — secure AI approval cards (meeting tasks + BOQ only). */
.support-ai-action-card{margin-top:12px;border:1px solid rgba(59,130,246,.28);border-radius:16px;background:var(--awl-bg-0f172a-380, rgba(15,23,42,.38));overflow:hidden;direction:rtl}
html:not(.dark) .support-ai-action-card{background:var(--awl-bg-f8fbff, #f8fbff);border-color:var(--awl-bd-cbdcf4, #cbdcf4)}
.support-ai-action-head{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px 13px;border-bottom:1px solid var(--awl-bd-94a3b8-180, rgba(148,163,184,.18))}
.support-ai-action-title{font-weight:800;font-size:13px;color:var(--awl-fg-e5e7eb, #e5e7eb)}.support-ai-action-status{font-size:10px;font-weight:800;padding:4px 8px;border-radius:999px;background:rgba(245,158,11,.14);color:var(--awl-fg-fbbf24, #fbbf24)}
html:not(.dark) .support-ai-action-title{color:#17253c}html:not(.dark) .support-ai-action-status{color:#92400e;background:#fef3c7}
.support-ai-action-body{padding:12px 13px;max-height:360px;overflow:auto}.support-ai-action-summary{font-size:12px;line-height:1.65;color:var(--awl-fg-cbd5e1, #cbd5e1);margin-bottom:9px}html:not(.dark) .support-ai-action-summary{color:#475569}
.support-ai-action-row{padding:8px 9px;margin:6px 0;border:1px solid var(--awl-bd-94a3b8-160, rgba(148,163,184,.16));border-radius:11px;background:var(--awl-bg-ffffff-025, rgba(255,255,255,.025));font-size:11.5px;line-height:1.6;color:var(--awl-fg-d4d4d8, #d4d4d8)}html:not(.dark) .support-ai-action-row{background:var(--awl-bg-ffffff, #fff);color:#334155;border-color:var(--awl-bd-dbe6f3, #dbe6f3)}
.support-ai-action-row strong{color:inherit}.support-ai-action-section{font-size:11px;font-weight:800;margin:10px 0 5px;color:var(--awl-fg-93c5fd, #93c5fd)}html:not(.dark) .support-ai-action-section{color:#1d4ed8}
.support-ai-action-warning{padding:7px 9px;margin:5px 0;border-radius:9px;background:rgba(245,158,11,.10);color:var(--awl-fg-fcd34d, #fcd34d);font-size:11px;line-height:1.55}html:not(.dark) .support-ai-action-warning{background:var(--awl-bg-fffbeb, #fffbeb);color:#92400e}
.support-ai-action-actions{display:flex;flex-wrap:wrap;gap:8px;padding:11px 13px;border-top:1px solid var(--awl-bd-94a3b8-180, rgba(148,163,184,.18))}
.support-ai-action-btn{border:0;border-radius:10px;padding:8px 12px;font-size:11px;font-weight:800;cursor:pointer}.support-ai-action-btn:disabled{opacity:.5;cursor:not-allowed}
.support-ai-action-btn.confirm{background:#2563eb;color:var(--awl-fg-ffffff, #fff)}.support-ai-action-btn.edit{background:var(--awl-bg-94a3b8-160, rgba(148,163,184,.16));color:var(--awl-fg-e5e7eb, #e5e7eb)}.support-ai-action-btn.cancel{background:rgba(239,68,68,.12);color:var(--awl-fg-fca5a5, #fca5a5)}
html:not(.dark) .support-ai-action-btn.edit{background:var(--awl-bg-eaf0f8, #eaf0f8);color:#334155}html:not(.dark) .support-ai-action-btn.cancel{background:var(--awl-bg-fee2e2, #fee2e2);color:#991b1b}


/* ── Thinking: live indicator while waiting + model thought summary above the answer ── */
.aw-thinking-live{display:flex;align-items:center;gap:10px;font-size:13px;font-weight:600;opacity:.8;padding:4px 0}
.aw-thinking-live .aw-dots{display:inline-flex;gap:4px}
.aw-thinking-live .aw-dots i{width:7px;height:7px;border-radius:50%;background:#6366f1;display:block;animation:awThinkDot 1s infinite ease-in-out}
.aw-thinking-live .aw-dots i:nth-child(2){animation-delay:.15s}
.aw-thinking-live .aw-dots i:nth-child(3){animation-delay:.3s}
.aw-thinking-live .aw-secs{font-size:11px;opacity:.65;font-variant-numeric:tabular-nums}
@keyframes awThinkDot{0%,80%,100%{transform:scale(.7);opacity:.45}40%{transform:scale(1.15);opacity:1}}
.aw-thinking{margin:0 0 10px;border:1px solid rgba(148,163,184,.28);border-radius:12px;background:rgba(148,163,184,.08);overflow:hidden}
.aw-thinking>summary{cursor:pointer;list-style:none;display:flex;align-items:center;gap:8px;padding:8px 12px;font-size:12.5px;font-weight:700;opacity:.8;user-select:none}
.aw-thinking>summary::-webkit-details-marker{display:none}
.aw-thinking>summary::after{content:'\25BE';margin-inline-start:auto;transition:transform .2s}
.aw-thinking[open]>summary::after{transform:rotate(180deg)}
.aw-thinking .aw-thinking-body{padding:0 12px 12px;font-size:12.5px;line-height:1.75;opacity:.78;white-space:pre-wrap}
@media (prefers-reduced-motion:reduce){.aw-thinking-live .aw-dots i{animation:none}}

/* ── Chat images: clean frame, hover actions, full-screen viewer ── */
.support-message-attachment.image.aw-img{display:block!important;padding:0!important;min-width:0!important;max-width:min(460px,82vw)!important;background:transparent!important;border:0!important;box-shadow:none!important;cursor:default!important;transform:none!important}
.aw-img-frame{position:relative;border-radius:18px;overflow:hidden;background:#0b1326;box-shadow:0 14px 34px rgba(15,23,42,.28),0 0 0 1px rgba(148,163,184,.18);line-height:0}
.aw-img-frame img{display:block;width:100%!important;max-width:100%!important;height:auto!important;max-height:460px!important;object-fit:cover!important;border:0!important;border-radius:0!important;cursor:zoom-in;transition:transform .35s ease}
.aw-img-frame:hover img{transform:scale(1.015)}
.aw-img-actions{position:absolute;inset-inline-end:10px;top:10px;display:flex;gap:6px;opacity:0;transform:translateY(-4px);transition:opacity .2s ease,transform .2s ease}
.aw-img-frame:hover .aw-img-actions,.aw-img-frame:focus-within .aw-img-actions{opacity:1;transform:none}
@media (hover:none){.aw-img-actions{opacity:1;transform:none}}
.aw-img-btn{display:inline-flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:10px;border:1px solid rgba(255,255,255,.22);background:rgba(15,23,42,.62);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);color:#fff;font-size:15px;line-height:1;text-decoration:none;cursor:pointer}
.aw-img-btn:hover{background:rgba(37,99,235,.85)}
.aw-img-badge{position:absolute;inset-inline-start:10px;bottom:10px;padding:5px 9px;border-radius:999px;background:rgba(15,23,42,.62);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);color:#e2e8f0;font:700 10.5px/1.2 system-ui,sans-serif;letter-spacing:.2px}
.aw-img-caption{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:8px 4px 0;font-size:11px;opacity:.72}
.aw-img-caption span:last-child{direction:ltr}
.aw-lightbox{position:fixed;inset:0;z-index:2147483600;display:flex;align-items:center;justify-content:center;padding:24px;background:rgba(2,6,23,.92);animation:awLbIn .18s ease}
.aw-lightbox img{max-width:min(1400px,96vw);max-height:86vh;border-radius:14px;box-shadow:0 30px 80px rgba(0,0,0,.6)}
.aw-lightbox-bar{position:fixed;top:16px;inset-inline-end:16px;display:flex;gap:8px}
@keyframes awLbIn{from{opacity:0}to{opacity:1}}
/* AI design services: generation modes + request status */
.aw-gen-modes{display:flex;gap:6px;flex-wrap:wrap;padding:0 2px 8px}
.aw-gen-chip{display:inline-flex;align-items:center;gap:6px;min-height:32px;padding:5px 12px;border-radius:999px;border:1px solid var(--sb-border,rgba(255,255,255,.08));background:rgba(148,163,184,.08);color:var(--sb-text,#f1f5f9);font:600 12px/1.2 'Cairo',sans-serif;cursor:pointer;transition:background .15s,border-color .15s,color .15s}
.aw-gen-chip:hover{border-color:rgba(59,130,246,.55)}
.aw-gen-chip:focus-visible{outline:2px solid #3b82f6;outline-offset:2px}
.aw-gen-chip.is-active{background:rgba(37,99,235,.2);border-color:#3b82f6;color:#bfdbfe}
.aw-gen-status{display:inline-flex;align-items:center;gap:6px;margin-top:8px;padding:3px 10px;border-radius:999px;font:700 11px/1.7 'Cairo',sans-serif}
.aw-gen-status.is-processing{background:rgba(245,158,11,.14);color:#fbbf24}
.aw-gen-status.is-processing::before{content:'';width:7px;height:7px;border-radius:50%;background:currentColor;animation:awThinkDot 1s infinite ease-in-out}
.aw-gen-status.is-completed{background:rgba(16,185,129,.14);color:#34d399}
.aw-gen-status.is-failed{background:rgba(239,68,68,.14);color:#f87171}
.aw-gen-retry{margin-inline-start:8px;border:1px solid rgba(239,68,68,.45);background:transparent;color:inherit;border-radius:999px;padding:2px 10px;font:700 11px/1.7 'Cairo',sans-serif;cursor:pointer}
.aw-gen-retry:hover{background:rgba(239,68,68,.12)}
html[data-aw-theme="light"] .aw-gen-chip{background:#f1f5f9;color:#0f172a;border-color:#cbd5e1}
html[data-aw-theme="light"] .aw-gen-chip.is-active{background:#dbeafe;border-color:#2563eb;color:#1e3a8a}
html[data-aw-theme="light"] .aw-gen-status.is-processing{background:#fef3c7;color:#b45309}
html[data-aw-theme="light"] .aw-gen-status.is-completed{background:#d1fae5;color:#047857}
html[data-aw-theme="light"] .aw-gen-status.is-failed{background:#fee2e2;color:#b91c1c}
.aw-gen-short{display:none}
@media (max-width:560px){.aw-gen-modes{gap:5px}.aw-gen-chip{flex:1 1 0;justify-content:center;padding:6px 6px;font-size:11.5px;min-width:0;white-space:nowrap}.aw-gen-full{display:none}.aw-gen-short{display:inline}}
</style>

{{-- Hotfix 9.6.1: render component JS directly for standalone/welcome/app layouts --}}
<script>
(function () {
    const bootSupportBot = function () {
    const widget = document.getElementById('supportBotWidget');

    if (!widget) {
        return;
    }

    // قد يُعاد إدراج الـcomponent في بعض التنقلات الجزئية؛ لا نربط
    // listeners أكثر من مرة لأن ذلك كان يجعل الفتح/الإرسال يتكرر.
    if (widget.dataset.supportBotBooted === '1') {
        return;
    }
    widget.dataset.supportBotBooted = '1';

    const toggleButton = document.getElementById('supportBotToggle');
    const closeButton = document.getElementById('supportBotClose');
    const panel = document.getElementById('supportBotPanel');
    const messagesContainer = document.getElementById('supportBotMessages');
    const actionsContainer = document.getElementById('supportBotActions');
    const form = document.getElementById('supportBotForm');
    const input = document.getElementById('supportBotInput');
    const sendButton = document.getElementById('supportBotSend');
    const fileInput = document.getElementById('supportBotFileInput');
    const attachButton = document.getElementById('supportBotAttach');
    const attachmentPreview = document.getElementById('supportBotAttachmentPreview');
    const dropOverlay = document.getElementById('supportBotDropOverlay');
    const statusText = document.getElementById('supportBotStatus');
    const unreadBadge = document.getElementById('supportBotUnread');
    const planLabel = document.getElementById('supportBotPlanLabel');
    const creditLabel = document.getElementById('supportBotCreditLabel');
    const limit5hLabel = document.getElementById('supportBotLimit5h');
    const limit7dLabel = document.getElementById('supportBotLimit7d');
    const limitMonthLabel = document.getElementById('supportBotLimitMonth');
    const historyButton = document.getElementById('supportBotHistoryBtn');
    const newButton = document.getElementById('supportBotNewBtn');
    const historyPanel = document.getElementById('supportBotHistory');
    const historyClose = document.getElementById('supportBotHistoryClose');
    const historyList = document.getElementById('supportBotHistoryList');
    const historySearch = document.getElementById('supportBotHistorySearch');
    const modeButtons = Array.from(document.querySelectorAll('[data-ai-mode]'));
    const effortButton = document.getElementById('supportBotEffortBtn');
    const effortButtonLabel = document.getElementById('supportBotEffortBtnLabel');
    const effortPopup = document.getElementById('supportBotEffortPopup');
    const profileList = document.getElementById('supportBotProfileList');
    const effortLabel = document.getElementById('supportBotEffortLabel');
    const effortCost = document.getElementById('supportBotEffortCost');
    const chatCostLabel = document.getElementById('supportBotChatCost');
    const thinkingCostLabel = document.getElementById('supportBotThinkingCost');
    const workCostLabel = document.getElementById('supportBotWorkCost');
    const modeCostLabel = document.getElementById('supportBotModeCost');
    const voiceButton = document.getElementById('supportBotVoice');
    const voiceCallButton = document.getElementById('supportBotVoiceCallBtn');
    const voiceOverlay = document.getElementById('supportBotVoiceOverlay');
    const voiceClose = document.getElementById('supportBotVoiceClose');
    const voiceStart = document.getElementById('supportBotVoiceStart');
    const voiceEnd = document.getElementById('supportBotVoiceEnd');
    const voiceStatus = document.getElementById('supportBotVoiceStatus');
    const voiceLiveText = document.getElementById('supportBotVoiceLiveText');
    const voiceOrb = document.getElementById('supportBotVoiceOrb');
    const suggestionsContainer = document.getElementById('supportBotSuggestions');
    const homeHero = document.getElementById('supportBotHomeHero');
    const homeMenuButton = document.getElementById('supportBotHistoryBtnHome');
    const homeModeButtons = Array.from(document.querySelectorAll('[data-home-mode]'));
    const historyBackdrop = document.getElementById('supportBotHistoryBackdrop');
    const staticPromptButtons = Array.from(document.querySelectorAll('[data-support-prompt]'));
    const settingsButton = document.getElementById('supportBotSettingsBtn');
    const settingsPanel = document.getElementById('supportBotSettingsPanel');
    const settingsBackdrop = document.getElementById('supportBotSettingsBackdrop');
    const settingsClose = document.getElementById('supportBotSettingsClose');
    const settingsMenuButtons = Array.from(document.querySelectorAll('[data-settings-section]'));
    const settingsPanes = Array.from(document.querySelectorAll('[data-settings-pane]'));
    const settingsHeading = document.getElementById('supportBotSettingsHeading');
    const settingsSubheading = document.getElementById('supportBotSettingsSubheading');
    const languageButton = document.getElementById('supportBotLanguageOpen');
    const currentLanguageLabel = document.getElementById('supportBotCurrentLanguage');
    const languageModal = document.getElementById('supportBotLanguageModal');
    const languageBackdrop = document.getElementById('supportBotLanguageBackdrop');
    const languageClose = document.getElementById('supportBotLanguageClose');
    const languageOptions = Array.from(document.querySelectorAll('[data-language-code]'));
    const settingsToggles = {
        memory_enabled: document.getElementById('supportBotMemoryToggle'),
        reflect_enabled: document.getElementById('supportBotReflectToggle'),
        focus_enabled: document.getElementById('supportBotFocusToggle'),
        code_enabled: document.getElementById('supportBotCodeToggle'),
        cowork_enabled: document.getElementById('supportBotCoworkToggle'),
        browser_context_enabled: document.getElementById('supportBotBrowserContextToggle'),
    };
    const memoryNote = document.getElementById('supportBotMemoryNote');
    const memoryNoteSave = document.getElementById('supportBotMemoryNoteSave');
    const skillsList = document.getElementById('supportBotSkillsList');
    const connectorsList = document.getElementById('supportBotConnectorsList');
    const pluginsList = document.getElementById('supportBotPluginsList');
    const capabilitiesTags = document.getElementById('supportBotCapabilitiesTags');

    const csrfToken = document.querySelector(
        'meta[name="csrf-token"]'
    )?.getAttribute('content');

    let ticketId = null;
    let pendingProjectId = null;
    let pendingLibraryId = null;
    let ticketMode = 'bot';
    let initialized = false;
    let requestRunning = false;
    let lastMessageId = 0;
    // Ids already on screen: the send response and the background polling can both return the
    // same new message (e.g. a slow image generation), so each id is rendered once.
    const renderedMessageIds = new Set();
    let pollingTimer = null;
    let pollingRunning = false;
    let currentEntitlement = {};
    let selectedAssistantMode = 'fast';
    let voiceConversationActive = false;
    let voiceListening = false;
    let recognition = null;
    let recognitionMode = 'single';
    let lastCustomerPrompt = '';
    let lastAssistantText = '';
    let selectedAssistantFile = null;
    // AI design services (image / transform image / video). The server says what is available.
    const genModesBar = document.getElementById('supportBotGenModes');
    let generationMode = null;
    let mediaCapabilities = {image: false, edit_image: false, video: false};
    let pendingGenerations = 0;
    let userNearBottom = true;
    let userScrollLocked = false;
    let suppressAutoScroll = false;
    let historyCache = [];
    let settingsCache = {
        language_code: 'ar',
        memory_enabled: true,
        reflect_enabled: true,
        focus_enabled: false,
        code_enabled: true,
        cowork_enabled: false,
        browser_context_enabled: true,
        enabled_skills: [],
        enabled_connectors: [],
        enabled_plugins: [],
        memory_note: '',
    };
    let settingsCatalog = {languages: [], skills: [], connectors: [], plugins: [], capabilities: {}};
    let settingsLoading = false;
    const settingsStorageKey = 'alwaleed_assistant_settings_cache';

    const frontend = {{ Illuminate\Support\Js::from($supportBotFrontend) }};
    const routes = frontend.routes;
    const authenticated = frontend.authenticated === true;
    const standalone = frontend.standalone === true;

    function readLocalSettingsCache() {
        try {
            const raw = localStorage.getItem(settingsStorageKey);
            if (!raw) return null;
            const parsed = JSON.parse(raw);
            return parsed && typeof parsed === 'object' ? parsed : null;
        } catch (error) {
            return null;
        }
    }

    function saveLocalSettingsCache(payload) {
        try {
            localStorage.setItem(settingsStorageKey, JSON.stringify(payload));
        } catch (error) {}
    }

    function languageName(code) {
        const found = (settingsCatalog.languages || []).find((item) => item.code === code);
        if (found?.label) return found.label;
        const option = languageOptions.find((item) => item.dataset.languageCode === code);
        return option?.dataset.languageName || 'العربية';
    }

    function applySettingsState() {
        const state = settingsCache || {};
        if (currentLanguageLabel) currentLanguageLabel.textContent = languageName(state.language_code || 'ar');
        languageOptions.forEach((option) => {
            option.classList.toggle('is-active', option.dataset.languageCode === (state.language_code || 'ar'));
        });
        Object.entries(settingsToggles).forEach(([key, element]) => {
            if (!element) return;
            element.checked = Boolean(state[key]);
        });
        if (memoryNote && document.activeElement !== memoryNote) {
            memoryNote.value = state.memory_note || '';
        }
        renderSettingsCatalog(skillsList, settingsCatalog.skills || [], state.enabled_skills || [], 'enabled_skills');
        renderSettingsCatalog(connectorsList, settingsCatalog.connectors || [], state.enabled_connectors || [], 'enabled_connectors');
        renderSettingsCatalog(pluginsList, settingsCatalog.plugins || [], state.enabled_plugins || [], 'enabled_plugins');
        if (capabilitiesTags) {
            capabilitiesTags.innerHTML = '';
            Object.entries(settingsCatalog.capabilities || {}).forEach(([key, enabled]) => {
                const tag = document.createElement('span');
                tag.textContent = `${key}: ${enabled ? 'ON' : 'OFF'}`;
                if (!enabled) tag.style.opacity = '.55';
                capabilitiesTags.appendChild(tag);
            });
        }
        const voiceAllowed = settingsCatalog.capabilities?.voice !== false;
        const fileAllowed = settingsCatalog.capabilities?.file_analysis !== false;
        if (voiceButton) {
            voiceButton.disabled = requestRunning || !voiceAllowed;
            voiceButton.title = voiceAllowed ? 'تسجيل صوتي' : 'الصوت معطل من الإعدادات > الأدوات والإضافات';
        }
        if (voiceCallButton) {
            voiceCallButton.disabled = !voiceAllowed;
            voiceCallButton.title = voiceAllowed ? 'محادثة صوتية' : 'الصوت معطل من الإعدادات > الأدوات والإضافات';
        }
        if (attachButton) {
            attachButton.disabled = requestRunning || !fileAllowed;
            attachButton.title = fileAllowed ? 'إرفاق ملف أو مخطط' : 'تحليل الملفات معطل من الإعدادات > الأدوات والإضافات';
        }
    }

    function renderSettingsCatalog(container, items, enabled, settingKey) {
        if (!container) return;
        container.innerHTML = '';
        if (!Array.isArray(items) || !items.length) {
            container.innerHTML = '<div class="support-bot-loading">لا توجد خيارات متاحة.</div>';
            return;
        }
        const enabledSet = new Set(Array.isArray(enabled) ? enabled : []);
        items.forEach((item) => {
            const label = document.createElement('label');
            label.className = 'support-bot-settings-catalog-item';
            const inputEl = document.createElement('input');
            inputEl.type = 'checkbox';
            inputEl.checked = enabledSet.has(item.id);
            const copy = document.createElement('span');
            const title = document.createElement('b');
            title.textContent = item.label || item.id;
            const desc = document.createElement('small');
            desc.textContent = item.description || '';
            copy.appendChild(title);
            copy.appendChild(desc);
            label.appendChild(inputEl);
            label.appendChild(copy);
            inputEl.addEventListener('change', async () => {
                const current = new Set(Array.isArray(settingsCache[settingKey]) ? settingsCache[settingKey] : []);
                if (inputEl.checked) current.add(item.id); else current.delete(item.id);
                try {
                    await updateBackendSettings({[settingKey]: Array.from(current)});
                } catch (error) {
                    inputEl.checked = !inputEl.checked;
                    showError(error.message);
                }
            });
            container.appendChild(label);
        });
    }

    async function loadBackendSettings({silent = false} = {}) {
        if (!authenticated || !routes.assistantSettings || settingsLoading) return;
        settingsLoading = true;
        if (!silent && settingsHeading) settingsHeading.dataset.loading = '1';
        try {
            const data = await apiRequest(routes.assistantSettings, {method: 'GET'});
            settingsCache = {...settingsCache, ...(data.settings || {})};
            settingsCatalog = {
                languages: Array.isArray(data.languages) ? data.languages : [],
                skills: Array.isArray(data.skills) ? data.skills : [],
                connectors: Array.isArray(data.connectors) ? data.connectors : [],
                plugins: Array.isArray(data.plugins) ? data.plugins : [],
                capabilities: data.capabilities || {},
            };
            saveLocalSettingsCache({settings: settingsCache, catalog: settingsCatalog});
            applySettingsState();
        } catch (error) {
            const cached = readLocalSettingsCache();
            if (cached?.settings) settingsCache = {...settingsCache, ...cached.settings};
            if (cached?.catalog) settingsCatalog = {...settingsCatalog, ...cached.catalog};
            applySettingsState();
            if (!silent) showError(error.message);
        } finally {
            settingsLoading = false;
            if (settingsHeading) delete settingsHeading.dataset.loading;
        }
    }

    async function updateBackendSettings(patch) {
        if (!authenticated || !routes.assistantSettingsUpdate) {
            throw new Error('يجب تسجيل الدخول لحفظ إعدادات المساعد.');
        }
        const previous = {...settingsCache};
        settingsCache = {...settingsCache, ...patch};
        applySettingsState();
        try {
            const data = await apiRequest(routes.assistantSettingsUpdate, {method: 'PATCH', body: patch});
            settingsCache = {...settingsCache, ...(data.settings || {})};
            if (Array.isArray(data.languages)) settingsCatalog.languages = data.languages;
            if (Array.isArray(data.skills)) settingsCatalog.skills = data.skills;
            if (Array.isArray(data.connectors)) settingsCatalog.connectors = data.connectors;
            if (Array.isArray(data.plugins)) settingsCatalog.plugins = data.plugins;
            if (data.capabilities) settingsCatalog.capabilities = data.capabilities;
            saveLocalSettingsCache({settings: settingsCache, catalog: settingsCatalog});
            applySettingsState();
            return data;
        } catch (error) {
            settingsCache = previous;
            applySettingsState();
            throw error;
        }
    }

    function openLanguageModal() {
        if (!languageModal) return;
        languageModal.classList.add('is-open');
        languageModal.setAttribute('aria-hidden', 'false');
    }

    function closeLanguageModal() {
        if (!languageModal) return;
        languageModal.classList.remove('is-open');
        languageModal.setAttribute('aria-hidden', 'true');
    }

    function settingsSectionMeta(section) {
        const map = {
            general: ['عام', 'ملخص حسابك وتجربة استخدام المساعد.'],
            account: ['الحساب والأمان', 'بيانات حسابك وكلمة المرور والتحقق بخطوتين.'],
            privacy: ['الخصوصية', 'تحكم في كيفية استخدام الذاكرة والسياق والملفات.'],
            billing: ['الباقة والفوترة', 'الاشتراك الحالي والرصيد والترقية وشراء Credits.'],
            usage: ['الاستخدام والحدود', 'رصيدك وحدود 5 ساعات و7 أيام والدورة الشهرية.'],
            capabilities: ['القدرات', 'راجع الأدوات والقدرات المفتوحة في باقتك الحالية.'],
            memory: ['الذاكرة', 'تحكم في استخدام سياق آمن من محادثاتك السابقة.'],
            reflect: ['تحسين الإجابة', 'مراجعة وتحسين الرد قبل عرضه عند الحاجة.'],
            focus: ['التركيز', 'تقليل الإلهاءات وإبقاء المساعد على المهمة الحالية.'],
            code: ['البرمجة', 'مساعدة برمجية ومراجعة أكواد حسب مستوى باقتك.'],
            cowork: ['مساحة العمل', 'تنظيم الأهداف والمهام والمخرجات للعمل الجماعي.'],
            chrome: ['سياق الصفحة', 'التحكم في استخدام سياق الصفحة الحالية داخل المنصة.'],
            skills: ['المهارات', 'اختر المهارات المتخصصة المتاحة للمساعد.'],
            connectors: ['ربط المنصة', 'حدد بيانات المنصة التي يسمح للمساعد باستخدامها كسياق.'],
            plugins: ['الأدوات والإضافات', 'تحكم بالصوت والملفات والأدوات الداخلية للمساعد.'],
        };
        return map[section] || map.general;
    }

    function selectSettingsSection(section) {
        settingsMenuButtons.forEach((button) => button.classList.toggle('is-active', button.dataset.settingsSection === section));
        settingsPanes.forEach((pane) => pane.classList.toggle('is-active', pane.dataset.settingsPane === section));
        const [title, subtitle] = settingsSectionMeta(section);
        if (settingsHeading) settingsHeading.textContent = title;
        if (settingsSubheading) settingsSubheading.textContent = subtitle;
    }

    async function openSettings() {
        if (!settingsPanel) return;
        settingsPanel.classList.add('is-open');
        settingsPanel.setAttribute('aria-hidden', 'false');
        closeHistory();
        const cached = readLocalSettingsCache();
        if (cached?.settings) settingsCache = {...settingsCache, ...cached.settings};
        if (cached?.catalog) settingsCatalog = {...settingsCatalog, ...cached.catalog};
        applySettingsState();
        syncSettingsEntitlement(currentEntitlement);
        await loadBackendSettings({silent: true});
    }

    function closeSettings() {
        if (!settingsPanel) return;
        settingsPanel.classList.remove('is-open');
        settingsPanel.setAttribute('aria-hidden', 'true');
        closeLanguageModal();
    }

    function buildPageContext() {
        return {
            ...(frontend.pageContext || {}),
            title: document.title || '',
            url: window.location.origin + window.location.pathname,
            path: window.location.pathname || frontend.pageContext?.path || '',
        };
    }

    function routeFor(template, id) {
        return template.replace('__TICKET__', id);
    }

    async function apiRequest(url, options = {}) {
        const method = options.method ?? 'POST';

        const headers = {
            'Accept': 'application/json',
            'X-CSRF-TOKEN': csrfToken,
            'X-Requested-With': 'XMLHttpRequest',
        };

        if (method !== 'GET') {
            headers['Content-Type'] = 'application/json';
        }

        const response = await fetch(url, {
            method: method,
            headers: headers,
            body:
                method !== 'GET' && options.body
                    ? JSON.stringify(options.body)
                    : undefined,
        });

        let data = {};

        try {
            data = await response.json();
        } catch (error) {
            data = {
                message: 'وصل رد غير صالح من الخادم.',
            };
        }

        if (!response.ok) {
            if (response.status === 419) {
                throw new Error(
                    'انتهت جلسة الدخول. حدّث الصفحة وحاول مرة أخرى.'
                );
            }

            if (
                response.status === 422 &&
                data.errors
            ) {
                const firstError = Object
                    .values(data.errors)
                    .flat()[0];

                throw new Error(
                    firstError ?? data.message
                );
            }

            throw new Error(
                data.message ??
                'حدث خطأ أثناء تنفيذ الطلب.'
            );
        }

        return data;
    }

    async function multipartRequest(url, formData) {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'X-CSRF-TOKEN': csrfToken,
                'X-Requested-With': 'XMLHttpRequest',
            },
            body: formData,
        });

        let data = {};
        try {
            data = await response.json();
        } catch (error) {
            data = {message: 'وصل رد غير صالح من الخادم.'};
        }

        if (!response.ok) {
            if (response.status === 419) {
                throw new Error('انتهت جلسة الدخول. حدّث الصفحة وحاول مرة أخرى.');
            }
            if (response.status === 422 && data.errors) {
                const firstError = Object.values(data.errors).flat()[0];
                throw new Error(firstError ?? data.message);
            }
            const error = new Error(data.message ?? 'حدث خطأ أثناء تحليل الملف.');
            error.payload = data;
            throw error;
        }

        return data;
    }

    function assistantProfiles() {
        const rows = Array.isArray(currentEntitlement?.assistant_profiles) ? currentEntitlement.assistant_profiles : [];
        if (rows.length) return rows;
        return [
            {key:'fast',label:'إجابة سريعة',description:'إجابة مباشرة وسريعة',credits:1,enabled:true,requires_plan:'AI Free',base_mode:'chat'},
            {key:'smart',label:'إجابة ذكية',description:'شرح أوضح وتحليل أفضل',credits:2,enabled:true,requires_plan:'AI Free',base_mode:'chat'},
            {key:'programming',label:'حلول برمجية',description:'كود وأخطاء وتحليل تقني',credits:3,enabled:false,requires_plan:'AI Plus',base_mode:'thinking'},
            {key:'engineering',label:'حلول هندسية',description:'مخططات وحسابات وتحليل هندسي',credits:4,enabled:false,requires_plan:'AI Plus',base_mode:'thinking'},
            {key:'design3d',label:'تصميم وتحليل 3D',description:'نمذجة وتصميم ثلاثي الأبعاد',credits:6,enabled:false,requires_plan:'AI Pro',base_mode:'work'},
            {key:'expert',label:'خبير متقدم',description:'أعلى عمق للحالات المعقدة',credits:8,enabled:false,requires_plan:'AI Pro',base_mode:'work'},
        ];
    }

    function profileInfo(key = selectedAssistantMode) {
        return assistantProfiles().find((item) => String(item.key) === String(key)) || assistantProfiles()[0];
    }

    function modeCredits(mode = selectedAssistantMode) {
        return Number(profileInfo(mode)?.credits ?? 1);
    }

    function baseModeForProfile(mode = selectedAssistantMode) {
        return String(profileInfo(mode)?.base_mode || 'chat');
    }

    function voiceCredits() {
        return Number(currentEntitlement.voice_turn_credits_cost ?? 2);
    }

    function planCapability(key, fallback = false) {
        const caps = currentEntitlement?.capabilities || {};
        if (Object.prototype.hasOwnProperty.call(caps, key)) return caps[key] === true;
        return fallback;
    }

    function modeAllowed(mode) {
        if (!authenticated) return mode === 'fast';
        return profileInfo(mode)?.enabled !== false;
    }

    function modeRequiredPlan(mode) {
        return String(profileInfo(mode)?.requires_plan || 'AI Free');
    }

    function voiceAllowed() {
        return authenticated && planCapability('voice', false);
    }

    function refreshModeUi() {
        const info = profileInfo();
        if (effortLabel) effortLabel.textContent = info?.label || 'إجابة سريعة';
        if (effortButtonLabel) effortButtonLabel.textContent = info?.label || 'إجابة سريعة';
        if (effortCost) effortCost.textContent = authenticated ? 'حسب الاستهلاك' : 'Sign in';
        if (modeCostLabel) {
            const base = modeCredits();
            const voice = voiceCredits();
            modeCostLabel.textContent = authenticated
                ? 'التكلفة النهائية حسب استهلاك Gemini الفعلي'
                : 'وضع الزائر • المحادثات المحفوظة بعد تسجيل الدخول';
        }
        if (profileList) {
            profileList.innerHTML = assistantProfiles().map((profile) => {
                const key = String(profile.key || 'fast');
                const allowed = modeAllowed(key);
                const active = key === selectedAssistantMode;
                return `<button type="button" class="support-bot-profile-option${active ? ' is-active' : ''}${allowed ? '' : ' is-locked'}" data-ai-profile="${key}" ${allowed ? '' : 'disabled'}>
                    <span><b>${escapeHtml(String(profile.label || key))}</b><small>${escapeHtml(String(profile.description || ''))}</small></span>
                    <em>${allowed ? 'حسب الاستهلاك' : escapeHtml(String(profile.requires_plan || 'ترقية'))}</em>
                </button>`;
            }).join('');
            profileList.querySelectorAll('[data-ai-profile]').forEach((button) => {
                button.addEventListener('click', () => {
                    const key = String(button.dataset.aiProfile || 'fast');
                    if (!modeAllowed(key)) return;
                    selectedAssistantMode = key;
                    refreshModeUi();
                    effortPopup?.classList.remove('is-open');
                    effortPopup?.setAttribute('aria-hidden', 'true');
                    updateStatus();
                });
            });
        }
    }

    function syncSettingsEntitlement(entitlement = currentEntitlement) {
        if (!entitlement || typeof entitlement !== 'object') return;

        const plan = entitlement.plan_label || 'AI Free';
        const credits = entitlement.unlimited
            ? '∞ غير محدودة'
            : `${Number(entitlement.available_credits ?? 0).toLocaleString()} Credit`;

        document.querySelectorAll('[data-settings-plan]').forEach((node) => {
            node.textContent = plan;
        });
        document.querySelectorAll('[data-settings-credit]').forEach((node) => {
            node.textContent = credits;
        });

        const limits = entitlement.usage_limits || {};
        ['five_hours', 'seven_days', 'month'].forEach((key) => {
            const windowData = limits[key] || {};
            const unlimited = entitlement.unlimited || windowData.unlimited;
            const remaining = Number(windowData.remaining ?? 0);
            const limit = Number(windowData.limit ?? 0);
            const used = Number(windowData.used ?? Math.max(0, limit - remaining));
            const percent = unlimited ? 0 : Math.max(0, Math.min(100, Number(windowData.percent ?? (limit > 0 ? (used / limit) * 100 : 0))));

            document.querySelectorAll(`[data-settings-limit="${key}"]`).forEach((node) => {
                node.textContent = unlimited ? '∞' : `${remaining.toLocaleString()} / ${limit.toLocaleString()}`;
            });

            document.querySelectorAll(`[data-settings-limit-detail="${key}"]`).forEach((node) => {
                if (unlimited) {
                    node.textContent = 'استخدام غير محدود لحساب المدير';
                } else if (!limit) {
                    node.textContent = 'لا يوجد حد منفصل لهذه النافذة';
                } else {
                    node.textContent = `استخدمت ${used.toLocaleString()} من ${limit.toLocaleString()} Credit`;
                }
            });

            document.querySelectorAll(`[data-settings-limit-bar="${key}"]`).forEach((node) => {
                node.style.width = `${percent}%`;
            });
        });
    }

    function applyEntitlement(entitlement) {
        if (!entitlement || typeof entitlement !== 'object') return;
        currentEntitlement = {...currentEntitlement, ...entitlement};
        if (planLabel) planLabel.textContent = entitlement.plan_label || 'AI Free';
        if (creditLabel) creditLabel.textContent = entitlement.unlimited ? '∞ Credit غير محدودة' : `${Number(entitlement.available_credits ?? 0)} Credit متاحة`;
        const limits = entitlement.usage_limits || {};
        const limitText = (windowData) => entitlement.unlimited || windowData?.unlimited ? '∞' : `${Number(windowData?.remaining ?? 0)}/${Number(windowData?.limit ?? 0)}`;
        if (limit5hLabel) limit5hLabel.textContent = limitText(limits.five_hours);
        if (limit7dLabel) limit7dLabel.textContent = limitText(limits.seven_days);
        if (limitMonthLabel) limitMonthLabel.textContent = limitText(limits.month);
        syncSettingsEntitlement(currentEntitlement);
        refreshModeUi();
    }

    function renderHistory(conversations) {
        if (!historyList) return;
        const query = (historySearch?.value || '').trim().toLowerCase();
        const filtered = conversations.filter((conversation) => {
            if (!query) return true;
            const haystack = `${conversation.title || ''} ${conversation.preview || ''}`.toLowerCase();
            return haystack.includes(query);
        });

        if (!filtered.length) {
            historyList.innerHTML = `<div class="support-bot-loading">${query ? 'لا توجد نتيجة مطابقة.' : 'لا توجد محادثات سابقة.'}</div>`;
            return;
        }

        historyList.innerHTML = '';
        filtered.forEach((conversation) => {
            const button = document.createElement('div');
            button.className = `support-bot-history-item ${Number(conversation.id) === Number(ticketId) ? 'is-active' : ''}`.trim();
            button.setAttribute('role', 'button');
            button.setAttribute('tabindex', '0');
            button.dataset.ticketId = String(conversation.id || '');

            const title = document.createElement('strong');
            title.textContent = conversation.title || 'محادثة AI';
            const preview = document.createElement('span');
            preview.textContent = conversation.preview || 'بدون رسائل بعد';
            button.appendChild(title);
            button.appendChild(preview);

            const actions = document.createElement('div');
            actions.className = 'support-bot-history-item-actions';

            const rename = document.createElement('button');
            rename.type = 'button';
            rename.className = 'support-bot-history-icon-btn';
            rename.title = 'إعادة تسمية';
            rename.textContent = '✎';
            rename.addEventListener('click', async (event) => {
                event.stopPropagation();
                const nextTitle = window.prompt('اسم المحادثة', conversation.title || 'محادثة AI');
                if (!nextTitle || !nextTitle.trim() || !routes.renameTemplate) return;
                try {
                    await apiRequest(routeFor(routes.renameTemplate, conversation.id), {
                        method: 'PATCH',
                        body: {title: nextTitle.trim()},
                    });
                    conversation.title = nextTitle.trim();
                    renderHistory(historyCache);
                } catch (error) {
                    showError(error.message);
                }
            });

            const archive = document.createElement('button');
            archive.type = 'button';
            archive.className = 'support-bot-history-icon-btn danger';
            archive.title = 'أرشفة';
            archive.textContent = '⌫';
            archive.addEventListener('click', async (event) => {
                event.stopPropagation();
                if (!routes.archiveTemplate || !window.confirm('أرشفة هذه المحادثة؟')) return;
                try {
                    await apiRequest(routeFor(routes.archiveTemplate, conversation.id), {method: 'DELETE'});
                    historyCache = historyCache.filter((item) => Number(item.id) !== Number(conversation.id));
                    renderHistory(historyCache);
                    if (Number(ticketId) === Number(conversation.id)) {
                        beginLocalDraftConversation();
                    }
                } catch (error) {
                    showError(error.message);
                }
            });

            actions.appendChild(rename);
            actions.appendChild(archive);
            button.appendChild(actions);

            const openConversation = async () => {
                await startConversation(Number(conversation.id));
                closeHistory();
            };
            button.addEventListener('click', openConversation);
            button.addEventListener('keydown', async (event) => {
                if (event.key !== 'Enter' && event.key !== ' ') return;
                event.preventDefault();
                await openConversation();
            });
            historyList.appendChild(button);
        });
    }

    async function loadHistory() {
        if (!authenticated || !routes.history || !historyList) return;
        historyList.innerHTML = '<div class="support-bot-loading">جاري تحميل المحادثات...</div>';
        try {
            const data = await apiRequest(routes.history, {method: 'GET'});
            applyEntitlement(data.ai_entitlement);
            applyMediaCapabilities(data.media_capabilities);
            historyCache = Array.isArray(data.conversations) ? data.conversations : [];
            renderHistory(historyCache);
        } catch (error) {
            historyList.innerHTML = `<div class="support-bot-loading">${error.message}</div>`;
        }
    }

    function openHistory() {
        if (!historyPanel) return;
        historyPanel.classList.add('is-open');
        historyPanel.setAttribute('aria-hidden', 'false');
        loadHistory();
    }

    function closeHistory() {
        if (!historyPanel) return;
        historyPanel.classList.remove('is-open');
        historyPanel.setAttribute('aria-hidden', 'true');
    }


    homeMenuButton?.addEventListener('click', async () => {
        if (authenticated) {
            await loadHistory();
            openHistory();
        } else {
            window.location.href = routes.login;
        }
    });

    homeModeButtons.forEach((button) => {
        button.addEventListener('click', () => {
            const nextMode = button.dataset.homeMode === 'work' ? 'work' : 'chat';
            if (!authenticated && nextMode === 'work') {
                window.location.href = routes.login;
                return;
            }
            if (!modeAllowed(nextMode)) {
                showError(`وضع ${nextMode === 'work' ? 'Work' : 'Thinking'} يحتاج باقة ${modeRequiredPlan(nextMode)} أو أعلى.`);
                return;
            }
            selectedAssistantMode = nextMode;
            refreshModeUi();
            homeModeButtons.forEach((item) => item.classList.toggle('is-active', item === button));
            updateStatus();
        });
    });

    function openPanel() {
        // للزائر: افتح صفحة المساعد كاملة بدل فتح لوحة صغيرة ثم الكيبورد فقط.
        if (!authenticated && !standalone) {
            window.location.href = routes.assistantPage || '/smart-assistant';
            return;
        }

        panel.classList.add('is-open');
        panel.setAttribute('aria-hidden', 'false');
        unreadBadge.classList.add('d-none');
        document.documentElement.classList.add('support-bot-open');

        if (!initialized) {
            if (authenticated) {
                openInitialConversation();
                if (standalone && window.innerWidth >= 980) {
                    window.setTimeout(loadHistory, 120);
                }
            } else {
                startGuestConversation();
            }
        } else if (window.innerWidth > 700 && !standalone) {
            window.setTimeout(() => input.focus({preventScroll: true}), 120);
        } else if (authenticated && standalone && window.innerWidth >= 980) {
            loadHistory();
        }
    }

    function closePanel() {
        endVoiceConversation();
        closeSettings();
        if (standalone) {
            closeHistory();
            if (window.history.length > 1) {
                window.history.back();
            } else {
                window.location.href = routes.home || '/';
            }
            return;
        }
        panel.classList.remove('is-open');
        panel.setAttribute('aria-hidden', 'true');
        document.documentElement.classList.remove('support-bot-open');
        closeHistory();
    }

    function clearMessages() {
        messagesContainer.innerHTML = '';
        renderedMessageIds.clear();
        if (suggestionsContainer) suggestionsContainer.classList.remove('is-hidden');
        if (standalone) panel.classList.remove('is-home');
        userNearBottom = true;
        userScrollLocked = false;
    }

    function escapeHtml(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function renderAssistantMarkup(value) {
        const codeBlocks = [];
        let text = String(value ?? '').replace(/```(?:[a-zA-Z0-9_+-]+)?\n?([\s\S]*?)```/g, (_, code) => {
            const index = codeBlocks.length;
            codeBlocks.push(`<pre><code>${escapeHtml(code.trim())}</code></pre>`);
            return `@@SUPPORT_CODE_${index}@@`;
        });

        text = escapeHtml(text)
            .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
            .replace(/`([^`\n]+)`/g, '<code>$1</code>')
            .replace(/(^|\n)#{1,3}\s+([^\n]+)/g, '$1<strong>$2</strong>')
            .replace(/(^|\n)[-*]\s+([^\n]+)/g, '$1• $2')
            .replace(/\n/g, '<br>');

        codeBlocks.forEach((block, index) => {
            text = text.replace(`@@SUPPORT_CODE_${index}@@`, block);
        });
        return text;
    }


    function aiActionStatusLabel(status) {
        return ({pending:'بانتظار موافقتك',executed:'تم التنفيذ',cancelled:'ملغاة',expired:'منتهية',superseded:'تم استبدالها'})[String(status || '')] || String(status || '');
    }

    function disablePreviousAiActionCards(actionId, status = 'superseded') {
        if (!actionId) return;
        document.querySelectorAll(`.support-ai-action-card[data-action-id="${CSS.escape(String(actionId))}"]`).forEach((card) => {
            card.dataset.actionStatus = status;
            const badge = card.querySelector('.support-ai-action-status');
            if (badge) badge.textContent = aiActionStatusLabel(status);
            card.querySelectorAll('button').forEach((button) => button.disabled = true);
        });
    }

    function createAiActionCard(action) {
        if (!action || !action.id || !action.preview) return null;
        const card = document.createElement('div');
        card.className = 'support-ai-action-card';
        card.dataset.actionId = String(action.id);
        card.dataset.actionStatus = String(action.status || 'pending');

        const head = document.createElement('div');
        head.className = 'support-ai-action-head';
        const title = document.createElement('div');
        title.className = 'support-ai-action-title';
        title.textContent = action.title || 'مسودة تنفيذ آمنة';
        const badge = document.createElement('span');
        badge.className = 'support-ai-action-status';
        badge.textContent = aiActionStatusLabel(action.status);
        head.append(title, badge);
        card.appendChild(head);

        const body = document.createElement('div');
        body.className = 'support-ai-action-body';
        const preview = action.preview || {};

        const summary = document.createElement('div');
        summary.className = 'support-ai-action-summary';
        if (action.type === 'create_meeting_tasks') {
            const tasks = Array.isArray(preview.tasks) ? preview.tasks : [];
            summary.textContent = `المرحلة: ${preview.milestone_title || 'غير محددة'} — عدد المهام: ${tasks.length}. لا يتم إنشاء أي مهمة قبل اعتمادك الصريح.`;
            body.appendChild(summary);
            tasks.forEach((task, index) => {
                const row = document.createElement('div');
                row.className = 'support-ai-action-row';
                const assignee = task.assigned_name || (task.assigned_to ? `#${task.assigned_to}` : 'غير مسندة');
                const due = task.due_date || 'بدون موعد محدد';
                row.innerHTML = `<strong>${index + 1}. ${escapeHtml(task.title || '')}</strong><br>${escapeHtml(task.description || '')}<br>المسؤول: ${escapeHtml(assignee)} — الموعد: ${escapeHtml(due)} — الأولوية: ${escapeHtml(task.priority || 'medium')}`;
                body.appendChild(row);
            });
        } else if (action.type === 'approve_boq') {
            summary.textContent = `عدد البنود: ${Number(preview.items_count || 0)} — الإجمالي: ${preview.grand_total ?? 0} ${preview.currency || ''}. الاعتماد سينشئ BOQ فعليًا ثم يرسله للمراجعة ويعتمده وفق صلاحياتك الحالية.`;
            body.appendChild(summary);
            (Array.isArray(preview.sections) ? preview.sections : []).forEach((section) => {
                const sectionTitle = document.createElement('div');
                sectionTitle.className = 'support-ai-action-section';
                sectionTitle.textContent = `${section.code || ''} — ${section.name || ''}`;
                body.appendChild(sectionTitle);
                (Array.isArray(section.items) ? section.items : []).forEach((item) => {
                    const row = document.createElement('div');
                    row.className = 'support-ai-action-row';
                    row.innerHTML = `<strong>${escapeHtml(item.item_code || '')} — ${escapeHtml(item.description || '')}</strong><br>${escapeHtml(String(item.quantity ?? 0))} ${escapeHtml(item.unit || '')} × ${escapeHtml(String(item.unit_rate ?? 0))} = ${escapeHtml(String(item.total_amount ?? 0))} ${escapeHtml(preview.currency || '')}${item.notes ? `<br>${escapeHtml(item.notes)}` : ''}`;
                    body.appendChild(row);
                });
            });
        }

        (Array.isArray(preview.warnings) ? preview.warnings : []).forEach((warning) => {
            const node = document.createElement('div');
            node.className = 'support-ai-action-warning';
            node.textContent = `⚠ ${warning}`;
            body.appendChild(node);
        });
        card.appendChild(body);

        if (String(action.status || '') === 'pending') {
            const actions = document.createElement('div');
            actions.className = 'support-ai-action-actions';
            if (action.can_confirm) {
                const confirmButton = document.createElement('button');
                confirmButton.type = 'button';
                confirmButton.className = 'support-ai-action-btn confirm';
                confirmButton.textContent = 'اعتماد وتنفيذ';
                confirmButton.addEventListener('click', () => runAiAction(action, 'confirm'));
                actions.appendChild(confirmButton);
            }
            if (action.can_edit) {
                const editButton = document.createElement('button');
                editButton.type = 'button';
                editButton.className = 'support-ai-action-btn edit';
                editButton.textContent = 'تعديل';
                editButton.addEventListener('click', () => runAiAction(action, 'edit'));
                actions.appendChild(editButton);
            }
            if (action.can_cancel) {
                const cancelButton = document.createElement('button');
                cancelButton.type = 'button';
                cancelButton.className = 'support-ai-action-btn cancel';
                cancelButton.textContent = 'إلغاء';
                cancelButton.addEventListener('click', () => runAiAction(action, 'cancel'));
                actions.appendChild(cancelButton);
            }
            card.appendChild(actions);
        }
        return card;
    }

    async function runAiAction(action, command) {
        if (!authenticated || !ticketId || !action?.id || !action?.preview_hash) return;
        let instruction = null;
        if (command === 'edit') {
            instruction = window.prompt('اكتب التعديل المطلوب على المسودة. مثال: غيّر موعد مهمة مراجعة المخطط إلى 2026-10-02، أو غيّر كمية البند 01.002 إلى 150.');
            if (instruction === null) return;
            instruction = String(instruction).trim();
            if (instruction.length < 3) {
                showError('اكتب التعديل المطلوب بوضوح.');
                return;
            }
        }
        if (command === 'confirm' && !window.confirm('سيتم الآن تعديل بيانات المشروع فعليًا وفق المسودة المعروضة. هل تريد اعتماد وتنفيذ هذه النسخة؟')) return;
        if (command === 'cancel' && !window.confirm('إلغاء هذه المسودة؟ لن يتم تعديل أي سجل في المشروع.')) return;

        const relatedCards = document.querySelectorAll(`.support-ai-action-card[data-action-id="${CSS.escape(String(action.id))}"]`);
        relatedCards.forEach((card) => card.querySelectorAll('button').forEach((button) => button.disabled = true));
        try {
            const data = await apiRequest(routes.send, {
                body: {
                    ticket_id: ticketId,
                    agent_action_id: action.id,
                    agent_action_command: command,
                    agent_action_hash: action.preview_hash,
                    agent_action_instruction: instruction,
                },
            });
            if (command === 'edit') disablePreviousAiActionCards(action.id, 'superseded');
            if (command === 'confirm') disablePreviousAiActionCards(action.id, 'executed');
            if (command === 'cancel') disablePreviousAiActionCards(action.id, 'cancelled');
            if (data.message) addMessage(data.message);
            applyEntitlement(data.ai_entitlement);
        } catch (error) {
            relatedCards.forEach((card) => card.querySelectorAll('button').forEach((button) => button.disabled = false));
            showError(error.message || 'تعذر تنفيذ أمر المسودة.');
        }
    }

    const genPlaceholders = {
        image: 'صف الصورة: معماري / داخلي / خارجي / لاندسكيب، الطراز، المواد، الإضاءة…',
        edit_image: 'أرفق الصورة ثم اكتب: حسّن الرندر، أعد التصميم بطراز…، غيّر المواد…',
        video: 'صف الفيديو: جولة داخلية، لقطة خارجية سينمائية… ويمكنك إرفاق صورة لتحريكها',
    };
    const genLabels = {image: 'توليد صورة', edit_image: 'تحويل / تعديل صورة', video: 'توليد فيديو'};
    let defaultInputPlaceholder = null;

    function applyMediaCapabilities(caps) {
        if (!genModesBar || !caps || typeof caps !== 'object') return;
        mediaCapabilities = {image: caps.image === true, edit_image: caps.edit_image === true, video: caps.video === true};
        let any = false;
        genModesBar.querySelectorAll('[data-gen-mode]').forEach((chip) => {
            const on = mediaCapabilities[chip.dataset.genMode] === true;
            chip.classList.toggle('d-none', !on);
            any = any || on;
        });
        genModesBar.classList.toggle('d-none', !any || !authenticated);
        if (generationMode && !mediaCapabilities[generationMode]) setGenerationMode(null);
    }

    function setGenerationMode(mode) {
        generationMode = mode && generationMode !== mode && mediaCapabilities[mode] ? mode : null;
        genModesBar?.querySelectorAll('[data-gen-mode]').forEach((chip) => {
            const active = chip.dataset.genMode === generationMode;
            chip.classList.toggle('is-active', active);
            chip.setAttribute('aria-pressed', active ? 'true' : 'false');
        });
        if (defaultInputPlaceholder === null) defaultInputPlaceholder = input.placeholder;
        input.placeholder = generationMode ? genPlaceholders[generationMode] : defaultInputPlaceholder;
        if (generationMode === 'edit_image' && !selectedAssistantFile && !(fileInput?.files?.length)) {
            fileInput?.click();
        }
    }

    genModesBar?.addEventListener('click', (event) => {
        const chip = event.target.closest('[data-gen-mode]');
        if (chip) setGenerationMode(chip.dataset.genMode);
    });

    function generationStatusChip(status) {
        const chip = document.createElement('span');
        chip.className = 'aw-gen-status is-' + status;
        chip.setAttribute('role', 'status');
        chip.textContent = status === 'processing' ? 'قيد المعالجة…' : (status === 'completed' ? '✓ مكتمل' : '✕ فشل');
        return chip;
    }

    function applyPendingGenerations(count) {
        pendingGenerations = Number(count || 0);
        if (pendingGenerations > 0) return;
        messagesContainer?.querySelectorAll('.aw-gen-status.is-processing').forEach((chip) => {
            chip.className = 'aw-gen-status is-completed';
            chip.textContent = '✓ انتهت المعالجة';
        });
    }

    async function retryGeneration(text, mode) {
        if (!text || requestRunning) return;
        await sendMessage(null, {forcedText: text, generationMode: mode, suppressLocalUser: true});
    }

    function showGenerationFailure(messageText, retryText, mode) {
        if (standalone) panel.classList.remove('is-home');
        addMessage({sender_type: 'system', message: messageText, scan_status: 'gen_failed', _retryText: retryText, _retryMode: mode});
    }

    function addMessage(message) {
        const followAfterAppend = userNearBottom;
        if (!message || !message.message) {
            return;
        }
        const messageKey = Number(message.id || 0);
        if (messageKey > 0) {
            if (renderedMessageIds.has(messageKey)) return;
            renderedMessageIds.add(messageKey);
        }

        const senderType = message.sender_type ?? 'system';
        const messageText = String(message.message ?? '');

        if (senderType === 'customer' && !messageText.includes('📎')) {
            lastCustomerPrompt = messageText;
            if (suggestionsContainer) suggestionsContainer.classList.add('is-hidden');
            if (standalone) panel.classList.remove('is-home');
        }
        if (senderType === 'bot') {
            lastAssistantText = messageText;
        }

        const row = document.createElement('div');
        row.className = `support-message-row ${senderType}`;

        const bubble = document.createElement('div');
        bubble.className = 'support-message';

        if (senderType === 'bot' && String(message.ai_thinking || '').trim() !== '') {
            const thinking = document.createElement('details');
            thinking.className = 'aw-thinking';
            const summary = document.createElement('summary');
            summary.textContent = (document.documentElement.getAttribute('lang') || '').startsWith('en') ? '🧠 Show thinking' : '🧠 عرض طريقة التفكير';
            const body = document.createElement('div');
            body.className = 'aw-thinking-body';
            body.textContent = String(message.ai_thinking).replace(/\*\*/g, '');
            thinking.appendChild(summary);
            thinking.appendChild(body);
            bubble.appendChild(thinking);
        }

        const content = document.createElement('div');
        content.className = 'support-message-content';
        if (senderType === 'bot' || senderType === 'employee' || senderType === 'admin') {
            content.innerHTML = renderAssistantMarkup(messageText);
        } else {
            content.textContent = messageText;
        }
        bubble.appendChild(content);

        const normalizedAttachment = message.attachment || (message.attachment_name ? {
            name: message.attachment_name,
            size: Number(message.attachment_size || 0),
            kind: (() => {
                const mime = String(message.attachment_mime || '').toLowerCase();
                const name = String(message.attachment_name || '').toLowerCase();
                if (mime.startsWith('image/')) return 'image';
                if (mime.startsWith('video/')) return 'video';
                if (mime.includes('pdf') || name.endsWith('.pdf')) return 'pdf';
                if (mime.includes('wordprocessingml') || mime.includes('msword') || /\.docx?$/.test(name)) return 'document';
                if (mime.includes('spreadsheetml') || mime.includes('excel') || /\.xlsx?$/.test(name)) return 'sheet';
                if (mime.includes('zip') || name.endsWith('.zip')) return 'archive';
                if (mime.includes('csv') || name.endsWith('.csv')) return 'csv';
                return 'file';
            })(),
            previewUrl: message.attachment_url || message.secure_attachment_url || null,
            uploading: false,
        } : null);
        if (normalizedAttachment) {
            const attachmentNode = createAttachmentMarkup(normalizedAttachment);
            if (attachmentNode) bubble.appendChild(attachmentNode);
        }

        // Generation request status: processing → completed | failed (+ retry).
        const scanStatus = String(message.scan_status || '');
        if (scanStatus === 'gen_processing') {
            bubble.appendChild(generationStatusChip(pendingGenerations > 0 || !message.id ? 'processing' : 'completed'));
            if (!(pendingGenerations > 0 || !message.id)) bubble.lastChild.textContent = '✓ انتهت المعالجة';
        } else if (scanStatus === 'gen_failed') {
            const chip = generationStatusChip('failed');
            const retryText = message._retryText || lastCustomerPrompt;
            const retryMode = message._retryMode || 'video';
            if (authenticated && retryText) {
                const retry = document.createElement('button');
                retry.type = 'button';
                retry.className = 'aw-gen-retry';
                retry.textContent = '↻ إعادة المحاولة';
                retry.addEventListener('click', () => retryGeneration(retryText, retryMode));
                chip.appendChild(retry);
            }
            bubble.appendChild(chip);
        } else if (scanStatus === 'generated' && normalizedAttachment && ['image', 'video'].includes(normalizedAttachment.kind)) {
            bubble.appendChild(generationStatusChip('completed'));
        }

        if (message.ai_action) {
            disablePreviousAiActionCards(message.ai_action.id, 'superseded');
            const actionCard = createAiActionCard(message.ai_action);
            if (actionCard) bubble.appendChild(actionCard);
        }

        if (senderType === 'bot') {
            const tools = document.createElement('div');
            tools.className = 'support-message-tools';

            const copyButton = document.createElement('button');
            copyButton.type = 'button';
            copyButton.className = 'support-message-tool';
            copyButton.textContent = 'نسخ';
            copyButton.addEventListener('click', async () => {
                try {
                    await navigator.clipboard.writeText(messageText);
                    copyButton.textContent = 'تم النسخ';
                    window.setTimeout(() => copyButton.textContent = 'نسخ', 1200);
                } catch (_) {
                    showError('تعذر نسخ الرد من المتصفح.');
                }
            });
            tools.appendChild(copyButton);

            if ('speechSynthesis' in window) {
                const speakButton = document.createElement('button');
                speakButton.type = 'button';
                speakButton.className = 'support-message-tool';
                speakButton.textContent = '🔊 استماع';
                speakButton.addEventListener('click', () => speakText(messageText, false));
                tools.appendChild(speakButton);
            }

            if (authenticated && ticketMode === 'bot' && lastCustomerPrompt) {
                const regenButton = document.createElement('button');
                regenButton.type = 'button';
                regenButton.className = 'support-message-tool';
                regenButton.textContent = '↻ إعادة التوليد';
                regenButton.addEventListener('click', regenerateLastAnswer);
                tools.appendChild(regenButton);
            }

            bubble.appendChild(tools);
        }

        if (message.created_at) {
            const meta = document.createElement('span');
            meta.className = 'support-message-meta';
            const date = new Date(message.created_at);
            meta.textContent = date.toLocaleTimeString('ar', {
                hour: '2-digit',
                minute: '2-digit',
            });
            bubble.appendChild(meta);
        }

        row.appendChild(bubble);
        messagesContainer.appendChild(row);
        if (!suppressAutoScroll && (followAfterAppend || senderType === 'customer')) {
            scrollToBottom(senderType === 'customer');
        }

        if (!panel.classList.contains('is-open') && senderType !== 'customer') {
            unreadBadge.classList.remove('d-none');
        }
    }

    let thinkingRow = null;
    let thinkingTimer = null;
    const thinkingEnglish = (document.documentElement.getAttribute('lang') || '').slice(0, 2) === 'en';
    const thinkingStages = thinkingEnglish
        ? ['Understanding your request', 'Reviewing the conversation', 'Choosing the right tool', 'Thinking it through', 'Preparing the answer']
        : ['يفهم طلبك', 'يراجع سياق المحادثة', 'يختار الأداة المناسبة', 'يفكر ويحلل', 'يجهز الرد'];

    function showThinking(mode = null) {
        hideThinking();
        const started = Date.now();
        thinkingRow = document.createElement('div');
        thinkingRow.className = 'support-message-row bot';
        thinkingRow.innerHTML = '<div class="support-message"><div class="aw-thinking-live" role="status" aria-live="polite" translate="no">'
            + '<span class="aw-dots"><i></i><i></i><i></i></span><span class="aw-stage"></span><span class="aw-secs"></span></div></div>';
        const stageEl = thinkingRow.querySelector('.aw-stage');
        const secsEl = thinkingRow.querySelector('.aw-secs');
        const tick = () => {
            const seconds = Math.floor((Date.now() - started) / 1000);
            const stage = thinkingStages[Math.min(thinkingStages.length - 1, Math.floor(seconds / 2.5))];
            stageEl.textContent = mode
                ? ({image: 'قيد المعالجة · جاري توليد الصورة', edit_image: 'قيد المعالجة · جاري تحويل الصورة', video: 'قيد المعالجة · جاري بدء الفيديو'})[mode] + '…'
                : (thinkingEnglish ? 'Thinking · ' : 'يفكر · ') + stage + '…';
            secsEl.textContent = seconds + 's';
        };
        tick();
        thinkingTimer = window.setInterval(tick, 1000);
        messagesContainer.appendChild(thinkingRow);
        scrollToBottom(true);
    }

    function hideThinking() {
        if (thinkingTimer) window.clearInterval(thinkingTimer);
        thinkingTimer = null;
        thinkingRow?.remove();
        thinkingRow = null;
    }

    function showError(message) {
        if (standalone) panel.classList.remove('is-home');
        addMessage({
            sender_type: 'system',
            message: message,
        });
    }

    function isNearMessagesBottom() {
        if (!messagesContainer) return true;
        const distance = messagesContainer.scrollHeight - messagesContainer.scrollTop - messagesContainer.clientHeight;
        return distance <= 110;
    }

    function scrollToBottom(force = false) {
        if (!messagesContainer) return;
        if (!force && (!userNearBottom || userScrollLocked)) return;
        messagesContainer.scrollTo({
            top: messagesContainer.scrollHeight,
            behavior: force ? 'smooth' : 'auto',
        });
    }

    function clearActions() {
        actionsContainer.innerHTML = '';
    }

    function createAction(
        label,
        callback,
        type = ''
    ) {
        const button = document.createElement('button');

        button.type = 'button';
        button.className =
            `support-bot-action ${type}`.trim();
        button.textContent = label;

        button.addEventListener('click', async function () {
            button.disabled = true;

            try {
                await callback();
            } finally {
                button.disabled = false;
            }
        });

        actionsContainer.appendChild(button);

        return button;
    }

    function showBotFeedbackActions() {
        clearActions();

        createAction(
            'نعم، تم حل المشكلة',
            resolveByBot,
            'primary'
        );

        createAction(
            'لا، تواصل مع موظف',
            transferToEmployee
        );
    }

    function showTransferAction() {
        clearActions();

        createAction(
            'تحويل إلى موظف الدعم',
            transferToEmployee,
            'primary'
        );
    }

    function updateStatus() {
        if (ticketMode === 'bot') {
            const modeLabel = selectedAssistantMode === 'thinking'
                ? 'تفكير وتحليل'
                : selectedAssistantMode === 'work'
                    ? 'عمل متقدم'
                    : 'سريع';
            statusText.textContent = `المساعد الذكي • ${modeLabel}`;
            return;
        }

        if (ticketMode === 'waiting_employee') {
            statusText.textContent = 'بانتظار موظف الدعم';
            return;
        }

        if (ticketMode === 'employee') {
            statusText.textContent = 'المحادثة مع موظف الدعم';
            return;
        }

        statusText.textContent = 'مساعد منصة الوليد الهندسية';
    }

    function showGuestLoginActions(data = {}) {
        clearActions();

        const loginUrl = data.login_url || routes.login;
        const registerUrl = data.register_url || routes.register;

        createAction('تسجيل الدخول', async function () {
            window.location.href = loginUrl;
        }, 'primary');

        createAction('إنشاء حساب', async function () {
            window.location.href = registerUrl;
        });
    }

    function startGuestConversation() {
        clearMessages();
        clearActions();
        initialized = true;
        ticketId = null;
        ticketMode = 'bot';
        statusText.textContent = 'المساعد الذكي متاح للزوار';
        addMessage({
            sender_type: 'bot',
            message: 'مرحبًا 👋 أنا مساعد منصة الوليد الهندسية. أقدر أساعدك في استخدام المنصة، الأعمال الهندسية، التلخيص، إعداد النصوص والتحليل. يمكنك أيضًا التحدث معي بالصوت. سجّل حسابًا لتحفظ محادثاتك وتحصل على 100 Credit مجانية.',
            created_at: new Date().toISOString(),
        });
    }

    function beginLocalDraftConversation(context = {}) {
        pendingProjectId = context?.projectId ? Number(context.projectId) : null;
        pendingLibraryId = context?.libraryId ? Number(context.libraryId) : null;
        ticketId = null;
        ticketMode = 'bot';
        initialized = true;
        lastMessageId = 0;
        clearMessages();
        clearActions();
        addMessage({
            sender_type: 'bot',
            message: 'مرحبًا 👋 أنا مساعد منصة الوليد الهندسية. اسألني عن المنصة أو اطلب مني تحليلًا أو إنجاز عمل.',
            created_at: new Date().toISOString(),
        });
        if (fileInput) fileInput.value = '';
        renderAttachmentPreview(null);
        input.value = '';
        resizeInput();
        updateStatus();
        window.dispatchEvent(new CustomEvent('support-bot-conversation-changed', {detail:{title:'محادثة جديدة', project_id:pendingProjectId, library_id:pendingLibraryId}}));
    }

    async function openInitialConversation() {
        if (!authenticated) {
            startGuestConversation();
            return;
        }
        try {
            const data = await apiRequest(routes.history, {method: 'GET'});
            applyEntitlement(data.ai_entitlement);
            applyMediaCapabilities(data.media_capabilities);
            historyCache = Array.isArray(data.conversations) ? data.conversations : [];
            const latestBotChat = historyCache.find(item => item?.support_mode === 'bot' && Number(item?.id));
            if (latestBotChat) {
                await startConversation(Number(latestBotChat.id));
            } else {
                beginLocalDraftConversation();
            }
        } catch (error) {
            beginLocalDraftConversation();
        }
    }

    async function ensureConversationCreated() {
        if (!authenticated || ticketId) return ticketId;
        const data = await apiRequest(routes.start, {body: {force_new_ai_session: true, ...(pendingProjectId ? {project_id: pendingProjectId} : {}), ...(pendingLibraryId ? {library_id: pendingLibraryId} : {})}});
        ticketId = Number(data.ticket?.id || 0) || null;
        if (!ticketId) throw new Error('تعذر بدء المحادثة.');
        ticketMode = data.ticket?.support_mode || 'bot';
        applyEntitlement(data.ai_entitlement);
        applyMediaCapabilities(data.media_capabilities);
        initialized = true;
        return ticketId;
    }

    async function startConversation(selectedTicketId = null, forceNew = false) {
        if (requestRunning) {
            return;
        }

        requestRunning = true;
        clearMessages();
        clearActions();
        suppressAutoScroll = true;
        if (standalone) panel.classList.remove('is-home');

        messagesContainer.innerHTML = `
            <div class="support-bot-loading">
                جاري فتح المحادثة...
            </div>
        `;

        try {
            const data = await apiRequest(
                routes.start,
                { body: {
                    ...(selectedTicketId ? {ticket_id: selectedTicketId} : {}),
                    ...(forceNew ? {force_new_ai_session: true} : {}),
                    ...(!selectedTicketId && pendingProjectId ? {project_id: pendingProjectId} : {}),
                    ...(!selectedTicketId && pendingLibraryId ? {library_id: pendingLibraryId} : {}),
                }}
            );

            ticketId = data.ticket.id;
            applyMediaCapabilities(data.media_capabilities);
            pendingGenerations = Number(data.pending_generations || 0);
            pendingProjectId = data.ticket?.project_id ? Number(data.ticket.project_id) : null;
            pendingLibraryId = data.ticket?.library_id ? Number(data.ticket.library_id) : null;
            applyEntitlement(data.ai_entitlement);
            ticketMode = data.ticket.support_mode;
            window.dispatchEvent(new CustomEvent('support-bot-conversation-changed', {detail:{title:data.ticket?.title || 'محادثة AI', project_id:pendingProjectId, library_id:pendingLibraryId}}));
            initialized = true;
            lastMessageId = Number(
                data.last_message_id ?? 0
            );

            startPolling();

            clearMessages();

            if (
                Array.isArray(data.messages) &&
                data.messages.length
            ) {
                data.messages.forEach(addMessage);
            } else if (!standalone) {
                addMessage({
                    sender_type: 'bot',
                    message:
                        'مرحبًا 👋 أنا مساعد منصة الوليد الهندسية. اسألني عن المنصة أو اطلب مني تحليلًا أو إنجاز عمل.',
                });
            }

            updateStatus();
            suppressAutoScroll = false;
            userNearBottom = false;
            userScrollLocked = true;
            messagesContainer.scrollTop = 0;
            if (historyPanel?.classList.contains('is-open')) loadHistory();
            if (window.innerWidth > 700 && !standalone) input.focus({preventScroll: true});
        } catch (error) {
            suppressAutoScroll = false;
            clearMessages();
            showError(error.message);
        } finally {
            requestRunning = false;
        }
    }

    function setVoiceStatus(status, liveText = null) {
        if (voiceStatus) voiceStatus.textContent = status;
        if (voiceLiveText && liveText !== null) voiceLiveText.textContent = liveText;
    }

    function recognitionConstructor() {
        return window.SpeechRecognition || window.webkitSpeechRecognition || null;
    }

    function ensureRecognition() {
        const Recognition = recognitionConstructor();
        if (!Recognition) return null;
        if (recognition) return recognition;

        recognition = new Recognition();
        recognition.lang = 'ar-SA';
        recognition.interimResults = true;
        recognition.continuous = false;
        recognition.maxAlternatives = 1;

        recognition.onstart = () => {
            voiceListening = true;
            voiceButton?.classList.add('is-listening');
            voiceOrb?.classList.add('is-listening');
            voiceOrb?.classList.remove('is-speaking');
            setVoiceStatus('أستمع إليك الآن...', '');
        };

        recognition.onresult = (event) => {
            let finalText = '';
            let interimText = '';
            for (let i = event.resultIndex; i < event.results.length; i++) {
                const transcript = event.results[i][0]?.transcript || '';
                if (event.results[i].isFinal) finalText += transcript;
                else interimText += transcript;
            }
            if (voiceLiveText) voiceLiveText.textContent = finalText || interimText;

            if (finalText.trim()) {
                const spoken = finalText.trim();
                input.value = spoken;
                resizeInput();
                window.setTimeout(() => {
                    sendMessage(null, {
                        forcedText: spoken,
                        inputSource: 'voice',
                    });
                }, 40);
            }
        };

        recognition.onerror = (event) => {
            voiceListening = false;
            voiceButton?.classList.remove('is-listening');
            voiceOrb?.classList.remove('is-listening');
            const code = event?.error || '';
            if (code === 'not-allowed' || code === 'service-not-allowed') {
                setVoiceStatus('اسمح للمتصفح باستخدام الميكروفون ثم أعد المحاولة.');
                showError('صلاحية الميكروفون مطلوبة للمحادثة الصوتية.');
                return;
            }
            if (code !== 'no-speech' && code !== 'aborted') {
                setVoiceStatus('تعذر التقاط الصوت. حاول مرة أخرى.');
            }
        };

        recognition.onend = () => {
            voiceListening = false;
            voiceButton?.classList.remove('is-listening');
            voiceOrb?.classList.remove('is-listening');
            if (
                voiceConversationActive &&
                recognitionMode === 'continuous' &&
                !requestRunning &&
                !(window.speechSynthesis?.speaking)
            ) {
                window.setTimeout(() => startRecognition('continuous'), 450);
            }
        };

        return recognition;
    }

    function startRecognition(mode = 'single') {
        if (authenticated && !voiceAllowed()) {
            showError('المحادثة الصوتية تحتاج باقة AI Plus أو أعلى.');
            return;
        }
        const instance = ensureRecognition();
        if (!instance) {
            showError('المتصفح الحالي لا يدعم تحويل الكلام إلى نص. استخدم Chrome/Edge حديثًا أو اكتب الرسالة.');
            setVoiceStatus('الميكروفون الصوتي غير مدعوم في هذا المتصفح.');
            return;
        }
        if (requestRunning || voiceListening) return;
        recognitionMode = mode;
        try {
            instance.start();
        } catch (_) {
            // المتصفح قد يرفض start إذا كان الانتقال بين جلسات التسجيل سريعًا جدًا.
        }
    }

    function stopRecognition() {
        if (!recognition || !voiceListening) return;
        try { recognition.stop(); } catch (_) {}
        voiceListening = false;
        voiceButton?.classList.remove('is-listening');
        voiceOrb?.classList.remove('is-listening');
    }

    function speakText(text, resumeListening = false) {
        if (!('speechSynthesis' in window) || !text) {
            if (resumeListening && voiceConversationActive) startRecognition('continuous');
            return;
        }

        window.speechSynthesis.cancel();
        const utterance = new SpeechSynthesisUtterance(String(text).replace(/```[\s\S]*?```/g, 'مقطع برمجي'));
        utterance.lang = 'ar-SA';
        utterance.rate = 1;
        utterance.pitch = 1;

        const voices = window.speechSynthesis.getVoices?.() || [];
        const arabicVoice = voices.find((voice) => /^ar([-_]|$)/i.test(voice.lang || ''));
        if (arabicVoice) utterance.voice = arabicVoice;

        utterance.onstart = () => {
            voiceOrb?.classList.remove('is-listening');
            voiceOrb?.classList.add('is-speaking');
            setVoiceStatus('المساعد يرد عليك...', String(text).slice(0, 260));
        };
        utterance.onend = () => {
            voiceOrb?.classList.remove('is-speaking');
            if (resumeListening && voiceConversationActive) {
                setVoiceStatus('تفضل، أكمل حديثك...', '');
                window.setTimeout(() => startRecognition('continuous'), 350);
            }
        };
        utterance.onerror = () => {
            voiceOrb?.classList.remove('is-speaking');
            if (resumeListening && voiceConversationActive) startRecognition('continuous');
        };
        window.speechSynthesis.speak(utterance);
    }

    function openVoiceConversation() {
        if (authenticated && !voiceAllowed()) {
            showError('المحادثة الصوتية تحتاج باقة AI Plus أو أعلى.');
            return;
        }
        voiceConversationActive = true;
        voiceOverlay?.classList.add('is-open');
        voiceOverlay?.setAttribute('aria-hidden', 'false');
        setVoiceStatus('اضغط بدء الاستماع وتحدث بشكل طبيعي', '');
        if (voiceStart) voiceStart.disabled = false;
    }

    function endVoiceConversation() {
        voiceConversationActive = false;
        stopRecognition();
        if ('speechSynthesis' in window) window.speechSynthesis.cancel();
        voiceOrb?.classList.remove('is-speaking', 'is-listening');
        voiceOverlay?.classList.remove('is-open');
        voiceOverlay?.setAttribute('aria-hidden', 'true');
        setVoiceStatus('اضغط بدء وتحدث بشكل طبيعي', '');
    }


    function fileKind(file) {
        const type = String(file?.type || '').toLowerCase();
        const name = String(file?.name || '').toLowerCase();
        if (type.startsWith('image/') || /\.(png|jpe?g|webp|gif|bmp|heic|heif|svg)$/i.test(name)) return 'image';
        if (type.startsWith('video/') || /\.(mp4|mov|mkv|avi|webm|m4v|mpeg|mpg|3gp)$/i.test(name)) return 'video';
        if (type.startsWith('audio/') || /\.(mp3|wav|m4a|aac|ogg|flac|opus|wma)$/i.test(name)) return 'audio';
        if (type.includes('pdf') || name.endsWith('.pdf')) return 'pdf';
        if (/\.(csv|tsv|xlsx?|xlsm|ods)$/i.test(name)) return 'sheet';
        if (/\.(docx?|odt|rtf|pages)$/i.test(name)) return 'document';
        if (/\.(pptx?|odp|key)$/i.test(name)) return 'presentation';
        if (/\.(txt|md|json|xml|ya?ml|log|ini|env|php|dart|js|ts|jsx|tsx|html?|css|scss|sass|less|py|java|kt|kts|c|h|cpp|hpp|cs|go|rs|rb|swift|sql|sh|bash|zsh|ps1|bat|cmd|gradle|properties|toml|vue|svelte|tex)$/i.test(name)) return 'text';
        if (/\.(zip|rar|7z|tar|gz|bz2|xz)$/i.test(name)) return 'archive';
        return 'file';
    }

    function humanFileSize(bytes) {
        const value = Number(bytes || 0);
        if (!value) return '';
        if (value < 1024) return `${value} B`;
        if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
        return `${(value / (1024 * 1024)).toFixed(1)} MB`;
    }

    function renderAttachmentPreview(file) {
        if (!attachmentPreview) return;
        if (!file) {
            attachmentPreview.innerHTML = '';
            attachmentPreview.classList.add('d-none');
            return;
        }
        const kind = fileKind(file);
        const iconMap = {pdf:'PDF', image:'IMG', video:'VIDEO', audio:'AUDIO', sheet:'SHEET', document:'DOC', presentation:'PPT', text:'TEXT', archive:'ZIP', file:'FILE'};
        const icon = iconMap[kind] || 'FILE';
        const previewUrl = kind === 'image' ? URL.createObjectURL(file) : '';
        attachmentPreview.innerHTML = `
            <div class="support-bot-file-preview-card ${kind}">
                ${previewUrl ? `<img src="${previewUrl}" alt="معاينة ${escapeHtml(file.name)}">` : `<div class="support-bot-file-preview-icon">${icon}</div>`}
                <div class="support-bot-file-preview-info">
                    <strong>${escapeHtml(file.name)}</strong>
                    <span>${escapeHtml((file.type || kind).toUpperCase())}${file.size ? ` • ${humanFileSize(file.size)}` : ''}</span>
                    <div class="support-bot-file-preview-progress"><i style="width:0%"></i></div>
                </div>
                <button type="button" class="support-bot-file-preview-remove" aria-label="إزالة المرفق">×</button>
            </div>`;
        attachmentPreview.classList.remove('d-none');
        attachmentPreview.querySelector('.support-bot-file-preview-remove')?.addEventListener('click', () => {
            selectedAssistantFile = null;
            if (fileInput) fileInput.value = '';
            attachButton?.classList.remove('has-file');
            renderAttachmentPreview(null);
        });
    }

    function setAttachmentProgress(percent, state = 'uploading') {
        if (!attachmentPreview) return;
        const bar = attachmentPreview.querySelector('.support-bot-file-preview-progress i');
        const card = attachmentPreview.querySelector('.support-bot-file-preview-card');
        if (bar) bar.style.width = `${Math.max(0, Math.min(100, Number(percent || 0)))}%`;
        if (card) {
            card.classList.toggle('is-uploading', state === 'uploading');
            card.classList.toggle('is-done', state === 'done');
            card.classList.toggle('is-error', state === 'error');
        }
    }

    function openImageViewer(url, name) {
        const english = (document.documentElement.getAttribute('lang') || '').startsWith('en');
        const box = document.createElement('div');
        box.className = 'aw-lightbox';
        box.setAttribute('role', 'dialog');
        box.setAttribute('aria-modal', 'true');
        box.innerHTML = '<img alt=""><div class="aw-lightbox-bar">'
            + '<a class="aw-img-btn" download title="' + (english ? 'Download' : 'تنزيل') + '">⬇</a>'
            + '<button type="button" class="aw-img-btn" title="' + (english ? 'Close' : 'إغلاق') + '">✕</button></div>';
        box.querySelector('img').src = url;
        box.querySelector('img').alt = name || '';
        const link = box.querySelector('a');
        link.href = url;
        link.setAttribute('download', name || 'image');
        const close = () => { box.remove(); document.removeEventListener('keydown', onKey); };
        const onKey = (event) => { if (event.key === 'Escape') close(); };
        box.addEventListener('click', (event) => { if (event.target === box || event.target.tagName === 'BUTTON') close(); });
        document.addEventListener('keydown', onKey);
        document.body.appendChild(box);
    }

    function createImageAttachment(attachment) {
        const english = (document.documentElement.getAttribute('lang') || '').startsWith('en');
        const wrap = document.createElement('div');
        wrap.className = 'support-message-attachment image aw-img';
        const frame = document.createElement('div');
        frame.className = 'aw-img-frame';
        const img = document.createElement('img');
        img.src = attachment.previewUrl;
        img.alt = attachment.name || (english ? 'Image' : 'صورة');
        img.loading = 'lazy';
        img.addEventListener('click', () => openImageViewer(attachment.previewUrl, attachment.name));
        frame.appendChild(img);

        const actions = document.createElement('div');
        actions.className = 'aw-img-actions';
        const view = document.createElement('button');
        view.type = 'button';
        view.className = 'aw-img-btn';
        view.title = english ? 'View full size' : 'عرض بالحجم الكامل';
        view.textContent = '⤢';
        view.addEventListener('click', () => openImageViewer(attachment.previewUrl, attachment.name));
        const download = document.createElement('a');
        download.className = 'aw-img-btn';
        download.href = attachment.previewUrl;
        download.setAttribute('download', attachment.name || 'image');
        download.title = english ? 'Download' : 'تنزيل';
        download.textContent = '⬇';
        actions.appendChild(view);
        actions.appendChild(download);
        frame.appendChild(actions);

        if (/^AI-(Generated|Edited)-Image/i.test(attachment.name || '')) {
            const badge = document.createElement('span');
            badge.className = 'aw-img-badge';
            badge.textContent = english ? '✨ AI image' : '✨ صورة بالذكاء الاصطناعي';
            frame.appendChild(badge);
        }
        wrap.appendChild(frame);

        const caption = document.createElement('div');
        caption.className = 'aw-img-caption';
        const label = document.createElement('span');
        label.textContent = english ? 'Tap the image to enlarge' : 'اضغط على الصورة للتكبير';
        const size = document.createElement('span');
        size.textContent = attachment.size ? humanFileSize(attachment.size) : '';
        caption.appendChild(label);
        caption.appendChild(size);
        wrap.appendChild(caption);
        return wrap;
    }

    function createAttachmentMarkup(attachment) {
        if (!attachment) return null;
        const wrap = document.createElement('div');
        wrap.className = `support-message-attachment ${attachment.kind || 'file'}`;
        if (attachment.previewUrl) {
            wrap.classList.add('has-download');
            wrap.tabIndex = 0;
            wrap.setAttribute('role', 'button');
            wrap.setAttribute('aria-label', `فتح ${attachment.name || 'المرفق'}`);
            const openAttachment = () => window.open(attachment.previewUrl, '_blank', 'noopener,noreferrer');
            wrap.addEventListener('click', (event) => {
                if (event.target?.tagName === 'IMG' || event.target?.tagName === 'VIDEO') return;
                openAttachment();
            });
            wrap.addEventListener('keydown', (event) => {
                if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); openAttachment(); }
            });
        }
        if (attachment.previewUrl && attachment.kind === 'image' && !attachment.uploading) {
            return createImageAttachment(attachment);
        }
        if (attachment.previewUrl && attachment.kind === 'image') {
            const img = document.createElement('img');
            img.src = attachment.previewUrl;
            img.alt = attachment.name || 'صورة مرفقة';
            img.loading = 'lazy';
            img.addEventListener('click', (event) => { event.stopPropagation(); window.open(attachment.previewUrl, '_blank', 'noopener,noreferrer'); });
            wrap.appendChild(img);
        } else if (attachment.previewUrl && attachment.kind === 'video') {
            const video = document.createElement('video');
            video.src = attachment.previewUrl;
            video.controls = true;
            video.preload = 'metadata';
            video.playsInline = true;
            video.style.cssText = 'display:block;width:100%;max-width:560px;border-radius:12px;background:#000;margin-bottom:8px';
            wrap.appendChild(video);
        } else {
            const icon = document.createElement('div');
            icon.className = 'support-message-attachment-icon';
            icon.textContent = attachment.kind === 'pdf' ? 'PDF'
                : attachment.kind === 'csv' ? 'CSV'
                : attachment.kind === 'document' ? 'WORD'
                : attachment.kind === 'sheet' ? 'XLSX'
                : attachment.kind === 'archive' ? 'ZIP'
                : 'FILE';
            wrap.appendChild(icon);
        }
        const info = document.createElement('div');
        info.className = 'support-message-attachment-info';
        const name = document.createElement('strong');
        name.textContent = attachment.name || 'ملف مرفق';
        const meta = document.createElement('span');
        const kindLabel = attachment.kind === 'document' ? 'WORD' : attachment.kind === 'sheet' ? 'EXCEL' : attachment.kind === 'archive' ? 'ZIP' : String(attachment.kind || 'file').toUpperCase();
        meta.textContent = `${kindLabel}${attachment.size ? ` • ${humanFileSize(attachment.size)}` : ''}${attachment.previewUrl && !attachment.uploading ? ' • اضغط للفتح' : ''}`;
        info.appendChild(name); info.appendChild(meta);
        if (attachment.uploading) {
            const progress = document.createElement('div');
            progress.className = 'support-message-attachment-progress';
            progress.innerHTML = '<i></i>';
            info.appendChild(progress);
        }
        wrap.appendChild(info);
        return wrap;
    }

    function finishLatestMessageAttachment(success = true) {
        const cards = Array.from(messagesContainer?.querySelectorAll('.support-message-row.customer .support-message-attachment') || []);
        const card = cards.reverse().find((node) => node.querySelector('.support-message-attachment-progress'));
        if (!card) return;
        const progress = card.querySelector('.support-message-attachment-progress');
        if (progress) {
            progress.innerHTML = '<i style="width:100%"></i>';
            window.setTimeout(() => progress.remove(), 320);
        }
        card.classList.toggle('is-done', success);
        card.classList.toggle('is-error', !success);
        const info = card.querySelector('.support-message-attachment-info');
        if (info) {
            const state = document.createElement('span');
            state.className = 'support-message-attachment-state';
            state.textContent = success ? '✓ تم الرفع' : 'تعذر الرفع';
            info.appendChild(state);
        }
    }

    async function multipartRequestWithProgress(url, formData, onProgress) {
        return await new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            xhr.open('POST', url, true);
            xhr.setRequestHeader('Accept', 'application/json');
            xhr.setRequestHeader('X-CSRF-TOKEN', csrfToken);
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            xhr.upload.onprogress = (event) => {
                if (!event.lengthComputable) return;
                const percent = Math.round((event.loaded / event.total) * 100);
                onProgress?.(percent);
            };
            xhr.onerror = () => reject(new Error('تعذر رفع الملف. تحقق من الاتصال وحاول مرة أخرى.'));
            xhr.onload = () => {
                let data = {};
                try { data = JSON.parse(xhr.responseText || '{}'); }
                catch (_) { data = {message: 'وصل رد غير صالح من الخادم.'}; }
                if (xhr.status >= 200 && xhr.status < 300) { resolve(data); return; }
                const error = new Error(data.message || 'حدث خطأ أثناء تحليل الملف.');
                error.payload = data;
                reject(error);
            };
            xhr.send(formData);
        });
    }

    async function sendMessage(event = null, options = {}) {
        event?.preventDefault?.();

        const regenerate = options.regenerate === true;
        const inputSource = options.inputSource === 'voice' ? 'voice' : 'text';
        const message = String(options.forcedText ?? input.value).trim();
        const selectedFile = !regenerate && authenticated
            ? (selectedAssistantFile || (fileInput?.files?.length ? fileInput.files[0] : null))
            : null;
        const mode = !authenticated || regenerate ? null
            : (options.generationMode !== undefined ? options.generationMode : generationMode);

        if ((!message && !selectedFile) || requestRunning) {
            return;
        }
        if (mode === 'edit_image' && !selectedFile) {
            showError('أرفق الصورة التي تريد تحويلها أو تعديلها ثم اكتب المطلوب.');
            fileInput?.click();
            return;
        }
        if (mode && selectedFile && fileKind(selectedFile) !== 'image') {
            showError('هذه الخدمة تحتاج صورة (PNG أو JPG أو WEBP).');
            return;
        }
        if (mode && message.length < 3) {
            showError('اكتب وصفًا واضحًا لما تريد توليده.');
            return;
        }

        if (authenticated && !ticketId) {
            try {
                await ensureConversationCreated();
            } catch (error) {
                showError(error.message || 'تعذر بدء المحادثة.');
                return;
            }
        }

        if (selectedFile && message.length < 3) {
            showError('اكتب ما الذي تريد من المساعد تحليله في الملف.');
            return;
        }

        clearActions();

        const localText = selectedFile ? message : message;
        const localAttachment = selectedFile ? {
            name: selectedFile.name,
            size: selectedFile.size,
            kind: fileKind(selectedFile),
            previewUrl: fileKind(selectedFile) === 'image' ? URL.createObjectURL(selectedFile) : null,
            uploading: true,
        } : null;

        if (!options.suppressLocalUser && !regenerate) {
            addMessage({
                sender_type: 'customer',
                message: localText || 'ملف مرفق',
                attachment: localAttachment,
                created_at: new Date().toISOString(),
            });
        }

        if (!regenerate) {
            input.value = '';
            resizeInput();
        }

        if (inputSource === 'voice') {
            stopRecognition();
            setVoiceStatus('جاري التفكير والرد...', localText);
        }

        requestRunning = true;
        sendButton.disabled = true;
        input.disabled = true;
        if (attachButton) attachButton.disabled = true;
        if (voiceButton) voiceButton.disabled = true;
        showThinking(mode);

        try {
            let data;

            if (selectedFile) {
                if (!authenticated || !routes.analyzeFile) {
                    throw new Error('سجّل الدخول لاستخدام تحليل الملفات داخل المساعد.');
                }

                const formData = new FormData();
                formData.append('ticket_id', String(ticketId));
                formData.append('message', message);
                formData.append('file', selectedFile);
                formData.append('assistant_profile', selectedAssistantMode);
                if (mode) formData.append('generation_mode', mode);

                const context = buildPageContext();
                Object.entries(context).forEach(([key, value]) => {
                    if (value === null || value === undefined) return;
                    if (key === 'parameters' && typeof value === 'object') {
                        Object.entries(value).forEach(([paramKey, paramValue]) => {
                            formData.append(`page_context[parameters][${paramKey}]`, String(paramValue ?? ''));
                        });
                    } else {
                        formData.append(`page_context[${key}]`, String(value));
                    }
                });

                setAttachmentProgress(8, 'uploading');
                data = await multipartRequestWithProgress(routes.analyzeFile, formData, (percent) => {
                    setAttachmentProgress(percent, 'uploading');
                });
                setAttachmentProgress(100, 'done');
                finishLatestMessageAttachment(true);
            } else {
                data = authenticated
                    ? await apiRequest(
                        routes.send,
                        {
                            body: {
                                ticket_id: ticketId,
                                message: message,
                                assistant_mode: baseModeForProfile(selectedAssistantMode),
                                assistant_profile: selectedAssistantMode,
                                input_source: inputSource,
                                regenerate: regenerate,
                                ...(mode ? {generation_mode: mode} : {}),
                                page_context: buildPageContext(),
                            },
                        }
                    )
                    : await apiRequest(
                        routes.guestAsk,
                        {
                            body: {
                                message: message,
                                input_source: inputSource,
                                page_context: buildPageContext(),
                            },
                        }
                    );
            }

            hideThinking();
            if (data.generation?.status === 'processing') pendingGenerations = Math.max(1, pendingGenerations + 1);
            if (data.message && typeof data.message === 'object' && data.thinking && !data.message.ai_thinking) {
                data.message.ai_thinking = data.thinking;
            }
            if (data.message) {
                addMessage(data.message);
            }
            // Messages returned here are already shown: polling must not fetch them again.
            lastMessageId = Math.max(lastMessageId, Number(data.customer_message_id || 0), Number(data.message?.id || 0));
            applyEntitlement(data.ai_entitlement);

            if (selectedFile) {
                selectedAssistantFile = null;
                if (fileInput) fileInput.value = '';
                attachButton?.classList.remove('has-file');
                if (attachButton) attachButton.title = 'تحليل ملف داخل المحادثة';
                window.setTimeout(() => renderAttachmentPreview(null), 420);
            }

            if (inputSource === 'voice' && data.message?.message) {
                speakText(String(data.message.message), voiceConversationActive);
            }

            if (!authenticated) {
                if (data.requires_login || data.show_login_hint) {
                    showGuestLoginActions(data);
                }
                statusText.textContent = 'المساعد الذكي متاح للزوار';
                return;
            }

            // The backend may safely fork an AI-tool request away from a conversation
            // that is currently with human support. Follow the returned AI ticket immediately.
            if (data.ticket?.id) {
                const returnedTicketId = Number(data.ticket.id || 0);
                if (returnedTicketId) ticketId = returnedTicketId;
            }
            if (data.ticket?.support_mode) {
                ticketMode = data.ticket.support_mode;
            } else if (data.handled_by === 'employee') {
                ticketMode = 'employee';
            }
            // A very long conversation continued in a new one: reload it so the carried-over turns show once.
            if (data.conversation_continued && data.ticket?.id) {
                const continuedId = Number(data.ticket.id);
                window.setTimeout(() => startConversation(continuedId), 0);
            }

            if (data.notice) {
                addMessage({
                    sender_type: 'system',
                    message: data.notice,
                });
            }

            if (data.show_feedback_buttons) {
                showBotFeedbackActions();
            }

            if (data.show_transfer_button) {
                showTransferAction();
            }

            updateStatus();
            if (historyPanel?.classList.contains('is-open')) loadHistory();
        } catch (error) {
            hideThinking();
            if (selectedFile) {
                setAttachmentProgress(100, 'error');
                finishLatestMessageAttachment(false);
            }
            if (error?.payload?.ticket?.id) {
                const returnedTicketId = Number(error.payload.ticket.id || 0);
                if (returnedTicketId) ticketId = returnedTicketId;
                if (error.payload.ticket.support_mode) ticketMode = error.payload.ticket.support_mode;
            }
            applyEntitlement(error?.payload?.ai_entitlement);
            if (inputSource === 'voice') {
                setVoiceStatus(error.message || 'تعذر إكمال المحادثة الصوتية.');
            }
            if (error?.payload?.code === 'ai_file_analysis_requires_upgrade' || error?.payload?.code === 'ai_credits_exhausted') {
                showError(`${error.message} استخدم زر «ترقية» أعلى المساعد.`);
            } else if (error?.payload?.generation?.retryable) {
                showGenerationFailure(error.message, message, error.payload.generation.mode || mode);
            } else {
                showError(error.message);
            }
        } finally {
            hideThinking();
            requestRunning = false;
            sendButton.disabled = false;
            input.disabled = false;
            if (attachButton) attachButton.disabled = settingsCatalog.capabilities?.file_analysis === false;
            if (voiceButton) voiceButton.disabled = settingsCatalog.capabilities?.voice === false;
            if (window.innerWidth > 700 && !standalone && !voiceConversationActive) input.focus({preventScroll: true});
        }
    }

    async function regenerateLastAnswer() {
        if (!authenticated || !ticketId || !lastCustomerPrompt || requestRunning) return;
        await sendMessage(null, {
            forcedText: lastCustomerPrompt,
            regenerate: true,
            suppressLocalUser: true,
            inputSource: 'text',
        });
    }

    async function resolveByBot() {
        if (!ticketId) {
            return;
        }

        try {
            const data = await apiRequest(
                routeFor(
                    routes.resolveTemplate,
                    ticketId
                )
            );

            clearActions();

            addMessage({
                sender_type: 'system',
                message: data.message,
            });

            input.disabled = true;
            sendButton.disabled = true;
            statusText.textContent =
                'تم حل المشكلة';

            stopPolling();
        } catch (error) {
            showError(error.message);
        }
    }

    async function transferToEmployee() {
        if (!ticketId) {
            return;
        }

        try {
            const data = await apiRequest(
                routeFor(
                    routes.transferTemplate,
                    ticketId
                )
            );

            clearActions();

            ticketMode =
                data.ticket?.support_mode ??
                (
                    data.assigned
                        ? 'employee'
                        : 'waiting_employee'
                );

            addMessage({
                sender_type: 'system',
                message: data.message,
            });

            updateStatus();
        } catch (error) {
            showError(error.message);
        }
    }

    function startPolling() {
        stopPolling();

        pollingTimer = window.setInterval(
            fetchNewMessages,
            4000
        );
    }

    function stopPolling() {
        if (pollingTimer) {
            window.clearInterval(pollingTimer);
            pollingTimer = null;
        }
    }

    async function fetchNewMessages() {
        if (
            !ticketId ||
            pollingRunning ||
            document.hidden
        ) {
            return;
        }

        pollingRunning = true;

        try {
            const baseUrl = routeFor(
                routes.messagesTemplate,
                ticketId
            );

            const separator = baseUrl.includes('?')
                ? '&'
                : '?';

            const data = await apiRequest(
                `${baseUrl}${separator}after_id=${lastMessageId}`,
                {
                    method: 'GET',
                }
            );

            if (data.ticket?.support_mode) {
                ticketMode = data.ticket.support_mode;
                updateStatus();
            }

            if (Array.isArray(data.messages)) {
                data.messages.forEach(function (message) {
                    if (message.sender_type !== 'customer') {
                        addMessage(message);
                    }

                    lastMessageId = Math.max(
                        lastMessageId,
                        Number(message.id ?? 0)
                    );
                });
            }

            lastMessageId = Math.max(
                lastMessageId,
                Number(data.last_message_id ?? 0)
            );
            if (data.pending_generations !== undefined) applyPendingGenerations(data.pending_generations);

            if (data.conversation_closed) {
                clearActions();
                input.disabled = true;
                sendButton.disabled = true;
                statusText.textContent =
                    'تم إغلاق المحادثة';
                stopPolling();
            }
        } catch (error) {
            console.error(
                'Support polling error:',
                error
            );
        } finally {
            pollingRunning = false;
        }
    }

    function resizeInput() {
        input.style.height = 'auto';

        input.style.height = Math.min(
            input.scrollHeight,
            120
        ) + 'px';
    }

    settingsMenuButtons.forEach((button) => {
        button.addEventListener('click', () => selectSettingsSection(button.dataset.settingsSection || 'general'));
    });
    if (settingsButton) settingsButton.addEventListener('click', openSettings);
    if (settingsBackdrop) settingsBackdrop.addEventListener('click', closeSettings);
    if (settingsClose) settingsClose.addEventListener('click', closeSettings);
    if (languageButton) languageButton.addEventListener('click', openLanguageModal);
    if (languageBackdrop) languageBackdrop.addEventListener('click', closeLanguageModal);
    if (languageClose) languageClose.addEventListener('click', closeLanguageModal);
    languageOptions.forEach((option) => {
        option.addEventListener('click', async () => {
            const code = option.dataset.languageCode || 'ar';
            try {
                await updateBackendSettings({language_code: code});
                closeLanguageModal();
            } catch (error) {
                showError(error.message);
            }
        });
    });
    Object.entries(settingsToggles).forEach(([key, element]) => {
        if (!element) return;
        element.addEventListener('change', async () => {
            const next = element.checked;
            try {
                await updateBackendSettings({[key]: next});
            } catch (error) {
                element.checked = !next;
                showError(error.message);
            }
        });
    });
    if (memoryNoteSave) {
        memoryNoteSave.addEventListener('click', async () => {
            try {
                await updateBackendSettings({memory_note: String(memoryNote?.value || '').trim()});
                memoryNoteSave.textContent = 'تم الحفظ ✓';
                window.setTimeout(() => { memoryNoteSave.textContent = 'حفظ الذاكرة'; }, 1300);
            } catch (error) {
                showError(error.message);
            }
        });
    }
    const lockMessageScroll = () => {
        userScrollLocked = true;
    };
    messagesContainer?.addEventListener('touchstart', lockMessageScroll, {passive: true});
    messagesContainer?.addEventListener('pointerdown', lockMessageScroll, {passive: true});
    messagesContainer?.addEventListener('wheel', lockMessageScroll, {passive: true});
    messagesContainer?.addEventListener('scroll', () => {
        userNearBottom = isNearMessagesBottom();
        if (userNearBottom) userScrollLocked = false;
    }, {passive: true});

    const cachedSettings = readLocalSettingsCache();
    if (cachedSettings?.settings) settingsCache = {...settingsCache, ...cachedSettings.settings};
    if (cachedSettings?.catalog) settingsCatalog = {...settingsCatalog, ...cachedSettings.catalog};
    applySettingsState();
    selectSettingsSection('general');
    if (authenticated) {
        loadBackendSettings({silent: true});
    }

    toggleButton.addEventListener('click', () => {
        if (frontend?.routes?.assistantPage) {
            window.location.href = frontend.routes.assistantPage;
            return;
        }
        openPanel();
    });

    if (historyButton) historyButton.addEventListener('click', openHistory);
    if (historyClose) historyClose.addEventListener('click', closeHistory);
    if (historyBackdrop) historyBackdrop.addEventListener('click', closeHistory);
    staticPromptButtons.forEach((button) => {
        button.addEventListener('click', () => {
            const prompt = String(button.dataset.supportPrompt || '').trim();
            if (!prompt || !input) return;
            input.value = prompt;
            input.dispatchEvent(new Event('input', {bubbles: true}));
            input.focus({preventScroll: true});
        });
    });
    if (historySearch) historySearch.addEventListener('input', () => renderHistory(historyCache));
    if (newButton) newButton.addEventListener('click', () => {
        closeHistory();
        beginLocalDraftConversation();
    });

    modeButtons.forEach((button) => {
        button.addEventListener('click', () => {
            const legacy = button.dataset.aiMode || 'chat';
            const next = legacy === 'work' ? 'expert' : (legacy === 'thinking' ? 'programming' : 'fast');
            if (!modeAllowed(next)) return;
            selectedAssistantMode = next;
            refreshModeUi();
            updateStatus();
        });
    });

    if (effortButton && effortPopup) {
        effortButton.addEventListener('click', (event) => {
            event.stopPropagation();
            const open = effortPopup.classList.toggle('is-open');
            effortPopup.setAttribute('aria-hidden', open ? 'false' : 'true');
        });
        effortPopup.addEventListener('click', (event) => event.stopPropagation());
        document.addEventListener('click', () => {
            effortPopup.classList.remove('is-open');
            effortPopup.setAttribute('aria-hidden', 'true');
        });
    }


    if (voiceButton) {
        voiceButton.addEventListener('click', () => {
            if (voiceListening) stopRecognition();
            else startRecognition('single');
        });
    }
    if (voiceCallButton) voiceCallButton.addEventListener('click', openVoiceConversation);
    if (voiceStart) voiceStart.addEventListener('click', () => startRecognition('continuous'));
    if (voiceEnd) voiceEnd.addEventListener('click', endVoiceConversation);
    if (voiceClose) voiceClose.addEventListener('click', endVoiceConversation);

    window.startSupportBotWorkspaceConversation = (context = {}) => { beginLocalDraftConversation(context); input?.focus(); };
    window.openSupportBotConversationById = (id) => { const value = Number(id || 0); if (value) startConversation(value); };
    window.openSupportBot = openPanel;
    window.addEventListener('open-support-bot', openPanel);

    closeButton.addEventListener(
        'click',
        closePanel
    );

    if (attachButton && fileInput) {
        const setSelectedAssistantFile = (file) => {
            if (!file || requestRunning) return;
            selectedAssistantFile = file;
            // لا نعتمد على تعيين input.files لأن بعض المتصفحات تمنعه للملفات المسحوبة.
            try { fileInput.value = ''; } catch (_) {}
            attachButton.classList.add('has-file');
            attachButton.title = `ملف محدد: ${file.name}`;
            renderAttachmentPreview(file);
            if (!input.value.trim()) {
                input.placeholder = 'اكتب ماذا تريد من المساعد أن يحلل في هذا الملف...';
            }
        };

        const clearSelectedAssistantFile = () => {
            selectedAssistantFile = null;
            try { fileInput.value = ''; } catch (_) {}
            attachButton.classList.remove('has-file');
            attachButton.title = 'تحليل ملف داخل المحادثة';
            renderAttachmentPreview(null);
        };

        attachButton.addEventListener('click', () => {
            if (!requestRunning) fileInput.click();
        });

        fileInput.addEventListener('change', () => {
            const file = fileInput.files?.[0] || null;
            if (!file) {
                clearSelectedAssistantFile();
                return;
            }
            selectedAssistantFile = file;
            attachButton.classList.add('has-file');
            attachButton.title = `ملف محدد: ${file.name}`;
            renderAttachmentPreview(file);
            if (!input.value.trim()) {
                input.placeholder = 'اكتب ماذا تريد من المساعد أن يحلل في هذا الملف...';
            }
        });

        // إزالة المرفق من المعاينة يجب أن تزيل الملف المختار سواء جاء من Picker أو Drag & Drop.
        attachmentPreview?.addEventListener('click', (event) => {
            const removeButton = event.target?.closest?.('.support-bot-file-preview-remove');
            if (!removeButton) return;
            event.preventDefault();
            clearSelectedAssistantFile();
        });

        const hasFilePayload = (event) => {
            const types = Array.from(event?.dataTransfer?.types || []);
            return types.length === 0 || types.includes('Files');
        };

        let dragDepth = 0;
        const showDropOverlay = () => {
            dropOverlay?.classList.add('is-active');
            dropOverlay?.setAttribute('aria-hidden', 'false');
        };
        const hideDropOverlay = () => {
            dragDepth = 0;
            dropOverlay?.classList.remove('is-active');
            dropOverlay?.setAttribute('aria-hidden', 'true');
        };

        // نلتقط السحب على نافذة المساعد كاملة وليس عنصرًا صغيرًا فقط.
        panel.addEventListener('dragenter', (event) => {
            if (!hasFilePayload(event)) return;
            event.preventDefault();
            event.stopPropagation();
            if (!authenticated) {
                hideDropOverlay();
                return;
            }
            if (requestRunning) return;
            dragDepth += 1;
            showDropOverlay();
        });

        panel.addEventListener('dragover', (event) => {
            if (!hasFilePayload(event)) return;
            event.preventDefault();
            event.stopPropagation();
            if (event.dataTransfer) event.dataTransfer.dropEffect = 'copy';
            if (authenticated && !requestRunning) showDropOverlay();
        });

        panel.addEventListener('dragleave', (event) => {
            if (!hasFilePayload(event)) return;
            event.preventDefault();
            event.stopPropagation();
            dragDepth = Math.max(0, dragDepth - 1);
            if (dragDepth === 0) hideDropOverlay();
        });

        panel.addEventListener('drop', (event) => {
            if (!hasFilePayload(event)) return;
            event.preventDefault();
            event.stopPropagation();
            hideDropOverlay();

            if (!authenticated) {
                showError('سجّل الدخول لإرفاق الملفات مع المساعد.');
                return;
            }
            if (requestRunning) return;

            const files = Array.from(event.dataTransfer?.files || []);
            if (!files.length) {
                showError('لم يتم العثور على ملف صالح في عملية السحب.');
                return;
            }

            setSelectedAssistantFile(files[0]);
            if (files.length > 1) {
                showError('تم اختيار أول ملف. أرسل كل ملف في رسالة مستقلة ليتم تحليله بدقة.');
            }
        });

        // منع المتصفح من فتح الملف بدل إسقاطه داخل المساعد إذا خرج المؤشر قليلًا من العنصر.
        window.addEventListener('dragover', (event) => {
            if (panel.classList.contains('is-open') && hasFilePayload(event)) event.preventDefault();
        });
        window.addEventListener('drop', (event) => {
            if (panel.classList.contains('is-open') && hasFilePayload(event)) event.preventDefault();
        });
    }

    form.addEventListener(
        'submit',
        sendMessage
    );

    input.addEventListener(
        'input',
        resizeInput
    );

    input.addEventListener(
        'keydown',
        function (event) {
            if (
                event.key === 'Enter' &&
                !event.shiftKey
            ) {
                event.preventDefault();
                form.requestSubmit();
            }
        }
    );

    window.addEventListener(
        'beforeunload',
        function () {
            stopPolling();
            endVoiceConversation();
        }
    );

    document.addEventListener(
        'visibilitychange',
        function () {
            if (
                !document.hidden &&
                initialized &&
                ticketId
            ) {
                fetchNewMessages();
            }
        }
    );

    refreshModeUi();

    if (standalone) {
        window.setTimeout(openPanel, 0);
    }
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bootSupportBot, { once: true });
    } else {
        bootSupportBot();
    }
})();
</script>
