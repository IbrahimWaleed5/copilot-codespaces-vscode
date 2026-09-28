/*
 * English interface helper (loaded only on English pages).
 * Translates Arabic text that JavaScript adds after the page has loaded
 * (toasts, modals, AJAX content, messages from phone-input.js / profile-photo-cropper.js ...)
 * by asking the server dictionary: POST /lang/translate.
 * If anything fails, the Arabic text simply stays as it is.
 */
(function () {
    'use strict';
    var root = document.documentElement;
    if ((root.getAttribute('lang') || '').slice(0, 2) !== 'en' || !window.fetch || !window.MutationObserver) {
        return;
    }
    var script = document.currentScript || document.querySelector('script[data-endpoint]');
    var endpoint = (script && script.getAttribute('data-endpoint')) || '/lang/translate';
    var ARABIC = /[ء-يٱ-ۓ]/;
    var ATTRS = ['placeholder', 'title', 'aria-label', 'alt'];
    var SKIP = 'script,style,textarea,code,pre,[contenteditable],[contenteditable=""],[translate="no"],.notranslate';
    var cache = Object.create(null);   // arabic -> english (or same text if unknown)
    var waiting = Object.create(null); // arabic -> [callbacks]
    var queue = [];
    var timer = null;
    var failures = 0;

    function lookup(text, apply) {
        var core = text.trim();
        if (!core || !ARABIC.test(core)) { return; }
        var lead = text.slice(0, text.indexOf(core));
        var tail = text.slice(text.indexOf(core) + core.length);
        var done = function (en) { if (en && en !== core) { apply(lead + en + tail); } };
        if (core in cache) { done(cache[core]); return; }
        if (waiting[core]) { waiting[core].push(done); return; }
        waiting[core] = [done];
        queue.push(core);
        if (!timer) { timer = setTimeout(flush, 60); }
    }

    function flush() {
        timer = null;
        if (!queue.length || failures > 3) { return; }
        var batch = queue.splice(0, 100);
        fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'X-Locale': 'en' },
            body: JSON.stringify({ texts: batch }),
            credentials: 'same-origin'
        }).then(function (r) { return r.ok ? r.json() : null; }).then(function (data) {
            var map = (data && data.translations) || {};
            batch.forEach(function (ar) {
                var en = typeof map[ar] === 'string' ? map[ar] : ar;
                cache[ar] = en;
                (waiting[ar] || []).forEach(function (cb) { try { cb(en); } catch (e) {} });
                delete waiting[ar];
            });
        }).catch(function () {
            failures++;
            batch.forEach(function (ar) { cache[ar] = ar; delete waiting[ar]; });
        }).then(function () {
            if (queue.length) { timer = setTimeout(flush, 60); }
        });
    }

    function skipped(el) {
        return !el || (el.closest && el.closest(SKIP)) || el.id === 'ui-lang-switch';
    }

    function textNode(node) {
        var value = node.nodeValue;
        if (!value || !ARABIC.test(value) || skipped(node.parentElement)) { return; }
        lookup(value, function (en) { if (node.nodeValue === value) { node.nodeValue = en; } });
    }

    function attributes(el) {
        if (skipped(el)) { return; }
        ATTRS.forEach(function (name) {
            var value = el.getAttribute && el.getAttribute(name);
            if (value && ARABIC.test(value)) {
                lookup(value, function (en) { if (el.getAttribute(name) === value) { el.setAttribute(name, en); } });
            }
        });
        if (el.tagName === 'INPUT' && /^(submit|button|reset)$/i.test(el.type) && !el.name && ARABIC.test(el.value || '')) {
            var v = el.value;
            lookup(v, function (en) { if (el.value === v) { el.value = en; } });
        }
    }

    function scan(node) {
        if (!node) { return; }
        if (node.nodeType === 3) { textNode(node); return; }
        if (node.nodeType !== 1 || skipped(node)) { return; }
        attributes(node);
        var walker = document.createTreeWalker(node, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, null);
        var current;
        while ((current = walker.nextNode())) {
            if (current.nodeType === 3) { textNode(current); } else { attributes(current); }
        }
    }

    // Native dialogs: translate when the text is already known.
    ['alert', 'confirm', 'prompt'].forEach(function (fn) {
        var original = window[fn];
        if (typeof original !== 'function') { return; }
        window[fn] = function (message) {
            var args = Array.prototype.slice.call(arguments);
            if (typeof message === 'string') {
                var core = message.trim();
                if (core in cache && cache[core] !== core) { args[0] = cache[core]; } else if (ARABIC.test(core)) { lookup(message, function () {}); }
            }
            return original.apply(window, args);
        };
    });

    function start() {
        scan(document.body);
        new MutationObserver(function (mutations) {
            mutations.forEach(function (m) {
                if (m.type === 'characterData') { textNode(m.target); }
                else if (m.type === 'attributes') { attributes(m.target); }
                else { for (var i = 0; i < m.addedNodes.length; i++) { scan(m.addedNodes[i]); } }
            });
        }).observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });
    }

    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
