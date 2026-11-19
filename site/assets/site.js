(function () {
  var KEY = 'otp-lang';
  var root = document.documentElement;
  var buttons = document.querySelectorAll('[data-set-lang]');
  var metaDesc = document.querySelector('meta[name="description"]');
  var ogTitle = document.querySelector('meta[property="og:title"]');
  var ogDesc = document.querySelector('meta[property="og:description"]');
  var ogImage = document.querySelector('meta[property="og:image"]');
  var ogLocale = document.querySelector('meta[property="og:locale"]');

  function apply(lang) {
    var isEN = lang === 'en';
    root.lang = isEN ? 'en' : 'zh-CN';
    document.querySelectorAll('[data-zh]').forEach(function (el) { el.hidden = isEN; });
    document.querySelectorAll('[data-en]').forEach(function (el) { el.hidden = !isEN; });
    buttons.forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-set-lang') === lang));
    });

    var title = isEN ? root.dataset.titleEn : root.dataset.titleZh;
    var desc = isEN ? root.dataset.descEn : root.dataset.descZh;
    if (title) document.title = title;
    if (desc && metaDesc) metaDesc.setAttribute('content', desc);
    if (title && ogTitle) ogTitle.setAttribute('content', title);
    if (desc && ogDesc) ogDesc.setAttribute('content', desc);
    if (ogImage) {
      var image = isEN ? root.dataset.ogEn : root.dataset.ogZh;
      if (image) ogImage.setAttribute('content', image);
    }
    if (ogLocale) ogLocale.setAttribute('content', isEN ? 'en_US' : 'zh_CN');
  }

  var saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) {}
  var initial = saved || ((navigator.language || 'zh').toLowerCase().indexOf('zh') === 0 ? 'zh' : 'en');
  apply(initial);

  buttons.forEach(function (b) {
    b.addEventListener('click', function () {
      var lang = b.getAttribute('data-set-lang');
      apply(lang);
      try { localStorage.setItem(KEY, lang); } catch (e) {}
    });
  });
})();
