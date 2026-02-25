// Bootstrap for Flutter web - loads main.dart.js
(function() {
  const base = document.querySelector('base');
  const baseHref = base ? base.getAttribute('href') || '/' : '/';
  window.FLUTTER_BASE_HREF = baseHref.endsWith('/') ? baseHref : baseHref + '/';
})();
