// mermaid-init.js -- bootstrap mermaid for markdown-preview-mode.
//
// This file is read at use-package config time by `myde-markdown-preview-script-tag'
// and inlined verbatim into the preview page (the package only inlines entries
// already wrapped in a <script> tag; raw paths/URLs become <script src=…>).
//
// Pandoc emits ```mermaid fences in any of these shapes:
//
//   <pre><code class="language-mermaid">…</code></pre>
//   <pre class="mermaid"><code>…</code></pre>
//   <pre class="sourceCode mermaid"><code>…</code></pre>
//   <div class="sourceCode"><pre class="sourceCode mermaid"><code>…</code></pre></div>
//
// Strategy:
//   1. Initialize mermaid once at script-tag time.
//   2. Define `window.mydeMermaidRender' which finds every unprocessed source
//      under #markdown-body, replaces it with <div class="mermaid">, and calls
//      mermaid.run().
//   3. The package's `markdown-preview-script-onupdate' hook calls the render
//      function after every WebSocket refresh -- no MutationObserver needed.

(function () {
  if (typeof window.mermaid === 'undefined') {
    console.error('[mermaid-init] mermaid global missing -- CDN load failed?');
    return;
  }
  window.mermaid.initialize({startOnLoad: false, theme: 'dark', securityLevel: 'loose'});
  console.log('[mermaid-init] initialized; mermaid version =', window.mermaid.version || '?');

  window.mydeMermaidRender = function () {
    if (typeof window.mermaid === 'undefined') return;
    const root = document.getElementById('markdown-body') || document.body;

    root.querySelectorAll('pre > code.language-mermaid').forEach(function (code) {
      const pre = code.parentNode;
      const div = document.createElement('div');
      div.className = 'mermaid';
      div.textContent = code.textContent;
      pre.parentNode.replaceChild(div, pre);
    });

    root.querySelectorAll('pre.mermaid, pre.sourceCode.mermaid').forEach(function (pre) {
      const code = pre.querySelector('code');
      const src = code ? code.textContent : pre.textContent;
      const wrap = pre.parentNode;
      const target = (wrap && wrap.classList && wrap.classList.contains('sourceCode')) ? wrap : pre;
      const div = document.createElement('div');
      div.className = 'mermaid';
      div.textContent = src;
      target.parentNode.replaceChild(div, target);
    });

    try {
      window.mermaid.run({querySelector: '#markdown-body .mermaid:not([data-processed="true"])'});
    } catch (e) {
      console.error('[mermaid-init] mermaid.run failed:', e);
    }
  };

  try { window.mydeMermaidRender(); } catch (e) {}
})();
