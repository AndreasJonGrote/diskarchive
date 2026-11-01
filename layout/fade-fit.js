(function () {
  if (window.__fadeFit) return; window.__fadeFit = true;
  var st = document.createElement('style');
  st.textContent = '[data-fit]{-webkit-mask-image:none!important;mask-image:none!important}';
  document.head.appendChild(st);
  var queued = false;
  function upd() {
    queued = false;
    var els = document.querySelectorAll('[style*="mask-image"]');
    for (var i = 0; i < els.length; i++) {
      var e = els[i], s = e.getAttribute('style') || '';
      if (!/linear-gradient\(\s*to right\s*,\s*(#000|rgb\(\s*0\s*,\s*0\s*,\s*0\s*\)|black)/i.test(s)) continue;
      var over = e.scrollWidth > e.clientWidth + 1;
      if (over) e.removeAttribute('data-fit'); else if (!e.hasAttribute('data-fit')) e.setAttribute('data-fit', '');
    }
  }
  function q() { if (!queued) { queued = true; requestAnimationFrame(upd); } }
  new MutationObserver(function (m) { for (var i = 0; i < m.length; i++) { if (m[i].attributeName !== 'data-fit') { q(); return; } } }).observe(document.documentElement, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ['style', 'class'] });
  window.addEventListener('resize', q);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(q);
  if (window.ResizeObserver) new ResizeObserver(q).observe(document.documentElement);
  q(); setTimeout(q, 500); setTimeout(q, 2000);
})();
