// Schildwall – YouTube-Werbung überspringen und ausblenden
(function () {
  if (window.__schildwall) return;
  window.__schildwall = true;

  var HIDE = [
    // mobile Seite (m.youtube.com)
    'ytm-promoted-sparkles-web-renderer', 'ytm-promoted-video-renderer',
    'ytm-companion-ad-renderer', 'ytm-companion-slot', 'ad-slot-renderer',
    'ytm-ad-slot-renderer', 'ytm-promoted-sparkles-text-search-renderer',
    'ytm-item-section-renderer:has(ad-slot-renderer)',
    'ytm-rich-item-renderer:has(ad-slot-renderer)',
    'ytm-statement-banner-renderer', 'ytm-mealbar-promo-renderer',
    'ytm-paid-content-overlay-renderer', '.ytm-paid-content-overlay',
    // Desktop-Seite (www.youtube.com)
    'ytd-ad-slot-renderer', 'ytd-in-feed-ad-layout-renderer',
    'ytd-banner-promo-renderer', 'ytd-promoted-sparkles-web-renderer',
    'ytd-promoted-video-renderer', 'ytd-display-ad-renderer',
    'ytd-companion-slot-renderer', 'ytd-action-companion-ad-renderer',
    'ytd-player-legacy-desktop-watch-ads-renderer', 'ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"]',
    'ytd-rich-item-renderer:has(ytd-ad-slot-renderer)',
    '#masthead-ad', '#player-ads', '#panels > ytd-ads-engagement-panel-content-renderer',
    // Overlays im Player
    '.ytp-ad-overlay-container', '.ytp-ad-overlay-slot', '.ytp-ad-image-overlay',
    '.ytp-ad-text-overlay', '.ytp-featured-product', '.ytp-suggested-action'
  ];

  var style = document.createElement('style');
  style.id = 'schildwall-yt';
  // jede Regel einzeln, damit ein unbekannter Selektor nicht alle anderen kaputt macht
  style.textContent = HIDE.map(function (sel) { return sel + ' { display: none !important; }'; }).join('\n');
  // Während einer Werbung: Untertitel der Werbung weg, Player schwarz mit Hinweis
  style.textContent += '\n' + [
    '.ad-showing .ytp-caption-window-container, .ad-showing .caption-window, .ad-showing .ytp-caption-segment, .ad-showing .ytp-ad-player-overlay, .ad-showing .ytp-ad-player-overlay-layout { display: none !important; }',
    '.ad-showing video { opacity: 0 !important; }',
    '.html5-video-player.ad-showing::after { content: "🛡 Werbung wird übersprungen …"; position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: #000; color: #7fd88e; font: 16px sans-serif; z-index: 99999; pointer-events: none; }'
  ].join('\n');
  (document.head || document.documentElement).appendChild(style);

  var SKIP = [
    '.ytp-ad-skip-button', '.ytp-ad-skip-button-modern', '.ytp-skip-ad-button',
    '.ytp-ad-skip-button-container button', '.ytm-skip-ad-button',
    'button.ytp-ad-skip-button-modern', '[class*="skip-ad"] button',
    '.ytp-ad-overlay-close-button'
  ].join(',');

  var inAd = false;
  var savedMuted = false;

  function tick() {
    if (!document.getElementById('schildwall-yt')) {
      (document.head || document.documentElement).appendChild(style);
    }

    var buttons = document.querySelectorAll(SKIP);
    for (var i = 0; i < buttons.length; i++) {
      try { buttons[i].click(); } catch (e) {}
    }

    var player = document.querySelector('.html5-video-player, #movie_player');
    var adShowing = !!(player && (player.classList.contains('ad-showing') ||
                                  player.classList.contains('ad-interrupting')));
    var video = document.querySelector('video');
    if (!video) return;

    if (adShowing) {
      if (!inAd) { inAd = true; savedMuted = video.muted; }
      video.muted = true;
      try { video.playbackRate = 16; } catch (e) {}
      if (isFinite(video.duration) && video.duration > 0 &&
          video.currentTime < video.duration - 0.1) {
        try { video.currentTime = video.duration; } catch (e) {}
      }
      if (video.paused) { try { video.play(); } catch (e) {} }
    } else if (inAd) {
      inAd = false;
      video.muted = savedMuted;
      try { video.playbackRate = 1; } catch (e) {}
    }
  }

  setInterval(tick, 250);
  var pending = false;
  new MutationObserver(function () {
    if (pending) return;
    pending = true;
    setTimeout(function () { pending = false; tick(); }, 60);
  }).observe(document.documentElement, {
    childList: true, subtree: true, attributes: true, attributeFilter: ['class']
  });
})();
