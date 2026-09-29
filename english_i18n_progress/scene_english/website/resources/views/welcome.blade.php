
<html lang="ar" dir="rtl" class="dark">
<head>
    {{-- Railway-safe conditionals build 2026-08-10-v3 --}}
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    {{-- Favicon V2: transparent edges + explicit sizes + cache busting. --}}
    <link rel="icon" type="image/png" sizes="32x32" href="{{ asset('favicon-32x32.png') }}?v=20260928b">
    <link rel="icon" type="image/png" sizes="16x16" href="{{ asset('favicon-16x16.png') }}?v=20260928b">
    <link rel="shortcut icon" type="image/x-icon" href="{{ asset('favicon.ico') }}?v=20260928b">
    <link rel="apple-touch-icon" sizes="180x180" href="{{ asset('apple-touch-icon.png') }}?v=20260928b">
    <link rel="manifest" href="{{ asset('site.webmanifest') }}?v=20260928b">


    <title>منصة الوليد الهندسية | للاستشارات الهندسية </title>

    <meta
        name="description"
        content="منصة الوليد الهندسية منصة هندسية متكاملة للاستشارات الهندسية والتصميم المعماري والإنشائي والكهربائي والميكانيكي والتصميم الداخلي وتصميم الواجهات واللاند سكيب ومتابعة المشاريع."
    >

    <meta
        name="keywords"
        content="منصة الوليد الهندسية, منصة الوليد الهندسية, استشارات هندسية, تصميم معماري, تصميم إنشائي, تصميم داخلي, تصميم واجهات, لاند سكيب, مهندسين, خدمات هندسية"
    >

    <meta
        name="robots"
        content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"
    >
<link rel="canonical" href="https://alwaleedoffice.com/">
    <link
        rel="canonical"
        href="{{ url('/') }}"
    >

    <meta
        property="og:locale"
        content="ar_AR"
    >

    <meta
        property="og:type"
        content="website"
    >

    <meta
        property="og:title"
        content="منصة الوليد الهندسية | منصة الاستشارات والخدمات الهندسية"
    >

    <meta
        property="og:description"
        content="منصة هندسية متكاملة تجمع العملاء والمهندسين وتوفر الاستشارات والتصميم ومتابعة المشاريع."
    >

    <meta
        property="og:url"
        content="{{ url('/') }}"
    >

    <meta
        property="og:site_name"
        content="منصة الوليد الهندسية"
    >

    <meta
        property="og:image"
        content="{{ asset('images/Mainlogo.png') }}"
    >

    <meta
        name="twitter:card"
        content="summary_large_image"
    >

    <meta
        name="twitter:title"
        content="منصة الوليد الهندسية | منصة الاستشارات والخدمات الهندسية"
    >

    <meta
        name="twitter:description"
        content="منصة الوليد الهندسية منصة متكاملة للاستشارات والخدمات والمشاريع الهندسية."
    >

    <meta
        name="twitter:image"
        content="{{ asset('images/Mainlogo.png') }}"
    >

    <script type="application/ld+json">
    {
        "@@context": "https://schema.org",
        "@@type": "WebSite",
        "name": "منصة الوليد الهندسية",
        "alternateName": [
            "منصة الوليد الهندسية",
            "Alwaleed Engineering",
            "Alwaleed منصة الوليد الهندسيةة"
        ],
        "url": "{{ url('/') }}"
    }
    </script>

    <script type="application/ld+json">
    {
        "@@context": "https://schema.org",
        "@@type": "Organization",
        "name": "منصة الوليد الهندسية",
        "alternateName": "منصة الوليد الهندسية",
        "url": "{{ url('/') }}",
        "logo": "{{ asset('images/Mainlogo.png') }}",
        "description": "منصة متكاملة للاستشارات والخدمات والمشاريع الهندسية."
    }
    </script>

    <link rel="preconnect" href="https://fonts.bunny.net">
    <link
        href="https://fonts.bunny.net/css?family=almarai:400,500,700,800&display=swap"
        rel="stylesheet"
    >

    @vite(['resources/css/app.css', 'resources/js/app.js'])

    {{-- Building scroll hero — exact visual motion from approved reference, page components preserved --}}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://cdnjs.cloudflare.com" crossorigin>
    <link rel="dns-prefetch" href="//cdnjs.cloudflare.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;500&family=Reem+Kufi:wght@500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="{{ asset('css/building-scroll-hero.css') }}?v=20260929-en-scene">

    <style>
        :root {
            --surface: var(--awl-bg-0b1326, #0b1326);
            --surface-lowest: var(--awl-bg-060e20, #060e20);
            --surface-low: var(--awl-bg-131b2e, #131b2e);
            --surface-container: var(--awl-bg-171f33, #171f33);
            --surface-high: var(--awl-bg-222a3d, #222a3d);
            --surface-highest: var(--awl-bg-2d3449, #2d3449);
            --on-surface: var(--awl-bg-dae2fd, #dae2fd);
            --on-surface-variant: var(--awl-bg-c3c6d7, #c3c6d7);
            --primary: #60a5fa;
            --primary-container: #2563eb;
            --secondary: #60a5fa;
            --tertiary: #60a5fa;
            --outline: var(--awl-bd-8d90a0, #8d90a0);
            --outline-variant: var(--awl-bd-434655, #434655);
        }

        html {
            scroll-behavior: smooth;
        }

        body {
            margin: 0;
            overflow-x: hidden;
            color: var(--on-surface);
            background: var(--surface);
            font-family: Almarai, sans-serif;
        }

        .glass-card {
            background: var(--awl-bg-2d3449-400, rgba(45, 52, 73, .4));
            backdrop-filter: blur(12px);
            border: 1px solid var(--awl-bd-ffffff-050, rgba(255, 255, 255, .05));
            transition: all .3s ease;
        }

        .glass-card:hover {
            background: var(--awl-bg-2d3449-600, rgba(45, 52, 73, .6));
            border-color: var(--awl-bd-b4c5ff-300, rgba(180, 197, 255, .3));
            transform: translateY(-4px);
        }

        .gradient-text {
            background: linear-gradient(135deg, var(--awl-fg-60a5fa, #60a5fa) 0%, var(--awl-fg-60a5fa, #60a5fa) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .reveal {
            opacity: 0;
            transform: translateY(30px);
            transition: all .8s ease-out;
        }

        .reveal.active {
            opacity: 1;
            transform: translateY(0);
        }

        .nav-link::after {
            display: block;
            width: 0;
            height: 2px;
            content: "";
            background: var(--primary);
            transition: width .3s;
        }

        .nav-link:hover::after {
            width: 100%;
        }

        #welcome-mobile-menu {
            animation: welcomeMenuIn .24s ease-out;
        }

        @@keyframes welcomeMenuIn {
            from {
                opacity: 0;
                transform: translateY(-10px);
            }

            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
    </style>
    <link rel="stylesheet" href="{{ asset('css/welcome-theme.css') }}?v=20260908-old-blue-final-2">

    <style id="legacy-blue-theme-override">
        /* الهوية الزرقاء القديمة - تثبيت نهائي فوق welcome-theme.css */
        :root {
            --primary: #60a5fa !important;
            --primary-container: #2563eb !important;
            --secondary: #60a5fa !important;
            --tertiary: #3b82f6 !important;
        }

        .gradient-text {
            background: linear-gradient(135deg, var(--awl-fg-60a5fa, #60a5fa) 0%, var(--awl-fg-2563eb, #2563eb) 100%) !important;
            -webkit-background-clip: text !important;
            background-clip: text !important;
            -webkit-text-fill-color: transparent !important;
        }

        .welcome-platform .nav-link::after {
            background: #60a5fa !important;
        }

        .welcome-platform .glass-card:hover {
            border-color: rgba(96, 165, 250, .35) !important;
        }

        /* أي مكوّن من الثيم كان يعتمد ألوانًا جانبية يصبح أزرق */
        .welcome-platform [class*="text-violet-"],
        .welcome-platform [class*="text-purple-"],
        .welcome-platform [class*="text-pink-"],
        .welcome-platform [class*="text-emerald-"],
        .welcome-platform [class*="text-cyan-"],
        .welcome-platform [class*="text-amber-"] {
            color: var(--awl-fg-60a5fa, #60a5fa) !important;
        }

        .welcome-platform [class*="bg-violet-"],
        .welcome-platform [class*="bg-purple-"],
        .welcome-platform [class*="bg-pink-"],
        .welcome-platform [class*="bg-emerald-"],
        .welcome-platform [class*="bg-cyan-"],
        .welcome-platform [class*="bg-amber-"] {
            background-color: rgba(37, 99, 235, .14) !important;
        }

        .welcome-platform [class*="border-violet-"],
        .welcome-platform [class*="border-purple-"],
        .welcome-platform [class*="border-pink-"],
        .welcome-platform [class*="border-emerald-"],
        .welcome-platform [class*="border-cyan-"],
        .welcome-platform [class*="border-amber-"] {
            border-color: rgba(96, 165, 250, .32) !important;
        }
    </style>
    <script defer src="{{ asset('js/welcome-theme.js') }}?v=20260908-old-blue-final-2"></script>

    <style id="force-old-blue-final">
        /*
         * OLD BLUE — FORCE FINAL
         * هذا البلوك محمّل بعد welcome-theme.css ويكسر أي ألوان بنفسجية
         * دون تغيير تخطيط الصفحة أو وظائفها.
         */
        body.welcome-platform {
            --surface: var(--awl-bg-071426, #071426) !important;
            --surface-lowest: var(--awl-bg-040b16, #040b16) !important;
            --surface-low: var(--awl-bg-0a172b, #0a172b) !important;
            --surface-container: var(--awl-bg-0d1b31, #0d1b31) !important;
            --surface-high: var(--awl-bg-11233f, #11233f) !important;
            --surface-highest: var(--awl-bg-172d4d, #172d4d) !important;

            --on-surface: var(--awl-bg-eef6ff, #eef6ff) !important;
            --on-surface-variant: #b9cbe3 !important;

            --primary: #60a5fa !important;
            --primary-container: #2563eb !important;
            --secondary: #3b82f6 !important;
            --tertiary: #60a5fa !important;

            --outline: var(--awl-bd-6d85a5, #6d85a5) !important;
            --outline-variant: var(--awl-bd-29415f, #29415f) !important;

            color: var(--awl-fg-eef6ff, #eef6ff) !important;
            background: var(--awl-bg-071426, #071426) !important;
        }

        html,
        body,
        .welcome-platform,
        .welcome-platform .wp-main {
            background-color: var(--awl-bg-071426, #071426) !important;
        }

        /* الهيدر */
        .welcome-platform .wp-header {
            background: var(--awl-bg-040b16-940, rgba(4, 11, 22, .94)) !important;
            border-color: rgba(59, 130, 246, .20) !important;
            box-shadow: 0 10px 35px var(--awl-sh-001946-220, rgba(0, 25, 70, .22)) !important;
        }

        .welcome-platform .wp-brand > span:first-child {
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
            background: rgba(37, 99, 235, .18) !important;
            border-color: rgba(96, 165, 250, .24) !important;
        }

        .welcome-platform .wp-brand > span:last-child,
        .welcome-platform .nav-link,
        .welcome-platform .wp-account a {
            text-shadow: none !important;
        }

        .welcome-platform .nav-link::after {
            background: #3b82f6 !important;
        }

        /* المساعد الذكي */
        .welcome-platform [data-open-welcome-assistant] {
            color: var(--awl-fg-bfdbfe, #bfdbfe) !important;
            background: rgba(37, 99, 235, .12) !important;
            border-color: rgba(96, 165, 250, .30) !important;
            box-shadow: none !important;
        }

        .welcome-platform [data-open-welcome-assistant]:hover {
            color: var(--awl-fg-ffffff, #ffffff) !important;
            background: rgba(37, 99, 235, .24) !important;
            border-color: rgba(96, 165, 250, .55) !important;
        }

        /* أزرار الأزرق — يلغي أي Gradient بنفسجي من الثيم */
        .welcome-platform .bg-blue-600,
        .welcome-platform a.bg-blue-600,
        .welcome-platform button.bg-blue-600,
        .welcome-platform [class*="bg-blue-600"] {
            background-color: #2563eb !important;
            background-image: none !important;
            color: var(--awl-fg-ffffff, #ffffff) !important;
            border-color: #2563eb !important;
            box-shadow: 0 10px 28px rgba(37, 99, 235, .23) !important;
        }

        .welcome-platform .bg-blue-600:hover,
        .welcome-platform a.bg-blue-600:hover,
        .welcome-platform button.bg-blue-600:hover {
            background-color: #1d4ed8 !important;
            background-image: none !important;
        }

        /* النص المتدرج */
        .welcome-platform .gradient-text {
            background: linear-gradient(135deg, var(--awl-fg-60a5fa, #60a5fa) 0%, var(--awl-fg-2563eb, #2563eb) 100%) !important;
            -webkit-background-clip: text !important;
            background-clip: text !important;
            -webkit-text-fill-color: transparent !important;
            color: var(--awl-fg-3b82f6, #3b82f6) !important;
        }

        /* HERO — الخلفية والصورة */
        .welcome-platform .welcome-cinema,
        .welcome-platform .wc-frame {
            background-color: #061226 !important;
            background-image: none !important;
        }

        /* تحويل البنفسجي الموجود داخل صور المخطط والمبنى إلى أزرق */
        .welcome-platform .wc-blueprint,
        .welcome-platform .wc-built {
            filter: hue-rotate(315deg) saturate(1.18) brightness(.96) !important;
        }

        .welcome-platform .wc-shade {
            background:
                linear-gradient(
                    90deg,
                    var(--awl-bg-040c1c-020, rgba(4, 12, 28, .02)) 0%,
                    var(--awl-bg-051127-180, rgba(5, 17, 39, .18)) 40%,
                    var(--awl-bg-051024-780, rgba(5, 16, 36, .78)) 63%,
                    var(--awl-bg-050f22-960, rgba(5, 15, 34, .96)) 78%,
                    var(--awl-bg-071426, #071426) 100%
                ) !important;
        }

        .welcome-platform .wc-mist {
            background:
                radial-gradient(circle at 70% 42%, rgba(37, 99, 235, .22), transparent 42%),
                radial-gradient(circle at 28% 58%, rgba(59, 130, 246, .13), transparent 48%) !important;
        }

        .welcome-platform .wc-wave {
            background:
                linear-gradient(
                    90deg,
                    transparent 0%,
                    rgba(96, 165, 250, .16) 45%,
                    rgba(37, 99, 235, .30) 53%,
                    rgba(96, 165, 250, .10) 61%,
                    transparent 100%
                ) !important;
        }

        .welcome-platform .wc-copy > div:first-child {
            color: var(--awl-fg-bfdbfe, #bfdbfe) !important;
            background: rgba(37, 99, 235, .12) !important;
            border-color: rgba(96, 165, 250, .28) !important;
        }

        .welcome-platform .wc-meter {
            background: rgba(96, 165, 250, .16) !important;
        }

        .welcome-platform .wc-meter > span {
            background: #3b82f6 !important;
            box-shadow: 0 0 15px rgba(59, 130, 246, .55) !important;
        }

        .welcome-platform .wc-step.is-active,
        .welcome-platform .wc-skip,
        .welcome-platform .wc-play {
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
        }

        /* الأقسام: إزالة أي توهج/خلفية بنفسجية */
        .welcome-platform .wp-stats,
        .welcome-platform .wp-services,
        .welcome-platform .wp-process,
        .welcome-platform .wp-works,
        .welcome-platform .wp-engineers,
        .welcome-platform .wp-offices,
        .welcome-platform .wp-feedback {
            background-color: var(--awl-bg-071426, #071426) !important;
            background-image: none !important;
        }

        .welcome-platform .wp-services,
        .welcome-platform .wp-works,
        .welcome-platform .wp-feedback {
            background-color: var(--awl-bg-09172b, #09172b) !important;
        }

        .welcome-platform .wp-offices {
            background-color: var(--awl-bg-081529, #081529) !important;
        }

        /* جميع البطاقات */
        .welcome-platform .glass-card,
        .welcome-platform .wp-stat,
        .welcome-platform .wp-service-card,
        .welcome-platform .wp-work-card,
        .welcome-platform .wp-engineer-card,
        .welcome-platform .wp-office-card,
        .welcome-platform .wp-feedback-card {
            background:
                linear-gradient(
                    145deg,
                    var(--awl-bg-0f223e-940, rgba(15, 34, 62, .94)) 0%,
                    var(--awl-bg-08172b-960, rgba(8, 23, 43, .96)) 100%
                ) !important;
            border-color: rgba(96, 165, 250, .16) !important;
            box-shadow: none !important;
        }

        .welcome-platform .glass-card:hover,
        .welcome-platform .wp-service-card:hover,
        .welcome-platform .wp-work-card:hover,
        .welcome-platform .wp-engineer-card:hover,
        .welcome-platform .wp-office-card:hover,
        .welcome-platform .wp-feedback-card:hover {
            background:
                linear-gradient(
                    145deg,
                    var(--awl-bg-122c4f-980, rgba(18, 44, 79, .98)) 0%,
                    var(--awl-bg-091c34-980, rgba(9, 28, 52, .98)) 100%
                ) !important;
            border-color: rgba(96, 165, 250, .40) !important;
        }

        /* حاويات الأيقونات داخل البطاقات */
        .welcome-platform .wp-stat > div:first-child,
        .welcome-platform .wp-service-card > div:first-child {
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
            background: rgba(37, 99, 235, .15) !important;
            border-color: rgba(96, 165, 250, .22) !important;
            box-shadow: none !important;
        }

        .welcome-platform .wp-service-card svg,
        .welcome-platform .wp-stat svg,
        .welcome-platform .wp-process-step svg,
        .welcome-platform .wp-engineer-card svg,
        .welcome-platform .wp-office-card svg,
        .welcome-platform .wp-feedback-card svg {
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
            stroke: currentColor !important;
        }

        /* الإحصائيات */
        .welcome-platform .wp-stat h3,
        .welcome-platform .wp-stat [class*="text-"] {
            color: var(--awl-fg-60a5fa, #60a5fa) !important;
        }

        /* خطوات العمل */
        .welcome-platform .wp-process-line {
            background: rgba(96, 165, 250, .18) !important;
        }

        .welcome-platform .wp-process-step > div:first-child {
            background: var(--awl-bg-112a4d, #112a4d) !important;
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
            border-color: rgba(96, 165, 250, .34) !important;
        }

        .welcome-platform .wp-process-step:first-of-type > div:first-child {
            background: #2563eb !important;
            color: var(--awl-fg-ffffff, #ffffff) !important;
            border-color: #3b82f6 !important;
        }

        /* المهندسون والمكاتب والشارات */
        .welcome-platform .wp-engineer-card [class*="bg-blue-600/20"],
        .welcome-platform .wp-work-card [class*="bg-blue-600/20"],
        .welcome-platform .wp-office-card [class*="bg-blue-"] {
            background-color: rgba(37, 99, 235, .16) !important;
            background-image: none !important;
        }

        .welcome-platform .wp-office-cover {
            background:
                linear-gradient(
                    135deg,
                    rgba(37, 99, 235, .28),
                    rgba(59, 130, 246, .10)
                ) !important;
        }

        /* الروابط والألوان الثانوية */
        .welcome-platform a[class*="text-[#60a5fa]"],
        .welcome-platform [class*="text-blue-"],
        .welcome-platform [class*="text-cyan-"],
        .welcome-platform [class*="text-violet-"],
        .welcome-platform [class*="text-purple-"],
        .welcome-platform [class*="text-pink-"],
        .welcome-platform [class*="text-emerald-"],
        .welcome-platform [class*="text-amber-"] {
            color: var(--awl-fg-60a5fa, #60a5fa) !important;
        }

        /* أي خلفية جانبية ملوّنة تصبح أزرق */
        .welcome-platform [class*="bg-violet-"],
        .welcome-platform [class*="bg-purple-"],
        .welcome-platform [class*="bg-pink-"],
        .welcome-platform [class*="bg-cyan-"],
        .welcome-platform [class*="bg-emerald-"],
        .welcome-platform [class*="bg-amber-"] {
            background-color: rgba(37, 99, 235, .14) !important;
            background-image: none !important;
        }

        .welcome-platform [class*="border-violet-"],
        .welcome-platform [class*="border-purple-"],
        .welcome-platform [class*="border-pink-"],
        .welcome-platform [class*="border-cyan-"],
        .welcome-platform [class*="border-emerald-"],
        .welcome-platform [class*="border-amber-"] {
            border-color: rgba(96, 165, 250, .30) !important;
        }

        /* منع أي توهج بنفسجي من pseudo elements داخل الثيم */
        .welcome-platform .wp-main::before,
        .welcome-platform .wp-main::after,
        .welcome-platform .welcome-cinema::before,
        .welcome-platform .welcome-cinema::after,
        .welcome-platform .wc-frame::before,
        .welcome-platform .wc-frame::after,
        .welcome-platform .wp-service-card::before,
        .welcome-platform .wp-service-card::after,
        .welcome-platform .glass-card::before,
        .welcome-platform .glass-card::after {
            border-color: rgba(59, 130, 246, .18) !important;
            box-shadow: none !important;
        }

        /* القائمة على الهاتف */
        .welcome-platform #welcome-mobile-menu {
            background: var(--awl-bg-040b16-980, rgba(4, 11, 22, .98)) !important;
            border-color: rgba(59, 130, 246, .18) !important;
        }
    </style>


    <style id="force-blue-feedback-cta">
        /* إصلاح نهائي لصندوق الملاحظات وصندوق CTA */
        .welcome-platform .wp-feedback-submit {
            background:
                linear-gradient(
                    135deg,
                    var(--awl-bg-0d223e-980, rgba(13, 34, 62, .98)) 0%,
                    var(--awl-bg-08182e-980, rgba(8, 24, 46, .98)) 100%
                ) !important;
            background-color: var(--awl-bg-0b1d36, #0b1d36) !important;
            background-image:
                linear-gradient(
                    135deg,
                    var(--awl-bg-0d223e-980, rgba(13, 34, 62, .98)) 0%,
                    var(--awl-bg-08182e-980, rgba(8, 24, 46, .98)) 100%
                ) !important;
            border-color: rgba(96, 165, 250, .28) !important;
            box-shadow: none !important;
        }

        .welcome-platform .wp-cta {
            background: var(--awl-bg-071426, #071426) !important;
            background-image: none !important;
        }

        .welcome-platform .wp-cta-panel {
            background:
                linear-gradient(
                    135deg,
                    var(--awl-bg-0e2747, #0e2747) 0%,
                    var(--awl-bg-0a1c35, #0a1c35) 55%,
                    var(--awl-bg-071426, #071426) 100%
                ) !important;
            background-color: var(--awl-bg-0a1c35, #0a1c35) !important;
            background-image:
                linear-gradient(
                    135deg,
                    var(--awl-bg-0e2747, #0e2747) 0%,
                    var(--awl-bg-0a1c35, #0a1c35) 55%,
                    var(--awl-bg-071426, #071426) 100%
                ) !important;
            border-color: rgba(96, 165, 250, .30) !important;
            box-shadow: none !important;
        }

        /* إلغاء أي طبقات بنفسجية من ملفات الثيم الخارجية */
        .welcome-platform .wp-feedback-submit::before,
        .welcome-platform .wp-feedback-submit::after,
        .welcome-platform .wp-cta-panel::before,
        .welcome-platform .wp-cta-panel::after {
            background: transparent !important;
            background-image: none !important;
            box-shadow: none !important;
            border-color: transparent !important;
        }

        /* الدائرتان الضبابيتان داخل CTA */
        .welcome-platform .wp-cta-panel > .absolute {
            background-color: rgba(37, 99, 235, .18) !important;
            background-image: none !important;
            filter: blur(42px) !important;
        }

        .welcome-platform .wp-feedback-submit h3,
        .welcome-platform .wp-cta-panel h2 {
            color: var(--awl-fg-eef6ff, #eef6ff) !important;
        }

        .welcome-platform .wp-feedback-submit p,
        .welcome-platform .wp-cta-panel p {
            color: var(--awl-fg-b9cbe3, #b9cbe3) !important;
        }

        .welcome-platform .wp-feedback-submit .bg-blue-600,
        .welcome-platform .wp-cta-panel .bg-blue-600 {
            background: #2563eb !important;
            background-image: none !important;
            color: var(--awl-fg-ffffff, #ffffff) !important;
            border-color: #2563eb !important;
        }

        .welcome-platform .wp-feedback-submit .bg-blue-600:hover,
        .welcome-platform .wp-cta-panel .bg-blue-600:hover {
            background: #1d4ed8 !important;
        }

        .welcome-platform .wp-cta-panel .bg-white\/5 {
            background-color: var(--awl-bg-ffffff-050, rgba(255, 255, 255, .05)) !important;
            border-color: rgba(96, 165, 250, .20) !important;
        }
    </style>


    <style id="office-card-blue-fix-v3">
        .welcome-platform .wp-office-card .wp-office-cover {
            background: var(--awl-bg-0d2442, #0d2442) !important;
            background-image: none !important;
        }

        .welcome-platform .wp-office-card .wp-office-cover > img {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            filter: none !important;
            mix-blend-mode: normal !important;
            position: absolute !important;
            inset: 0 !important;
            width: 100% !important;
            height: 100% !important;
            object-fit: cover !important;
            z-index: 0 !important;
        }

        .welcome-platform .wp-office-open-btn {
            background: #2563eb !important;
            background-color: #2563eb !important;
            background-image: none !important;
            color: var(--awl-fg-ffffff, #ffffff) !important;
            border-color: #2563eb !important;
            box-shadow: 0 8px 22px rgba(37, 99, 235, .22) !important;
        }

        .welcome-platform .wp-office-open-btn:hover {
            background: #1d4ed8 !important;
            background-color: #1d4ed8 !important;
            background-image: none !important;
        }

        .welcome-platform .wp-office-card .wp-office-body > .flex > div:first-child {
            background: var(--awl-bg-0d2442, #0d2442) !important;
            border-color: rgba(96, 165, 250, .28) !important;
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
            box-shadow: none !important;
        }

        .welcome-platform .wp-office-card .wp-office-body > .flex > div:first-child svg {
            color: var(--awl-fg-93c5fd, #93c5fd) !important;
        }

        .welcome-platform .wp-office-card .wp-office-metrics > div {
            background: var(--awl-bg-102847, #102847) !important;
            border: 1px solid rgba(96, 165, 250, .12) !important;
        }
    </style>

    <style id="cta-reference-match-v5">
        .welcome-platform .wp-cta {
            padding: 72px 24px !important;
        }
        .welcome-platform .wp-cta-panel {
            position: relative !important;
            display: grid !important;
            grid-template-columns: 52% 48% !important;
            min-height: 510px !important;
            padding: 0 !important;
            overflow: hidden !important;
            border-radius: 34px !important;
            border: 1px solid rgba(96, 165, 250, .24) !important;
            background: var(--awl-bg-071a38, #071a38) !important;
            box-shadow: 0 22px 60px var(--awl-sh-0f172a-120, rgba(15, 23, 42, .12)) !important;
            text-align: right !important;
        }
        .welcome-platform .wp-cta-panel::before,
        .welcome-platform .wp-cta-panel::after {
            content: none !important;
            display: none !important;
        }
        .welcome-platform .wp-cta-media {
            position: relative !important;
            grid-column: 1 !important;
            grid-row: 1 !important;
            min-width: 0 !important;
            overflow: hidden !important;
            background: var(--awl-bg-0b1f3d, #0b1f3d) !important;
        }
        .welcome-platform .wp-cta-building-image {
            position: absolute !important;
            inset: 0 !important;
            display: block !important;
            width: 100% !important;
            height: 100% !important;
            object-fit: cover !important;
            object-position: 49% center !important;
            filter: none !important;
            opacity: 1 !important;
            z-index: 0 !important;
        }
        .welcome-platform .wp-cta-media::after {
            content: "" !important;
            display: block !important;
            position: absolute !important;
            inset: 0 !important;
            background: linear-gradient(90deg, var(--awl-bg-061937-000, rgba(6,25,55,0)) 0%, var(--awl-bg-061937-020, rgba(6,25,55,.02)) 63%, var(--awl-bg-061937-420, rgba(6,25,55,.42)) 86%, var(--awl-bg-071a38, #071a38) 100%) !important;
            pointer-events: none !important;
            z-index: 1 !important;
        }
        .welcome-platform .wp-cta-content {
            grid-column: 2 !important;
            grid-row: 1 !important;
            width: auto !important;
            min-width: 0 !important;
            margin: 0 !important;
            padding: 58px 54px 38px !important;
            display: flex !important;
            flex-direction: column !important;
            justify-content: center !important;
            position: relative !important;
            z-index: 3 !important;
            text-align: right !important;
            background: radial-gradient(circle at 82% 18%, rgba(37,99,235,.13), transparent 28%), linear-gradient(135deg,var(--awl-bg-0a2248, #0a2248) 0%,var(--awl-bg-071a38, #071a38) 58%,var(--awl-bg-05152e, #05152e) 100%) !important;
        }
        .welcome-platform .wp-cta-kicker {
            color: var(--awl-fg-60a5fa, #60a5fa) !important;
            font-size: 13px !important;
            font-weight: 800 !important;
            letter-spacing: .02em !important;
            margin-bottom: 10px !important;
        }
        .welcome-platform .wp-cta-title {
            margin: 0 !important;
            color: var(--awl-fg-ffffff, #fff) !important;
            font-size: clamp(32px,3.2vw,54px) !important;
            line-height: 1.22 !important;
            font-weight: 950 !important;
            letter-spacing: -.02em !important;
        }
        .welcome-platform .wp-cta-title .wp-cta-title-accent { color: var(--awl-fg-2f80ff, #2f80ff) !important; }
        .welcome-platform .wp-cta-description {
            max-width: 590px !important;
            margin: 22px 0 0 !important;
            color: var(--awl-fg-c5d1e4, #c5d1e4) !important;
            font-size: clamp(15px,1.3vw,19px) !important;
            line-height: 1.95 !important;
            font-weight: 500 !important;
        }
        .welcome-platform .wp-cta-actions {
            display: flex !important;
            align-items: center !important;
            justify-content: flex-start !important;
            gap: 12px !important;
            margin-top: 30px !important;
        }
        .welcome-platform .wp-cta-primary {
            display: inline-flex !important;
            align-items: center !important;
            justify-content: center !important;
            gap: 12px !important;
            min-width: 178px !important;
            min-height: 56px !important;
            padding: 13px 24px !important;
            border: 1px solid rgba(96,165,250,.55) !important;
            border-radius: 18px !important;
            background: linear-gradient(135deg,#2563eb 0%,#2d8cff 100%) !important;
            color: var(--awl-fg-ffffff, #fff) !important;
            font-size: 17px !important;
            font-weight: 900 !important;
            box-shadow: 0 14px 28px rgba(37,99,235,.26) !important;
            transition: transform .2s ease, box-shadow .2s ease, filter .2s ease !important;
        }
        .welcome-platform .wp-cta-primary:hover {
            transform: translateY(-2px) !important;
            filter: brightness(1.04) !important;
            box-shadow: 0 18px 36px rgba(37,99,235,.34) !important;
        }
        .welcome-platform .wp-cta-primary-icon {
            width: 34px !important;
            height: 34px !important;
            border-radius: 999px !important;
            display: inline-flex !important;
            align-items: center !important;
            justify-content: center !important;
            background: var(--awl-bg-071a38-280, rgba(7,26,56,.28)) !important;
            border: 1px solid var(--awl-bd-ffffff-140, rgba(255,255,255,.14)) !important;
            flex: 0 0 auto !important;
        }
        .welcome-platform .wp-cta-features {
            display: grid !important;
            grid-template-columns: repeat(3,minmax(0,1fr)) !important;
            gap: 0 !important;
            margin-top: 42px !important;
            direction: rtl !important;
        }
        .welcome-platform .wp-cta-feature {
            min-width: 0 !important;
            padding: 0 22px !important;
            text-align: center !important;
            position: relative !important;
        }
        .welcome-platform .wp-cta-feature:first-child { padding-right: 0 !important; }
        .welcome-platform .wp-cta-feature:last-child { padding-left: 0 !important; }
        .welcome-platform .wp-cta-feature + .wp-cta-feature { border-right: 1px solid var(--awl-bd-94a3b8-220, rgba(148,163,184,.22)) !important; }
        .welcome-platform .wp-cta-feature-icon {
            width: 38px !important;
            height: 38px !important;
            margin: 0 auto 9px !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            color: var(--awl-fg-2f80ff, #2f80ff) !important;
        }
        .welcome-platform .wp-cta-feature-icon svg { width: 31px !important; height: 31px !important; }
        .welcome-platform .wp-cta-feature strong {
            display: block !important;
            color: var(--awl-fg-ffffff, #fff) !important;
            font-size: 15px !important;
            line-height: 1.45 !important;
            font-weight: 900 !important;
        }
        .welcome-platform .wp-cta-feature span {
            display: block !important;
            margin-top: 5px !important;
            color: var(--awl-fg-9fb0c9, #9fb0c9) !important;
            font-size: 12px !important;
            line-height: 1.65 !important;
            font-weight: 500 !important;
        }
        @media (max-width: 1023px) {
            .welcome-platform .wp-cta-panel { grid-template-columns: 48% 52% !important; min-height: 470px !important; }
            .welcome-platform .wp-cta-content { padding: 44px 34px 30px !important; }
            .welcome-platform .wp-cta-features { margin-top: 32px !important; }
            .welcome-platform .wp-cta-feature { padding: 0 12px !important; }
        }
        @media (max-width: 767px) {
            .welcome-platform .wp-cta { padding: 48px 16px !important; }
            .welcome-platform .wp-cta-panel { display: flex !important; flex-direction: column !important; min-height: 0 !important; border-radius: 26px !important; }
            .welcome-platform .wp-cta-media { width: 100% !important; height: 285px !important; flex: 0 0 285px !important; }
            .welcome-platform .wp-cta-building-image { object-position: center 48% !important; }
            .welcome-platform .wp-cta-media::after { background: linear-gradient(180deg,var(--awl-bg-071a38-000, rgba(7,26,56,0)) 45%,var(--awl-bg-071a38-450, rgba(7,26,56,.45)) 74%,var(--awl-bg-071a38, #071a38) 100%) !important; }
            .welcome-platform .wp-cta-content { width: 100% !important; padding: 32px 22px 26px !important; text-align: center !important; align-items: center !important; margin-top: -1px !important; }
            .welcome-platform .wp-cta-title { font-size: clamp(29px,9vw,40px) !important; }
            .welcome-platform .wp-cta-description { margin-top: 15px !important; font-size: 15px !important; }
            .welcome-platform .wp-cta-actions { justify-content: center !important; margin-top: 22px !important; }
            .welcome-platform .wp-cta-primary { min-width: 190px !important; min-height: 52px !important; font-size: 16px !important; }
            .welcome-platform .wp-cta-features { width: 100% !important; grid-template-columns: 1fr !important; gap: 0 !important; margin-top: 28px !important; }
            .welcome-platform .wp-cta-feature { padding: 16px 0 !important; }
            .welcome-platform .wp-cta-feature + .wp-cta-feature { border-right: 0 !important; border-top: 1px solid var(--awl-bd-94a3b8-200, rgba(148,163,184,.20)) !important; }
        }
    </style>



    <style id="welcome-exact-performance">
        /* Phase 8–15.9: the supplied reference is the source of truth for the Welcome hero. */
        .welcome-platform > .wp-header {
            display:flex !important;
            opacity:0;
            visibility:hidden;
            pointer-events:none;
            transform:translateY(-110%);
            transition:opacity .28s ease, transform .34s cubic-bezier(.2,.8,.2,1), visibility 0s linear .34s;
            will-change:opacity,transform;
        }
        .welcome-platform > .wp-header.is-scene-complete {
            opacity:1;
            visibility:visible;
            pointer-events:auto;
            transform:translateY(0);
            transition-delay:0s;
        }
        .welcome-platform .wp-main {
            padding-top:0 !important;
        }
        .welcome-platform #home {
            font-family:"IBM Plex Sans Arabic",Tahoma,system-ui,sans-serif !important;
            background:#0F2F4F !important;
        }
        .welcome-platform #home .bh-top {
            display:flex !important;
        }
        .welcome-platform #home .bh-stage {
            top:0 !important;
            height:100vh !important;
            height:100svh !important;
        }
        /* Keep the existing page sections fast after the exact hero. */
        .welcome-platform .wp-main > section:not(#home) {
            content-visibility:auto;
            contain-intrinsic-size:900px;
        }
        @media (max-width: 768px) {
            .welcome-platform .glass-card {
                backdrop-filter:none !important;
                -webkit-backdrop-filter:none !important;
            }
            .welcome-platform .reveal {
                transition:none !important;
                transform:none !important;
                opacity:1 !important;
            }
        }
    </style>


    {{-- Light/dark preference shared with all site views. --}}
    @include('components.daylight-theme')
<style id="awl-download-modal-style">
    .awl-app-download-modal[hidden] { display: none !important; }
    .awl-app-download-modal { position: fixed; inset: 0; z-index: 2147483000; display: grid; place-items: center; padding: 18px; direction: rtl; }
    .awl-app-download-backdrop { position: absolute; inset: 0; background: var(--awl-bg-020a1c-720, rgba(2, 10, 28, .72)); backdrop-filter: blur(5px); -webkit-backdrop-filter: blur(5px); }
    .awl-app-download-panel { position: relative; width: min(100%, 360px); padding: 26px 24px 24px; border: 1px solid rgba(96, 165, 250, .32); border-radius: 22px; background: var(--awl-bg-101e39, #101e39); color: var(--awl-fg-eef6ff, #eef6ff); box-shadow: 0 24px 75px var(--awl-sh-000000-420, rgba(0, 0, 0, .42)); text-align: center; font-family: "Almarai", Tahoma, sans-serif; }
    .awl-app-download-close { position: absolute; top: 12px; left: 12px; width: 34px; height: 34px; border: 1px solid var(--awl-bd-93c5fd-300, rgba(147, 197, 253, .3)); border-radius: 50%; color: var(--awl-fg-eef6ff, #eef6ff); background: var(--awl-bg-ffffff-080, rgba(255, 255, 255, .08)); cursor: pointer; font-size: 22px; line-height: 1; }
    .awl-app-download-icon { width: 88px; height: 88px; margin: 2px auto 14px; object-fit: cover; border-radius: 21px; background: var(--awl-bg-ffffff, #fff); box-shadow: 0 7px 22px var(--awl-sh-000000-180, rgba(0, 0, 0, .18)); }
    .awl-app-download-title { font-size: 21px; font-weight: 800; line-height: 1.5; margin: 0 0 6px; color: inherit; }
    .awl-app-download-description { margin: 0 0 20px; font-size: 13px; line-height: 1.8; color: var(--awl-fg-c3d5ef, #c3d5ef); }
    .awl-app-download-action { display: flex; align-items: center; justify-content: center; gap: 9px; width: 100%; min-height: 48px; padding: 10px 16px; border-radius: 12px; font-weight: 800; font-size: 16px; color: var(--awl-fg-ffffff, #fff) !important; background: #2563eb; text-decoration: none !important; }
    .awl-app-download-action:hover, .awl-app-download-action:focus-visible { background: #1d4ed8; }
    .awl-app-download-unavailable { margin: 0; padding: 11px; background: var(--awl-bg-94a3b8-130, rgba(148, 163, 184, .13)); border-radius: 12px; color: var(--awl-fg-c3d5ef, #c3d5ef); font-size: 13px; line-height: 1.7; }
    .awl-app-download-close:focus-visible, [data-awl-app-download-open]:focus-visible { outline: 3px solid #60a5fa; outline-offset: 3px; }
    html[data-aw-theme="light"] .awl-app-download-backdrop { background: rgba(15, 23, 42, .52); }
    html[data-aw-theme="light"] .awl-app-download-panel { background: #fff; color: #102746; border-color: #c8d8ed; box-shadow: 0 24px 70px rgba(15, 36, 71, .22); }
    html[data-aw-theme="light"] .awl-app-download-close { color: #102746; background: #edf3fb; border-color: #c8d8ed; }
    html[data-aw-theme="light"] .awl-app-download-description { color: #40556f; }
    html[data-aw-theme="light"] .awl-app-download-unavailable { color: #40556f; background: #edf3fb; }
</style>
</head>

<body class="welcome-platform">
    {{-- Railway persistent storage: offer only the APK whose checked release was approved. --}}
    @php
        $appApkRelativePath = 'downloads/alwaleed-app.apk';
        $appApkApprovedMarker = 'downloads/.alwaleed-release-3fff23cb.ready';
        // The marker must be created ONLY after matching the server SHA-256 to the local release.
        // Both checks use the configured public disk so Railway volumes keep working after redeploys.
        $appApkHasLocalFile = \Illuminate\Support\Facades\Storage::disk('public')->exists($appApkRelativePath)
            && \Illuminate\Support\Facades\Storage::disk('public')->exists($appApkApprovedMarker);
        $appApkDownloadUrl = $appApkHasLocalFile
            ? route('public-storage.show', ['path' => $appApkRelativePath])
            : null;
    @endphp
    {{-- Build marker: 2026-08-10-2250 - forces fresh Railway Blade compile --}}
    {{-- شريط التنقل --}}
    <header
        class="wp-header fixed top-0 z-50 flex items-center w-full h-16 px-6 border-b shadow-sm bg-[#0b1326]/80 backdrop-blur-md border-[#434655]/10"
    >
        <div class="flex items-center justify-between w-full mx-auto max-w-7xl">
            <a
                href="{{ route('home') }}"
                class="flex items-center gap-3 wp-brand"
            >
                <span
                    class="flex items-center justify-center w-10 h-10 text-white rounded-xl bg-blue-600/20"
                    aria-hidden="true"
                >
                    <svg
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.8"
                        class="w-6 h-6"
                    >
                        <path d="M3 11.5 12 4l9 7.5"/>
                        <path d="M5.5 10.5V21h13V10.5"/>
                        <path d="M9 21v-6h6v6"/>
                    </svg>
                </span>

                <span class="text-xl font-extrabold text-[#60a5fa]">
                    منصة الوليد الهندسية
                </span>
            </a>

            <nav class="wp-nav items-center hidden gap-8 text-sm font-bold md:flex text-[#c3c6d7]">
                <a class="nav-link text-[#60a5fa]" href="#home">
                    الرئيسية
                </a>

                <a class="nav-link hover:text-white" href="#feedback">
                    الآراء والملاحظات
                </a>

                <a class="nav-link hover:text-white" href="#services">
                    خدماتنا
                </a>

                <a class="nav-link hover:text-white" href="#works">
                    أعمالنا
                </a>

                <a class="nav-link hover:text-white" href="#engineers">
                    المهندسون
                </a>

                <a class="nav-link hover:text-white" href="#how-it-works">
                    كيف نعمل
                </a>

                <button type="button" class="nav-link hover:text-white" data-awl-app-download-open aria-haspopup="dialog" aria-controls="awl-app-download-modal">تحميل التطبيق</button>

                <button
                    type="button"
                    data-open-welcome-assistant
                    class="inline-flex items-center gap-2 px-4 py-2 text-blue-200 transition border rounded-full border-blue-400/20 bg-blue-500/10 hover:border-blue-300/40 hover:bg-blue-500/20 hover:text-white"
                >
                    <span aria-hidden="true">🤖</span>
                    <span>المساعد الذكي</span>
                </button>
            </nav>

            <div class="items-center hidden gap-3 wp-account md:flex">
                <?php if (auth()->check()): ?>
                    <a
                        href="{{ route('dashboard') }}"
                        class="px-6 py-2 text-sm font-bold text-white transition bg-blue-600 rounded-full active:scale-95"
                    >
                        لوحة التحكم
                    </a>
                <?php else: ?>
                    <a
                        href="{{ route('login') }}"
                        class="px-4 py-2 text-sm font-bold text-[#c3c6d7] hover:text-white"
                    >
                        تسجيل الدخول
                    </a>

                    <a
                        href="{{ route('register') }}"
                        class="px-6 py-2 text-sm font-bold text-white transition bg-blue-600 rounded-full active:scale-95"
                    >
                        إنشاء حساب
                    </a>
                <?php endif; ?>
            </div>

            <button
                id="welcome-mobile-menu-button"
                type="button"
                aria-label="قائمة التنقل"
                aria-controls="welcome-mobile-menu"
                aria-expanded="false"
                class="flex items-center justify-center border w-11 h-11 md:hidden rounded-xl border-white/10 bg-white/5"
            >
                <svg
                    id="welcome-menu-open-icon"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    class="w-6 h-6"
                >
                    <path d="M4 6h16M4 12h16M4 18h16"/>
                </svg>

                <svg
                    id="welcome-menu-close-icon"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    class="hidden w-6 h-6"
                >
                    <path d="M6 18 18 6M6 6l12 12"/>
                </svg>
            </button>
        </div>
    </header>

    {{-- قائمة الهاتف --}}
    <div
        id="welcome-mobile-menu"
        class="fixed top-16 right-0 left-0 z-40 hidden px-4 py-5 border-b shadow-2xl md:hidden border-white/10 bg-[#0b1326]/95 backdrop-blur-2xl"
    >
        <div class="space-y-2">
            <a data-welcome-mobile-link href="#home" class="block px-4 py-3 rounded-xl hover:bg-white/5">
                الرئيسية
            </a>

            <a data-welcome-mobile-link href="#feedback" class="block px-4 py-3 rounded-xl hover:bg-white/5">
                الآراء والملاحظات
            </a>

            <a data-welcome-mobile-link href="#services" class="block px-4 py-3 rounded-xl hover:bg-white/5">
                خدماتنا
            </a>

            <a data-welcome-mobile-link href="#works" class="block px-4 py-3 rounded-xl hover:bg-white/5">
                أعمالنا
            </a>

            <a data-welcome-mobile-link href="#engineers" class="block px-4 py-3 rounded-xl hover:bg-white/5">
                المهندسون
            </a>

            <a data-welcome-mobile-link href="#how-it-works" class="block px-4 py-3 rounded-xl hover:bg-white/5">
                كيف نعمل
            </a>

            <button type="button" data-welcome-mobile-link data-awl-app-download-open
                    aria-haspopup="dialog" aria-controls="awl-app-download-modal"
                    class="block w-full px-4 py-3 font-bold text-right text-blue-200 rounded-xl bg-blue-500/10 hover:bg-blue-500/20">
                📱 تحميل تطبيق Android
            </button>

            <button
                type="button"
                data-open-welcome-assistant
                class="flex items-center w-full gap-3 px-4 py-3 text-right text-blue-200 transition rounded-xl hover:bg-blue-500/10 hover:text-white"
            >
                <span aria-hidden="true">🤖</span>
                <span>المساعد الذكي</span>
            </button>

            <div class="grid grid-cols-1 gap-2 border-t border-white/10 pt-3 text-sm text-[#c3c6d7]">
                <a
                    href="{{ route('privacy-policy') }}"
                    class="block px-4 py-3 rounded-xl hover:bg-white/5 hover:text-white"
                >
                    سياسة الخصوصية
                </a>

                <a
                    href="{{ Route::has('usage-policy') ? route('usage-policy') : route('terms-and-conditions') }}"
                    class="block px-4 py-3 rounded-xl hover:bg-white/5 hover:text-white"
                >
                    سياسة الاستخدام
                </a>

                <a
                    href="{{ route('terms-and-conditions') }}"
                    class="block px-4 py-3 rounded-xl hover:bg-white/5 hover:text-white"
                >
                    الشروط والأحكام
                </a>
            </div>

            <div class="pt-3 border-t border-white/10">
                <?php if (auth()->check()): ?>
                    <a
                        href="{{ route('dashboard') }}"
                        class="flex justify-center w-full px-6 py-3 font-bold text-white bg-blue-600 rounded-xl"
                    >
                        لوحة التحكم
                    </a>
                <?php else: ?>
                    <div class="grid grid-cols-2 gap-3">
                        <a
                            href="{{ route('login') }}"
                            class="flex justify-center px-4 py-3 font-bold border rounded-xl border-white/10 bg-white/5"
                        >
                            دخول
                        </a>

                        <a
                            href="{{ route('register') }}"
                            class="flex justify-center px-4 py-3 font-bold text-white bg-blue-600 rounded-xl"
                        >
                            حساب جديد
                        </a>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <main class="pt-16 wp-main">
        {{-- Hero — نفس تجربة building-scroll-hero مع مكونات صفحة الوليد الحالية --}}
        <section id="home" class="bh-hero" aria-label="رحلة المشروع من المخطط حتى الحديقة">
            <div class="bh-track" id="bh-track">
                <div class="bh-stage" id="bh-stage">
                    <canvas class="bh-canvas" id="bh-canvas" role="img" aria-label="مبنى يُبنى من المخطط حتى الاكتمال، ثم جولة داخل تصميمه الداخلي وخروج إلى الحديقة الخلفية"></canvas>
                    <div class="bh-film" aria-hidden="true"></div>
                    <div class="bh-grain" id="bh-grain" aria-hidden="true"></div>

                    <div class="bh-top">
                        <a class="bh-brand" href="#home">منصة الوليد الهندسية</a>
                        @auth
                            <a class="bh-toplink" href="{{ route('projects.index') }}">ابدأ مشروعك</a>
                        @else
                            <a class="bh-toplink" href="{{ route('register') }}">ابدأ مشروعك</a>
                        @endauth
                    </div>

                    <button
                        id="bh-skip-scene"
                        type="button"
                        aria-label="تخطي المشهد والانتقال إلى محتوى الصفحة"
                        style="position:absolute;z-index:12;top:84px;inset-inline-end:clamp(16px,4vw,48px);display:inline-flex;align-items:center;gap:8px;padding:10px 14px;border:1px solid var(--awl-bd-ffffff-280, rgba(255,255,255,.28));border-radius:999px;background:var(--awl-bg-050b16-620, rgba(5,11,22,.62));backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);color:var(--awl-fg-ffffff, #fff);font:800 12px/1.2 'IBM Plex Sans Arabic',Tahoma,sans-serif;cursor:pointer;box-shadow:0 10px 30px var(--awl-sh-000000-180, rgba(0,0,0,.18));"
                    >
                        <span>تخطي المشهد</span>
                        <span aria-hidden="true">↓</span>
                    </button>

                    <div class="bh-intro" id="bh-intro">
                        <h1>نرافق مبناك من المخطط إلى الحديقة</h1>
                        <p>منصة الوليد الهندسية تربطك بمهندسين متخصصين لكل مرحلة من مشروعك: التخطيط، الإنشاء، التصميم الداخلي، وتنسيق الحدائق.</p>
                        <span class="bh-hint"><i></i>مرّر لتتابع بناء المبنى</span>
                        <span class="bh-loading">جارٍ تجهيز المشهد…</span>
                    </div>

                    <nav class="bh-rail" id="bh-rail" aria-label="مراحل المشروع"></nav>

                    <aside class="bh-tb" id="bh-tb" aria-live="polite">
                        <div class="bh-tb-num"><span id="bh-tb-num">01</span><small>من 05</small></div>
                        <div class="bh-tb-body">
                            <p class="bh-tb-title" id="bh-tb-title">التخطيط</p>
                            <p class="bh-tb-text" id="bh-tb-text">مخطط الموقع، محاور الأعمدة، وتوزيع الفراغات قبل أول ضربة حفر.</p>
                        </div>
                    </aside>

                    <div class="bh-cta" id="bh-cta">
                        <h2>ابدأ مشروعك من المخطط الأول</h2>
                        <p>اعرض فكرتك واختر المهندس المناسب لكل مرحلة.</p>
                        <div class="bh-actions">
                            @auth
                                @if(auth()->user()->role === 'customer')
                                    <a class="bh-btn primary" href="{{ route('projects.index') }}">ابدأ مشروعك الآن</a>
                                @else
                                    <a class="bh-btn primary" href="{{ route('projects.index') }}">ابدأ مشروعك الآن</a>
                                @endif
                            @else
                                <a class="bh-btn primary" href="{{ route('register') }}">ابدأ مشروعك الآن</a>
                            @endauth
                            <a class="bh-btn" href="{{ route('engineer.works.public') }}">تصفح مكتبة الأعمال</a>
                            <button type="button" class="bh-btn" data-awl-app-download-open
                                    aria-haspopup="dialog" aria-controls="awl-app-download-modal"
                                    aria-label="خيارات تنزيل تطبيق الوليد الهندسية">📱 تحميل التطبيق</button>
                        </div>
                    </div>

                </div>
            </div>
        </section>

        {{-- تنزيل تطبيق Android: يظهر الرابط فقط عند إعداد ملف APK أو رابط HTTPS صالح. --}}
        <section id="download-app" class="px-4 py-10 sm:px-6" aria-labelledby="download-app-heading">
            <div class="mx-auto max-w-5xl rounded-3xl border border-blue-400/25 bg-[#101e39] px-6 py-8 shadow-lg sm:px-10 sm:py-10">
                <div class="flex flex-col items-center justify-between gap-6 text-center sm:flex-row sm:text-right">
                    <div>
                        <h2 id="download-app-heading" class="mb-2 text-2xl font-extrabold text-white">📱 تطبيق الوليد الهندسية</h2>
                        <p class="text-sm leading-7 text-[#c3c6d7]">خدماتك الهندسية من جوالك. التطبيق متاح لهواتف Android.</p>
                    </div>
                    <div class="w-full shrink-0 sm:w-auto">
                        <button type="button" data-awl-app-download-open
                                aria-haspopup="dialog" aria-controls="awl-app-download-modal"
                                class="inline-flex items-center justify-center w-full gap-2 py-4 text-base font-extrabold text-white transition bg-blue-600 shadow-lg rounded-xl px-7 hover:bg-blue-500 sm:w-auto"
                                aria-label="خيارات تنزيل تطبيق الوليد الهندسية لنظام Android">
                            <span aria-hidden="true">↓</span><span>تحميل التطبيق — Android</span>
                        </button>
                    </div>
                </div>
            </div>
        </section>

        {{-- الإحصائيات --}}
        <section id="after" class="px-6 py-20 wp-stats">
            <div class="grid grid-cols-1 gap-8 mx-auto wp-stats-grid max-w-7xl sm:grid-cols-2 lg:grid-cols-4">
                <article class="p-6 text-center wp-stat glass-card rounded-2xl reveal">
                    <div class="flex items-center justify-center w-14 h-14 mx-auto mb-4 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                            <path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-7h6v7"/>
                        </svg>
                    </div>

                    <h3 class="text-4xl font-black text-[#60a5fa]">
                        {{ $statistics['engineers'] }}
                    </h3>

                    <p class="mt-2 text-sm font-bold text-[#c3c6d7]">
                        مهندس فعّال
                    </p>
                </article>

                <article class="p-6 text-center wp-stat glass-card rounded-2xl reveal">
                    <div class="flex items-center justify-center w-14 h-14 mx-auto mb-4 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                            <path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4v8Z"/>
                        </svg>
                    </div>

                    <h3 class="text-4xl font-black text-[#60a5fa]">
                        {{ $statistics['consultations'] }}
                    </h3>

                    <p class="mt-2 text-sm font-bold text-[#c3c6d7]">
                        استشارة مدفوعة
                    </p>
                </article>

                <article class="p-6 text-center wp-stat glass-card rounded-2xl reveal">
                    <div class="flex items-center justify-center w-14 h-14 mx-auto mb-4 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                            <path d="m5 12 4 4L19 6"/>
                            <circle cx="12" cy="12" r="9"/>
                        </svg>
                    </div>

                    <h3 class="text-4xl font-black text-[#60a5fa]">
                        {{ $statistics['completed'] }}
                    </h3>

                    <p class="mt-2 text-sm font-bold text-[#c3c6d7]">
                        مشروع مكتمل
                    </p>
                </article>

                <article class="p-6 text-center wp-stat glass-card rounded-2xl reveal">
                    <div class="flex items-center justify-center mx-auto mb-4 text-blue-300 w-14 h-14 rounded-2xl bg-blue-400/10">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                            <rect x="3" y="3" width="18" height="18" rx="3"/>
                            <path d="m7 15 3-3 2 2 4-5 2 3"/>
                        </svg>
                    </div>

                    <h3 class="text-4xl font-black text-blue-300">
                        {{ $statistics['works'] }}
                    </h3>

                    <p class="mt-2 text-sm font-bold text-[#c3c6d7]">
                        عمل منشور
                    </p>
                </article>
            </div>
        </section>

        {{-- الخدمات --}}
        <section
            id="services"
            class="wp-services px-6 py-24 bg-[#131b2e]/30"
        >
            <div class="mx-auto max-w-7xl">
                <div class="mb-16 text-center wp-section-head reveal">
                    <h2 class="mb-4 text-4xl font-black">
                        خدماتنا الهندسية المتكاملة
                    </h2>

                    <p class="max-w-xl mx-auto text-[#c3c6d7]">
                        نقدم حلولًا هندسية مبتكرة تغطي احتياجات مشروعك من التخطيط إلى التنفيذ.
                    </p>
                </div>

                <?php
$services = [
    [
        'title' => 'التصميم المعماري',
        'description' => 'تصاميم عصرية تجمع بين الجمال والوظيفة، مع مراعاة أدق التفاصيل.',
        'icon' => 'architecture',
    ],
    [
        'title' => 'التصميم الإنشائي',
        'description' => 'دراسات إنشائية دقيقة تضمن أمان واستدامة المبنى.',
        'icon' => 'building',
    ],
    [
        'title' => 'التصميم الكهربائي',
        'description' => 'أنظمة كهربائية ذكية وآمنة تدعم كفاءة الطاقة.',
        'icon' => 'bolt',
    ],
    [
        'title' => 'الهندسة الميكانيكية',
        'description' => 'تصميم أنظمة التكييف والتهوية والصرف الصحي ومكافحة الحريق بكفاءة واحترافية.',
        'icon' => 'mechanical',
    ],
    [
        'title' => 'الحلول البرمجية',
        'description' => 'تطوير أنظمة إدارة وربط العمليات التقنية بالعمل الميداني.',
        'icon' => 'code',
    ],
    [
        'title' => 'التصميم الداخلي',
        'description' => 'ابتكار مساحات داخلية تعكس شخصيتك وتستغل المساحة بكفاءة.',
        'icon' => 'paint',
    ],
    [
        'title' => 'استشارات تقنية',
        'description' => 'دعم واستشارات تخصصية لمراجعة المخططات وحل المشكلات.',
        'icon' => 'support',
    ],
    [
    'title' => 'تصميم الواجهات',
    'description' => 'تصميم واجهات معمارية حديثة تجمع بين الهوية الجمالية والوظيفة وتناسب طبيعة المشروع.',
    'icon' => 'facade',
],
[
    'title' => 'تصميم اللاند سكيب',
    'description' => 'تصميم الحدائق والمساحات الخارجية والممرات والجلسات بما يحقق الراحة والجمال والاستدامة.',
    'icon' => 'landscape',
],
];
                ?>

                <div class="grid grid-cols-1 gap-8 wp-services-grid sm:grid-cols-2 lg:grid-cols-3">
                    <?php foreach ($services as $index => $service): ?>
                        <article
                            class="p-8 wp-service-card glass-card rounded-3xl reveal"
                            style="transition-delay: {{ $index * 80 }}ms"
                        >
                            <div class="flex items-center justify-center w-14 h-14 mb-6 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                                @switch($service['icon'])
                                    @case('architecture')
                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                                            <path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-7h6v7"/>
                                        </svg>
                                        @break

                                    @case('building')
                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                                            <rect x="4" y="3" width="16" height="18" rx="2"/>
                                            <path d="M8 7h2M14 7h2M8 11h2M14 11h2M8 15h2M14 15h2"/>
                                        </svg>
                                        @break

                                    @case('bolt')
                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                                            <path d="m13 2-8 12h7l-1 8 8-12h-7l1-8Z"/>
                                        </svg>
                                        @break

                                    @case('code')
                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                                            <path d="m8 9-4 3 4 3M16 9l4 3-4 3M14 5l-4 14"/>
                                        </svg>
                                        @break

                                    @case('paint')
                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                                            <path d="m14 4 6 6-9 9H5v-6l9-9Z"/>
                                            <path d="m12 6 6 6"/>
                                        </svg>
                                        @break
@case('mechanical')
    <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        class="w-7 h-7"
    >
        <circle cx="12" cy="12" r="3"/>
        <path d="M19.4 15a1.8 1.8 0 0 0 .36 1.98l.06.06-2.12 2.12-.06-.06a1.8 1.8 0 0 0-1.98-.36 1.8 1.8 0 0 0-1.1 1.65V20.5h-3v-.09a1.8 1.8 0 0 0-1.1-1.65 1.8 1.8 0 0 0-1.98.36l-.06.06-2.12-2.12.06-.06A1.8 1.8 0 0 0 4.6 15a1.8 1.8 0 0 0-1.65-1.1H2.5v-3h.45A1.8 1.8 0 0 0 4.6 9a1.8 1.8 0 0 0-.36-1.98l-.06-.06 2.12-2.12.06.06A1.8 1.8 0 0 0 8.34 5.26 1.8 1.8 0 0 0 9.44 3.6V3.5h3v.1a1.8 1.8 0 0 0 1.1 1.65 1.8 1.8 0 0 0 1.98-.36l.06-.06 2.12 2.12-.06.06A1.8 1.8 0 0 0 19.4 9c.26.67.9 1.1 1.65 1.1h.45v3h-.45A1.8 1.8 0 0 0 19.4 15Z"/>
    </svg>
    @break
    @case('facade')
    <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        class="w-7 h-7"
    >
        <path d="M4 21V5h16v16"/>
        <path d="M8 21v-5h8v5"/>
        <path d="M8 9h2M14 9h2M8 13h2M14 13h2"/>
        <path d="M2 21h20"/>
    </svg>
    @break

@case('landscape')
    <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        class="w-7 h-7"
    >
        <path d="M3 20h18"/>
        <path d="M6 20v-6"/>
        <path d="M6 14c-2 0-3-1.5-3-3 0-2 1.5-3.5 3.5-3.5S10 9 10 11c0 1.5-1 3-4 3Z"/>
        <path d="M16 20v-8"/>
        <path d="M16 12c-2.5 0-4-1.8-4-4 0-2.5 1.8-4.5 4.5-4.5S21 5.5 21 8c0 2.2-1.5 4-5 4Z"/>
    </svg>
    @break
                                    @default
                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-7 h-7">
                                            <path d="M4 12a8 8 0 0 1 16 0v5a3 3 0 0 1-3 3h-2v-7h5M4 12v5a3 3 0 0 0 3 3h2v-7H4"/>
                                        </svg>
                                @endswitch
                            </div>

                            <h3 class="mb-3 text-xl font-bold">
                                {{ $service['title'] }}
                            </h3>

                            <p class="text-sm leading-7 text-[#c3c6d7]">
                                {{ $service['description'] }}
                            </p>

                            <?php if (auth()->check()): ?>
                                <?php if (auth()->user()->role === 'customer'): ?>
                                    <a
                                        href="{{ route('consultations.create') }}"
                                        class="inline-flex items-center gap-2 mt-6 text-sm font-bold text-[#60a5fa]"
                                    >
                                        اطلب الخدمة

                                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                                            <path d="m15 18-6-6 6-6"/>
                                        </svg>
                                    </a>
                                <?php endif; ?>
                            <?php else: ?>
                                <a
                                    href="{{ route('register') }}"
                                    class="inline-flex items-center gap-2 mt-6 text-sm font-bold text-[#60a5fa]"
                                >
                                    ابدأ الآن

                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                                        <path d="m15 18-6-6 6-6"/>
                                    </svg>
                                </a>
                            <?php endif; ?>
                        </article>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>

        {{-- كيف نعمل --}}
        <section
            id="how-it-works"
            class="px-6 py-24 wp-process"
        >
            <div class="mx-auto max-w-7xl">
                <div class="mb-20 text-center wp-section-head reveal">
                    <h2 class="mb-4 text-4xl font-black">
                        رحلتك نحو التميز
                    </h2>

                    <p class="text-[#c3c6d7]">
                        أربع خطوات بسيطة تفصلك عن بدء مشروع أحلامك
                    </p>
                </div>

                <?php
                    $steps = [
                        [
                            'number' => '١',
                            'title' => 'اختر تخصصك',
                            'description' => 'حدد المجال الهندسي الذي يتناسب مع احتياجات مشروعك.',
                        ],
                        [
                            'number' => '٢',
                            'title' => 'أرسل التفاصيل',
                            'description' => 'زودنا بالمعلومات والمخططات الأولية للبدء في الدراسة.',
                        ],
                        [
                            'number' => '٣',
                            'title' => 'الدفع الإلكتروني',
                            'description' => 'ارفع إيصال الدفع ليتم مراجعته من الإدارة.',
                        ],
                        [
                            'number' => '٤',
                            'title' => 'استلم مشروعك',
                            'description' => 'احصل على ملفاتك بجودة عالية مع متابعة كاملة.',
                        ],
                    ];
                ?>

                <div class="relative grid grid-cols-1 gap-8 wp-process-grid md:grid-cols-4">
                    <div class="absolute left-0 right-0 hidden h-px wp-process-line top-8 md:block bg-white/10"></div>

                    <?php foreach ($steps as $index => $step): ?>
                        <article
                            class="relative z-10 flex flex-col items-center text-center wp-process-step reveal"
                            style="transition-delay: {{ $index * 100 }}ms"
                        >
                            <div
                                class="flex items-center justify-center w-16 h-16 mb-6 text-2xl font-bold border rounded-full {{
                                    $index === 0
                                        ? 'bg-blue-600 text-white border-blue-500'
                                        : 'bg-[#2d3449] text-[#60a5fa] border-[#60a5fa]/30'
                                }}"
                            >
                                {{ $step['number'] }}
                            </div>

                            <h3 class="mb-2 text-lg font-bold">
                                {{ $step['title'] }}
                            </h3>

                            <p class="px-4 text-sm leading-7 text-[#c3c6d7]">
                                {{ $step['description'] }}
                            </p>
                        </article>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>

        {{-- أحدث الأعمال --}}
        <section
            id="works"
            class="wp-works px-6 py-24 bg-[#131b2e]/30"
        >
            <div class="mx-auto max-w-7xl">
                <div class="flex flex-col items-start justify-between gap-6 mb-16 wp-section-head wp-section-head-split md:flex-row md:items-end reveal">
                    <div>
                        <h2 class="mb-4 text-4xl font-black">
                            أحدث أعمال مهندسينا
                        </h2>

                        <p class="max-w-2xl text-[#c3c6d7]">
                            استكشف بعض المشاريع التي أضافها مهندسو منصة الوليد الهندسية واجتازت رقابة المحتوى.
                        </p>
                    </div>

                    <a
                        href="{{ route('engineer.works.public') }}"
                        class="inline-flex items-center gap-2 font-bold text-[#60a5fa]"
                    >
                        عرض جميع الأعمال

                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                            <path d="m15 18-6-6 6-6"/>
                        </svg>
                    </a>
                </div>

                <div class="grid grid-cols-1 gap-8 wp-works-grid md:grid-cols-2 lg:grid-cols-3">
                    <?php if (count($latestWorks ?? []) > 0): foreach ($latestWorks as $work): ?>
                        <article class="overflow-hidden wp-work-card glass-card rounded-3xl reveal">
                            <div class="relative h-64 overflow-hidden wp-work-cover">
                                @php
                                    $homeCoverImage = $work->coverImage;
                                    $homeCoverAvailable = $homeCoverImage
                                        && \App\Support\PortfolioMediaPath::exists($homeCoverImage->image_path);
                                @endphp

                                @if ($homeCoverAvailable)
                                    <img
                                        src="{{ route('portfolio.media.engineer.image', ['engineerWork' => $work, 'image' => $homeCoverImage], false) }}"
                                        alt="{{ $work->title }}"
                                        class="object-cover w-full h-full transition duration-700 hover:scale-110"
                                        loading="lazy"
                                        decoding="async"
                                        onerror="this.classList.add('hidden'); this.nextElementSibling.classList.remove('hidden');"
                                    >
                                    <div class="hidden items-center justify-center w-full h-full bg-gradient-to-br from-[#222a3d] to-[#0b1326]">
                                        <svg
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="1.5"
                                            class="w-16 h-16 text-[#60a5fa]"
                                        >
                                            <path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-7h6v7"/>
                                        </svg>
                                    </div>
                                @else
                                    <div class="flex items-center justify-center w-full h-full bg-gradient-to-br from-[#222a3d] to-[#0b1326]">
                                        <svg
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="1.5"
                                            class="w-16 h-16 text-[#60a5fa]"
                                        >
                                            <path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-7h6v7"/>
                                        </svg>
                                    </div>
                                @endif

                                <?php if ($work->project_type): ?>
                                    <span
                                        class="absolute px-3 py-2 text-xs font-bold border rounded-full top-4 right-4 border-white/10 bg-[#060e20]/80"
                                    >
                                        {{ $work->project_type }}
                                    </span>
                                <?php endif; ?>
                            </div>

                            <div class="p-6 wp-work-body">
                                <h3 class="text-xl font-bold">
                                    {{ $work->title }}
                                </h3>

                                <div class="flex items-center gap-3 mt-4 wp-work-author">
                                    @if ($work->engineer)
                                        <img
                                            src="{{ $work->engineer->profile_photo_url }}"
                                            alt="{{ $work->engineer->name }}"
                                            class="object-cover w-11 h-11 shrink-0 rounded-full border border-blue-400/30 bg-blue-600/10"
                                            loading="lazy"
                                            decoding="async"
                                        >
                                    @else
                                        <div class="flex items-center justify-center w-11 h-11 shrink-0 font-bold rounded-full bg-blue-600/20 text-[#60a5fa]">
                                            م
                                        </div>
                                    @endif

                                    <div class="min-w-0">
                                        <div class="inline-flex max-w-full items-center gap-1.5">
                                            <span class="truncate text-sm font-black">
                                                {{ $work->engineer?->name ?? 'مهندس منصة الوليد الهندسية' }}
                                            </span>
                                            @if ($work->engineer)
                                                <x-verified-badge :subject="$work->engineer" size="sm" />
                                            @endif
                                        </div>

                                        <p class="mt-1 text-xs text-[#c3c6d7]">
                                            {{ $work->location ?? 'الموقع غير محدد' }}
                                        </p>
                                    </div>
                                </div>

                                <div class="flex gap-3 mt-6 wp-work-actions">
                                    <a
                                        href="{{ route('engineer.works.show', $work) }}"
                                        class="flex items-center justify-center flex-1 px-5 py-3 font-bold text-white bg-blue-600 rounded-xl"
                                    >
                                        عرض المشروع
                                    </a>

                                    <?php if (auth()->check()): ?>
                                        <?php if ( auth()->user()->role === 'customer' && $work->engineer ): ?>
                                            <a
                                                href="{{ route(
                                                    'consultations.create-for-engineer',
                                                    $work->engineer
                                                ) }}"
                                                class="flex items-center justify-center w-12 h-12 border rounded-xl border-white/10 bg-white/5"
                                                title="اطلب هذا المهندس"
                                            >
                                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-5 h-5">
                                                    <path d="M4 5h16v14H4z"/>
                                                    <path d="m4 7 8 6 8-6"/>
                                                </svg>
                                            </a>
                                        <?php endif; ?>
                                    <?php endif; ?>
                                </div>
                            </div>
                        </article>
                    <?php endforeach; else: ?>
                        <div class="p-12 text-center col-span-full glass-card rounded-3xl">
                            <svg
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="1.5"
                                class="w-14 h-14 mx-auto mb-4 text-[#60a5fa]"
                            >
                                <path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-7h6v7"/>
                            </svg>

                            <h3 class="text-xl font-bold">
                                لا توجد أعمال منشورة حاليًا
                            </h3>

                            <p class="mt-3 text-[#c3c6d7]">
                                ستظهر هنا أحدث أعمال المهندسين بعد اعتمادها.
                            </p>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>

        {{-- المهندسون --}}
        <section
            id="engineers"
            class="px-6 py-24 wp-engineers"
        >
            <div class="mx-auto max-w-7xl">
                <div class="flex flex-col items-start justify-between gap-6 mb-16 wp-section-head wp-section-head-split md:flex-row md:items-end reveal">
                    <div>
                        <h2 class="mb-4 text-4xl font-black">
                            نخبة المهندسين
                        </h2>

                        <p class="text-[#c3c6d7]">
                            تعاون مع خبراء معتمدين ذوي خبرة واسعة في مجالات متعددة.
                        </p>
                    </div>

                    <a
                        href="{{ route('engineer.works.public') }}"
                        class="inline-flex items-center gap-2 font-bold text-[#60a5fa]"
                    >
                        عرض جميع المهندسين

                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                            <path d="m15 18-6-6 6-6"/>
                        </svg>
                    </a>
                </div>

                <div class="grid grid-cols-1 gap-8 wp-engineers-grid sm:grid-cols-2 lg:grid-cols-3">
                    <?php if (count($featuredEngineers ?? []) > 0): foreach ($featuredEngineers as $engineer): ?>
                        <?php
                            $engineerProfileUrl = Route::has('engineers.show')
                                ? route('engineers.show', $engineer)
                                : '#';
                            $engineerRating = round((float) ($engineer->received_engineer_reviews_avg_rating ?? 0), 1);
                            $engineerReviewsCount = (int) ($engineer->received_engineer_reviews_count ?? 0);
                            $engineerWorksCount = (int) ($engineer->approved_works_count ?? $engineer->engineerWorks->count());
                            $engineerVerified = $engineer->professional_verification_status === 'verified'
                                && $engineer->professional_verification_expires_at
                                && $engineer->professional_verification_expires_at->isFuture();
                            $engineerSpecialty = $engineer->employeeProfile?->specialty?->name
                                ?? $engineer->employeeProfile?->job_title
                                ?? 'مهندس على المنصة';
                        ?>
                        <article class="wp-engineer-card group relative overflow-hidden p-6 glass-card rounded-3xl reveal transition hover:-translate-y-1 hover:border-[#60a5fa]/40 hover:shadow-2xl">
                            <a href="{{ $engineerProfileUrl }}" class="absolute inset-0 z-0" aria-label="فتح ملف {{ $engineer->name }}"></a>
                            <div class="relative z-10 wp-engineer-body">
                                <div class="flex items-center gap-4 mb-6 wp-engineer-profile">
                                    <img
    src="{{ $engineer->profile_photo_url }}"
    alt="{{ $engineer->name }}"
    class="object-cover w-16 h-16 border rounded-full border-white/10"
    loading="lazy"
    decoding="async"
>

                                    <div class="flex-1 min-w-0">
                                        <div class="flex items-center gap-1.5 min-w-0">
                                            <h3 class="text-lg font-black truncate">
                                                {{ $engineer->name }}
                                            </h3>
                                            @if ($engineerVerified)
                                                <x-verified-badge :subject="$engineer" size="sm" />
                                            @endif
                                        </div>

                                        <p class="mt-1 text-xs font-bold text-[#60a5fa] truncate">
                                            {{ $engineerSpecialty }}
                                        </p>
                                    </div>
                                </div>

                                <div class="flex items-center justify-between px-2 mb-6 wp-engineer-metrics">
                                    <div class="text-center">
                                        <span class="block text-lg font-bold">
                                            {{ $engineerWorksCount }}
                                        </span>

                                        <span class="text-[10px] text-[#c3c6d7]">
                                            أعمال
                                        </span>
                                    </div>

                                    <div class="w-px h-8 bg-white/10"></div>

                                    <div class="text-center">
                                        <span class="block text-lg font-bold">
                                            {{ $engineerReviewsCount > 0 ? number_format($engineerRating, 1) : '—' }}
                                        </span>

                                        <span class="text-[10px] text-[#60a5fa]">
                                            تقييم
                                        </span>
                                    </div>

                                    <div class="w-px h-8 bg-white/10"></div>

                                    <div class="text-center">
                                        <span class="block text-lg font-bold">
                                            نشط
                                        </span>

                                        <span class="text-[10px] text-[#c3c6d7]">
                                            الحالة
                                        </span>
                                    </div>
                                </div>

                                <div class="relative z-20 grid gap-2 wp-engineer-actions">
                                    <a
                                        href="{{ $engineerProfileUrl }}"
                                        class="flex items-center justify-center w-full px-5 py-3 font-bold text-white bg-blue-600 rounded-xl hover:bg-blue-500"
                                    >
                                        فتح الملف الشخصي
                                    </a>

                                    <?php if (auth()->check() && auth()->user()->role === 'customer' && Route::has('consultations.create-for-engineer')): ?>
                                        <a
                                            href="{{ route('consultations.create-for-engineer', $engineer) }}"
                                            class="flex items-center justify-center w-full px-5 py-3 font-bold rounded-xl bg-[#2d3449] hover:bg-blue-600/20"
                                        >
                                            اطلب هذا المهندس
                                        </a>
                                    <?php elseif (! auth()->check()): ?>
                                        <a
                                            href="{{ route('login') }}"
                                            class="flex items-center justify-center w-full px-5 py-3 font-bold rounded-xl bg-[#2d3449] hover:bg-blue-600/20"
                                        >
                                            سجّل لطلب استشارة
                                        </a>
                                    <?php endif; ?>
                                </div>
                            </div>
                        </article>
                    <?php endforeach; else: ?>
                        <div class="p-10 text-center col-span-full glass-card rounded-3xl">
                            لا يوجد مهندسون متاحون حاليًا.
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>

        {{-- المكاتب الهندسية المعتمدة --}}
        <section id="offices" class="wp-offices px-6 py-24 bg-[#131b2e]/20">
            <div class="mx-auto max-w-7xl">
                <div class="flex flex-col items-start justify-between gap-6 wp-section-head wp-section-head-split mb-14 md:flex-row md:items-end reveal">
                    <div>
                        <div class="inline-flex items-center gap-2 px-4 py-2 mb-4 text-xs font-black text-blue-300 border rounded-full border-blue-400/20 bg-blue-400/10">✓ مكاتب موثقة</div>
                        <h2 class="mb-4 text-4xl font-black">المكاتب الهندسية المعتمدة</h2>
                        <p class="text-[#c3c6d7]">اكتشف مكاتب موثقة، أعمالها المنشورة وتقييمات عملائها قبل طلب مشروعك أو استشارتك.</p>
                    </div>
                    @if (Route::has('engineering-offices.index'))
                        <a href="{{ route('engineering-offices.index') }}" class="inline-flex items-center gap-2 font-bold text-[#60a5fa]">عرض دليل المكاتب ←</a>
                    @endif
                </div>

                <div class="grid grid-cols-1 wp-offices-grid gap-7 md:grid-cols-2 lg:grid-cols-3">
                    @forelse (($featuredOffices ?? collect()) as $office)

@php
    $officeCoverRaw = $office->cover_path ?: $office->logo_path;
    $officeCoverUrl = null;

    if ($officeCoverRaw) {
        $officeCoverUrl = \Illuminate\Support\Str::startsWith(
            $officeCoverRaw,
            ['http://', 'https://']
        )
            ? $officeCoverRaw
            : route('public-storage.show', ['path' => ltrim($officeCoverRaw, '/')]);
    }
@endphp

<article class="overflow-hidden wp-office-card glass-card rounded-3xl reveal">
    <div class="relative h-32 overflow-hidden wp-office-cover bg-[#0d2442]">
        @if ($officeCoverUrl)
            <img
                src="{{ $officeCoverUrl }}"
                class="absolute inset-0 z-0 object-cover w-full h-full opacity-100"
                alt="{{ $office->name }}"
                loading="lazy"
            >
            <div class="absolute inset-0 z-10 bg-gradient-to-t from-[#071426]/55 via-transparent to-[#0b1d36]/10"></div>
        @else
            <div class="absolute inset-0 z-0 flex items-center justify-center bg-gradient-to-br from-[#173b6d] to-[#0b1d36]">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
                     stroke-width="1.7" class="w-12 h-12 text-blue-200 opacity-80">
                    <rect x="4" y="3" width="16" height="18" rx="2"/>
                    <path d="M8 7h2M14 7h2M8 11h2M14 11h2M8 15h2M14 15h2M9 21v-3h6v3"/>
                </svg>
            </div>
        @endif

    </div>
                            <div class="p-6 wp-office-body">
                                <div class="flex items-center gap-3">
                                    <div class="h-14 w-14 overflow-hidden rounded-2xl border border-blue-400/25 bg-[#0d2442] flex items-center justify-center">
                                        @if ($office->logo_path)
                                            <img src="{{ route('public-storage.show', ['path' => $office->logo_path]) }}" class="object-cover w-full h-full" alt="{{ $office->name }}">
                                        @else
                                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"
         class="text-blue-300 w-7 h-7">
        <rect x="4" y="3" width="16" height="18" rx="2"/>
        <path d="M8 7h2M14 7h2M8 11h2M14 11h2M8 15h2M14 15h2M9 21v-3h6v3"/>
    </svg>
                                        @endif
                                    </div>
                                    <div class="flex-1 min-w-0">
                                        <div class="flex items-center gap-1.5 min-w-0">
                                            <h3 class="text-lg font-black truncate">{{ $office->name }}</h3>
                                            <x-verified-badge :subject="$office" type="office" size="sm" />
                                        </div>
                                        <p class="text-xs text-[#c3c6d7] mt-1">{{ $office->city ?: '—' }} @if($office->country) • {{ $office->country }} @endif</p>
                                    </div>
                                </div>
                                <div class="grid grid-cols-3 gap-2 mt-5 text-center wp-office-metrics">
                                    <div class="p-3 rounded-xl bg-white/5"><b>{{ number_format((float)($office->reviews_avg_rating ?? 0), 1) }} ★</b><span class="block text-[10px] text-[#c3c6d7] mt-1">{{ $office->reviews_count ?? 0 }} تقييم</span></div>
                                    <div class="p-3 rounded-xl bg-white/5"><b>{{ $office->published_works_count ?? 0 }}</b><span class="block text-[10px] text-[#c3c6d7] mt-1">عمل</span></div>
                                    <div class="p-3 rounded-xl bg-white/5"><b>{{ $office->completed_projects_count ?? 0 }}</b><span class="block text-[10px] text-[#c3c6d7] mt-1">مشروع</span></div>
                                </div>
                                @if (Route::has('engineering-offices.show'))
                                    <a href="{{ route('engineering-offices.show', $office) }}" class="flex items-center justify-center w-full px-5 py-3 mt-5 font-black text-white transition bg-blue-600 wp-office-open-btn rounded-xl hover:bg-blue-700">فتح ملف المكتب</a>
                                @endif
                            </div>
                        </article>
                    @empty
                        <div class="col-span-full glass-card rounded-3xl p-10 text-center text-[#c3c6d7]">لا توجد مكاتب موثقة ظاهرة حاليًا.</div>
                    @endforelse
                </div>
            </div>
        </section>

        {{-- الآراء والملاحظات --}}
        <section
            id="feedback"
            class="wp-feedback px-6 py-24 bg-[#131b2e]/30"
        >
            <div class="mx-auto max-w-7xl">
                <div class="max-w-3xl mx-auto text-center wp-section-head mb-14 reveal">
                    <span class="inline-flex items-center gap-2 px-4 py-2 mb-5 text-sm font-bold border rounded-full border-[#60a5fa]/20 bg-[#60a5fa]/10 text-[#60a5fa]">
                        <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.8"
                            class="w-4 h-4"
                            aria-hidden="true"
                        >
                            <path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4v8Z"/>
                            <path d="M8 10h8M8 14h5"/>
                        </svg>

                        صوتك يهمنا
                    </span>

                    <h2 class="mb-4 text-4xl font-black">
                        الآراء والملاحظات
                    </h2>

                    <p class="text-[#c3c6d7] leading-8">
                        شاركنا رأيك في منصة الوليد الهندسية، وأرسل ملاحظاتك
                        أو اقتراحاتك لتطوير تجربة العملاء والمهندسين والمكاتب الهندسية.
                    </p>
                </div>

                <div class="grid grid-cols-1 gap-6 mb-10 wp-feedback-grid md:grid-cols-3">
                    <article class="wp-feedback-card p-7 glass-card rounded-3xl reveal">
                        <div class="flex items-center justify-center w-12 h-12 mb-5 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-6 h-6" aria-hidden="true">
                                <path d="M4 4h16v12H7l-3 3V4Z"/>
                                <path d="M8 8h8M8 12h5"/>
                            </svg>
                        </div>

                        <h3 class="text-xl font-bold">
                            شاركنا رأيك
                        </h3>

                        <p class="mt-3 text-sm leading-7 text-[#c3c6d7]">
                            أخبرنا عن تجربتك وما الذي أعجبك في المنصة.
                        </p>
                    </article>

                    <article class="wp-feedback-card p-7 glass-card rounded-3xl reveal">
                        <div class="flex items-center justify-center w-12 h-12 mb-5 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-6 h-6" aria-hidden="true">
                                <path d="M12 3a6 6 0 0 0-3 11.2V18h6v-3.8A6 6 0 0 0 12 3Z"/>
                                <path d="M9 21h6"/>
                            </svg>
                        </div>

                        <h3 class="text-xl font-bold">
                            اقترح تطويرًا
                        </h3>

                        <p class="mt-3 text-sm leading-7 text-[#c3c6d7]">
                            لديك فكرة أو ميزة جديدة؟ نرحب باقتراحاتك.
                        </p>
                    </article>

                    <article class="wp-feedback-card p-7 glass-card rounded-3xl reveal">
                        <div class="flex items-center justify-center w-12 h-12 mb-5 rounded-2xl bg-blue-400/10 text-[#60a5fa]">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-6 h-6" aria-hidden="true">
                                <path d="M12 21s-7-4.35-7-11a4 4 0 0 1 7-2.65A4 4 0 0 1 19 10c0 6.65-7 11-7 11Z"/>
                            </svg>
                        </div>

                        <h3 class="text-xl font-bold">
                            ملاحظاتك تصنع الفرق
                        </h3>

                        <p class="mt-3 text-sm leading-7 text-[#c3c6d7]">
                            كل ملاحظة تساعدنا على تقديم تجربة أكثر احترافية.
                        </p>
                    </article>
                </div>

                <div class="wp-feedback-submit flex flex-col items-center justify-between gap-6 p-7 border rounded-3xl border-blue-400/20 bg-[#0b1d36] reveal md:flex-row">
                    <div>
                        <h3 class="text-2xl font-black">
                            عندك رأي أو ملاحظة؟
                        </h3>

                        <p class="mt-2 text-sm leading-7 text-[#c3c6d7]">
                            أرسلها لنا وسنعمل على مراجعتها وتحسين المنصة باستمرار.
                        </p>
                    </div>

                    <?php if (Route::has('feedback.create')): ?>
                        <a
                            href="{{ route('feedback.create') }}"
                            class="inline-flex items-center justify-center py-3 font-bold text-white transition bg-blue-600 px-7 rounded-xl hover:bg-blue-500"
                        >
                            أرسل رأيك الآن
                        </a>
                    <?php else: ?>
                        <button
                            type="button"
                            data-open-welcome-assistant
                            class="inline-flex items-center justify-center py-3 font-bold text-white transition bg-blue-600 px-7 rounded-xl hover:bg-blue-500"
                        >
                            أرسل رأيك الآن
                        </button>
                    <?php endif; ?>
                </div>
            </div>
        </section>
        {{-- CTA --}}
        <section class="wp-cta">
            <div class="mx-auto max-w-7xl">
                <div class="wp-cta-panel">
                    <div class="wp-cta-media" aria-hidden="true">
                        <img class="wp-cta-building-image" src="{{ asset('images/ai/cta-building.webp') }}" alt="" loading="lazy" decoding="async">
                    </div>
                    <div class="wp-cta-content">
                        <span class="wp-cta-kicker">ابدأ من الفكرة... وانتهِ بالتنفيذ</span>
                        <h2 class="wp-cta-title">مستعد لبدء <span class="wp-cta-title-accent">مشروعك</span>؟</h2>
                        <p class="wp-cta-description">انضم إلى منصة الوليد الهندسية واحصل على استشارة هندسية احترافية من نخبة المهندسين.</p>
                        <div class="wp-cta-actions">
                            <?php if (auth()->check()): ?>
                                <?php if (auth()->user()->role === 'customer'): ?>
                                    <a href="{{ route('engineer.works.public') }}" class="wp-cta-primary"><span>اختر مهندسًا</span><span class="wp-cta-primary-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span></a>
                                <?php else: ?>
                                    <a href="{{ route('dashboard') }}" class="wp-cta-primary"><span>لوحة التحكم</span><span class="wp-cta-primary-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span></a>
                                <?php endif; ?>
                            <?php else: ?>
                                <a href="{{ route('register') }}" class="wp-cta-primary"><span>ابدأ الآن</span><span class="wp-cta-primary-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span></a>
                            <?php endif; ?>
                        </div>
                        <div class="wp-cta-features">
                            <div class="wp-cta-feature">
                                <span class="wp-cta-feature-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-5"/></svg></span>
                                <strong>مهندسون معتمدون</strong><span>ذوو خبرة وكفاءة</span>
                            </div>
                            <div class="wp-cta-feature">
                                <span class="wp-cta-feature-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5"/><path d="m3 17 9 5 9-5"/></svg></span>
                                <strong>مشاريع متنوعة</strong><span>سكنية، تجارية ومؤسسية</span>
                            </div>
                            <div class="wp-cta-feature">
                                <span class="wp-cta-feature-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 13a8 8 0 0 1 16 0"/><path d="M4 13v5a2 2 0 0 0 2 2h1v-7H4Z"/><path d="M20 13v5a2 2 0 0 1-2 2h-1v-7h3Z"/></svg></span>
                                <strong>دعم مستمر</strong><span>من الفكرة حتى التنفيذ</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </main>

    {{-- Footer --}}
    <footer class="wp-footer px-6 py-16 border-t bg-[#060e20] border-white/10">
        <div class="grid gap-12 mx-auto wp-footer-grid max-w-7xl sm:grid-cols-2 lg:grid-cols-5">
            <div class="md:col-span-2">
                <div class="flex items-center gap-3">
                    <span class="flex items-center justify-center w-11 h-11 rounded-xl bg-blue-600/20 text-[#60a5fa]">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="w-6 h-6">
                            <path d="M3 11.5 12 4l9 7.5"/>
                            <path d="M5.5 10.5V21h13V10.5"/>
                            <path d="M9 21v-6h6v6"/>
                        </svg>
                    </span>

                    <span class="text-xl font-black text-[#60a5fa]">
                        منصة الوليد الهندسية
                    </span>
                </div>

                <p class="max-w-md mt-5 leading-8 text-[#c3c6d7]">
                    منصة هندسية متكاملة تجمع العملاء والمهندسين وتسهّل طلب الاستشارات ومتابعة المشاريع.
                </p>
            </div>

            <div>
                <h3 class="mb-5 font-bold">
                    روابط سريعة
                </h3>

                <div class="space-y-3 text-sm text-[#c3c6d7]">
                    <a href="#services" class="block hover:text-white">خدماتنا</a>
                    <a href="#works" class="block hover:text-white">أعمالنا</a>
                    <a href="#engineers" class="block hover:text-white">المهندسون</a>
                    <a href="#feedback" class="block hover:text-white">الآراء والملاحظات</a>
                </div>
            </div>

            <div>
                <h3 class="mb-5 font-bold">
                    الحساب
                </h3>

                <div class="space-y-3 text-sm text-[#c3c6d7]">
                    <?php if (auth()->check()): ?>
                        <a href="{{ route('dashboard') }}" class="block hover:text-white">
                            لوحة التحكم
                        </a>
                    <?php else: ?>
                        <a href="{{ route('login') }}" class="block hover:text-white">
                            تسجيل الدخول
                        </a>

                        <a href="{{ route('register') }}" class="block hover:text-white">
                            إنشاء حساب
                        </a>
                    <?php endif; ?>
                </div>
            </div>

            <div>
                <h3 class="mb-5 font-bold">
                    السياسات القانونية
                </h3>

                <div class="space-y-3 text-sm text-[#c3c6d7]">
                    <a
                        href="{{ route('privacy-policy') }}"
                        class="block hover:text-white"
                    >
                        سياسة الخصوصية
                    </a>

                    <a
                        href="{{ Route::has('usage-policy') ? route('usage-policy') : route('terms-and-conditions') }}"
                        class="block hover:text-white"
                    >
                        سياسة الاستخدام
                    </a>

                    <a
                        href="{{ route('terms-and-conditions') }}"
                        class="block hover:text-white"
                    >
                        الشروط والأحكام
                    </a>
                </div>
            </div>
        </div>

        <div class="pt-8 mt-12 text-sm text-center border-t border-white/10 text-[#8d90a0]">
            © {{ now()->year }} منصة الوليد الهندسية. جميع الحقوق محفوظة.
        </div>
    </footer>

{{-- نافذة تنزيل التطبيق: تستخدم رابط APK الحالي، ولا تتجاوز شرط وجود الملف. --}}
<div id="awl-app-download-modal" class="awl-app-download-modal" role="dialog" aria-modal="true"
     aria-labelledby="awl-app-download-title" aria-describedby="awl-app-download-description" hidden>
    <div class="awl-app-download-backdrop" data-awl-app-download-close aria-hidden="true"></div>
    <div class="awl-app-download-panel" tabindex="-1">
        <button type="button" class="awl-app-download-close" data-awl-app-download-close aria-label="إغلاق نافذة التنزيل">&times;</button>
        <img class="awl-app-download-icon" src="{{ asset('images/alwaleed-app-icon.png') }}"
             alt="أيقونة تطبيق الوليد الهندسية" width="88" height="88" loading="lazy">
        <h2 id="awl-app-download-title" class="awl-app-download-title">تطبيق الوليد الهندسية</h2>
        <p id="awl-app-download-description" class="awl-app-download-description">نزّل تطبيق المنصة لهواتف Android</p>
        @if($appApkDownloadUrl)
            <a class="awl-app-download-action" href="{{ $appApkDownloadUrl }}"
               @if($appApkHasLocalFile) download="alwaleed-engineering.apk" @else rel="noopener noreferrer" @endif
               aria-label="Download تطبيق الوليد الهندسية لنظام Android">
                <span aria-hidden="true">↓</span><span>Download</span>
            </a>
        @else
            <p class="awl-app-download-unavailable" role="status">ملف التطبيق قيد التحقق من سلامة الإصدار الجديد؛ سيتاح التنزيل بعد اكتمال الرفع.</p>
        @endif
    </div>
</div>
<script id="awl-app-download-modal-script">
(() => {
    const modal = document.getElementById('awl-app-download-modal');
    if (!modal) return;
    const panel = modal.querySelector('.awl-app-download-panel');
    const closeButton = modal.querySelector('.awl-app-download-close');
    let previousFocus = null;
    let previousOverflow = '';
    function openModal(event) {
        event.preventDefault();
        previousFocus = document.activeElement;
        previousOverflow = document.body.style.overflow;
        modal.hidden = false;
        document.body.style.overflow = 'hidden';
        closeButton.focus();
    }
    function closeModal() {
        if (modal.hidden) return;
        modal.hidden = true;
        document.body.style.overflow = previousOverflow;
        if (previousFocus && previousFocus.isConnected && typeof previousFocus.focus === 'function') previousFocus.focus();
    }
    document.querySelectorAll('[data-awl-app-download-open]').forEach(button => button.addEventListener('click', openModal));
    modal.querySelectorAll('[data-awl-app-download-close]').forEach(button => button.addEventListener('click', closeModal));
    modal.addEventListener('keydown', event => {
        if (event.key === 'Escape') { event.preventDefault(); closeModal(); return; }
        if (event.key !== 'Tab') return;
        const targets = [...panel.querySelectorAll('a[href], button:not([disabled])')];
        if (!targets.length) return;
        const first = targets[0], last = targets[targets.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    });
})();
</script>

    <script defer src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <script defer src="{{ asset('js/building-scroll-hero.js') }}?v=20260929-en-scene"></script>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const skipSceneButton = document.getElementById('bh-skip-scene');
            const afterSceneSection = document.getElementById('after');

            if (skipSceneButton && afterSceneSection) {
                skipSceneButton.addEventListener('click', function () {
                    const destination = afterSceneSection.getBoundingClientRect().top + window.scrollY;
                    window.scrollTo({ top: destination, behavior: 'auto' });
                });
            }

            const menuButton =
                document.getElementById(
                    'welcome-mobile-menu-button'
                );

            const menu =
                document.getElementById(
                    'welcome-mobile-menu'
                );

            const openIcon =
                document.getElementById(
                    'welcome-menu-open-icon'
                );

            const closeIcon =
                document.getElementById(
                    'welcome-menu-close-icon'
                );

            const closeMenu = () => {
                menu?.classList.add('hidden');
                openIcon?.classList.remove('hidden');
                closeIcon?.classList.add('hidden');
                menuButton?.setAttribute(
                    'aria-expanded',
                    'false'
                );
            };

            menuButton?.addEventListener(
                'click',
                function () {
                    const isOpen =
                        ! menu.classList.contains(
                            'hidden'
                        );

                    menu.classList.toggle(
                        'hidden'
                    );

                    openIcon.classList.toggle(
                        'hidden',
                        ! isOpen
                    );

                    closeIcon.classList.toggle(
                        'hidden',
                        isOpen
                    );

                    menuButton.setAttribute(
                        'aria-expanded',
                        String(! isOpen)
                    );
                }
            );

            document
                .querySelectorAll(
                    '[data-welcome-mobile-link]'
                )
                .forEach((link) => {
                    link.addEventListener(
                        'click',
                        closeMenu
                    );
                });

            document
                .querySelectorAll(
                    '[data-open-welcome-assistant]'
                )
                .forEach((button) => {
                    button.addEventListener(
                        'click',
                        function () {
                            closeMenu();

                            window.location.href = @json(route('smart-assistant.index'));
                        }
                    );
                });

            const observer =
                new IntersectionObserver(
                    (entries) => {
                        entries.forEach(
                            (entry) => {
                                if (
                                    entry.isIntersecting
                                ) {
                                    entry.target
                                        .classList
                                        .add('active');

                                    observer.unobserve(
                                        entry.target
                                    );
                                }
                            }
                        );
                    },
                    {
                        threshold: 0.12,
                    }
                );

            document
                .querySelectorAll('.reveal')
                .forEach((element) => {
                    observer.observe(element);
                });

            const canvas =
                document.getElementById(
                    'creativehome-shader'
                );

            if (! canvas) {
                return;
            }

            const gl =
                canvas.getContext('webgl')
                || canvas.getContext(
                    'experimental-webgl'
                );

            if (! gl) {
                return;
            }

            const syncSize = () => {
                const width =
                    canvas.clientWidth
                    || window.innerWidth;

                const height =
                    canvas.clientHeight
                    || window.innerHeight;

                if (
                    canvas.width !== width
                    || canvas.height !== height
                ) {
                    canvas.width = width;
                    canvas.height = height;
                }
            };

            const vertexShaderSource = `
                attribute vec2 a_position;
                varying vec2 v_texCoord;

                void main() {
                    v_texCoord =
                        a_position * 0.5 + 0.5;

                    gl_Position =
                        vec4(
                            a_position,
                            0.0,
                            1.0
                        );
                }
            `;

            const fragmentShaderSource = `
                precision highp float;

                varying vec2 v_texCoord;

                uniform float u_time;
                uniform vec2 u_resolution;

                void main() {
                    vec2 uv = v_texCoord;

                    float noise =
                        sin(
                            uv.x * 3.0
                            + u_time * 0.5
                        )
                        * cos(
                            uv.y * 2.0
                            + u_time * 0.3
                        );

                    noise +=
                        sin(
                            uv.y * 5.0
                            - u_time * 0.4
                        ) * 0.5;

                    vec3 color1 =
                        vec3(
                            0.043,
                            0.075,
                            0.149
                        );

                    vec3 color2 =
                        vec3(
                            0.145,
                            0.388,
                            0.922
                        );

                    vec3 color3 =
                        vec3(
                            0.537,
                            0.122,
                            0.941
                        );

                    vec3 finalColor =
                        mix(
                            color1,
                            color2,
                            noise * 0.2 + 0.1
                        );

                    finalColor =
                        mix(
                            finalColor,
                            color3,
                            clamp(
                                sin(
                                    u_time * 0.2
                                    + uv.x * 2.0
                                ) * 0.1,
                                0.0,
                                1.0
                            )
                        );

                    gl_FragColor =
                        vec4(
                            finalColor,
                            1.0
                        );
                }
            `;

            const compileShader = (
                type,
                source
            ) => {
                const shader =
                    gl.createShader(type);

                gl.shaderSource(
                    shader,
                    source
                );

                gl.compileShader(shader);

                return shader;
            };

            const program =
                gl.createProgram();

            gl.attachShader(
                program,
                compileShader(
                    gl.VERTEX_SHADER,
                    vertexShaderSource
                )
            );

            gl.attachShader(
                program,
                compileShader(
                    gl.FRAGMENT_SHADER,
                    fragmentShaderSource
                )
            );

            gl.linkProgram(program);
            gl.useProgram(program);

            const buffer =
                gl.createBuffer();

            gl.bindBuffer(
                gl.ARRAY_BUFFER,
                buffer
            );

            gl.bufferData(
                gl.ARRAY_BUFFER,
                new Float32Array([
                    -1,
                    -1,
                    1,
                    -1,
                    -1,
                    1,
                    1,
                    1,
                ]),
                gl.STATIC_DRAW
            );

            const position =
                gl.getAttribLocation(
                    program,
                    'a_position'
                );

            gl.enableVertexAttribArray(
                position
            );

            gl.vertexAttribPointer(
                position,
                2,
                gl.FLOAT,
                false,
                0,
                0
            );

            const timeUniform =
                gl.getUniformLocation(
                    program,
                    'u_time'
                );

            const resolutionUniform =
                gl.getUniformLocation(
                    program,
                    'u_resolution'
                );

            const render = (time) => {
                syncSize();

                gl.viewport(
                    0,
                    0,
                    canvas.width,
                    canvas.height
                );

                gl.uniform1f(
                    timeUniform,
                    time * 0.001
                );

                gl.uniform2f(
                    resolutionUniform,
                    canvas.width,
                    canvas.height
                );

                gl.drawArrays(
                    gl.TRIANGLE_STRIP,
                    0,
                    4
                );

                requestAnimationFrame(
                    render
                );
            };

            window.addEventListener(
                'resize',
                syncSize
            );

            requestAnimationFrame(
                render
            );
        });
    </script>

    {{-- صفحة Welcome الجديدة مستقلة بصريًا عن المساعد العائم حتى تطابق المرجع. --}}
</body>
</html>
