(function () {
  'use strict';
  var btn = document.getElementById('menuBtn');
  var list = document.getElementById('navList');
  if (btn && list) {
    btn.addEventListener('click', function () {
      var open = list.classList.toggle('open');
      btn.setAttribute('aria-expanded', open);
    });
    list.addEventListener('click', function (e) {
      if (e.target.tagName === 'A') { list.classList.remove('open'); btn.setAttribute('aria-expanded', false); }
    });
  }
  var y = document.getElementById('year');
  if (y) y.textContent = new Date().getFullYear();

  var items = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); } });
    }, { threshold: 0.12 });
    items.forEach(function (el) { io.observe(el); });
  } else { items.forEach(function (el) { el.classList.add('in'); }); }

  // Contact form: no backend, so it validates and opens the visitor's email app.
  var form = document.getElementById('contactForm');
  if (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var msg = document.getElementById('formMsg');
      var name = form.name.value.trim(), email = form.email.value.trim(), text = form.message.value.trim();
      if (!name || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || text.length < 10) {
        msg.className = 'msg err';
        msg.textContent = 'Enter your name, a valid email, and a message of at least 10 characters.';
        return;
      }
      msg.className = 'msg ok';
      msg.textContent = 'Opening your email app…';
      window.location.href = 'mailto:' + form.dataset.to + '?subject=' + encodeURIComponent('Portfolio enquiry from ' + name) +
        '&body=' + encodeURIComponent(text + '\n\n' + name + ' (' + email + ')');
    });
  }
})();
