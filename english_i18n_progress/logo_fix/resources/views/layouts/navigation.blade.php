@php
    $user = auth()->user();
    $role = $user?->role;

    /*
     * Navigation data used to execute several database/schema queries on every
     * page reload. Keep this tiny state for 20 seconds per user so normal page
     * navigation does not repeatedly hit notifications, office membership and
     * feedback tables.
     */
    $navState = $user
        ? \Illuminate\Support\Facades\Cache::remember(
            "navigation-state:{$user->id}:{$role}",
            now()->addSeconds(20),
            function () use ($user, $role) {
                $state = [
                    'unreadNotifications' => $user->unreadNotifications()->count(),
                    'pendingFeedbackCount' => 0,
                    'hasOfficeWorkspace' => false,
                    'canManageOfficeWorkspace' => false,
                    'hasOfficeApplication' => false,
                ];

                if (
                    $role === 'admin'
                    && \Illuminate\Support\Facades\Schema::hasTable('feedback')
                ) {
                    $state['pendingFeedbackCount'] = \App\Models\Feedback::query()
                        ->where('status', 'new')
                        ->count();
                }

                if (\Illuminate\Support\Facades\Schema::hasTable('office_members')) {
                    $membership = \App\Models\OfficeMember::query()
                        ->where('user_id', $user->id)
                        ->where('status', 'active')
                        ->orderByRaw("CASE office_role WHEN 'owner' THEN 0 WHEN 'manager' THEN 1 ELSE 2 END")
                        ->first(['office_role']);

                    $state['hasOfficeWorkspace'] = $membership !== null;
                    $state['canManageOfficeWorkspace'] = $membership?->office_role === 'owner';
                }

                if (in_array($role, ['customer', 'engineer'], true)) {
                    $state['hasOfficeApplication'] = \App\Models\OfficeApplication::query()
                        ->where('user_id', $user->id)
                        ->exists();
                }

                return $state;
            }
        )
        : [
            'unreadNotifications' => 0,
            'pendingFeedbackCount' => 0,
            'hasOfficeWorkspace' => false,
            'canManageOfficeWorkspace' => false,
            'hasOfficeApplication' => false,
        ];

    $unreadNotifications = (int) ($navState['unreadNotifications'] ?? 0);
    $pendingFeedbackCount = (int) ($navState['pendingFeedbackCount'] ?? 0);

    $navVerifiedSubject = $user && $role === 'engineer' ? $user : null;
    $navVerifiedType = 'engineer';

    $homeLink = $user ? route('dashboard') : route('home');
    $welcomeLink = route('home');

    $hasOfficeWorkspace = (bool) ($navState['hasOfficeWorkspace'] ?? false);
    $canManageOfficeWorkspace = (bool) ($navState['canManageOfficeWorkspace'] ?? false);

    // توافق مع الحسابات القديمة قبل اكتمال backfill لعضويات المكتب.
    if ($role === 'office_owner') {
        $hasOfficeWorkspace = true;
        $canManageOfficeWorkspace = true;
    }

    $officeApplicationRoute = null;
    $officeApplicationLabel = 'تسجيل مكتب هندسي';

    if ($user && in_array($role, ['customer', 'engineer'], true)) {
        $hasOfficeApplication = (bool) ($navState['hasOfficeApplication'] ?? false);
        $officeApplicationRoute = $hasOfficeApplication
            ? route('office-applications.status')
            : route('office-applications.create');
        $officeApplicationLabel = $hasOfficeApplication
            ? 'متابعة طلب المكتب'
            : 'تسجيل مكتب هندسي';
    }

    $navItemBase = 'group relative inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-xl px-2.5 py-2 text-[12px] font-bold transition-all duration-200 xl:px-3 xl:text-[13px]';
    $navItemIdle = 'text-slate-300 hover:-translate-y-0.5 hover:bg-white/[0.07] hover:text-white';
    $navItemActive = 'bg-gradient-to-l from-cyan-500 to-blue-600 text-white shadow-lg shadow-cyan-500/20 ring-1 ring-cyan-300/20';

    $mobileItemBase = 'flex w-full items-center gap-3 rounded-2xl border px-4 py-3.5 text-right text-sm font-bold transition-all duration-200';
    $mobileItemIdle = 'border-white/[0.07] bg-white/[0.03] text-slate-200 hover:border-cyan-400/20 hover:bg-cyan-500/10 hover:text-white';
    $mobileItemActive = 'border-cyan-400/25 bg-gradient-to-l from-cyan-500/25 to-blue-600/25 text-white shadow-lg shadow-cyan-500/10';
@endphp

<nav
    id="main-navigation"
    class="sticky top-0 z-50 border-b border-white/[0.07] bg-slate-950/75 shadow-[0_12px_50px_rgba(2,6,23,0.35)] backdrop-blur-2xl"
    dir="rtl"
>
    {{-- إضاءة خفيفة أعلى الناف --}}
    <div
        class="absolute inset-x-0 top-0 h-px pointer-events-none bg-gradient-to-l from-transparent via-cyan-400/70 to-transparent"
    ></div>

    <div class="relative mx-auto max-w-[1500px] px-3 sm:px-5 lg:px-7">
        <div class="flex h-[72px] items-center justify-between gap-2 xl:gap-3">

            {{-- الشعار والروابط الرئيسية --}}
            <div class="flex items-center flex-1 min-w-0 gap-2 xl:gap-4">
                <a
                    href="{{ $homeLink }}"
                    wire:navigate.hover
                    class="flex items-center min-w-0 gap-3 outline-none group rounded-2xl focus-visible:ring-2 focus-visible:ring-cyan-400/70"
                    aria-label="منصة الوليد الهندسية"
                >
                    <div class="relative shrink-0">
                        <div
                            class="absolute transition -inset-1 rounded-2xl bg-gradient-to-br from-cyan-400/35 to-blue-600/35 opacity-70 blur group-hover:opacity-100"
                        ></div>

                        <div
                            class="relative flex items-center justify-center overflow-hidden border shadow-xl h-11 w-11 rounded-xl border-cyan-300/20 bg-slate-900/90 shadow-cyan-950/40 xl:h-12 xl:w-12"
                        >
                            <img
                                src="{{ asset('images/Mainlogo.png') }}"
                                alt="شعار منصة الوليد الهندسية"
                                class="h-full w-full object-contain transition duration-300 group-hover:scale-105"
                                style="width:135%;height:135%;max-width:none;flex-shrink:0"
                            >
                        </div>
                    </div>

                    <div class="hidden min-w-0 sm:block">
                        <p class="truncate text-[15px] font-black tracking-tight text-white xl:text-base">
                            منصة الوليد الهندسية
                        </p>
                        <div class="flex items-center gap-2 mt-1">
                            <span class="h-1.5 w-1.5 rounded-full bg-emerald-400 shadow-[0_0_12px_rgba(52,211,153,0.9)]"></span>
                            <p class="truncate text-[11px] font-semibold text-slate-400">
                                منصة الاستشارات الهندسية
                            </p>
                        </div>
                    </div>
                </a>

                {{-- روابط سطح المكتب المختصرة — باقي الأدوات داخل القائمة الجانبية --}}
                <div class="hidden min-w-0 flex-1 items-center justify-center gap-1 lg:flex">
                    <a
                        href="{{ $welcomeLink }}"
                        class="{{ $navItemBase }} {{ request()->routeIs('home') ? $navItemActive : $navItemIdle }}"
                    >
                        <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3 11.5 12 4l9 7.5M5 10.5V20h14v-9.5M9 20v-6h6v6" />
                        </svg>
                        <span>الرئيسية</span>
                    </a>

                    @auth
                        <a
                            href="{{ $homeLink }}"
                            wire:navigate.hover
                            class="{{ $navItemBase }} {{ request()->routeIs('dashboard') ? $navItemActive : $navItemIdle }}"
                        >
                            <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M3 12l9-9 9 9M5 10v10h14V10M9 20v-6h6v6" />
                            </svg>
                            <span>لوحة التحكم</span>
                        </a>

                    @include('components.management-navigation-links', ['managementNavMode' => 'desktop'])
                    @endauth

                    <a
                        href="{{ route('engineer.works.public') }}"
                        wire:navigate.hover
                        class="{{ $navItemBase }} {{ request()->routeIs('engineer.works.public', 'engineer.works.show') ? $navItemActive : $navItemIdle }}"
                    >
                        <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 20h16M6 20V8l6-4 6 4v12M9 11h1m4 0h1M9 15h1m4 0h1" />
                        </svg>
                        <span>مكتبة المهندسين</span>
                    </a>

                    @if (Route::has('engineering-offices.index'))
                        <a
                            href="{{ route('engineering-offices.index') }}"
                            wire:navigate.hover
                            class="{{ $navItemBase }} {{ request()->routeIs('engineering-offices.*') ? $navItemActive : $navItemIdle }}"
                        >
                            <span class="text-base">🏢</span>
                            <span>المكاتب</span>
                        </a>
                    @endif

                    @auth
                        @if (Route::has('smart-assistant.index'))
                            <a
                                href="{{ route('smart-assistant.index') }}"
                                class="{{ $navItemBase }} {{ request()->routeIs('smart-assistant.*', 'ai.premium.*') ? $navItemActive : $navItemIdle }}"
                            >
                                <span class="text-base">✨</span>
                                <span>المساعد الذكي</span>
                            </a>
                        @endif
                    @endauth
                </div>
            </div>

            {{-- الطرف الأيسر في سطح المكتب --}}
            <div class="flex items-center gap-2 shrink-0">
                @auth
                    {{-- الإشعارات --}}
                    <a
                        href="{{ route('notifications.index') }}"
                    wire:navigate.hover
                        class="relative hidden h-11 w-11 items-center justify-center rounded-2xl border border-white/[0.08] bg-white/[0.04] text-slate-300 transition hover:-translate-y-0.5 hover:border-cyan-400/25 hover:bg-cyan-500/10 hover:text-white xl:flex"
                        title="الإشعارات"
                    >
                        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M18 8a6 6 0 10-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />
                        </svg>

                        <span
                            data-notification-badge
                            class="absolute -left-1 -top-1 min-h-5 min-w-5 items-center justify-center rounded-full border-2 border-slate-950 bg-rose-500 px-1 text-[10px] font-black text-white shadow-lg shadow-rose-500/30 {{ $unreadNotifications > 0 ? 'flex' : 'hidden' }}"
                        >
                            {{ $unreadNotifications > 99 ? '99+' : $unreadNotifications }}
                        </span>
                    </a>

                    {{-- قائمة الحساب على سطح المكتب --}}
                    <div
                        id="account-menu-wrapper"
                        class="relative hidden xl:block"
                    >
                        <button
                            id="account-menu-button"
                            type="button"
                            class="flex items-center gap-3 rounded-2xl border border-white/[0.08] bg-white/[0.04] p-1.5 pl-3 text-right transition hover:border-cyan-400/25 hover:bg-white/[0.07] focus:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400/60"
                            aria-expanded="false"
                            aria-controls="account-menu"
                        >
                            <div class="relative shrink-0">
                                @if ($user->profile_photo)
                                    <img
                                        src="{{ $user->profile_photo_url }}"
                                        alt="{{ $user->name }}"
                                        class="object-cover w-10 h-10 border rounded-xl border-cyan-300/25"
                                    >
                                @else
                                    <div
                                        class="flex items-center justify-center w-10 h-10 text-base font-black text-white border rounded-xl border-cyan-300/25 bg-gradient-to-br from-cyan-500 to-blue-600"
                                    >
                                        {{ mb_substr($user->name, 0, 1) }}
                                    </div>
                                @endif

                                <span
                                    class="absolute -bottom-0.5 -left-0.5 h-3 w-3 rounded-full border-2 border-slate-950 bg-emerald-400"
                                ></span>
                            </div>

                            <div class="hidden max-w-32 xl:block">
                                <div class="flex items-center gap-1.5 min-w-0">
                                    <p class="text-xs font-black text-white truncate">{{ $user->name }}</p>
                                    @if ($navVerifiedSubject)
                                        <x-verified-badge :subject="$navVerifiedSubject" :type="$navVerifiedType" size="xs" />
                                    @endif
                                </div>
                                <p class="mt-0.5 truncate text-[10px] font-semibold text-slate-400">
                                    @switch($role)
                                        @case('admin') مدير النظام @break
                                        @case('engineer') مهندس @break
                                        @case('employee') موظف @break
                                        @case('financial_manager') مدير مالي @break
                                        @case('office_owner') مالك مكتب @break
                                        @default عميل
                                    @endswitch
                                </p>
                            </div>

                            <svg
                                id="account-menu-chevron"
                                class="w-4 h-4 transition text-slate-400"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                            >
                                <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                            </svg>
                        </button>

                        <div
                            id="account-menu"
                            class="absolute left-0 mt-3 hidden w-72 origin-top-left overflow-hidden rounded-3xl border border-white/[0.09] bg-slate-950/95 p-2 opacity-0 scale-95 shadow-2xl shadow-black/40 backdrop-blur-2xl transition duration-150"
                        >
                            <div class="mb-1 rounded-2xl border border-white/[0.07] bg-white/[0.04] px-4 py-3">
                                <div class="flex items-center gap-1.5 min-w-0">
                                    <p class="truncate text-sm font-black text-white">{{ $user->name }}</p>
                                    @if ($navVerifiedSubject)
                                        <x-verified-badge :subject="$navVerifiedSubject" :type="$navVerifiedType" size="xs" />
                                    @endif
                                </div>
                                <p class="mt-1 truncate text-[11px] text-slate-400">
                                    {{ $user->email }}
                                </p>
                            </div>

                            <a
                                href="{{ route('profile.edit') }}"
                                class="flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-black text-slate-200 transition hover:bg-white/[0.06] hover:text-white"
                            >
                                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-cyan-500/10 text-cyan-300">👤</span>
                                <span>الملف الشخصي</span>
                            </a>

                            <div class="my-1 h-px bg-white/[0.07]"></div>

                            <form method="POST" action="{{ route('logout') }}">
                                @csrf
                                <button
                                    type="submit"
                                    class="flex w-full items-center gap-3 rounded-2xl px-4 py-3 text-right text-sm font-black text-rose-300 transition hover:bg-rose-500/10 hover:text-rose-200"
                                >
                                    <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-rose-500/10">🚪</span>
                                    <span>تسجيل الخروج</span>
                                </button>
                            </form>
                        </div>
                    </div>
                @else
                    <div class="items-center hidden gap-2 xl:flex">
                        <a
                            href="{{ route('login') }}"
                            class="rounded-2xl px-4 py-2.5 text-sm font-black text-slate-200 transition hover:bg-white/[0.06] hover:text-white"
                        >
                            تسجيل الدخول
                        </a>

                        <a
                            href="{{ route('register') }}"
                            class="rounded-2xl bg-gradient-to-l from-cyan-500 to-blue-600 px-5 py-2.5 text-sm font-black text-white shadow-lg shadow-cyan-500/20 transition hover:-translate-y-0.5"
                        >
                            إنشاء حساب
                        </a>
                    </div>
                @endauth

                {{-- زر القائمة الشاملة — يعمل على الجوال وسطح المكتب --}}
                <button
                    id="mobile-menu-open"
                    type="button"
                    class="relative flex h-11 items-center justify-center gap-2 overflow-hidden rounded-2xl border border-white/[0.09] bg-white/[0.05] px-3 text-white shadow-lg transition hover:-translate-y-0.5 hover:border-cyan-400/30 hover:bg-cyan-500/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400/70"
                    aria-label="فتح القائمة الشاملة"
                    aria-expanded="false"
                    aria-controls="mobile-menu"
                >
                    <span class="absolute inset-0 bg-gradient-to-br from-cyan-500/10 to-blue-600/10"></span>
                    <svg class="relative h-6 w-6 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 7h16M4 12h16M4 17h16" />
                    </svg>
                    <span class="relative hidden text-sm font-black sm:inline">القائمة</span>
                </button>
            </div>
        </div>
    </div>

    {{-- طبقة خلفية لقائمة الجوال --}}
    <div
        id="mobile-menu-backdrop"
        class="fixed inset-0 z-[60] hidden bg-slate-950/75 opacity-0 backdrop-blur-sm transition-opacity duration-300"
        aria-hidden="true"
    ></div>

    {{-- قائمة الجوال الجانبية --}}
    <aside
        id="mobile-menu"
        class="pointer-events-none fixed right-0 top-0 z-[70] flex h-dvh w-[min(92vw,410px)] translate-x-full flex-col border-l border-white/[0.08] bg-slate-950/95 opacity-0 shadow-2xl shadow-black/50 backdrop-blur-2xl transition duration-300 lg:w-[430px]"
        aria-label="قائمة التنقل الشاملة"
        aria-hidden="true"
    >
        {{-- رأس القائمة --}}
        <div class="relative overflow-hidden border-b border-white/[0.07] p-4">
            <div class="absolute w-48 h-48 rounded-full pointer-events-none -right-20 -top-20 bg-cyan-500/15 blur-3xl"></div>

            <div class="relative flex items-center justify-between gap-3">
                <div class="flex items-center min-w-0 gap-3">
                    <div class="flex items-center justify-center w-12 h-12 overflow-hidden border shrink-0 rounded-2xl border-cyan-300/20 bg-slate-900">
                        <img
                            src="{{ asset('images/Mainlogo.png') }}"
                            alt="شعار منصة الوليد الهندسية"
                            class="h-full w-full object-contain"
                            style="width:135%;height:135%;max-width:none;flex-shrink:0"
                        >
                    </div>

                    <div class="min-w-0">
                        <p class="text-sm font-black text-white truncate">
                            منصة الوليد الهندسية
                        </p>
                        <p class="mt-1 truncate text-[11px] font-semibold text-slate-400">
                            منصة الاستشارات الهندسية
                        </p>
                    </div>
                </div>

                <button
                    id="mobile-menu-close"
                    type="button"
                    class="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl border border-white/[0.08] bg-white/[0.05] text-slate-300 transition hover:bg-rose-500/10 hover:text-rose-300"
                    aria-label="إغلاق القائمة"
                >
                    <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 6l12 12M18 6L6 18" />
                    </svg>
                </button>
            </div>

            @auth
                <div class="relative mt-4 flex items-center gap-3 rounded-2xl border border-white/[0.07] bg-white/[0.04] p-3">
                    @if ($user->profile_photo)
                        <img
                            src="{{ $user->profile_photo_url }}"
                            alt="{{ $user->name }}"
                            class="object-cover w-12 h-12 border shrink-0 rounded-2xl border-cyan-300/25"
                        >
                    @else
                        <div class="flex items-center justify-center w-12 h-12 text-lg font-black text-white shrink-0 rounded-2xl bg-gradient-to-br from-cyan-500 to-blue-600">
                            {{ mb_substr($user->name, 0, 1) }}
                        </div>
                    @endif

                    <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-1.5 min-w-0">
                            <p class="text-sm font-black text-white truncate">{{ $user->name }}</p>
                            @if ($navVerifiedSubject)
                                <x-verified-badge :subject="$navVerifiedSubject" :type="$navVerifiedType" size="xs" />
                            @endif
                        </div>
                        <p class="mt-1 text-xs truncate text-slate-400">
                            {{ $user->email }}
                        </p>
                    </div>

                    <span class="h-2.5 w-2.5 shrink-0 rounded-full bg-emerald-400 shadow-[0_0_12px_rgba(52,211,153,0.8)]"></span>
                </div>
            @endauth

            <div class="relative mt-4">
                <svg class="pointer-events-none absolute right-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
                    <circle cx="11" cy="11" r="7"></circle>
                    <path stroke-linecap="round" d="m20 20-3.5-3.5"></path>
                </svg>
                <input
                    id="site-menu-search"
                    type="search"
                    autocomplete="off"
                    placeholder="ابحث داخل القائمة..."
                    class="w-full rounded-2xl border border-white/[0.08] bg-white/[0.04] py-3 pr-11 pl-4 text-sm font-bold text-white outline-none transition placeholder:text-slate-500 focus:border-cyan-400/30 focus:bg-cyan-500/[0.06] focus:ring-2 focus:ring-cyan-400/10"
                >
            </div>
        </div>

        {{-- روابط القائمة --}}
        <div class="flex-1 px-4 py-5 space-y-5 overflow-y-auto overscroll-contain">
            <div>
                <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                    القائمة الرئيسية
                </p>

                <div class="space-y-2">
                    <a
                        href="{{ $welcomeLink }}"
                        class="{{ $mobileItemBase }} {{ request()->routeIs('home') ? $mobileItemActive : $mobileItemIdle }}"
                    >
                        <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🌐</span>
                        <span>الصفحة الرئيسية</span>
                    </a>

                    @if (Route::has('feedback.create'))
                        <a
                            href="{{ route('feedback.create') }}"
                                wire:navigate.hover
                            class="{{ $mobileItemBase }} {{ request()->routeIs('feedback.create', 'feedback.thanks') ? $mobileItemActive : $mobileItemIdle }}"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">
                                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z" />
                                    <path stroke-linecap="round" d="M8 10h.01M12 10h.01M16 10h.01" />
                                </svg>
                            </span>
                            <span>الآراء والملاحظات</span>
                        </a>
                    @endif

                    <a
                        href="{{ $homeLink }}"
                    wire:navigate.hover
                        class="{{ $mobileItemBase }} {{ request()->routeIs('dashboard') ? $mobileItemActive : $mobileItemIdle }}"
                    >
                        <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">🏠</span>
                        <span>لوحة التحكم</span>
                    </a>

                    <a
                        href="{{ route('engineer.works.public') }}"
                        wire:navigate.hover
                        class="{{ $mobileItemBase }} {{ request()->routeIs('engineer.works.public', 'engineer.works.show') ? $mobileItemActive : $mobileItemIdle }}"
                    >
                        <span class="flex items-center justify-center w-10 h-10 text-blue-300 shrink-0 rounded-xl bg-blue-500/10">👷</span>
                        <span>مكتبة المهندسين</span>
                    </a>

                    @if (Route::has('engineering-offices.index'))
                        <a
                            href="{{ route('engineering-offices.index') }}"
                            wire:navigate.hover
                            class="{{ $mobileItemBase }} {{ request()->routeIs('engineering-offices.*') ? $mobileItemActive : $mobileItemIdle }}"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-indigo-500/10 text-indigo-300">🏢</span>
                            <span>دليل المكاتب الهندسية</span>
                        </a>
                    @endif

                    @auth
                        @if (Route::has('smart-assistant.index'))
                            <a
                                href="{{ route('smart-assistant.index') }}"
                                class="{{ $mobileItemBase }} {{ request()->routeIs('smart-assistant.*', 'ai.premium.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">✨</span>
                                <span>المساعد الذكي</span>
                            </a>
                        @endif
                    @endauth

                </div>
            </div>

            @auth
                <div>
                    <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                        حسابي
                    </p>

                    <div class="space-y-2">
                        <a
                            href="{{ route('profile.edit') }}"
                    wire:navigate.hover
                            class="{{ $mobileItemBase }} {{ request()->routeIs('profile.*') ? $mobileItemActive : $mobileItemIdle }}"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">👤</span>
                            <span>إعدادات الحساب</span>
                        </a>

                        <a
                            href="{{ route('notifications.index') }}"
                    wire:navigate.hover
                            class="{{ $mobileItemBase }} {{ request()->routeIs('notifications.*') ? $mobileItemActive : $mobileItemIdle }}"
                        >
                            <span class="relative flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-amber-500/10 text-amber-300">
                                🔔
                                <span
                                    data-notification-badge
                                    class="absolute -left-1 -top-1 min-h-5 min-w-5 items-center justify-center rounded-full bg-rose-500 px-1 text-[9px] font-black text-white {{ $unreadNotifications > 0 ? 'flex' : 'hidden' }}"
                                >
                                    {{ $unreadNotifications > 99 ? '99+' : $unreadNotifications }}
                                </span>
                            </span>
                            <span>الإشعارات</span>
                        </a>

                        @if (Route::has('conversations.index'))
                            <a
                                href="{{ route('conversations.index') }}"
                                wire:navigate.hover
                                class="{{ $mobileItemBase }} {{ request()->routeIs('conversations.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-sky-500/10 text-sky-300">💬</span>
                                <span>المحادثات</span>
                            </a>
                        @endif

                        @if (Route::has('profile.security'))
                            <a
                                href="{{ route('profile.security') }}"
                                wire:navigate.hover
                                class="{{ $mobileItemBase }} {{ request()->routeIs('profile.security', 'profile.email-2fa.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🛡️</span>
                                <span>مركز الأمان والجلسات</span>
                            </a>
                        @endif



                        @if ($role !== 'admin')
                            <a
                                href="{{ route('support.center') }}"
                                class="{{ $mobileItemBase }} {{ request()->routeIs('support.center') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-sky-500/10 text-sky-300">
                                    🎧
                                </span>

                                <span>التواصل مع الدعم الفني</span>
                            </a>
                        @endif

                        <a
                            href="{{ route('privacy-policy') }}"
                                wire:navigate.hover
                            class="{{ $mobileItemBase }} {{ request()->routeIs('privacy-policy') ? $mobileItemActive : $mobileItemIdle }}"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">
                                🔒
                            </span>

                            <span>سياسة الخصوصية</span>
                        </a>

                        <a
                            href="{{ route('terms-and-conditions') }}"
                                wire:navigate.hover
                            class="{{ $mobileItemBase }} {{ request()->routeIs('terms-and-conditions') ? $mobileItemActive : $mobileItemIdle }}"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-amber-500/10 text-amber-300">
                                📜
                            </span>

                            <span>الشروط والأحكام</span>
                        </a>

                    </div>
                </div>

                @if ($role === 'customer')
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                            خدمات العميل
                        </p>

                        <div class="space-y-2">
                            <a
                                href="{{ route('consultations.mine') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('consultations.mine', 'consultations.messages.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">📋</span>
                                <span>استشاراتي</span>
                            </a>

                            <a
                                href="{{ route('consultations.create') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('consultations.create') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">➕</span>
                                <span>طلب استشارة جديدة</span>
                            </a>

                            @if ($officeApplicationRoute)
                                <a
                                    href="{{ $officeApplicationRoute }}"
                                wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('office-applications.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🏢</span>
                                    <span>{{ $officeApplicationLabel }}</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif

                @if ($role === 'engineer')
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                            لوحة المهندس
                        </p>

                        <div class="space-y-2">
                            <a
                                href="{{ route('engineer.consultations') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('engineer.consultations') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">📐</span>
                                <span>استشارات المهندس</span>
                            </a>

                            <a
                                href="{{ route('engineers.show', $user) }}"
                                wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('engineers.show') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-amber-500/10 text-amber-300">⭐</span>
                                <span>صفحتي العامة</span>
                            </a>

                            <a
                                href="{{ route('engineer.specialty.edit') }}"
                                wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('engineer.specialty.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">🎓</span>
                                <span>التخصص والنبذة</span>
                            </a>
                            @if (Route::has('payout-account.mine'))
                                <a href="{{ route('payout-account.mine') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('payout-account.mine*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 text-blue-300 shrink-0 rounded-xl bg-blue-500/10">🏦</span>
                                    <span>حساب استلام المستحقات</span>
                                </a>
                            @endif

                            @if ($officeApplicationRoute)
                                <a
                                    href="{{ $officeApplicationRoute }}"
                                wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('office-applications.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🏢</span>
                                    <span>{{ $officeApplicationLabel }}</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif

                @if (Route::has('disputes.index'))
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">الحماية والمتابعة</p>
                        <div class="space-y-2">
                            <a href="{{ route('disputes.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('disputes.*') ? $mobileItemActive : $mobileItemIdle }}">
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-amber-500/10 text-amber-300">⚖️</span>
                                <span>مركز النزاعات</span>
                            </a>
                            @if (Route::has('sla.index'))
                                <a href="{{ route('sla.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('sla.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">⏱️</span>
                                    <span>مركز المتابعة و SLA</span>
                                </a>
                            @endif

                            @if (Route::has('smart-assistant.index'))
                                <a href="{{ route('smart-assistant.index') }}" class="{{ $mobileItemBase }} {{ request()->routeIs('smart-assistant.*', 'ai.premium.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">✨</span>
                                    <span>المساعد الذكي</span>
                                </a>
                            @endif
                            @if ($role === 'admin' && Route::has('ai.admin.index'))
                                <a href="{{ route('ai.admin.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('ai.admin.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-blue-500/10 text-blue-300">🧠</span>
                                    <span>إدارة AI</span>
                                </a>
                            @endif
                            @if (in_array($role, ['admin', 'financial_manager'], true) && Route::has('financial.control-center'))
                                <a href="{{ route('financial.control-center') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('financial.control-center', 'financial.refunds.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">📊</span>
                                    <span>الرقابة المالية والاستردادات</span>
                                </a>
                            @endif

                            @if (in_array($role, ['admin', 'financial_manager'], true) && Route::has('admin.kyc.index'))
                                <a href="{{ route('admin.kyc.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('admin.kyc.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🪪</span>
                                    <span>مركز مراجعة KYC</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif

                @if ($hasOfficeWorkspace)
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                            مساحة المكتب
                        </p>

                        <div class="space-y-2">
                            @if ($role === 'office_owner' || $canManageOfficeWorkspace)
                                <a
                                    href="{{ route('office.dashboard') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('office.dashboard') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">🏢</span>
                                    <span>لوحة المكتب</span>
                                </a>
                            @endif

                            @if (($role === 'office_owner' || $canManageOfficeWorkspace) && Route::has('office.finance.index'))
                                <a
                                    href="{{ route('office.finance.index') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('office.finance.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">📊</span>
                                    <span>مالية المكتب</span>
                                </a>
                            @endif

                            @if (Route::has('office.subscription'))
                                <a
                                    href="{{ route('office.subscription') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('office.subscription*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">💳</span>
                                    <span>الباقة والاشتراك</span>
                                </a>
                            @endif

                            @if (($role === 'office_owner' || $canManageOfficeWorkspace) && Route::has('office.payout-account'))
                                <a href="{{ route('office.payout-account') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('office.payout-account*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 text-blue-300 shrink-0 rounded-xl bg-blue-500/10">🏦</span>
                                    <span>حساب المكتب البنكي</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif

                                @include('components.management-navigation-links', ['managementNavMode' => 'mobile'])

@if ($role === 'admin')
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                            إدارة النظام
                        </p>

                        <div class="space-y-2">
                            <a
                                href="{{ route('consultations.index') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('consultations.index', 'consultations.assign.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">📋</span>
                                <span>جميع الاستشارات</span>
                            </a>

                            <a
                                href="{{ route('payments.index') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('payments.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">💳</span>
                                <span>إدارة الدفعات</span>
                            </a>

                            <a
                                href="{{ route('employees.index') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('employees.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 text-blue-300 shrink-0 rounded-xl bg-blue-500/10">👥</span>
                                <span>الموظفون</span>
                            </a>

                            <a
                                href="{{ route('users.index') }}"
                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('users.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">⚙️</span>
                                <span>إدارة المستخدمين</span>
                            </a>
                            @if (Route::has('financial.payout-accounts.index'))
                                <a href="{{ route('financial.payout-accounts.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('financial.payout-accounts.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 text-emerald-300 shrink-0 rounded-xl bg-emerald-500/10">🏦</span>
                                    <span>مراجعة الحسابات البنكية</span>
                                </a>
                            @endif

                            @if (Route::has('admin.office-finance.index'))
                                <a
                                    href="{{ route('admin.office-finance.index') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('admin.office-finance.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🏦</span>
                                    <span>مالية المكاتب</span>
                                </a>
                            @endif

                            @if (Route::has('financial.payout-queue'))
                                <a
                                    href="{{ route('financial.payout-queue') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('financial.payout-queue*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-amber-500/10 text-amber-300">💸</span>
                                    <span>المستحقات الجاهزة للصرف</span>
                                </a>
                            @endif

                            @if (Route::has('financial.platform-payment-methods'))
                                <a
                                    href="{{ route('financial.platform-payment-methods') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('financial.platform-payment-methods*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">💳</span>
                                    <span>طرق دفع المنصة</span>
                                </a>
                            @endif

                            @if (Route::has('admin.conversation-reviews'))
                                <a
                                    href="{{ route('admin.conversation-reviews') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('admin.conversation-reviews*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-sky-500/10 text-sky-300">🔎</span>
                                    <span>مراجعة المحادثات</span>
                                </a>
                            @endif

                            @if (Route::has('admin.moderation.index'))
                                <a
                                    href="{{ route('admin.moderation.index') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('admin.moderation.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-rose-500/10 text-rose-300">🛡️</span>
                                    <span>الإشراف والمراجعة</span>
                                </a>
                            @endif

                            @if (Route::has('admin.moderation-appeals.index'))
                                <a
                                    href="{{ route('admin.moderation-appeals.index') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('admin.moderation-appeals.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-orange-500/10 text-orange-300">📨</span>
                                    <span>طعون تعليق الحسابات</span>
                                </a>
                            @endif

                            @if (Route::has('production.control'))
                                <a
                                    href="{{ route('production.control') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('production.control') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">🚀</span>
                                    <span>مركز جاهزية الإنتاج</span>
                                </a>
                            @endif

                            @if (Route::has('admin.feedback.index'))
                                <a
                                    href="{{ route('admin.feedback.index') }}"
                                wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('admin.feedback.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="relative flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">
                                        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 4h16v12H8l-4 4V4z" />
                                            <path stroke-linecap="round" d="M8 8h8M8 12h5" />
                                        </svg>

                                        @if ($pendingFeedbackCount > 0)
                                            <span class="absolute -left-1 -top-1 flex min-h-5 min-w-5 items-center justify-center rounded-full bg-rose-500 px-1 text-[9px] font-black text-white">
                                                {{ $pendingFeedbackCount > 99 ? '99+' : $pendingFeedbackCount }}
                                            </span>
                                        @endif
                                    </span>

                                    <span>إدارة الآراء والملاحظات</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif

                @if ($role === 'financial_manager')
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                            الإدارة المالية
                        </p>
                        <div class="space-y-2">
                            @if (Route::has('financial.payout-queue'))
                                <a href="{{ route('financial.payout-queue') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('financial.payout-queue*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-amber-500/10 text-amber-300">💸</span>
                                    <span>المستحقات الجاهزة للصرف</span>
                                </a>
                            @endif
                            @if (Route::has('financial.payout-accounts.index'))
                                <a href="{{ route('financial.payout-accounts.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('financial.payout-accounts.*') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🏦</span>
                                    <span>مراجعة الحسابات البنكية</span>
                                </a>
                            @endif
                            @if (Route::has('production.control'))
                                <a href="{{ route('production.control') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('production.control') ? $mobileItemActive : $mobileItemIdle }}">
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">🚀</span>
                                    <span>مركز جاهزية الإنتاج</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif

                @include('layouts.partials.v23-sidebar-links')
                            @if (Route::has('kyc.index'))
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">توثيق الحساب</p>
                        <div class="space-y-2">
                            <a href="{{ route('kyc.index') }}" wire:navigate.hover class="{{ $mobileItemBase }} {{ request()->routeIs('kyc.*') ? $mobileItemActive : $mobileItemIdle }}">
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-300">🪪</span>
                                <span>توثيق الهوية KYC</span>
                            </a>
                        </div>
                    </div>
                @endif

                @if (in_array($role, ['employee', 'admin'], true))
                    <div>
                        <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                            الدعم الفني
                        </p>

                        <div class="space-y-2">
                            @if ($role === 'employee' && Route::has('admin.conversation-reviews'))
                                <a
                                    href="{{ route('admin.conversation-reviews') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('admin.conversation-reviews*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-sky-500/10 text-sky-300">🔎</span>
                                    <span>مراجعة محادثات الدعم</span>
                                </a>
                            @endif

                            <a
                                href="{{ route('employee.support-tickets.index') }}"
                                wire:navigate.hover
                                class="{{ $mobileItemBase }} {{ request()->routeIs('employee.support-tickets.*') ? $mobileItemActive : $mobileItemIdle }}"
                            >
                                <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">🎫</span>
                                <span>تذاكر الدعم الفني</span>
                            </a>

                            @if (Route::has('employee.support-customers.index'))
                                <a
                                    href="{{ route('employee.support-customers.index') }}"
                                    wire:navigate.hover
                                    class="{{ $mobileItemBase }} {{ request()->routeIs('employee.support-customers.*') ? $mobileItemActive : $mobileItemIdle }}"
                                >
                                    <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-violet-500/10 text-violet-300">👤</span>
                                    <span>البحث الشامل عن الحساب</span>
                                </a>
                            @endif
                        </div>
                    </div>
                @endif
            @else
                <div>
                    <p class="mb-2 px-2 text-[10px] font-black uppercase tracking-[0.25em] text-slate-500">
                        الحساب
                    </p>

                    <div class="space-y-2">
                        <a
                            href="{{ route('login') }}"
                            class="{{ $mobileItemBase }} {{ $mobileItemIdle }}"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-cyan-500/10 text-cyan-300">🔑</span>
                            <span>تسجيل الدخول</span>
                        </a>

                        <a
                            href="{{ route('register') }}"
                            class="{{ $mobileItemBase }} border-cyan-400/25 bg-gradient-to-l from-cyan-500/25 to-blue-600/25 text-white"
                        >
                            <span class="flex items-center justify-center w-10 h-10 shrink-0 rounded-xl bg-white/10">✨</span>
                            <span>إنشاء حساب جديد</span>
                        </a>
                    </div>
                </div>
            @endauth
        </div>

        {{-- أسفل القائمة --}}
        @auth
            <div class="border-t border-white/[0.07] p-4">
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button
                        type="submit"
                        class="flex w-full items-center justify-center gap-3 rounded-2xl border border-rose-400/20 bg-rose-500/10 px-4 py-3.5 text-sm font-black text-rose-200 transition hover:bg-rose-500/15 hover:text-white"
                    >
                        <span>🚪</span>
                        <span>تسجيل الخروج</span>
                    </button>
                </form>
            </div>
        @endauth
    </aside>

    <script>
        (function () {
            /**
             * تهيئة الناف بشكل آمن مع التنقل الداخلي عبر Livewire.
             *
             * الفكرة:
             * - نعيد ربط عناصر الناف بعد كل livewire:navigated.
             * - نلغي الـ listeners القديمة عبر AbortController حتى لا تتكرر.
             * - نبقي الصفحات الحساسة/الثقيلة بدون wire:navigate.hover إلى أن يتم
             *   تجهيز JavaScript الخاص بها للتنقل الداخلي.
             */
            window.__initMainNavigation = function () {
                if (window.__mainNavigationController) {
                    window.__mainNavigationController.abort();
                }

                const controller = new AbortController();
                const signal = controller.signal;

                window.__mainNavigationController = controller;

                const accountWrapper =
                    document.getElementById('account-menu-wrapper');

                const accountButton =
                    document.getElementById('account-menu-button');

                const accountMenu =
                    document.getElementById('account-menu');

                const accountChevron =
                    document.getElementById('account-menu-chevron');

                const mobileOpenButton =
                    document.getElementById('mobile-menu-open');

                const mobileCloseButton =
                    document.getElementById('mobile-menu-close');

                const mobileMenu =
                    document.getElementById('mobile-menu');

                const mobileBackdrop =
                    document.getElementById('mobile-menu-backdrop');

                const siteMenuSearch =
                    document.getElementById('site-menu-search');

                function resetMenuSearch() {
                    if (siteMenuSearch) {
                        siteMenuSearch.value = '';
                    }

                    mobileMenu
                        ?.querySelectorAll('a')
                        .forEach(function (link) {
                            link.classList.remove('hidden');
                        });
                }

                function filterSiteMenu() {
                    if (!siteMenuSearch || !mobileMenu) {
                        return;
                    }

                    const query = siteMenuSearch.value
                        .trim()
                        .toLocaleLowerCase('ar');

                    mobileMenu
                        .querySelectorAll('a')
                        .forEach(function (link) {
                            const text = (link.textContent || '')
                                .replace(/\s+/g, ' ')
                                .trim()
                                .toLocaleLowerCase('ar');

                            link.classList.toggle(
                                'hidden',
                                query.length > 0 && !text.includes(query)
                            );
                        });
                }

                function openAccountMenu() {
                    if (!accountMenu || !accountButton) {
                        return;
                    }

                    accountMenu.classList.remove('hidden');

                    requestAnimationFrame(function () {
                        accountMenu.classList.remove(
                            'opacity-0',
                            'scale-95'
                        );

                        accountMenu.classList.add(
                            'opacity-100',
                            'scale-100'
                        );
                    });

                    accountButton.setAttribute(
                        'aria-expanded',
                        'true'
                    );

                    accountChevron?.classList.add(
                        'rotate-180'
                    );
                }

                function closeAccountMenu() {
                    if (!accountMenu || !accountButton) {
                        return;
                    }

                    accountMenu.classList.remove(
                        'opacity-100',
                        'scale-100'
                    );

                    accountMenu.classList.add(
                        'opacity-0',
                        'scale-95'
                    );

                    accountButton.setAttribute(
                        'aria-expanded',
                        'false'
                    );

                    accountChevron?.classList.remove(
                        'rotate-180'
                    );

                    window.setTimeout(function () {
                        if (
                            accountButton.getAttribute(
                                'aria-expanded'
                            ) === 'false'
                        ) {
                            accountMenu.classList.add(
                                'hidden'
                            );
                        }
                    }, 150);
                }

                function toggleAccountMenu(event) {
                    event.preventDefault();
                    event.stopPropagation();

                    if (!accountMenu || !accountButton) {
                        return;
                    }

                    const isOpen =
                        accountButton.getAttribute(
                            'aria-expanded'
                        ) === 'true';

                    if (isOpen) {
                        closeAccountMenu();
                    } else {
                        openAccountMenu();
                    }
                }

                function openMobileMenu() {
                    if (
                        !mobileMenu
                        || !mobileBackdrop
                        || !mobileOpenButton
                    ) {
                        return;
                    }

                    mobileBackdrop.classList.remove(
                        'hidden'
                    );

                    mobileMenu.classList.remove(
                        'pointer-events-none'
                    );

                    mobileMenu.setAttribute(
                        'aria-hidden',
                        'false'
                    );

                    mobileOpenButton.setAttribute(
                        'aria-expanded',
                        'true'
                    );

                    document.body.classList.add(
                        'overflow-hidden'
                    );

                    resetMenuSearch();

                    requestAnimationFrame(function () {
                        mobileBackdrop.classList.remove(
                            'opacity-0'
                        );

                        mobileBackdrop.classList.add(
                            'opacity-100'
                        );

                        mobileMenu.classList.remove(
                            'translate-x-full',
                            'opacity-0'
                        );

                        mobileMenu.classList.add(
                            'translate-x-0',
                            'opacity-100'
                        );
                    });
                }

                function closeMobileMenu() {
                    if (
                        !mobileMenu
                        || !mobileBackdrop
                        || !mobileOpenButton
                    ) {
                        document.body.classList.remove(
                            'overflow-hidden'
                        );

                        return;
                    }

                    mobileBackdrop.classList.remove(
                        'opacity-100'
                    );

                    mobileBackdrop.classList.add(
                        'opacity-0'
                    );

                    mobileMenu.classList.remove(
                        'translate-x-0',
                        'opacity-100'
                    );

                    mobileMenu.classList.add(
                        'translate-x-full',
                        'opacity-0',
                        'pointer-events-none'
                    );

                    mobileMenu.setAttribute(
                        'aria-hidden',
                        'true'
                    );

                    mobileOpenButton.setAttribute(
                        'aria-expanded',
                        'false'
                    );

                    document.body.classList.remove(
                        'overflow-hidden'
                    );

                    window.setTimeout(function () {
                        if (
                            mobileMenu.getAttribute(
                                'aria-hidden'
                            ) === 'true'
                        ) {
                            mobileBackdrop.classList.add(
                                'hidden'
                            );
                        }
                    }, 300);
                }

                accountButton?.addEventListener(
                    'click',
                    toggleAccountMenu,
                    { signal }
                );

                document.addEventListener(
                    'click',
                    function (event) {
                        if (
                            accountWrapper
                            && !accountWrapper.contains(
                                event.target
                            )
                        ) {
                            closeAccountMenu();
                        }
                    },
                    { signal }
                );

                mobileOpenButton?.addEventListener(
                    'click',
                    function (event) {
                        event.preventDefault();
                        openMobileMenu();
                    },
                    { signal }
                );

                mobileCloseButton?.addEventListener(
                    'click',
                    closeMobileMenu,
                    { signal }
                );

                mobileBackdrop?.addEventListener(
                    'click',
                    closeMobileMenu,
                    { signal }
                );

                siteMenuSearch?.addEventListener(
                    'input',
                    filterSiteMenu,
                    { signal }
                );

                mobileMenu
                    ?.querySelectorAll('a')
                    .forEach(function (link) {
                        link.addEventListener(
                            'click',
                            closeMobileMenu,
                            { signal }
                        );
                    });

                document.addEventListener(
                    'keydown',
                    function (event) {
                        if (event.key === 'Escape') {
                            closeAccountMenu();
                            closeMobileMenu();
                        }
                    },
                    { signal }
                );

                window.__closeMainNavigationMenus =
                    function () {
                        closeAccountMenu();
                        closeMobileMenu();
                    };
            };

            /*
             * نربط دورة حياة Livewire مرة واحدة فقط.
             * الدالة نفسها محفوظة على window، لذلك لو تم تحميل نسخة جديدة
             * من هذا الـ partial ستستخدم أحدث نسخة من دالة التهيئة.
             */
            if (!window.__mainNavigationLifecycleBound) {
                window.__mainNavigationLifecycleBound = true;

                document.addEventListener(
                    'livewire:navigating',
                    function () {
                        window.__closeMainNavigationMenus?.();

                        document.body.classList.remove(
                            'overflow-hidden'
                        );
                    }
                );

                document.addEventListener(
                    'livewire:navigated',
                    function () {
                        window.__initMainNavigation?.();
                    }
                );

                document.addEventListener(
                    'DOMContentLoaded',
                    function () {
                        window.__initMainNavigation?.();
                    },
                    { once: true }
                );
            }

            /*
             * عند تنفيذ السكربت بعد تنقل Livewire يكون DOM جاهزًا أصلًا،
             * لذلك نهيئ مباشرة.
             */
            if (document.readyState !== 'loading') {
                window.__initMainNavigation();
            }
        })();
    </script>

</nav>


<script>
(function () {
    function initNavigationDropdowns() {
        const menu = document.getElementById('mobile-menu');
        if (!menu) return;

        menu.querySelectorAll('p.mb-2').forEach((heading) => {
            const content = heading.nextElementSibling;
            if (!content || !content.classList.contains('space-y-2')) return;
            if (heading.dataset.dropdownReady === '1') return;

            heading.dataset.dropdownReady = '1';
            heading.setAttribute('role', 'button');
            heading.setAttribute('tabindex', '0');
            heading.classList.add('cursor-pointer', 'select-none', 'flex', 'items-center', 'justify-between', 'gap-3');

            const arrow = document.createElement('span');
            arrow.textContent = '⌄';
            arrow.className = 'text-slate-400 transition-transform duration-200';
            heading.appendChild(arrow);

            const toggle = () => {
                const hidden = content.classList.toggle('hidden');
                arrow.style.transform = hidden ? 'rotate(90deg)' : 'rotate(0deg)';
                heading.setAttribute('aria-expanded', hidden ? 'false' : 'true');
            };

            heading.setAttribute('aria-expanded', 'true');
            heading.addEventListener('click', toggle);
            heading.addEventListener('keydown', (event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    toggle();
                }
            });
        });
    }

    document.addEventListener('DOMContentLoaded', initNavigationDropdowns);
    document.addEventListener('livewire:navigated', initNavigationDropdowns);
})();
</script>

@auth
<script>
(function () {
    const liveUrl = @json(route('notifications.live'));
    const notificationsUrl = @json(route('notifications.index'));

    function setBadges(count) {
        const value = Number(count || 0);
        document.querySelectorAll('[data-notification-badge]').forEach((badge) => {
            badge.textContent = value > 99 ? '99+' : String(value);
            badge.classList.toggle('hidden', value <= 0);
            badge.classList.toggle('flex', value > 0);
        });
    }

    function beep() {
        try {
            const AudioContextCtor = window.AudioContext || window.webkitAudioContext;
            if (!AudioContextCtor) return;
            const ctx = new AudioContextCtor();
            const oscillator = ctx.createOscillator();
            const gain = ctx.createGain();
            oscillator.frequency.value = 740;
            gain.gain.setValueAtTime(0.035, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.16);
            oscillator.connect(gain);
            gain.connect(ctx.destination);
            oscillator.start();
            oscillator.stop(ctx.currentTime + 0.17);
            oscillator.onended = () => ctx.close().catch(() => {});
        } catch (_) {}
    }

    function showToast(item) {
        if (!item) return;

        document.getElementById('platform-live-notification-toast')?.remove();

        const toast = document.createElement('a');
        toast.id = 'platform-live-notification-toast';
        toast.href = notificationsUrl;
        toast.dir = 'rtl';
        toast.className = 'fixed left-4 top-20 z-[10000] w-[min(92vw,390px)] rounded-2xl border border-cyan-300/25 bg-[#071426]/95 p-4 text-right text-white shadow-2xl shadow-black/35 backdrop-blur-xl transition';
        toast.innerHTML = `
            <div class="flex items-start gap-3">
                <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-cyan-500/15 text-lg">🔔</div>
                <div class="min-w-0 flex-1">
                    <div class="text-sm font-black text-white"></div>
                    <div class="mt-1 text-xs leading-6 text-slate-300"></div>
                    <div class="mt-2 text-[10px] font-black text-cyan-300">فتح مركز الإشعارات ←</div>
                </div>
            </div>`;
        toast.querySelector('div.text-sm').textContent = item.title || 'إشعار جديد';
        toast.querySelector('div.mt-1').textContent = item.message || '';
        document.body.appendChild(toast);
        window.setTimeout(() => toast.remove(), 9000);

        beep();

        if ('Notification' in window && Notification.permission === 'granted') {
            try {
                const nativeNotice = new Notification(item.title || 'منصة الوليد الهندسية', {
                    body: item.message || '',
                    tag: 'platform-notification-' + String(item.id || ''),
                });
                nativeNotice.onclick = () => {
                    window.focus();
                    window.location.href = notificationsUrl;
                };
            } catch (_) {}
        }
    }

    async function pollNotifications() {
        try {
            const response = await fetch(liveUrl, {
                headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
                credentials: 'same-origin',
                cache: 'no-store',
            });
            if (!response.ok) return;
            const payload = await response.json();
            setBadges(payload.unread_count);

            const latestId = payload.latest?.id ? String(payload.latest.id) : null;
            if (window.__platformNotificationLastId === undefined) {
                window.__platformNotificationLastId = latestId;
                return;
            }

            if (latestId && latestId !== window.__platformNotificationLastId) {
                window.__platformNotificationLastId = latestId;
                showToast(payload.latest);
            } else if (!latestId) {
                window.__platformNotificationLastId = null;
            }
        } catch (_) {}
    }

    function startNotificationPolling() {
        if (window.__platformNotificationTimer) {
            clearInterval(window.__platformNotificationTimer);
        }
        pollNotifications();
        window.__platformNotificationTimer = setInterval(pollNotifications, 15000);
    }

    if (!window.__platformNotificationPollingBound) {
        window.__platformNotificationPollingBound = true;
        document.addEventListener('DOMContentLoaded', startNotificationPolling, { once: true });
        document.addEventListener('livewire:navigated', startNotificationPolling);
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden) pollNotifications();
        });
    }

    if (document.readyState !== 'loading') {
        startNotificationPolling();
    }
})();
</script>
@endauth
