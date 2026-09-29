{{--
  Platform root UI fix.
  One central layer for legacy pages:
  - remove page-local navigation and keep layouts.navigation as the only nav
  - normalize legacy dark-only surfaces when the global theme is light
  - keep the original dark design untouched
  - rerun after Livewire/AJAX DOM changes
--}}
<style id="aw-platform-root-fix">
  #platform-main-content{min-width:0;width:100%;}
  #platform-main-content .aw-local-nav-removed{display:none!important;}
  #platform-main-content .aw-rootfix-content{
    margin-inline:0!important;right:auto!important;left:auto!important;
    width:100%!important;max-width:none!important;min-width:0!important;
  }
  #platform-main-content .aw-rootfix-layout{
    grid-template-columns:minmax(0,1fr)!important;
    margin-inline:0!important;padding-inline-start:0!important;padding-inline-end:0!important;
  }

  html[data-aw-theme="light"] #platform-main-content{
    --bg:#f4f7fb;--page-bg:#f4f7fb;--background:#f4f7fb;
    --surface:#ffffff;--surface-low:#f8fafc;--surface-container:#ffffff;
    --surface-high:#eef3f8;--surface-highest:#e2e8f0;--card:#ffffff;
    --text:#0f172a;--text-primary:#0f172a;--muted:#475569;--text-secondary:#475569;
    --outline:#cbd5e1;--border:#cbd5e1;--divider:#e2e8f0;
    --cp-bg:#f4f7fb;--cp-surface:#ffffff;--cp-card:#ffffff;--cp-text:#0f172a;--cp-muted:#475569;
    --crm-bg:#f4f7fb;--crm-surface:#ffffff;--crm-card:#ffffff;--crm-text:#0f172a;--crm-muted:#475569;
    color:#0f172a;background:#f4f7fb;
  }
  html[data-aw-theme="light"] #platform-main-content .aw-light-surface{
    background:#fff!important;background-image:none!important;color:#0f172a!important;
    border-color:#d8e1ec!important;box-shadow:0 10px 30px rgba(15,23,42,.06)!important;
  }
  html[data-aw-theme="light"] #platform-main-content .aw-light-surface-soft{
    background:#f8fafc!important;background-image:none!important;color:#0f172a!important;
    border-color:#d8e1ec!important;
  }
  html[data-aw-theme="light"] #platform-main-content .aw-light-readable{color:#0f172a!important;}
  html[data-aw-theme="light"] #platform-main-content .aw-light-muted{color:#475569!important;}
  html[data-aw-theme="light"] #platform-main-content input:not([type="checkbox"]):not([type="radio"]),
  html[data-aw-theme="light"] #platform-main-content textarea,
  html[data-aw-theme="light"] #platform-main-content select{
    background-color:#fff;color:#0f172a;border-color:#cbd5e1;
  }
  html[data-aw-theme="light"] #platform-main-content input::placeholder,
  html[data-aw-theme="light"] #platform-main-content textarea::placeholder{color:#64748b;opacity:1;}
  html[data-aw-theme="light"] #platform-main-content table{color:#0f172a;}
  html[data-aw-theme="light"] #platform-main-content thead{background:#eef3f8;color:#334155;}
  html[data-aw-theme="light"] #platform-main-content tbody tr{border-color:#e2e8f0;}

  /* Known legacy Tailwind arbitrary colours used as page/card backgrounds. */
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#071426]"],
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#060e20]"],
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#0b1326]"],
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#10131a]"],
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#171f33]"],
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#1b2437]"],
  html[data-aw-theme="light"] #platform-main-content [class*="bg-[#222a3d]"]{
    background-color:#fff!important;background-image:none!important;color:#0f172a!important;
    border-color:#d8e1ec!important;
  }

  @media(max-width:1023px){
    #platform-main-content .aw-rootfix-content{padding-bottom:1rem!important;}
  }
</style>
<script>
(function(){
  'use strict';
  if(window.__awPlatformRootFixLoaded)return;
  window.__awPlatformRootFixLoaded=true;

  var ROOT='#platform-main-content';
  var navWords=/(^|[-_])(sidebar|topbar|mobile[-_]?nav|bottom[-_]?nav|mobile[-_]?drawer|side[-_]?nav)([-_]|$)/i;
  var contentWords=/(^|[-_])(main|content|page[-_]?content|workspace)([-_]|$)/i;
  var skipWords=/(button|btn|badge|chip|status|alert|toast|avatar|logo|image|media|video|chart|map|gradient|primary|accent|success|danger|warning|neon)/i;

  function cls(el){return (typeof el.className==='string'?el.className:'')}
  function visible(el){var r=el.getBoundingClientRect();return r.width>0&&r.height>0}
  function isNavish(el){
    var c=cls(el);
    if(!navWords.test(c))return false;
    var tag=el.tagName.toLowerCase();
    var links=el.querySelectorAll('a,button,[role="button"]').length;
    var cs=getComputedStyle(el);
    if(tag==='nav'||tag==='aside'||links>=2)return true;
    return cs.position==='fixed'||cs.position==='sticky';
  }
  function removeLocalNavigation(root){
    root.querySelectorAll('aside,header,nav,div').forEach(function(el){
      if(el.closest('#main-navigation'))return;
      if(isNavish(el))el.classList.add('aw-local-nav-removed');
    });
    root.querySelectorAll('main,section,div').forEach(function(el){
      var c=cls(el);
      if(contentWords.test(c)&&(c.indexOf('cp-main')>=0||/lg:m[lr]-\d+|margin-(left|right)/i.test(c)||el.parentElement&&el.parentElement.querySelector('.aw-local-nav-removed'))){
        el.classList.add('aw-rootfix-content');
      }
      if(el.parentElement&&el.parentElement.querySelector(':scope > .aw-local-nav-removed')){
        el.parentElement.classList.add('aw-rootfix-layout');
      }
    });
  }
  // Parses rgb()/rgba() including the alpha channel. A transparent background
  // (rgba(0,0,0,0)) must NOT be treated as a dark surface.
  function rgb(c){
    var m=c&&c.match(/rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,\/]\s*([\d.]+%?))?/i);
    if(!m)return null;
    var a=m[4]===undefined?1:(String(m[4]).slice(-1)==='%'?parseFloat(m[4])/100:parseFloat(m[4]));
    return [+m[1],+m[2],+m[3],isNaN(a)?1:a];
  }
  function opaque(v){return !!v&&v[3]>=0.08}
  function lum(v){return v?(0.2126*v[0]+0.7152*v[1]+0.0722*v[2])/255:1}
  function normalizeLight(root){
    if(document.documentElement.getAttribute('data-aw-theme')!=='light')return;
    root.querySelectorAll('main,section,article,form,div,table').forEach(function(el){
      if(el.classList.contains('aw-local-nav-removed')||skipWords.test(cls(el)))return;
      if(el.closest('button,a,[role="button"],dialog,[role="dialog"]'))return;
      if(el.querySelector('video')&&el.getBoundingClientRect().height<500)return;
      var r=el.getBoundingClientRect();
      if(r.width*r.height<6500)return;
      var bg=rgb(getComputedStyle(el).backgroundColor);
      if(opaque(bg)&&lum(bg)<.22){
        el.classList.add(r.width>500||r.height>180?'aw-light-surface':'aw-light-surface-soft');
      }
    });
    root.querySelectorAll('h1,h2,h3,h4,h5,h6,p,label,dt,dd,th,td,span').forEach(function(el){
      if(el.closest('button,a,[role="button"],.badge,[class*="badge"],[class*="chip"],[class*="status"]'))return;
      var color=rgb(getComputedStyle(el).color);if(color&&color[3]>0&&lum(color)>.68){
        var fs=parseFloat(getComputedStyle(el).fontSize||'14');
        el.classList.add(fs<=13?'aw-light-muted':'aw-light-readable');
      }
    });
  }
  function run(){var root=document.querySelector(ROOT);if(!root)return;removeLocalNavigation(root);normalizeLight(root)}
  function queue(){clearTimeout(window.__awRootFixTimer);window.__awRootFixTimer=setTimeout(run,20)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',run,{once:true});else run();
  document.addEventListener('livewire:navigated',run);
  new MutationObserver(queue).observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['data-aw-theme','class']});
  window.addEventListener('pageshow',run);
})();
</script>
