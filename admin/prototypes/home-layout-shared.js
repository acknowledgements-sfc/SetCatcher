/* eslint-disable no-var */
(function () {
  var STATES = {
    noSource: { color: "var(--dormant)", stroke: "#6B7280", label: "No Protection Source", detail: "Set up a recording folder…", bg: "rgba(107,114,128,0.06)" },
    detected: { color: "var(--detected)", stroke: "#E5E7EB", label: "Source Detected", detail: "Serato DJ Pro found", bg: "rgba(229,231,235,0.04)" },
    ready: { color: "var(--ready)", stroke: "#34D399", label: "Watching", detail: "Serato DJ Pro", bg: "rgba(52,211,153,0.05)" },
    armed: { color: "var(--armed)", stroke: "#FBBF24", label: "Armed", detail: "Serato DJ Pro — waiting for audio", meta: "Since 9:42 PM", bg: "rgba(251,191,36,0.06)" },
    capturing: { color: "var(--capturing)", stroke: "#EF4444", label: "Capturing", detail: "Recording from Serato DJ Pro", bold: true, bg: "rgba(239,68,68,0.06)" },
    saving: { color: "var(--saving)", stroke: "#60A5FA", label: "Saving…", detail: "Saturday Night Set — archiving", meta: "67%", bg: "rgba(96,165,250,0.06)" },
    setProtected: { color: "var(--protected)", stroke: "#10B981", label: "Set Protected", detail: "Saturday Night Set — just now", bg: "rgba(16,185,129,0.06)" },
    attentionNeeded: { color: "var(--attention)", stroke: "#F97316", label: "Attention Needed", detail: "Recording folder not found", fix: true, bg: "rgba(249,115,22,0.06)" }
  };

  var ATTENTION = {
    folderMoved: {
      detail: "Recording folder was moved · Fix now →",
      title: "Attention Needed",
      body: "Your recording folder was moved from /Music/DJ Sets to /Volumes/External/DJ Sets",
      warn: "Your next set won't be protected until this is resolved.",
      copy: "DJMemory found your folder at the new location.",
      actions: ["Use new location", "Choose folder…", "Use original path"]
    },
    folderMissing: {
      detail: "Recording folder not found · Fix now →",
      title: "Attention Needed",
      body: "/Music/DJ Sets no longer exists",
      warn: "Your next set won't be protected until you choose a new folder.",
      copy: "Previously protected sets are safe — they're already archived.",
      actions: ["Choose new folder…", "Create /Music/DJ Sets"]
    },
    permissionDenied: {
      detail: "Can't access recording folder · Fix now →",
      title: "Attention Needed",
      body: "SetCatcher can't write to /Music/DJ Sets",
      warn: "Recordings can't be saved until access is granted.",
      copy: "macOS sometimes resets folder permissions after updates. Granting access takes about 5 seconds.",
      actions: ["Grant access…", "Choose different folder…", "Open System Settings"]
    },
    diskFull: {
      detail: "Low disk space · 1.2 GB remaining · Fix now →",
      title: "Attention Needed",
      body: "Low disk space — 1.2 GB remaining",
      warn: "Capture may stop after approximately 18 minutes.",
      copy: "SetCatcher needs at least 2 GB free to safely capture a full set.",
      actions: ["Choose different folder…", "Open Storage Management", "Continue anyway"]
    },
    saveFailed: {
      detail: "Failed to archive Saturday Night Set · Fix now →",
      title: "Attention Needed",
      body: "Saturday Night Set could not be saved",
      warn: "",
      copy: "Your recording is safe in a temporary file. Nothing has been lost.",
      actions: ["Retry save", "Save to different location…", "Reveal temp file in Finder"]
    },
    sourceUnreadable: {
      detail: "Serato DJ Pro not responding · Fix now →",
      title: "Attention Needed",
      body: "Serato DJ Pro not responding",
      warn: "SetCatcher can't read audio from this source.",
      copy: "This usually happens when the app closes or the audio device changes. If Serato is still running, try restarting it.",
      actions: ["Choose different source…", "Dismiss"]
    }
  };

  var timerSeconds = 5025;
  var meterTimer = null;
  var capTimer = null;
  var toastTimer = null;

  /** Spec: Set Protected never appears in primary row — show Armed + toast instead. */
  function displayState(stateId) {
    return stateId === "setProtected" ? "armed" : stateId;
  }

  function showToastForState(stateId, manualToggle) {
    if (stateId !== "setProtected") return false;
    if (manualToggle) return true;
    return true;
  }

  function fmtTime(s) {
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(sec).padStart(2, "0");
  }

  function shieldIcon(stroke) {
    return '<svg viewBox="0 0 20 20" fill="none"><path d="M10 3L17 6.5v7L10 17 3 13.5V6.5L10 3z" stroke="' + stroke + '" stroke-width="1.2"/></svg>';
  }

  function secondaryRow(stateId) {
    var isFreshSave = stateId === "setProtected";
    return (
      '<div class="cockpit-secondary">' +
      '<div class="cs-dot"><svg viewBox="0 0 16 16" fill="#10B981">' + shieldIcon("#10B981") + "</svg></div>" +
      '<div class="cs-text"><div class="cs-label">Last Protected</div><div class="cs-value">' +
      (isFreshSave ? "Saturday Night Set · 1h 24m" : "Friday Night Set · 2h 14m") +
      "</div></div>" +
      '<div class="cs-meta">' + (isFreshSave ? "Just now" : "Aug 28, 11:42 PM") + "</div></div>"
    );
  }

  function toastRow() {
    return (
      '<div class="cockpit-toast" id="cockpit-toast">' +
      '<div class="toast-text">Set protected — Saturday Night Set · 1h 24m</div>' +
      '<div class="toast-meta">3.2 GB</div></div>'
    );
  }

  function recoveryPanel(kind) {
    var a = ATTENTION[kind] || ATTENTION.folderMissing;
    var buttons = a.actions.map(function (label, i) {
      return '<button type="button" class="btn ' + (i === 0 ? "btn-primary" : "btn-ghost") + '">' + label + "</button>";
    }).join("");
    var warn = a.warn ? '<p class="warn">' + a.warn + "</p>" : "";
    return (
      '<div class="recovery-panel" id="recovery-panel">' +
      "<h3>" + a.title + "</h3>" +
      "<p><strong>" + a.body + "</strong></p>" +
      warn +
      "<p>" + a.copy + "</p>" +
      '<div class="recovery-actions">' + buttons + "</div></div>"
    );
  }

  function renderPrimary(stateId, attentionKind) {
    var s = STATES[stateId] || STATES.ready;
    if (stateId === "attentionNeeded" && attentionKind && ATTENTION[attentionKind]) {
      s = Object.assign({}, s, { detail: ATTENTION[attentionKind].detail });
    }
    var fix = s.fix ? '<span class="cp-fix" id="fix-now">Fix now →</span>' : "";
    var meta = s.meta ? '<div class="cp-meta">' + s.meta + "</div>" : fix;
    return (
      '<div class="cockpit-primary" style="background:' + s.bg + '">' +
      '<div class="cp-icon">' + shieldIcon(s.stroke) + "</div>" +
      '<div class="cp-text"><div class="cp-name' + (s.bold ? " bold" : "") + '" style="color:' + s.color + '">' + s.label + "</div>" +
      '<div class="cp-detail">' + s.detail + "</div></div>" + meta + "</div>"
    );
  }

  function renderControls(stateId, mode) {
    var effective = displayState(stateId);
    if (mode === "band") return "";
    if (effective === "capturing") {
      return (
        '<div class="controls-stack">' +
        '<div class="capture-strip"><div class="rec-dot"></div><div><div class="cap-timer" id="cap-timer">' + fmtTime(timerSeconds) + '</div>' +
        '<div class="cap-meta">Serato DJ Pro · <span id="cap-size">128.4 MB</span></div></div>' +
        '<div class="cap-stop" title="Stop (requires confirmation)"><svg viewBox="0 0 12 12" width="12" height="12" fill="var(--capturing)"><rect x="2" y="2" width="8" height="8" rx="1.5"/></svg></div></div>' +
        meterHtml(true) + "</div>"
      );
    }
    if (effective === "noSource" || effective === "saving") return "";
    var armed = effective === "armed" || stateId === "setProtected";
    return (
      '<div class="controls-stack">' +
      '<div class="arm-row"><div class="toggle-track' + (armed ? " on-armed" : "") + '"><div class="toggle-knob"></div></div>' +
      '<div><div class="arm-title" style="color:' + (armed ? "var(--armed)" : "inherit") + '">' + (armed ? "Protection Armed" : "Arm Protection") + "</div>" +
      '<div class="arm-detail">' + (armed ? "Watching Serato DJ Pro · Will capture automatically" : "Tap to arm protection") + "</div></div></div>" +
      (armed || effective === "ready" ? meterHtml(armed) : "") +
      sourceCards() +
      "</div>"
    );
  }

  function meterHtml(active) {
    if (!active) return "";
    return (
      '<div class="meter-wrap"><div class="meter-label"><span>Input Level</span><span>-60 · -40 · -20 · -12 · 0</span></div>' +
      '<div class="meter-bar"><div class="meter-fill" id="meter-fill" style="width:35%;background:linear-gradient(90deg,var(--ready),var(--armed))"></div>' +
      '<div class="meter-peak" id="meter-peak" style="left:42%;background:var(--armed)"></div></div></div>'
    );
  }

  function sourceCards() {
    return (
      '<div class="source-card active"><div><div class="src-name">Serato DJ Pro</div><div class="src-method">App audio tap · Running</div></div>' +
      '<div class="src-badge" style="background:rgba(52,211,153,0.1);color:var(--ready)">Active</div></div>' +
      '<div class="source-card dim"><div><div class="src-name">rekordbox</div><div class="src-method">App audio tap · Not running</div></div></div>' +
      '<button type="button" class="add-source">+ Add source…</button>'
    );
  }

  function dashboardBelow(showAttentionBanner) {
    var banner = showAttentionBanner
      ? '<div class="attention-banner"><strong>Serato folder is unavailable.</strong> Everything already in your archive is safe. <button type="button" class="btn btn-primary" style="margin-top:8px">Fix Folder</button></div>'
      : "";
    return (
      banner +
      '<div class="dashboard-section"><div class="identity-band"><div class="greeting">Good evening, Rob</div><div class="meta">2 sources watched · SetCatcher since Aug 2025</div></div></div>' +
      '<div class="dashboard-section"><h2>At a glance</h2><div class="tiles">' +
      '<div class="tile"><div class="tile-label">Sets protected</div><div class="tile-value">47</div></div>' +
      '<div class="tile"><div class="tile-label">Hours archived</div><div class="tile-value">126</div></div>' +
      '<div class="tile"><div class="tile-label">Sources watched</div><div class="tile-value">2/5</div></div>' +
      '<div class="tile"><div class="tile-label">Unmatched sets</div><div class="tile-value">3</div></div></div></div>' +
      '<div class="dashboard-section"><h2>Recent sets</h2><div class="shelf">' +
      '<div class="shelf-card">Friday Night Set<br><span style="color:var(--text-muted)">2h 14m · Serato</span></div>' +
      '<div class="shelf-card">Warehouse Warmup<br><span style="color:var(--text-muted)">1h 02m · Serato</span></div>' +
      '<div class="shelf-card">Sunday Session<br><span style="color:var(--text-muted)">3h 01m · rekordbox</span></div></div></div>'
    );
  }

  function captureRoutePanel(stateId) {
    return (
      '<div class="split-pane-label">Capture route</div>' +
      renderControls(stateId, "full") +
      '<div class="annotation" style="margin-top:20px">Advanced: mode picker, session status, alternate-source banner, and permission retry stay on this route in layout C.</div>'
    );
  }

  function bandOnlyLink() {
    return '<button type="button" class="band-only-link" id="open-capture-link">Open Capture controls →</button>';
  }

  function scheduleToastDismiss() {
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      var toast = document.getElementById("cockpit-toast");
      if (toast) {
        toast.style.transition = "opacity 0.2s ease";
        toast.style.opacity = "0";
        setTimeout(function () { if (toast.parentNode) toast.remove(); }, 200);
      }
    }, 5000);
  }

  function renderMenuBar(stateId) {
    var effective = displayState(stateId);
    var s = STATES[effective] || STATES.ready;
    var badge = stateId === "attentionNeeded" ? '<span class="mb-badge"></span>' : "";
    var label = "";
    if (stateId === "capturing") {
      label = 'Serato · <span class="mb-timer">' + fmtTime(timerSeconds) + "</span>";
    } else if (stateId !== "noSource") {
      label = "Serato DJ Pro";
    }
    return (
      '<div class="menubar-preview"><div class="menubar-strip">' +
      '<div class="mb-item"><div class="mb-icon-wrap">' + badge + shieldIcon(s.stroke) + "</div>" +
      (label ? '<span class="mb-label">' + label + "</span>" : "") +
      "</div></div></div>"
    );
  }

  function renderDropdown(stateId) {
    if (stateId === "capturing") {
      return (
        '<div class="dropdown-preview"><div class="dd-zone capture">' +
        '<div class="dd-title" style="color:var(--capturing)">Capturing</div>' +
        '<div class="dd-detail">' + fmtTime(timerSeconds) + " · Serato DJ Pro · 128.4 MB</div></div>" +
        '<div class="dd-divider"></div><div class="dd-row"><span>Last Protected</span><span class="dd-kbd">Friday Night Set</span></div>' +
        '<div class="dd-divider"></div>' +
        '<div class="dd-row action"><span>Stop capture</span><span class="dd-kbd">⌘.</span></div>' +
        '<div class="dd-row action"><span>Stop &amp; disarm</span><span class="dd-kbd">⌘⇧A</span></div>' +
        '<div class="dd-divider"></div><div class="dd-row action">Open SetCatcher</div><div class="dd-row action">Activity Log</div>' +
        '<div class="dd-hidden-note">Preferences and Quit hidden during capture</div></div>'
      );
    }
    if (stateId === "attentionNeeded") {
      return (
        '<div class="dropdown-preview"><div class="dd-zone attention">' +
        '<div class="dd-title" style="color:var(--attention)">Attention Needed</div>' +
        '<div class="dd-detail">Save failed — your set is safe in a temp file</div></div>' +
        '<div class="dd-divider"></div><div class="dd-row action">Resolve in SetCatcher</div>' +
        '<div class="dd-divider"></div><div class="dd-row action">Open SetCatcher</div>' +
        '<div class="dd-hidden-note">Preferences and Quit hidden</div></div>'
      );
    }
    if (stateId === "armed") {
      return (
        '<div class="dropdown-preview"><div class="dd-zone">' +
        '<div class="dd-title" style="color:var(--armed)">Armed</div>' +
        '<div class="dd-detail">Watching Serato DJ Pro · Waiting for audio…</div>' +
        '<div class="dd-meta">Since 9:42 PM</div><div class="dd-mini-meter"><div></div></div></div>' +
        '<div class="dd-divider"></div><div class="dd-row"><span>Last Protected</span><span class="dd-kbd">Fri · 2h 14m</span></div>' +
        '<div class="dd-divider"></div>' +
        '<div class="dd-row action"><span>Start capture now</span><span class="dd-kbd">⌘⇧R</span></div>' +
        '<div class="dd-row action"><span>Disarm</span><span class="dd-kbd">⌘⇧A</span></div>' +
        '<div class="dd-divider"></div><div class="dd-row action">Open SetCatcher</div>' +
        '<div class="dd-row action">Preferences…</div><div class="dd-row action">Quit SetCatcher</div></div>'
      );
    }
    return (
      '<div class="dropdown-preview"><div class="dd-zone">' +
      '<div class="dd-title" style="color:' + s.color + '">' + s.label + "</div>" +
      '<div class="dd-detail">' + s.detail + "</div></div>" +
      '<div class="dd-divider"></div><div class="dd-row action">Open SetCatcher</div></div>'
    );
  }

  function sidebarHtml(layout, activeRoute) {
    var homeLabel = layout === "live" ? "Live" : "Home";
    var items = [
      { id: "home", label: homeLabel, route: layout === "live" ? "live" : "home" },
      { id: "protection", label: "Protection", route: "protection" },
      { id: "capture", label: "Capture", route: "capture", hide: layout === "a" || layout === "live" },
      { id: "library", label: "Library", route: "library" },
      { id: "settings", label: "Settings", route: "settings" }
    ];
    return items.map(function (item) {
      if (item.hide) {
        return '<div class="sidebar-item disabled"><span class="sidebar-dot"></span>' + item.label + " (removed)</div>";
      }
      var active = item.route === activeRoute ? " active" : "";
      return '<div class="sidebar-item' + active + '"><span class="sidebar-dot"></span>' + item.label + "</div>";
    }).join("");
  }

  function startAnimations(stateId) {
    if (meterTimer) clearInterval(meterTimer);
    if (capTimer) clearInterval(capTimer);
    if (stateId === "capturing") {
      capTimer = setInterval(function () {
        timerSeconds += 1;
        var el = document.getElementById("cap-timer");
        var mb = document.querySelector(".mb-timer");
        if (el) el.textContent = fmtTime(timerSeconds);
        if (mb) mb.textContent = fmtTime(timerSeconds);
      }, 1000);
    }
    if (stateId === "armed" || stateId === "capturing") {
      meterTimer = setInterval(function () {
        var fill = document.getElementById("meter-fill");
        var ddMeter = document.getElementById("dd-meter");
        var peak = document.getElementById("meter-peak");
        if (!fill && !ddMeter) return;
        var w = 20 + Math.random() * 55;
        if (fill) fill.style.width = w + "%";
        if (ddMeter) ddMeter.style.width = w + "%";
        if (peak) peak.style.left = Math.min(w + 4, 98) + "%";
      }, 66);
    }
  }

  function compactRecoveryPanel(kind) {
    var a = ATTENTION[kind] || ATTENTION.folderMissing;
    var buttons = a.actions.map(function (label, i) {
      return '<button type="button" class="btn ' + (i === 0 ? "btn-primary" : "btn-ghost") + '">' + label + "</button>";
    }).join("");
    var warn = a.warn ? '<p class="warn">' + a.warn + "</p>" : "";
    return (
      '<div class="compact-recovery">' +
      "<h3>" + a.title + "</h3>" +
      "<p><strong>" + a.body + "</strong></p>" +
      warn +
      "<p>" + a.copy + "</p>" +
      '<div class="recovery-actions">' + buttons + "</div></div>"
    );
  }

  function compactSourceChips() {
    return (
      '<div class="compact-sources">' +
      '<span class="source-chip active"><span class="dot"></span>Serato DJ Pro</span>' +
      '<span class="source-chip"><span class="dot"></span>rekordbox</span>' +
      '<span class="source-chip">+ Add</span></div>'
    );
  }

  function renderCompact(layout) {
    var stateId = window.__mockState || "armed";
    var attentionKind = window.__attentionKind || "folderMissing";
    var showRecovery = document.getElementById("toggle-recovery") && document.getElementById("toggle-recovery").checked;
    var primaryState = displayState(stateId);
    var s = STATES[primaryState] || STATES.ready;
    if (stateId === "attentionNeeded" && ATTENTION[attentionKind]) {
      s = Object.assign({}, s, { detail: ATTENTION[attentionKind].detail });
    }
    var showToast = showToastForState(stateId, false);
    var armed = primaryState === "armed" || stateId === "setProtected";
    var capturing = primaryState === "capturing";

    var fix = stateId === "attentionNeeded" ? '<span class="cp-fix" id="fix-now">Fix →</span>' : (s.meta ? '<span class="cp-meta">' + s.meta + "</span>" : "");

    var hero =
      '<div class="compact-hero" style="border-color:' + (stateId === "attentionNeeded" ? "rgba(249,115,22,0.2)" : "var(--border-subtle)") + '">' +
      '<div class="compact-status-row" style="background:' + s.bg + '">' +
      '<div class="cp-icon">' + shieldIcon(s.stroke) + "</div>" +
      '<div class="cp-text"><div class="cp-name' + (s.bold ? " bold" : "") + '" style="color:' + s.color + '">' + s.label + "</div>" +
      '<div class="cp-detail">' + s.detail + "</div></div>" + fix;

    if (capturing) {
      hero += '<div class="cap-timer" id="cap-timer" style="font-family:var(--fm);font-size:14px;color:var(--capturing)">' + fmtTime(timerSeconds) + "</div>";
    } else if (primaryState !== "noSource" && stateId !== "attentionNeeded" && primaryState !== "saving") {
      hero += '<div class="toggle-track' + (armed ? " on-armed" : "") + '" style="transform:scale(0.85);transform-origin:center right"><div class="toggle-knob"></div></div>';
    }
    hero += "</div>";

    if (showToast) {
      hero += '<div class="compact-toast" id="cockpit-toast">Set protected — Saturday Night Set · 1h 24m</div>';
    }

    if (stateId !== "noSource") {
      hero +=
        '<div class="compact-last"><span><strong>Last protected</strong> · ' +
        (stateId === "setProtected" ? "Saturday Night Set · 1h 24m" : "Friday Night Set · 2h 14m") +
        '</span><span class="mono">' + (stateId === "setProtected" ? "Just now" : "Aug 28") + "</span></div>";
    }

    if (capturing) {
      hero +=
        '<div class="compact-capture"><div class="rec-dot"></div>' +
        '<div><div class="cap-meta">Serato DJ Pro · <span id="cap-size">128.4 MB</span></div></div>' +
        '<div class="cap-stop" title="Stop"><svg viewBox="0 0 12 12" width="10" height="10" fill="var(--capturing)"><rect x="2" y="2" width="8" height="8" rx="1.5"/></svg></div></div>' +
        '<div class="compact-meter"><div class="meter-bar"><div class="meter-fill" id="meter-fill" style="width:42%;background:linear-gradient(90deg,var(--ready),var(--armed))"></div></div></div>';
    } else if (armed && primaryState !== "saving") {
      hero +=
        '<div class="compact-meter" style="padding:0 12px 8px"><div class="meter-bar"><div class="meter-fill" id="meter-fill" style="width:28%;background:linear-gradient(90deg,var(--ready),var(--armed))"></div></div></div>' +
        compactSourceChips();
    } else if (primaryState === "ready" || primaryState === "detected") {
      hero += compactSourceChips();
    }

    if (showRecovery && stateId === "attentionNeeded") {
      hero += compactRecoveryPanel(attentionKind);
    }

    hero += "</div>";

    var dashboard =
      '<div class="compact-dashboard">' +
      (stateId === "attentionNeeded" ? '<div class="attention-banner" style="padding:8px 10px;font-size:11px"><strong>Folder unavailable.</strong> Archive is safe.</div>' : "") +
      '<div class="dashboard-section"><div class="tiles">' +
      '<div class="tile"><div class="tile-label">Sets</div><div class="tile-value">47</div></div>' +
      '<div class="tile"><div class="tile-label">Hours</div><div class="tile-value">126</div></div>' +
      '<div class="tile"><div class="tile-label">Sources</div><div class="tile-value">2/5</div></div>' +
      '<div class="tile"><div class="tile-label">Unmatched</div><div class="tile-value">3</div></div></div></div>' +
      '<div class="dashboard-section"><h2>Recent sets</h2><div class="shelf">' +
      '<div class="shelf-card">Friday Night Set<br><span style="color:var(--text-muted)">2h 14m</span></div>' +
      '<div class="shelf-card">Warehouse Warmup<br><span style="color:var(--text-muted)">1h 02m</span></div>' +
      '<div class="shelf-card">Sunday Session<br><span style="color:var(--text-muted)">3h 01m</span></div></div></div></div>';

    var appEl = document.getElementById("app-root");
    if (!appEl) return;
    appEl.innerHTML =
      '<div class="app-shell"><div class="sidebar">' + sidebarHtml("b", "home") + '</div>' +
      '<div class="main-pane"><div class="main-scroll compact-home">' + hero + dashboard +
      '<div class="annotation">Layout B-Compact: single protection card (~48px status + inline toggle/meter/chips). Dashboard tiles + recent sets below. No separate identity band.</div>' +
      "</div></div></div>";

    var previewEl = document.getElementById("menu-preview");
    if (previewEl) previewEl.innerHTML = renderMenuBar(stateId) + renderDropdown(stateId);

    document.querySelectorAll(".state-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.dataset.state === stateId);
    });
    document.querySelectorAll(".attention-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.dataset.attention === attentionKind);
    });

    var fixEl = document.getElementById("fix-now");
    if (fixEl) fixEl.addEventListener("click", function () {
      var rec = document.getElementById("toggle-recovery");
      if (rec) rec.checked = true;
      renderCompact(layout);
    });

    startAnimations(primaryState);
    if (showToast && stateId === "setProtected") scheduleToastDismiss();
  }

  function liveCardTitle(stateId, primaryState) {
    var app = "Serato DJ";
    if (stateId === "attentionNeeded") return app + " needs attention";
    if (primaryState === "noSource") return "No protection source";
    if (primaryState === "detected") return app + " detected";
    if (primaryState === "ready") return app + " is watching";
    if (primaryState === "armed" || stateId === "setProtected") return app + " is Armed";
    if (primaryState === "capturing") return app + " is Capturing";
    if (primaryState === "saving") return "Saving set…";
    return STATES[primaryState].label;
  }

  function liveCardSince(stateId, primaryState) {
    if (primaryState === "armed" || stateId === "setProtected") return "since 9:42 PM";
    if (primaryState === "capturing") return fmtTime(timerSeconds) + " elapsed";
    if (primaryState === "saving") return "archiving…";
    if (stateId === "attentionNeeded") return ATTENTION[window.__attentionKind || "folderMissing"].detail.replace(" · Fix now →", "").replace(" · Fix now →", "");
    if (primaryState === "ready") return "configured · not armed";
    if (primaryState === "detected") return "found · set up to protect";
    if (primaryState === "noSource") return "add a source to begin";
    return "";
  }

  function renderLiveCard(layout) {
    var stateId = window.__mockState || "armed";
    var attentionKind = window.__attentionKind || "folderMissing";
    var showRecovery = document.getElementById("toggle-recovery") && document.getElementById("toggle-recovery").checked;
    var primaryState = displayState(stateId);
    var s = STATES[primaryState] || STATES.ready;
    var showToast = showToastForState(stateId, false);
    var showMeter = primaryState === "armed" || primaryState === "capturing" || stateId === "setProtected";
    var title = liveCardTitle(stateId, primaryState);
    var since = liveCardSince(stateId, primaryState);

    var card =
      '<div class="live-card" style="border-color:' + (stateId === "attentionNeeded" ? "rgba(249,115,22,0.25)" : "var(--border-subtle)") + '">' +
      '<div class="live-card-header" style="background:' + s.bg + '">' +
      '<div class="live-card-title" style="color:' + s.color + '">' +
      '<span class="hex">' + shieldIcon(s.stroke) + "</span><span>" + title + "</span></div>" +
      (since ? '<div class="live-card-since">' + since + "</div>" : "") +
      "</div>" +
      '<hr class="live-card-divider" />';

    if (showToast) {
      card += '<div class="live-card-toast" id="cockpit-toast">Set protected — Saturday Night Set · 1h 24m</div>';
    }

    if (showMeter) {
      card +=
        '<div class="live-card-body">' +
        '<div class="live-meter-label">Input Level</div>' +
        '<div class="live-meter-bar"><div class="live-meter-fill" id="meter-fill" style="width:38%;background:linear-gradient(90deg,var(--ready),var(--armed))"></div></div>' +
        "</div>";
    } else if (stateId === "attentionNeeded" && showRecovery) {
      card += compactRecoveryPanel(attentionKind);
    }

    card +=
      '<div class="live-card-footer">Last: ' +
      (stateId === "setProtected" ? "8/30 · Just now" : "8/28 · 11:42") +
      "</div></div>";

    var appEl = document.getElementById("app-root");
    if (!appEl) return;
    appEl.innerHTML =
      '<div class="app-shell"><div class="sidebar">' + sidebarHtml("live", "live") + '</div>' +
      '<div class="main-pane"><div class="main-scroll live-page">' + card +
      '<div class="live-sidebar-note"><strong>Not a dashboard.</strong> This route is the live protection surface only — matches your sketch. Library holds history; arm/disarm via menu bar or keyboard (⌘⇧A). No tiles, no recent sets shelf.</div>' +
      "</div></div></div>";

    var previewEl = document.getElementById("menu-preview");
    if (previewEl) {
      previewEl.innerHTML =
        renderMenuBar(stateId) +
        '<div class="dropdown-preview" style="margin-top:8px">' +
        '<div class="dd-zone">' +
        '<div class="dd-title" style="color:' + s.color + '">' + title + "</div>" +
        (since ? '<div class="dd-detail">' + since + "</div>" : "") +
        (showMeter ? '<div class="dd-mini-meter" style="height:6px;margin-top:10px"><div id="dd-meter" style="width:38%;height:100%;background:linear-gradient(90deg,var(--ready),var(--armed));border-radius:3px"></div></div>' : "") +
        '<div class="dd-meta" style="text-align:right;margin-top:8px">Last: 8/28 · 11:42</div></div>' +
        '<div class="dd-divider"></div><div class="dd-row action"><span>Disarm</span><span class="dd-kbd">⌘⇧A</span></div>' +
        '<div class="dd-row action">Open SetCatcher</div></div>';
    }

    var sketchEl = document.getElementById("sketch-ref");
    if (sketchEl) {
      sketchEl.innerHTML = '<figure class="sketch-ref"><img src="sketch-reference.jpg" alt="Your sketch" /><figcaption>Your sketch</figcaption></figure>';
    }

    document.querySelectorAll(".state-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.dataset.state === stateId);
    });
    document.querySelectorAll(".attention-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.dataset.attention === attentionKind);
    });

    startAnimations(primaryState);
    if (showToast && stateId === "setProtected") scheduleToastDismiss();
  }

  function render(layout) {
    if (layout === "live") {
      renderLiveCard(layout);
      return;
    }
    if (layout === "b-compact") {
      renderCompact(layout);
      return;
    }
    var stateId = window.__mockState || "armed";
    var attentionKind = window.__attentionKind || "folderMissing";
    var manualToast = document.getElementById("toggle-toast") && document.getElementById("toggle-toast").checked;
    var showRecovery = document.getElementById("toggle-recovery") && document.getElementById("toggle-recovery").checked;
    var primaryState = displayState(stateId);
    var showToast = showToastForState(stateId, manualToast);

    var cockpit =
      '<div class="cockpit" id="cockpit">' +
      renderPrimary(primaryState, attentionKind) +
      '<div class="cockpit-divider"></div>' +
      (showToast ? toastRow() : "") +
      (stateId !== "noSource" ? secondaryRow(stateId) : "") +
      (showRecovery && stateId === "attentionNeeded" ? recoveryPanel(attentionKind) : "") +
      "</div>";

    var controlsMode = layout === "c" ? "band" : "full";
    var controls = renderControls(stateId, controlsMode);
    var bandLink = layout === "c" && stateId !== "capturing" ? bandOnlyLink() : "";

    var mainContent = cockpit + bandLink;
    if (layout !== "c") {
      mainContent += '<div class="section-gap"></div>' + controls;
    }
    if (layout === "b") {
      mainContent += dashboardBelow(stateId === "attentionNeeded");
    }
    if (layout === "a") {
      mainContent +=
        '<div class="annotation">Layout A: Home is the live operations surface only. No recent sets shelf, tiles, or venues. Capture route removed from sidebar.</div>';
    }

    var appEl = document.getElementById("app-root");
    if (!appEl) return;

    if (layout === "c") {
      appEl.innerHTML =
        '<div class="app-shell split-panes">' +
        '<div class="sidebar">' +
        sidebarHtml(layout, "home") +
        "</div>" +
        '<div class="split-pane"><div class="split-pane-label">Home route</div>' +
        mainContent +
        dashboardBelow(false) +
        "</div>" +
        '<div class="split-pane">' +
        captureRoutePanel(stateId) +
        "</div></div>";
    } else {
      appEl.innerHTML =
        '<div class="app-shell">' +
        '<div class="sidebar">' +
        sidebarHtml(layout, "home") +
        "</div>" +
        '<div class="main-pane"><div class="main-scroll">' +
        mainContent +
        "</div></div></div>";
    }

    var previewEl = document.getElementById("menu-preview");
    if (previewEl) {
      previewEl.innerHTML = renderMenuBar(stateId) + renderDropdown(stateId);
    }

    document.querySelectorAll(".state-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.dataset.state === stateId);
    });
    document.querySelectorAll(".attention-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.dataset.attention === attentionKind);
    });

    var fix = document.getElementById("fix-now");
    if (fix) {
      fix.addEventListener("click", function () {
        var rec = document.getElementById("toggle-recovery");
        if (rec) rec.checked = true;
        render(layout);
      });
    }

    startAnimations(primaryState);
    if (showToast && stateId === "setProtected") scheduleToastDismiss();
  }

  function mountAttentionButtons() {
    var host = document.getElementById("attention-buttons");
    if (!host) return;
    host.innerHTML = Object.keys(ATTENTION).map(function (key) {
      var label = key.replace(/([A-Z])/g, " $1").replace(/^./, function (c) { return c.toUpperCase(); });
      return '<button type="button" class="attention-btn" data-attention="' + key + '">' + label + "</button>";
    }).join("");
  }

  function init(layout) {
    window.__mockLayout = layout;
    window.__mockState = "armed";
    window.__attentionKind = "folderMissing";
    mountAttentionButtons();

    document.querySelectorAll(".state-btn").forEach(function (btn) {
      btn.addEventListener("click", function () {
        window.__mockState = btn.dataset.state;
        render(layout);
      });
    });
    document.querySelectorAll(".attention-btn").forEach(function (btn) {
      btn.addEventListener("click", function () {
        window.__mockState = "attentionNeeded";
        window.__attentionKind = btn.dataset.attention;
        var rec = document.getElementById("toggle-recovery");
        if (rec) rec.checked = true;
        render(layout);
      });
    });

    ["toggle-toast", "toggle-recovery"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.addEventListener("change", function () { render(layout); });
    });

    render(layout);
  }

  window.HomeLayoutMock = { init: init, render: render };
})();
