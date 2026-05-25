/* ============================================================================
   AI CONVERSATIONS RIGHT SIDEBAR — api-initializer
   ----------------------------------------------------------------------------
   SINGLE RESPONSIBILITY:
     The AI Memories panel (#vc-right-sidebar) — its DOM, the memory CRUD against
     /ai-persistent-memory, the enable/disable toggle, and the ONE right chevron
     (#vc-sidebar-toggle) that opens/closes that panel via body.vc-right-sidebar-open.

   THIS COMPONENT DOES NOT OWN (the boundary):
     - The LEFT chevron / Discourse conversations sidebar — owned by the
       left-sidebar component. This component injects NO left toggle.
     - The greeting / title.
     - The cohesive visual system, page-shell width, composer framing, or
       chat-detail polish — all owned by the styling component (built last).
       This file ships only the behavior + a low-specificity baseline.

   v2.0.0 (clean rebuild) — PRIOR STATE: the component shipped two initializers
     that double-injected the panel, and a second left toggle that collided with
     the left-sidebar component's chevron. The previous Pass-1 fix (v1.7) deduped
     to one initializer and dropped the left toggle. ROOT CAUSE of the remaining
     gaps: no settings/i18n/changelog (house standards), and memory key/value
     were interpolated raw into innerHTML (stored-XSS surface, since memories are
     user-authored). WHAT CHANGED: rebuilt as a single standalone component with
     namespaced i18n, a master-enable + default-open setting, and DOM-safe memory
     rendering (textContent, not innerHTML interpolation). RESULT: one
     initializer, one right chevron, zero left-toggle entanglement, no injection
     surface, fully translatable.
   ============================================================================ */

import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default apiInitializer("2.0.1", (api) => {
  const RIGHT_SIDEBAR_ID = "vc-right-sidebar";
  const RIGHT_SIDEBAR_TOGGLE_ID = "vc-sidebar-toggle";
  const SIDEBAR_OPEN_CLASS = "vc-right-sidebar-open";
  const MEMORY_ENABLED_KEY = "vc-ai-memories-enabled";
  const PANEL_OPEN_KEY = "vc-ai-panel-open";

  // themePrefix is auto-injected in theme-component .gjs files; it rewrites a
  // bare key into this component's theme_translations.{theme_id}.<key> namespace.
  // Do NOT import it (that throws "already declared") and do NOT hardcode "js."
  // (that resolves against core's table, where these strings do not exist).
  const t = (key, opts) => i18n(themePrefix(`ai_conv_right_sidebar.${key}`), opts);

  // Master switch (site-wide). When off, inject nothing.
  function componentEnabled() {
    return settings.ai_conv_right_sidebar_enabled !== false;
  }

  // --- Per-user state (localStorage) ---------------------------------------

  function isMemoryEnabled() {
    const stored = localStorage.getItem(MEMORY_ENABLED_KEY);
    return stored === null ? true : stored === "true";
  }
  function setMemoryEnabled(enabled) {
    localStorage.setItem(MEMORY_ENABLED_KEY, enabled.toString());
  }

  // Default-open setting applies only until the user has expressed a preference.
  function shouldStartOpen() {
    const stored = localStorage.getItem(PANEL_OPEN_KEY);
    if (stored !== null) {
      return stored === "true";
    }
    return settings.ai_conv_memory_panel_default_open === true;
  }
  function setPanelOpen(open) {
    localStorage.setItem(PANEL_OPEN_KEY, open.toString());
  }

  // --- API ------------------------------------------------------------------

  async function loadMemories() {
    try {
      const result = await ajax("/ai-persistent-memory");
      return result.memories || [];
    } catch (e) {
      // null is the "plugin unavailable" sentinel the UI renders distinctly.
      console.warn("[VC Right Sidebar] Failed to load memories:", e);
      return null;
    }
  }
  async function addMemory(key, value) {
    try {
      await ajax("/ai-persistent-memory", { type: "POST", data: { key, value } });
      return true;
    } catch (e) {
      console.error("[VC Right Sidebar] Failed to add memory:", e);
      return false;
    }
  }
  async function deleteMemory(key) {
    try {
      await ajax(`/ai-persistent-memory/${encodeURIComponent(key)}`, { type: "DELETE" });
      return true;
    } catch (e) {
      console.error("[VC Right Sidebar] Failed to delete memory:", e);
      return false;
    }
  }

  // --- DOM construction -----------------------------------------------------

  function buildRightSidebar() {
    const enabled = isMemoryEnabled();
    const sidebar = document.createElement("div");
    sidebar.id = RIGHT_SIDEBAR_ID;

    const header = document.createElement("div");
    header.className = "vc-sidebar-header";

    const title = document.createElement("span");
    title.className = "vc-sidebar-title";
    title.textContent = t("title");

    const controls = document.createElement("div");
    controls.className = "vc-header-controls";

    const toggleLabel = document.createElement("label");
    toggleLabel.className = "vc-memory-toggle";
    toggleLabel.title = t("toggle_memory_label");
    const toggleInput = document.createElement("input");
    toggleInput.type = "checkbox";
    toggleInput.className = "vc-toggle-checkbox";
    toggleInput.checked = enabled;
    const toggleSlider = document.createElement("span");
    toggleSlider.className = "vc-toggle-slider";
    toggleLabel.append(toggleInput, toggleSlider);

    const closeBtn = document.createElement("button");
    closeBtn.className = "vc-sidebar-close";
    closeBtn.setAttribute("aria-label", t("close_label"));
    closeBtn.textContent = "×";

    controls.append(toggleLabel, closeBtn);
    header.append(title, controls);

    const content = document.createElement("div");
    content.className = "vc-sidebar-content" + (enabled ? "" : " vc-memories-disabled");
    const container = document.createElement("div");
    container.className = "vc-memories-container";
    const loading = document.createElement("p");
    loading.className = "vc-memories-loading";
    loading.textContent = t("loading");
    container.appendChild(loading);
    content.appendChild(container);

    sidebar.append(header, content);
    return sidebar;
  }

  function buildToggleButton() {
    const btn = document.createElement("button");
    btn.id = RIGHT_SIDEBAR_TOGGLE_ID;
    btn.setAttribute("aria-label", t("toggle_panel_label"));
    btn.setAttribute("title", t("open_panel"));
    const chevron = document.createElement("span");
    chevron.className = "vc-chevron";
    chevron.textContent = "›";
    btn.appendChild(chevron);
    return btn;
  }

  // Render the memory list. All user-authored strings go through textContent —
  // never innerHTML — so a memory value can't inject markup.
  function renderMemoriesUI(container, memories, refreshCallback, enabled) {
    container.textContent = "";

    if (!enabled) {
      const paused = document.createElement("div");
      paused.className = "vc-memories-paused";
      const msg = document.createElement("p");
      msg.className = "vc-paused-message";
      msg.textContent = t("paused_message");
      const hint = document.createElement("p");
      hint.className = "vc-paused-hint";
      hint.textContent = t("paused_hint");
      paused.append(msg, hint);
      container.appendChild(paused);
      return;
    }

    if (memories === null) {
      const unavailable = document.createElement("p");
      unavailable.className = "vc-memories-unavailable";
      unavailable.textContent = t("unavailable");
      container.appendChild(unavailable);
      return;
    }

    // Add-memory form (at top)
    const addWrap = document.createElement("div");
    addWrap.className = "vc-add-memory";
    const addTitle = document.createElement("div");
    addTitle.className = "vc-add-memory-title";
    addTitle.textContent = t("add_title");
    const keyInput = document.createElement("input");
    keyInput.type = "text";
    keyInput.className = "vc-memory-key-input";
    keyInput.placeholder = t("add_key_placeholder");
    const valueInput = document.createElement("input");
    valueInput.type = "text";
    valueInput.className = "vc-memory-value-input";
    valueInput.placeholder = t("add_value_placeholder");
    const saveBtn = document.createElement("button");
    saveBtn.className = "vc-memory-save-btn";
    saveBtn.textContent = t("add_save");
    addWrap.append(addTitle, keyInput, valueInput, saveBtn);
    container.appendChild(addWrap);

    // List or empty state
    if (memories.length === 0) {
      const empty = document.createElement("p");
      empty.className = "vc-memories-empty";
      empty.textContent = t("empty");
      container.appendChild(empty);
    } else {
      const list = document.createElement("div");
      list.className = "vc-memories-list";
      memories.forEach((mem) => {
        const card = document.createElement("div");
        card.className = "vc-memory-card";
        card.dataset.key = mem.key;
        const k = document.createElement("div");
        k.className = "vc-memory-key";
        k.textContent = mem.key;
        const v = document.createElement("div");
        v.className = "vc-memory-value";
        v.textContent = mem.value;
        const del = document.createElement("button");
        del.className = "vc-memory-delete";
        del.dataset.key = mem.key;
        del.setAttribute("aria-label", t("delete_label"));
        del.textContent = "×";
        del.addEventListener("click", async () => {
          if (await deleteMemory(mem.key)) {
            refreshCallback();
          }
        });
        card.append(k, v, del);
        list.appendChild(card);
      });
      container.appendChild(list);
    }

    // Add handler
    const submit = async () => {
      const key = keyInput.value.trim();
      const value = valueInput.value.trim();
      if (key && value && (await addMemory(key, value))) {
        keyInput.value = "";
        valueInput.value = "";
        refreshCallback();
      }
    };
    saveBtn.addEventListener("click", submit);
    valueInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        submit();
      }
    });
  }

  // --- Lifecycle ------------------------------------------------------------

  function isEligiblePage() {
    return (
      document.body.classList.contains("ai-bot-conversations-page") ||
      document.body.classList.contains("has-ai-bot-docked-composer")
    );
  }

  function removeAll() {
    [RIGHT_SIDEBAR_TOGGLE_ID, RIGHT_SIDEBAR_ID].forEach((id) => {
      const el = document.getElementById(id);
      if (el) {
        el.remove();
      }
    });
  }

  function initRightSidebar() {
    if (!componentEnabled() || !isEligiblePage()) {
      removeAll();
      return;
    }
    if (document.getElementById(RIGHT_SIDEBAR_ID)) {
      return; // already present
    }

    const sidebar = buildRightSidebar();
    document.body.appendChild(sidebar);

    const toggleBtn = buildToggleButton();
    document.body.appendChild(toggleBtn);

    const setOpen = (open) => {
      document.body.classList.toggle(SIDEBAR_OPEN_CLASS, open);
      toggleBtn.setAttribute("title", open ? t("close_panel") : t("open_panel"));
      toggleBtn.setAttribute("aria-expanded", open ? "true" : "false");
      setPanelOpen(open);
    };

    toggleBtn.addEventListener("click", () =>
      setOpen(!document.body.classList.contains(SIDEBAR_OPEN_CLASS))
    );

    const closeBtn = sidebar.querySelector(".vc-sidebar-close");
    closeBtn?.addEventListener("click", () => setOpen(false));

    const memoryToggle = sidebar.querySelector(".vc-toggle-checkbox");
    const contentArea = sidebar.querySelector(".vc-sidebar-content");
    const container = sidebar.querySelector(".vc-memories-container");

    async function refreshMemories() {
      const enabled = isMemoryEnabled();
      contentArea.classList.toggle("vc-memories-disabled", !enabled);
      if (enabled) {
        container.textContent = "";
        const loading = document.createElement("p");
        loading.className = "vc-memories-loading";
        loading.textContent = t("loading");
        container.appendChild(loading);
        const memories = await loadMemories();
        renderMemoriesUI(container, memories, refreshMemories, true);
      } else {
        renderMemoriesUI(container, null, refreshMemories, false);
      }
    }

    memoryToggle.addEventListener("change", (e) => {
      setMemoryEnabled(e.target.checked);
      refreshMemories();
    });

    // Honor default-open / remembered open state (without thrashing the title).
    if (shouldStartOpen()) {
      document.body.classList.add(SIDEBAR_OPEN_CLASS);
      toggleBtn.setAttribute("title", t("close_panel"));
      toggleBtn.setAttribute("aria-expanded", "true");
    }

    refreshMemories();
    console.info("[VC Right Sidebar] Initialized v2.0.0");
  }

  function tryInit() {
    if (componentEnabled() && isEligiblePage()) {
      initRightSidebar();
    } else {
      removeAll();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", tryInit);
  } else {
    setTimeout(tryInit, 50);
  }

  api.onPageChange(() => setTimeout(tryInit, 150));

  // Watch only body class flips (page scope changes), not the whole subtree.
  const bodyObserver = new MutationObserver(() => {
    if (componentEnabled() && isEligiblePage() && !document.getElementById(RIGHT_SIDEBAR_ID)) {
      initRightSidebar();
    } else if ((!componentEnabled() || !isEligiblePage()) && document.getElementById(RIGHT_SIDEBAR_ID)) {
      removeAll();
    }
  });
  bodyObserver.observe(document.body, { attributes: true, attributeFilter: ["class"] });
});
