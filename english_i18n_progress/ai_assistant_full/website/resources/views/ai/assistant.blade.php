<!DOCTYPE html>
<html class="dark" dir="rtl" lang="ar">
<head>
    <meta charset="utf-8"/>
    <meta content="width=device-width, initial-scale=1.0" name="viewport"/>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>مساعد الوليد الهندسي </title>
    <script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        brand: {500:'#10a37f',600:'#0e8c6d',accent:'#6366f1'},
                        dark: {bg:'#0d0d0e',surface:'#171719',sidebar:'#09090b',border:'#26262a',card:'#1f1f23',hover:'#2a2b32'}
                    },
                    fontFamily: {
                        sans: ['Tajawal','Cairo','Segoe UI','sans-serif'],
                        mono: ['JetBrains Mono','Fira Code','Consolas','monospace']
                    }
                }
            }
        }
    </script>
    <link href="https://fonts.googleapis.com" rel="preconnect"/>
    <link crossorigin href="https://fonts.gstatic.com" rel="preconnect"/>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&family=Tajawal:wght@400;500;700&display=swap" rel="stylesheet"/>
    <style>
        html,body{margin:0;width:100%;height:100%;overflow:hidden;background:var(--awl-bg-0d0d0e, #0d0d0e);color:var(--awl-fg-ececf1, #ececf1)}
        body{font-family:'Cairo','Tajawal',sans-serif;-webkit-font-smoothing:antialiased}
        code,pre{font-family:'JetBrains Mono',monospace}
        ::-webkit-scrollbar{width:6px;height:6px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:#2b2c35;border-radius:9999px}::-webkit-scrollbar-thumb:hover{background:#3f414e}
        #aiExactShell{visibility:hidden;position:absolute;inset:0;z-index:10}
        #aiExactShell.is-mounted{visibility:visible}

        /* Keep the existing AI runtime alive, but the visual surface comes from the exact shell. */
        #supportBotToggle{display:none!important}
        #supportBotPanel{position:fixed!important;inset:0!important;width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;border:0!important;border-radius:0!important;box-shadow:none!important;background:transparent!important;overflow:visible!important;z-index:30!important}
        #supportBotPanel>.support-bot-header,
        #supportBotPanel>#supportBotHomeHero,
        #supportBotPanel>#supportBotActions,
        #supportBotPanel>#supportBotSuggestions{display:none!important}
        #supportBotHistory{display:none!important}

        /* Runtime message stream mapped to the supplied desktop design. */
        #supportBotMessages{display:block!important;flex:1!important;min-height:0!important;overflow-y:auto!important;width:100%!important;margin:0!important;padding:24px 32px 150px!important;background:var(--awl-bg-0d0d0e, #0d0d0e)!important;scrollbar-width:thin;scrollbar-color:#2b2c35 transparent}
        .support-message-row{display:flex!important;width:100%!important;margin:0 auto 26px!important;max-width:896px!important}
        .support-message-row.customer{justify-content:flex-start!important}
        .support-message-row.bot,.support-message-row.employee,.support-message-row.admin{justify-content:flex-end!important}
        .support-message-row.system{justify-content:flex-end!important}
        .support-message{max-width:min(720px,88%)!important;padding:0!important;border:0!important;box-shadow:none!important;background:transparent!important;color:var(--awl-fg-e5e7eb, #e5e7eb)!important;position:relative!important;font-size:14px!important;line-height:1.8!important}
        .support-message-row.customer .support-message{background:var(--awl-bg-1e1b4b-400, rgba(30,27,75,.4))!important;border:1px solid rgba(99,102,241,.30)!important;border-radius:16px 4px 16px 16px!important;padding:14px 16px!important;color:var(--awl-fg-f3f4f6, #f3f4f6)!important;box-shadow:0 1px 2px var(--awl-sh-000000-250, rgba(0,0,0,.25))!important}
        .support-message-row.bot .support-message,.support-message-row.employee .support-message,.support-message-row.admin .support-message{max-width:820px!important;width:100%!important;padding-right:52px!important}
        .support-message-row.bot .support-message:before,.support-message-row.employee .support-message:before,.support-message-row.admin .support-message:before{content:'✦';position:absolute;right:0;top:0;width:36px;height:36px;border-radius:12px;background:linear-gradient(135deg,#059669,#14b8a6,#4f46e5);display:grid;place-items:center;color:var(--awl-fg-ffffff, white);font-size:18px;box-shadow:0 8px 22px var(--awl-sh-000000-350, rgba(0,0,0,.35));border:1px solid var(--awl-bd-ffffff-100, rgba(255,255,255,.1))}
        .support-message-row.bot .support-message-content:before,.support-message-row.employee .support-message-content:before,.support-message-row.admin .support-message-content:before{content:'مساعد الوليد الهندسية';display:block;color:var(--awl-fg-ffffff, #fff);font-weight:700;font-size:16px;margin-bottom:12px}
        .support-message-content{color:var(--awl-fg-d1d5db, #d1d5db)!important;line-height:1.9!important}
        .support-message-content strong{color:var(--awl-fg-f8fafc, #f8fafc)!important}
        .support-message-content code:not(pre code){background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;color:var(--awl-fg-a7f3d0, #a7f3d0)!important;padding:2px 6px!important;border-radius:6px!important;font-size:12px!important}
        .support-message-content pre{direction:ltr!important;text-align:left!important;margin:14px 0!important;padding:48px 16px 16px!important;background:var(--awl-bg-121316, #121316)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:12px!important;overflow:auto!important;position:relative!important;box-shadow:0 12px 30px var(--awl-sh-000000-300, rgba(0,0,0,.30))!important}
        .support-message-content pre:before{content:'Dart  ·  code';position:absolute;left:0;right:0;top:0;height:36px;display:flex;align-items:center;padding:0 14px;color:var(--awl-fg-34d399, #34d399);background:var(--awl-bg-1a1b20, #1a1b20);border-bottom:1px solid var(--awl-bd-26262a, #26262a);font:600 11px 'JetBrains Mono',monospace}
        .support-message-content pre code{color:var(--awl-fg-d1d5db, #d1d5db)!important;background:transparent!important;font-size:12px!important;line-height:1.7!important}
        .support-message-tools{display:flex!important;gap:4px!important;margin-top:10px!important}
        .support-message-tool{width:auto!important;min-width:0!important;height:30px!important;padding:0 8px!important;border:0!important;border-radius:7px!important;background:transparent!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;font-size:11px!important}
        .support-message-tool:hover{background:var(--awl-bg-2a2b32, #2a2b32)!important;color:var(--awl-fg-ffffff, #fff)!important}
        .support-message-meta{display:block!important;color:#6b7280!important;font:10px 'JetBrains Mono',monospace!important;margin-top:6px!important}
        .support-message-row.customer .support-message-meta{color:#6b7280!important;text-align:left!important}
        .support-message-row.system .support-message{display:inline-flex!important;align-items:center!important;gap:10px!important;background:var(--awl-bg-1f1f23, #1f1f23)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:12px!important;padding:9px 14px!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;font-size:12px!important}

        /* Existing composer, exact desktop styling from the supplied design. */
        #supportBotForm{display:block!important;width:100%!important;padding:0!important;background:transparent!important;border:0!important;margin:0!important}
        #supportBotForm .support-bot-composer-shell{background:var(--awl-bg-1f1f23, #1f1f23)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:16px!important;padding:8px!important;box-shadow:0 18px 48px var(--awl-sh-000000-450, rgba(0,0,0,.45))!important;transition:.15s ease!important}
        #supportBotForm .support-bot-composer-shell:focus-within{border-color:rgba(99,102,241,.70)!important;box-shadow:0 0 0 2px rgba(99,102,241,.18),0 18px 48px var(--awl-sh-000000-450, rgba(0,0,0,.45))!important}
        #supportBotForm .support-bot-composer-inline{display:flex!important;align-items:center!important;gap:8px!important}
        #supportBotAttach{width:36px!important;height:36px!important;border-radius:12px!important;background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;color:var(--awl-fg-d1d5db, #d1d5db)!important;font-size:20px!important}
        #supportBotInput{min-height:40px!important;max-height:120px!important;background:transparent!important;border:0!important;box-shadow:none!important;color:var(--awl-fg-f3f4f6, #f3f4f6)!important;font-size:14px!important;padding:8px!important;resize:none!important;outline:none!important}
        #supportBotInput::placeholder{color:#6b7280!important}
        #supportBotEffortBtn{height:34px!important;border-radius:9px!important;background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;color:var(--awl-fg-d1d5db, #d1d5db)!important;padding:0 10px!important;font-size:12px!important}
        #supportBotVoice{width:36px!important;height:36px!important;border:0!important;background:transparent!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;border-radius:10px!important;font-size:16px!important}
        #supportBotVoice:hover{background:var(--awl-bg-2a2b32, #2a2b32)!important;color:var(--awl-fg-ffffff, #fff)!important}
        #supportBotSend{width:36px!important;height:36px!important;border-radius:10px!important;background:#4f46e5!important;border:0!important;color:var(--awl-fg-ffffff, white)!important;box-shadow:0 7px 18px rgba(79,70,229,.30)!important}
        #supportBotSend:hover{background:#6366f1!important}
        .support-bot-mobile-indicator{display:none!important}
        #supportBotAttachmentPreview{margin-bottom:8px!important}
        #supportBotDropOverlay{position:fixed!important;inset:0!important;z-index:90!important}

        /* Reused history controls inside the exact sidebar. */
        #aiExactHistoryHost .support-bot-history-search{padding:0 0 8px!important;margin:0!important}
        #aiExactHistoryHost #supportBotHistorySearch{width:100%!important;background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:9px!important;color:var(--awl-fg-e5e7eb, #e5e7eb)!important;padding:8px 10px!important;font-size:11px!important;outline:none!important}
        #aiExactHistoryHost #supportBotHistoryList{display:block!important;overflow:visible!important;padding:0!important;margin:0!important}
        #aiExactHistoryHost .support-bot-history-item{position:relative!important;width:100%!important;text-align:right!important;border:1px solid transparent!important;background:transparent!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;border-radius:8px!important;padding:8px 30px 8px 8px!important;margin:0 0 2px!important;cursor:pointer!important;transition:.15s ease!important}
        #aiExactHistoryHost .support-bot-history-item:hover,#aiExactHistoryHost .support-bot-history-item.is-active{background:var(--awl-bg-2a2b32, #2a2b32)!important;color:var(--awl-fg-ffffff, #fff)!important;border-color:var(--awl-bd-26262a, #26262a)!important}
        #aiExactHistoryHost .support-bot-history-item strong{display:block!important;font-size:11px!important;white-space:nowrap!important;overflow:hidden!important;text-overflow:ellipsis!important}
        #aiExactHistoryHost .support-bot-history-item span{display:none!important}
        #aiExactHistoryHost .support-bot-history-item-actions{position:absolute!important;right:5px!important;top:5px!important;display:none!important}
        #aiExactHistoryHost .support-bot-history-item:hover .support-bot-history-item-actions{display:flex!important}
        #aiExactHistoryHost .support-bot-history-icon-btn{width:24px!important;height:24px!important;border:0!important;background:var(--awl-bg-171719, #171719)!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;border-radius:6px!important}

        /* Runtime overlays must stay functional above the new visual shell. */
        #supportBotSettingsPanel,#supportBotLanguageModal,#supportBotVoiceOverlay{z-index:120!important}

        @media(max-width:900px){
            #aiExactShell .ai-exact-sidebar{display:none!important}
            #aiExactShell .ai-project-label,#aiExactShell .ai-share-text{display:none!important}
            #supportBotMessages{padding:18px 14px 132px!important}
            .support-message-row{margin-bottom:20px!important}
            .support-message-row.bot .support-message,.support-message-row.employee .support-message,.support-message-row.admin .support-message{padding-right:0!important}
            .support-message-row.bot .support-message:before,.support-message-row.employee .support-message:before,.support-message-row.admin .support-message:before{display:none!important}
        }
    </style>
    {{-- Shared day/night preference (same key as every other page). --}}
    @include('components.daylight-theme')
    {{-- Day colours for the browser-built Tailwind on this page. --}}
    @include('components.daylight-cdn-tokens')
    <style id="aw-assistant-brand">
        /* Assistant avatar = platform logo (was a generic sparkle). background-size crops the logo image's own margins. */
        .support-message-row.bot .support-message:before,
        .support-message-row.employee .support-message:before,
        .support-message-row.admin .support-message:before{
            content:''!important;
            background:#0b1326 url('{{ asset('images/Mainlogo.png') }}') center/140% no-repeat!important;
            border:1px solid rgba(96,165,250,.28)!important;
            box-shadow:0 6px 18px rgba(15,23,42,.25)!important;
        }
    </style>
</head>
<body class="flex w-screen h-screen overflow-hidden antialiased text-gray-200 bg-dark-bg selection:bg-indigo-500 selection:text-white">

<div id="aiExactShell" class="flex w-screen h-screen overflow-hidden text-gray-200 bg-dark-bg">
    <aside class="flex flex-col flex-shrink-0 h-full border-l select-none ai-exact-sidebar w-72 bg-dark-sidebar border-dark-border">
        <div class="p-3 pb-2 space-y-3">
            <div class="flex items-center justify-between px-2 pt-1 text-gray-300">
                <div class="flex items-center gap-2">
                    <div class="flex items-center justify-center w-8 h-8 text-base font-bold border rounded-lg shadow-sm bg-emerald-600/20 text-emerald-400 border-emerald-500/30">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M13 10V3L4 14h7v7l9-11h-7z" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                    </div>
                    <span class="text-sm font-bold tracking-wide text-white">DevAI Assistant</span>
                </div>
                <button id="aiExactSearchFocus" class="p-1.5 hover:bg-dark-hover rounded-md text-gray-400 hover:text-white transition" title="بحث وتصفية">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                </button>
            </div>
            <button id="aiExactNewChat" class="w-full flex items-center justify-between px-3.5 py-2.5 bg-dark-surface hover:bg-dark-hover border border-dark-border hover:border-gray-700 text-sm text-gray-200 font-medium rounded-xl transition duration-150 group shadow-sm">
                <div class="flex items-center gap-2.5">
                    <div class="flex items-center justify-center w-5 h-5 rounded bg-emerald-500/20 text-emerald-400">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path d="M12 4v16m8-8H4" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                    </div>
                    <span>محادثة جديدة</span>
                </div>
                <kbd class="text-[10px] text-gray-500 bg-dark-card px-1.5 py-0.5 rounded border border-dark-border group-hover:border-gray-600 font-mono">⌘K</kbd>
            </button>
        </div>
        <nav class="px-3 py-1 space-y-0.5 text-xs text-gray-300 font-medium border-b border-dark-border/60 pb-2">
            <button id="aiExactVisual" type="button" class="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg hover:bg-dark-hover text-gray-300 hover:text-white transition">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                <span class="flex-1">الصور والتحليل البصري</span><span class="px-1.5 py-0.2 text-[9px] font-semibold bg-emerald-900/50 text-emerald-300 rounded border border-emerald-700/40">محدّث</span>
            </button>
            <button id="aiExactLibraries" type="button" class="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg hover:bg-dark-hover text-gray-300 hover:text-white transition">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                <span>المكتبة البرمجية (Library)</span>
            </button>
            <button id="aiExactProjects" type="button" class="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg hover:bg-dark-hover text-gray-300 hover:text-white transition">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                <span>المشاريع النشطة</span>
            </button>
            <button id="aiExactTasks" type="button" class="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg hover:bg-dark-hover text-gray-300 hover:text-white transition">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                <span>المهام المجدولة</span>
            </button>
        </nav>
        <div class="flex-1 px-3 pt-3 space-y-1 overflow-y-auto text-xs">
            <div class="px-2 pb-1.5 text-[11px] font-semibold text-gray-400 uppercase tracking-wider">المحادثات الأخيرة</div>
            <div id="aiExactHistoryHost"></div>
        </div>
        <div class="p-3 border-t border-dark-border bg-dark-sidebar/95">
            <div class="flex items-center justify-between p-2 transition cursor-pointer rounded-xl hover:bg-dark-hover group">
                <div class="flex items-center gap-3">
                    <div class="relative">
                        <div class="flex items-center justify-center w-8 h-8 text-xs font-bold text-white rounded-full bg-gradient-to-tr from-sky-600 to-indigo-600 ring-2 ring-emerald-500/30">{{ mb_substr(auth()->user()->name ?? 'م',0,1) }}</div>
                        <div class="absolute bottom-0 right-0 w-2.5 h-2.5 bg-emerald-500 rounded-full ring-2 ring-dark-sidebar"></div>
                    </div>
                    <div class="flex flex-col text-right">
                        <span class="text-xs font-semibold text-gray-200 group-hover:text-white">{{ auth()->user()->name ?? 'مستخدم' }}</span>
                        <span class="text-[10px] text-emerald-400 font-medium flex items-center gap-1"><span>Plus Member</span><span class="w-1 h-1 rounded-full bg-emerald-400"></span><span class="font-mono text-gray-400">Flutter Dev</span></span>
                    </div>
                </div>
                <div class="text-gray-400 group-hover:text-white"><svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M12 5v.01M12 12v.01M12 19v.01" stroke-linecap="round" stroke-linejoin="round"></path></svg></div>
            </div>
        </div>
    </aside>

    <main class="relative flex flex-col flex-1 h-full overflow-hidden bg-dark-bg">
        <header class="z-20 flex items-center justify-between px-6 border-b h-14 border-dark-border bg-dark-bg/80 backdrop-blur">
            <div class="flex items-center gap-3">
                <div class="relative" id="aiExactVersionSelector">
                    <button type="button" id="aiExactVersionButton" aria-haspopup="true" aria-expanded="false" aria-controls="aiExactVersionPopup" class="flex items-center gap-2.5 px-3 py-1.5 rounded-lg bg-dark-surface border border-dark-border hover:border-gray-700 text-xs font-semibold text-gray-200 transition shadow-sm">
                        <span class="w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.7)] animate-pulse"></span><span id="aiExactVersionLabel">V1 (إجابة سريعة)</span>
                        <svg class="w-3.5 h-3.5 text-gray-400 mr-1" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M19 9l-7 7-7-7" stroke-linecap="round" stroke-linejoin="round"></path></svg>
                    </button>
                    <div id="aiExactVersionPopup" role="menu" class="hidden absolute top-full right-0 mt-2 w-[min(350px,calc(100vw-32px))] max-h-[70vh] overflow-y-auto rounded-xl border border-dark-border bg-dark-surface p-2 shadow-2xl z-[80]"></div>
                </div>
                <span class="text-sm text-gray-600 ai-project-label">|</span>
                <span class="ai-project-label text-xs text-gray-400 flex items-center gap-1.5"><svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" stroke-linecap="round" stroke-linejoin="round"></path></svg>المحادثة: <span id="aiExactConversationTitle" class="font-mono text-gray-300">محادثة جديدة</span></span>
            </div>
            <div class="flex items-center gap-2">
                <button id="aiExactShare" class="flex items-center gap-1.5 px-3 py-1.5 text-xs text-gray-300 hover:text-white bg-dark-surface hover:bg-dark-hover border border-dark-border rounded-lg transition"><svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316" stroke-linecap="round" stroke-linejoin="round"></path></svg><span class="ai-share-text">مشاركة الجلسة</span></button>
                <button id="aiExactOptions" class="p-2 text-gray-400 transition rounded-lg hover:text-white hover:bg-dark-hover" title="خيارات إضافية"><svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M5 12h.01M12 12h.01M19 12h.01" stroke-linecap="round" stroke-linejoin="round"></path></svg></button>
            </div>
        </header>
        <div id="aiExactMessagesHost" class="flex-1 min-h-0 overflow-hidden"></div>
        <footer class="absolute inset-x-0 bottom-0 z-20 px-4 pb-3 pt-7 bg-gradient-to-t from-dark-bg via-dark-bg/95 to-transparent">
            <div id="aiExactComposerHost" class="max-w-4xl mx-auto"></div>
            <p class="text-[11px] text-center text-gray-500 mt-2 font-normal">قد يقع الذكاء الاصطناعي في الخطأ أحياناً. تحقق دائماً من سلامة الأكواد والملفات البرمجية قبل النشر على الإنتاج.</p>
        </footer>
    </main>
</div>

<div id="aiExactWorkspaceModal" class="hidden fixed inset-0 z-[150] bg-black/70 backdrop-blur-sm items-center justify-center p-4">
    <div class="w-full max-w-xl max-h-[78vh] overflow-hidden rounded-2xl border border-dark-border bg-dark-surface shadow-2xl">
        <div class="flex items-center justify-between px-4 py-3 border-b border-dark-border">
            <strong id="aiExactWorkspaceTitle" class="text-sm text-white">مساحة AI</strong>
            <button id="aiExactWorkspaceClose" class="p-2 text-gray-400 hover:text-white">✕</button>
        </div>
        <div id="aiExactWorkspaceActions" class="px-4 pt-3"></div>
        <div id="aiExactWorkspaceBody" class="p-4 overflow-y-auto max-h-[62vh] space-y-2"></div>
    </div>
</div>

<x-support-bot :standalone="true" />
@stack('styles')
<style id="aiExactFinalOverrides">
        html,body{margin:0;width:100%;height:100%;overflow:hidden;background:var(--awl-bg-0d0d0e, #0d0d0e);color:var(--awl-fg-ececf1, #ececf1)}
        body{font-family:'Cairo','Tajawal',sans-serif;-webkit-font-smoothing:antialiased}
        code,pre{font-family:'JetBrains Mono',monospace}
        ::-webkit-scrollbar{width:6px;height:6px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:#2b2c35;border-radius:9999px}::-webkit-scrollbar-thumb:hover{background:#3f414e}
        #aiExactShell{visibility:hidden;position:absolute;inset:0;z-index:10}
        #aiExactShell.is-mounted{visibility:visible}

        /* Keep the existing AI runtime alive, but the visual surface comes from the exact shell. */
        #supportBotToggle{display:none!important}
        #supportBotPanel{position:fixed!important;inset:0!important;width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;border:0!important;border-radius:0!important;box-shadow:none!important;background:transparent!important;overflow:visible!important;z-index:30!important}
        #supportBotPanel>.support-bot-header,
        #supportBotPanel>#supportBotHomeHero,
        #supportBotPanel>#supportBotActions,
        #supportBotPanel>#supportBotSuggestions{display:none!important}
        #supportBotHistory{display:none!important}

        /* Runtime message stream mapped to the supplied desktop design. */
        #supportBotMessages{display:block!important;flex:1!important;min-height:0!important;overflow-y:auto!important;width:100%!important;margin:0!important;padding:24px 32px 150px!important;background:var(--awl-bg-0d0d0e, #0d0d0e)!important;scrollbar-width:thin;scrollbar-color:#2b2c35 transparent}
        .support-message-row{display:flex!important;width:100%!important;margin:0 auto 26px!important;max-width:896px!important}
        .support-message-row.customer{justify-content:flex-start!important}
        .support-message-row.bot,.support-message-row.employee,.support-message-row.admin{justify-content:flex-end!important}
        .support-message-row.system{justify-content:flex-end!important}
        .support-message{max-width:min(720px,88%)!important;padding:0!important;border:0!important;box-shadow:none!important;background:transparent!important;color:var(--awl-fg-e5e7eb, #e5e7eb)!important;position:relative!important;font-size:14px!important;line-height:1.8!important}
        .support-message-row.customer .support-message{background:var(--awl-bg-1e1b4b-400, rgba(30,27,75,.4))!important;border:1px solid rgba(99,102,241,.30)!important;border-radius:16px 4px 16px 16px!important;padding:14px 16px!important;color:var(--awl-fg-f3f4f6, #f3f4f6)!important;box-shadow:0 1px 2px var(--awl-sh-000000-250, rgba(0,0,0,.25))!important}
        .support-message-row.bot .support-message,.support-message-row.employee .support-message,.support-message-row.admin .support-message{max-width:820px!important;width:100%!important;padding-right:52px!important}
        .support-message-row.bot .support-message:before,.support-message-row.employee .support-message:before,.support-message-row.admin .support-message:before{content:'✦';position:absolute;right:0;top:0;width:36px;height:36px;border-radius:12px;background:linear-gradient(135deg,#059669,#14b8a6,#4f46e5);display:grid;place-items:center;color:var(--awl-fg-ffffff, white);font-size:18px;box-shadow:0 8px 22px var(--awl-sh-000000-350, rgba(0,0,0,.35));border:1px solid var(--awl-bd-ffffff-100, rgba(255,255,255,.1))}
        .support-message-row.bot .support-message-content:before,.support-message-row.employee .support-message-content:before,.support-message-row.admin .support-message-content:before{content:'مساعد الوليد الهندسية';display:block;color:var(--awl-fg-ffffff, #fff);font-weight:700;font-size:16px;margin-bottom:12px}
        .support-message-content{color:var(--awl-fg-d1d5db, #d1d5db)!important;line-height:1.9!important}
        .support-message-content strong{color:var(--awl-fg-f8fafc, #f8fafc)!important}
        .support-message-content code:not(pre code){background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;color:var(--awl-fg-a7f3d0, #a7f3d0)!important;padding:2px 6px!important;border-radius:6px!important;font-size:12px!important}
        .support-message-content pre{direction:ltr!important;text-align:left!important;margin:14px 0!important;padding:48px 16px 16px!important;background:var(--awl-bg-121316, #121316)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:12px!important;overflow:auto!important;position:relative!important;box-shadow:0 12px 30px var(--awl-sh-000000-300, rgba(0,0,0,.30))!important}
        .support-message-content pre:before{content:'Dart  ·  code';position:absolute;left:0;right:0;top:0;height:36px;display:flex;align-items:center;padding:0 14px;color:var(--awl-fg-34d399, #34d399);background:var(--awl-bg-1a1b20, #1a1b20);border-bottom:1px solid var(--awl-bd-26262a, #26262a);font:600 11px 'JetBrains Mono',monospace}
        .support-message-content pre code{color:var(--awl-fg-d1d5db, #d1d5db)!important;background:transparent!important;font-size:12px!important;line-height:1.7!important}
        .support-message-tools{display:flex!important;gap:4px!important;margin-top:10px!important}
        .support-message-tool{width:auto!important;min-width:0!important;height:30px!important;padding:0 8px!important;border:0!important;border-radius:7px!important;background:transparent!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;font-size:11px!important}
        .support-message-tool:hover{background:var(--awl-bg-2a2b32, #2a2b32)!important;color:var(--awl-fg-ffffff, #fff)!important}
        .support-message-meta{display:block!important;color:#6b7280!important;font:10px 'JetBrains Mono',monospace!important;margin-top:6px!important}
        .support-message-row.customer .support-message-meta{color:#6b7280!important;text-align:left!important}
        .support-message-row.system .support-message{display:inline-flex!important;align-items:center!important;gap:10px!important;background:var(--awl-bg-1f1f23, #1f1f23)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:12px!important;padding:9px 14px!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;font-size:12px!important}

        /* Existing composer, exact desktop styling from the supplied design. */
        #supportBotForm{display:block!important;width:100%!important;padding:0!important;background:transparent!important;border:0!important;margin:0!important}
        #supportBotForm .support-bot-composer-shell{background:var(--awl-bg-1f1f23, #1f1f23)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:16px!important;padding:8px!important;box-shadow:0 18px 48px var(--awl-sh-000000-450, rgba(0,0,0,.45))!important;transition:.15s ease!important}
        #supportBotForm .support-bot-composer-shell:focus-within{border-color:rgba(99,102,241,.70)!important;box-shadow:0 0 0 2px rgba(99,102,241,.18),0 18px 48px var(--awl-sh-000000-450, rgba(0,0,0,.45))!important}
        #supportBotForm .support-bot-composer-inline{display:flex!important;align-items:center!important;gap:8px!important}
        #supportBotAttach{width:36px!important;height:36px!important;border-radius:12px!important;background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;color:var(--awl-fg-d1d5db, #d1d5db)!important;font-size:20px!important}
        #supportBotInput{min-height:40px!important;max-height:120px!important;background:transparent!important;border:0!important;box-shadow:none!important;color:var(--awl-fg-f3f4f6, #f3f4f6)!important;font-size:14px!important;padding:8px!important;resize:none!important;outline:none!important}
        #supportBotInput::placeholder{color:#6b7280!important}
        #supportBotEffortBtn{height:34px!important;border-radius:9px!important;background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;color:var(--awl-fg-d1d5db, #d1d5db)!important;padding:0 10px!important;font-size:12px!important}
        #supportBotVoice{width:36px!important;height:36px!important;border:0!important;background:transparent!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;border-radius:10px!important;font-size:16px!important}
        #supportBotVoice:hover{background:var(--awl-bg-2a2b32, #2a2b32)!important;color:var(--awl-fg-ffffff, #fff)!important}
        #supportBotSend{width:36px!important;height:36px!important;border-radius:10px!important;background:#4f46e5!important;border:0!important;color:var(--awl-fg-ffffff, white)!important;box-shadow:0 7px 18px rgba(79,70,229,.30)!important}
        #supportBotSend:hover{background:#6366f1!important}
        .support-bot-mobile-indicator{display:none!important}
        #supportBotAttachmentPreview{margin-bottom:8px!important}
        #supportBotDropOverlay{position:fixed!important;inset:0!important;z-index:90!important}

        /* Reused history controls inside the exact sidebar. */
        #aiExactHistoryHost .support-bot-history-search{padding:0 0 8px!important;margin:0!important}
        #aiExactHistoryHost #supportBotHistorySearch{width:100%!important;background:var(--awl-bg-171719, #171719)!important;border:1px solid var(--awl-bd-26262a, #26262a)!important;border-radius:9px!important;color:var(--awl-fg-e5e7eb, #e5e7eb)!important;padding:8px 10px!important;font-size:11px!important;outline:none!important}
        #aiExactHistoryHost #supportBotHistoryList{display:block!important;overflow:visible!important;padding:0!important;margin:0!important}
        #aiExactHistoryHost .support-bot-history-item{position:relative!important;width:100%!important;text-align:right!important;border:1px solid transparent!important;background:transparent!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;border-radius:8px!important;padding:8px 30px 8px 8px!important;margin:0 0 2px!important;cursor:pointer!important;transition:.15s ease!important}
        #aiExactHistoryHost .support-bot-history-item:hover,#aiExactHistoryHost .support-bot-history-item.is-active{background:var(--awl-bg-2a2b32, #2a2b32)!important;color:var(--awl-fg-ffffff, #fff)!important;border-color:var(--awl-bd-26262a, #26262a)!important}
        #aiExactHistoryHost .support-bot-history-item strong{display:block!important;font-size:11px!important;white-space:nowrap!important;overflow:hidden!important;text-overflow:ellipsis!important}
        #aiExactHistoryHost .support-bot-history-item span{display:none!important}
        #aiExactHistoryHost .support-bot-history-item-actions{position:absolute!important;right:5px!important;top:5px!important;display:none!important}
        #aiExactHistoryHost .support-bot-history-item:hover .support-bot-history-item-actions{display:flex!important}
        #aiExactHistoryHost .support-bot-history-icon-btn{width:24px!important;height:24px!important;border:0!important;background:var(--awl-bg-171719, #171719)!important;color:var(--awl-fg-9ca3af, #9ca3af)!important;border-radius:6px!important}

        /* Runtime overlays must stay functional above the new visual shell. */
        #supportBotSettingsPanel,#supportBotLanguageModal,#supportBotVoiceOverlay{z-index:120!important}

        @media(max-width:900px){
            #aiExactShell .ai-exact-sidebar{display:none!important}
            #aiExactShell .ai-project-label,#aiExactShell .ai-share-text{display:none!important}
            #supportBotMessages{padding:18px 14px 132px!important}
            .support-message-row{margin-bottom:20px!important}
            .support-message-row.bot .support-message,.support-message-row.employee .support-message,.support-message-row.admin .support-message{padding-right:0!important}
            .support-message-row.bot .support-message:before,.support-message-row.employee .support-message:before,.support-message-row.admin .support-message:before{display:none!important}
        }

        /* ===== Center the conversation column in the chat area =====
           support-bot.blade.php pins message rows to one side with
           margin-left/right !important. The #supportBotMessages ID selector
           has higher priority, so rows are centered again here. */
        #supportBotMessages .support-message-row,
        #supportBotMessages .support-message-row.customer,
        #supportBotMessages .support-message-row.bot,
        #supportBotMessages .support-message-row.employee,
        #supportBotMessages .support-message-row.admin,
        #supportBotMessages .support-message-row.system{
            display:flex!important;
            flex-direction:row!important;
            align-items:flex-start!important;
            width:100%!important;
            max-width:896px!important;
            margin-left:auto!important;
            margin-right:auto!important;
        }
        #supportBotMessages .support-message-row.customer{justify-content:flex-start!important}
        #supportBotMessages .support-message-row.bot,
        #supportBotMessages .support-message-row.employee,
        #supportBotMessages .support-message-row.admin,
        #supportBotMessages .support-message-row.system{justify-content:flex-end!important}
        #supportBotMessages .support-message-row.customer .support-message{margin-left:0!important;margin-right:0!important}
        @media(max-width:900px){
            #supportBotMessages .support-message-row,
            #supportBotMessages .support-message-row.customer,
            #supportBotMessages .support-message-row.bot{max-width:100%!important}
        }

        /* ===== Make the message list scroll inside the chat area =====
           The messages box is moved into #aiExactMessagesHost by JS.
           Give the host a flex column and give the list a fixed height,
           so long conversations scroll instead of being cut off. */
        #aiExactMessagesHost{
            display:flex!important;
            flex-direction:column!important;
            flex:1 1 0%!important;
            min-height:0!important;
            overflow:hidden!important;
        }
        #aiExactMessagesHost > #supportBotMessages{
            display:block!important;
            flex:1 1 0%!important;
            height:100%!important;
            max-height:100%!important;
            min-height:0!important;
            overflow-y:auto!important;
            overflow-x:hidden!important;
            overscroll-behavior-y:contain!important;
            -webkit-overflow-scrolling:touch;
        }
</style>
@stack('scripts')

<script>
(function(){
    const mount = () => {
        const shell = document.getElementById('aiExactShell');
        const panel = document.getElementById('supportBotPanel');
        const messages = document.getElementById('supportBotMessages');
        const form = document.getElementById('supportBotForm');
        const historyList = document.getElementById('supportBotHistoryList');
        const historySearch = document.getElementById('supportBotHistorySearch');
        if (!shell || !panel || !messages || !form) return;

        const messagesHost = document.getElementById('aiExactMessagesHost');
        const composerHost = document.getElementById('aiExactComposerHost');
        const historyHost = document.getElementById('aiExactHistoryHost');

        messagesHost.appendChild(messages);
        composerHost.appendChild(form);
        if (historyHost && historySearch) {
            const wrap = document.createElement('div');
            wrap.className = 'support-bot-history-search';
            wrap.appendChild(historySearch);
            historyHost.appendChild(wrap);
        }
        if (historyHost && historyList) historyHost.appendChild(historyList);

        panel.appendChild(shell);
        shell.classList.add('is-mounted');

        // The header mirrors the real six-profile picker. Selecting a version calls
        // the existing, server-authorized AI profile option; no duplicate billing path.
        const versionButton = document.getElementById('aiExactVersionButton');
        const versionLabel = document.getElementById('aiExactVersionLabel');
        const versionPopup = document.getElementById('aiExactVersionPopup');
        const runtimeProfiles = document.getElementById('supportBotProfileList');
        const versionByProfile = {fast:'V1',smart:'V2',programming:'V3',engineering:'V4',design3d:'V5',expert:'V6'};
        const safeLabel = (value) => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
        const closeVersionPopup = () => {
            versionPopup?.classList.add('hidden');
            versionButton?.setAttribute('aria-expanded', 'false');
        };
        const syncVersion = () => {
            if (!runtimeProfiles || !versionPopup || !versionLabel) return;
            const sourceButtons = Array.from(runtimeProfiles.querySelectorAll('[data-ai-profile]'));
            const active = sourceButtons.find(button => button.classList.contains('is-active')) || sourceButtons[0];
            if (active) {
                const key = active.dataset.aiProfile || 'fast';
                const name = active.querySelector('b')?.textContent?.trim() || 'إجابة سريعة';
                versionLabel.textContent = `${versionByProfile[key] || 'V1'} (${name})`;
            }
            versionPopup.innerHTML = sourceButtons.map(button => {
                const key = button.dataset.aiProfile || 'fast';
                const name = button.querySelector('b')?.textContent?.trim() || 'إجابة سريعة';
                const description = button.querySelector('small')?.textContent?.trim() || '';
                const cost = button.querySelector('em')?.textContent?.trim() || '';
                const disabled = button.disabled;
                const selected = button.classList.contains('is-active');
                return `<button type="button" role="menuitem" data-version-profile="${safeLabel(key)}" ${disabled ? 'disabled' : ''}
                    class="w-full rounded-lg px-3 py-2.5 text-right ${selected ? 'bg-dark-hover text-white' : 'text-gray-300 hover:bg-dark-hover'} ${disabled ? 'opacity-50 cursor-not-allowed' : ''}">
                    <span class="flex items-center justify-between gap-3"><b class="text-xs">${safeLabel(versionByProfile[key] || 'V1')} · ${safeLabel(name)}</b><em class="text-[11px] text-indigo-300 not-italic">${safeLabel(cost)}</em></span>
                    <small class="block text-[10px] text-gray-400 mt-1">${safeLabel(description)}</small></button>`;
            }).join('');
            versionPopup.querySelectorAll('[data-version-profile]').forEach(button => {
                button.addEventListener('click', () => {
                    const source = sourceButtons.find(item => item.dataset.aiProfile === button.dataset.versionProfile);
                    if (source && !source.disabled) source.click();
                    closeVersionPopup();
                });
            });
        };
        versionButton?.addEventListener('click', () => {
            syncVersion();
            const isOpen = versionPopup?.classList.toggle('hidden') === false;
            versionButton.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        });
        document.addEventListener('click', event => {
            if (!document.getElementById('aiExactVersionSelector')?.contains(event.target)) closeVersionPopup();
        });
        document.addEventListener('keydown', event => { if (event.key === 'Escape') closeVersionPopup(); });
        if (runtimeProfiles) new MutationObserver(syncVersion).observe(runtimeProfiles, {childList:true, subtree:true});
        syncVersion();

        document.getElementById('aiExactNewChat')?.addEventListener('click', () => document.getElementById('supportBotNewBtn')?.click());
        document.getElementById('aiExactSearchFocus')?.addEventListener('click', () => historySearch?.focus());
        document.getElementById('aiExactOptions')?.addEventListener('click', () => document.getElementById('supportBotSettingsBtn')?.click());
        document.getElementById('aiExactShare')?.addEventListener('click', async () => {
            const text = Array.from(messages.querySelectorAll('.support-message-content')).map(el => el.innerText.trim()).filter(Boolean).join('\n\n');
            try {
                if (navigator.share) await navigator.share({title:'محادثة AI', text});
                else await navigator.clipboard.writeText(text);
            } catch (_) {}
        });

        const workspaceModal = document.getElementById('aiExactWorkspaceModal');
        const workspaceTitle = document.getElementById('aiExactWorkspaceTitle');
        const workspaceBody = document.getElementById('aiExactWorkspaceBody');
        const workspaceActions = document.getElementById('aiExactWorkspaceActions');
        const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
        const workspaceUrl = @json(route('support-bot.workspace'));
        const libraryCreateUrl = @json(route('support-bot.workspace.libraries.create'));
        const workspaceConversationsUrl = @json(route('support-bot.workspace.conversations'));

        const escapeText = (value) => String(value ?? '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));
        const closeWorkspace = () => { workspaceModal?.classList.add('hidden'); workspaceModal?.classList.remove('flex'); };
        const openWorkspace = () => { workspaceModal?.classList.remove('hidden'); workspaceModal?.classList.add('flex'); };
        document.getElementById('aiExactWorkspaceClose')?.addEventListener('click', closeWorkspace);
        workspaceModal?.addEventListener('click', (e) => { if (e.target === workspaceModal) closeWorkspace(); });

        async function fetchJson(url, options = {}) {
            const response = await fetch(url, {
                credentials: 'same-origin',
                headers: {'Accept':'application/json','Content-Type':'application/json','X-CSRF-TOKEN':csrf,'X-Requested-With':'XMLHttpRequest', ...(options.headers || {})},
                ...options,
            });
            const data = await response.json().catch(() => ({}));
            if (!response.ok) throw new Error(data.message || 'تعذر تنفيذ الطلب.');
            return data;
        }

        async function openLinkedPicker({projectId = null, libraryId = null, label = 'مساحة AI'}) {
            const query = new URLSearchParams();
            if (projectId) query.set('project_id', projectId);
            if (libraryId) query.set('library_id', libraryId);
            const data = await fetchJson(`${workspaceConversationsUrl}?${query.toString()}`, {method:'GET'});
            workspaceTitle.textContent = label;
            workspaceActions.innerHTML = '';
            const items = Array.isArray(data.conversations) ? data.conversations : [];
            workspaceBody.innerHTML = `<button id="aiExactNewLinkedChat" class="w-full p-3 text-right text-white border rounded-xl border-indigo-500/30 bg-indigo-950/30 hover:bg-indigo-950/50"><b>＋ محادثة AI جديدة مرتبطة هنا</b></button>` + items.map(item => `<button data-chat-id="${Number(item.id)}" class="w-full p-3 text-right border rounded-xl border-dark-border bg-dark-card hover:bg-dark-hover"><b class="text-gray-100">${escapeText(item.title || 'محادثة AI')}</b></button>`).join('');
            openWorkspace();
            document.getElementById('aiExactNewLinkedChat')?.addEventListener('click', () => {
                closeWorkspace();
                window.startSupportBotWorkspaceConversation?.({projectId, libraryId});
            });
            workspaceBody.querySelectorAll('[data-chat-id]').forEach(btn => btn.addEventListener('click', () => {
                closeWorkspace();
                const id = Number(btn.dataset.chatId || 0);
                if (id) window.openSupportBotConversationById?.(id);
            }));
        }

        async function openWorkspaceSection(section) {
            try {
                const data = await fetchJson(workspaceUrl, {method:'GET'});
                const rows = section === 'projects' ? (data.projects || []) : section === 'libraries' ? (data.libraries || []) : (data.scheduled_tasks || []);
                workspaceTitle.textContent = section === 'projects' ? 'المشاريع النشطة' : section === 'libraries' ? 'المكتبة البرمجية (Library)' : 'المهام المجدولة';
                workspaceActions.innerHTML = section === 'libraries' ? '<button id="aiExactCreateLibrary" class="px-3 py-2 text-xs font-bold text-white bg-indigo-600 rounded-lg">＋ مكتبة جديدة</button>' : '';
                workspaceBody.innerHTML = rows.length ? rows.map(item => {
                    const title = section === 'libraries' ? item.name : item.title;
                    const subtitle = section === 'projects' ? `${item.number || ''} • ${item.status || ''}` : section === 'libraries' ? `${item.conversations_count || 0} محادثة` : (item.project_title || '');
                    const pid = section === 'projects' ? item.id : section === 'tasks' ? item.project_id : '';
                    const lid = section === 'libraries' ? item.id : '';
                    return `<button data-project-id="${pid || ''}" data-library-id="${lid || ''}" data-label="${escapeText(title || '')}" class="w-full p-3 text-right border rounded-xl border-dark-border bg-dark-card hover:bg-dark-hover"><b class="block text-gray-100">${escapeText(title || 'عنصر')}</b><small class="text-gray-400">${escapeText(subtitle)}</small></button>`;
                }).join('') : '<div class="py-10 text-center text-gray-500">لا توجد عناصر حالياً.</div>';
                openWorkspace();
                workspaceBody.querySelectorAll('[data-project-id],[data-library-id]').forEach(btn => btn.addEventListener('click', () => openLinkedPicker({projectId:Number(btn.dataset.projectId || 0) || null, libraryId:Number(btn.dataset.libraryId || 0) || null, label:btn.dataset.label || 'مساحة AI'})));
                document.getElementById('aiExactCreateLibrary')?.addEventListener('click', async () => {
                    const name = window.prompt('اسم المكتبة الجديدة:');
                    if (!name?.trim()) return;
                    await fetchJson(libraryCreateUrl, {method:'POST', body:JSON.stringify({name:name.trim()})});
                    await openWorkspaceSection('libraries');
                });
            } catch (error) {
                workspaceTitle.textContent = 'تعذر التحميل';
                workspaceBody.innerHTML = `<div class="text-sm text-rose-400">${escapeText(error.message || 'حدث خطأ.')}</div>`;
                openWorkspace();
            }
        }

        document.getElementById('aiExactVisual')?.addEventListener('click', () => {
            const input = document.getElementById('supportBotFileInput');
            if (!input) return;
            input.setAttribute('accept', 'image/*');
            input.click();
            setTimeout(() => input.removeAttribute('accept'), 500);
        });
        document.getElementById('aiExactLibraries')?.addEventListener('click', () => openWorkspaceSection('libraries'));
        document.getElementById('aiExactProjects')?.addEventListener('click', () => openWorkspaceSection('projects'));
        document.getElementById('aiExactTasks')?.addEventListener('click', () => openWorkspaceSection('tasks'));
        window.addEventListener('support-bot-conversation-changed', (event) => {
            const titleNode = document.getElementById('aiExactConversationTitle');
            if (titleNode) titleNode.textContent = event.detail?.title || 'محادثة جديدة';
        });


        document.addEventListener('keydown', (event) => {
            if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
                event.preventDefault();
                document.getElementById('supportBotNewBtn')?.click();
            }
        });
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount, {once:true});
    else mount();
})();
</script>
</body>
</html>
