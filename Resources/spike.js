// Verification-build probes (spec section 10, K1-K5). Injected at document start, main frame only.
// Every probe is isolated: a failure in one must not break the page or the other probes.
(function () {
  "use strict";

  try {
    if (window.top !== window) return;
  } catch (e) {
    return;
  }

  var handler = null;
  try {
    handler = window.webkit.messageHandlers.mw;
  } catch (e) {
    return;
  }
  if (!handler) return;

  function send(type, fields) {
    try {
      var message = { type: type };
      if (fields) {
        for (var key in fields) {
          if (Object.prototype.hasOwnProperty.call(fields, key)) message[key] = fields[key];
        }
      }
      handler.postMessage(message);
    } catch (e) {
      // Nothing useful to do if posting itself fails.
    }
  }

  function guard(probe, fn) {
    return function () {
      try {
        return fn.apply(this, arguments);
      } catch (e) {
        send("error", { probe: probe, message: String((e && e.message) || e) });
      }
    };
  }

  function optionalString(value) {
    return value === undefined || value === null ? null : String(value);
  }

  // title: every document.title change, with document.visibilityState.
  guard("title", function () {
    var lastTitle = null;
    var observedHead = null;
    var headObserver = new MutationObserver(guard("title", check));
    var rootObserver = new MutationObserver(guard("title", attach));

    function check() {
      var title = document.title;
      if (title === lastTitle) return;
      lastTitle = title;
      send("title", { title: title, visibility: document.visibilityState });
    }

    // Re-attach whenever <head> appears or is replaced.
    function attach() {
      var head = document.head;
      if (head && head !== observedHead) {
        headObserver.disconnect();
        headObserver.observe(head, { childList: true, subtree: true, characterData: true });
        observedHead = head;
      }
      check();
    }

    if (document.documentElement) {
      rootObserver.observe(document.documentElement, { childList: true });
    }
    attach();
    document.addEventListener("DOMContentLoaded", guard("title", attach));
  })();

  // notification: fake Notification class that reports every `new Notification(t, o)`.
  guard("notification", function () {
    function FakeNotification(title, options) {
      var o = options || {};
      this.title = String(title);
      this.body = optionalString(o.body);
      this.tag = optionalString(o.tag);
      this.onclick = null;
      this.onshow = null;
      this.onclose = null;
      this.onerror = null;
      send("notification", { title: this.title, body: this.body, tag: this.tag });
    }
    FakeNotification.permission = "granted";
    FakeNotification.requestPermission = function (callback) {
      send("notificationPermissionRequest", {});
      try {
        if (typeof callback === "function") callback("granted");
      } catch (e) {
        // Ignore errors thrown by the page's callback.
      }
      return Promise.resolve("granted");
    };
    FakeNotification.prototype.close = function () {};
    FakeNotification.prototype.addEventListener = function () {};
    FakeNotification.prototype.removeEventListener = function () {};
    FakeNotification.prototype.dispatchEvent = function () {
      return true;
    };

    try {
      Object.defineProperty(window, "Notification", {
        value: FakeNotification,
        writable: true,
        configurable: true
      });
    } catch (e) {
      window.Notification = FakeNotification;
    }
  })();

  // sw: once, whether service workers and push are exposed.
  guard("sw", function () {
    send("sw", {
      serviceWorker: "serviceWorker" in navigator,
      pushManager: "PushManager" in window
    });
  })();

  // layout: 5 s after load and every 60 s, the banner and :root custom properties with "header".
  guard("layout", function () {
    function collectHeaderPropertyNames(names, rules) {
      for (var i = 0; i < rules.length; i++) {
        var rule = rules[i];
        if (rule.style) {
          for (var j = 0; j < rule.style.length; j++) {
            var name = rule.style[j];
            if (name.indexOf("--") === 0 && name.toLowerCase().indexOf("header") !== -1) names[name] = true;
          }
        }
        if (rule.cssRules) collectHeaderPropertyNames(names, rule.cssRules);
      }
    }

    function report() {
      var root = document.documentElement;
      var computed = getComputedStyle(root);
      var names = {};
      var unreadableSheets = 0;
      var i;

      // Custom properties exposed by computed-style enumeration (engine dependent).
      for (i = 0; i < computed.length; i++) {
        var computedName = computed[i];
        if (computedName.indexOf("--") === 0 && computedName.toLowerCase().indexOf("header") !== -1) {
          names[computedName] = true;
        }
      }
      // Custom properties declared in readable stylesheets.
      for (i = 0; i < document.styleSheets.length; i++) {
        try {
          collectHeaderPropertyNames(names, document.styleSheets[i].cssRules);
        } catch (e) {
          unreadableSheets++;
        }
      }

      var headerVars = {};
      for (var name in names) {
        var value = computed.getPropertyValue(name).trim();
        if (value !== "") headerVars[name] = value;
      }

      var banner = document.querySelector('[role="banner"]');
      send("layout", {
        path: location.pathname,
        banner: banner !== null,
        bannerHeight: banner ? banner.offsetHeight : null,
        headerVars: headerVars,
        unreadableSheets: unreadableSheets
      });
    }

    var start = guard("layout", function () {
      setTimeout(guard("layout", report), 5000);
      setInterval(guard("layout", report), 60000);
    });
    if (document.readyState === "complete") {
      start();
    } else {
      window.addEventListener("load", start, { once: true });
    }
  })();

  // heartbeat: every 30 s with visibilityState, to measure timer throttling while hidden.
  guard("heartbeat", function () {
    setInterval(guard("heartbeat", function () {
      send("heartbeat", { visibility: document.visibilityState });
    }), 30000);
  })();
})();
