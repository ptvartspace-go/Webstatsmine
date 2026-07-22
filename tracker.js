/* ---------------------------------------------------------------------
   PTV Traffic Ledger — tracker
   Drop this on any page you want counted:

     <script src="https://YOURNAME.github.io/webstats/tracker.js"
             data-site="ptv-english" defer></script>

   No cookies, no fingerprinting, no third parties. A visit id lives in
   sessionStorage and disappears when the tab closes.

   To count something that is not a page load (a worksheet tab, a
   finished quiz), call it yourself:

     ptvTrack('/burger-worksheet#step-4');
--------------------------------------------------------------------- */
(function () {
  "use strict";

  // ---- settings -----------------------------------------------------
  var SUPABASE_URL = "https://tvzkshimtvomdezdprzl.supabase.co";
  var SUPABASE_ANON_KEY = "sb_publishable_VcR7yM25FNnTSbwMMHrFaQ_i2TsPeJC";
  var RESPECT_DNT = true;   // skip visitors who ask not to be tracked
  var SKIP_LOCAL = true;    // skip localhost / 127.0.0.1 / file://

  // ---- work out which site this is ----------------------------------
  var tag = document.currentScript;
  var SITE = (tag && tag.getAttribute("data-site")) || location.hostname || "unknown";

  // ---- bail out politely --------------------------------------------
  var host = location.hostname;
  var isLocal = !host || host === "localhost" || host === "127.0.0.1" || location.protocol === "file:";
  var ua = navigator.userAgent || "";
  var looksAutomated = navigator.webdriver === true ||
    /bot|crawl|spider|slurp|headless|lighthouse|preview|pingdom|monitor/i.test(ua);
  var optedOut = RESPECT_DNT &&
    (navigator.doNotTrack === "1" || window.doNotTrack === "1" || navigator.msDoNotTrack === "1");

  if (looksAutomated || optedOut || (SKIP_LOCAL && isLocal)) return;

  // ---- visit id ------------------------------------------------------
  function visitId() {
    try {
      var v = sessionStorage.getItem("ptv_visit");
      if (!v) {
        v = (Date.now().toString(36) + Math.random().toString(36).slice(2, 10));
        sessionStorage.setItem("ptv_visit", v);
      }
      return v;
    } catch (e) {
      return "no-storage";
    }
  }

  // ---- where did they come from --------------------------------------
  function source() {
    var r = document.referrer;
    if (!r) return "";
    try {
      var h = new URL(r).hostname.replace(/^www\./, "");
      return h === host.replace(/^www\./, "") ? "" : h;
    } catch (e) {
      return "";
    }
  }

  // ---- rough device and browser --------------------------------------
  function device() {
    var w = window.innerWidth || screen.width || 0;
    if (/Mobi|Android|iPhone|iPod/i.test(ua) || w < 640) return "phone";
    if (/iPad|Tablet/i.test(ua) || w < 1024) return "tablet";
    return "desktop";
  }

  function browser() {
    if (/Edg\//.test(ua)) return "Edge";
    if (/OPR\/|Opera/.test(ua)) return "Opera";
    if (/Firefox\//.test(ua)) return "Firefox";
    if (/SamsungBrowser/.test(ua)) return "Samsung";
    if (/Chrome\//.test(ua)) return "Chrome";
    if (/Safari\//.test(ua)) return "Safari";
    return "Other";
  }

  // ---- send ------------------------------------------------------------
  function send(path) {
    var body = {
      site: SITE,
      path: (path || location.pathname + location.search).slice(0, 300) || "/",
      referrer: source().slice(0, 200),
      visit_id: visitId(),
      device: device(),
      browser: browser(),
      lang: (navigator.language || "").slice(0, 10)
    };

    try {
      fetch(SUPABASE_URL + "/rest/v1/hits", {
        method: "POST",
        keepalive: true,
        headers: {
          "apikey": SUPABASE_ANON_KEY,
          "Authorization": "Bearer " + SUPABASE_ANON_KEY,
          "Content-Type": "application/json",
          "Prefer": "return=minimal"
        },
        body: JSON.stringify(body)
      })["catch"](function () {});
    } catch (e) {}
  }

  window.ptvTrack = send;
  send();
})();
