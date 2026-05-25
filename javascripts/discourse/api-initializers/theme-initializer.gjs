/* ============================================================================
   AI CONVERSATIONS RIGHT SIDEBAR
   ----------------------------------------------------------------------------
   SINGLE RESPONSIBILITY:
     The AI Memories panel (#vc-right-sidebar) — its DOM, the memory CRUD against
     /ai-persistent-memory, the enable/disable toggle, and the ONE right chevron
     (#vc-sidebar-toggle) that opens/closes that panel.

   THIS COMPONENT DOES NOT OWN:
     - The LEFT chevron / Discourse conversations sidebar. That single chevron is
       owned by the "AI Sidebar Search Enhanced" component.
     - The cohesive visual system / page-shell width (Pass 2 styling component).
     - The greeting.

   v1.7.0 (Pass 1 bug-fix) — DEDUPE INITIALIZER + DROP LEFT TOGGLE
     PRIOR STATE:
       This component shipped TWO near-identical initializers — right-sidebar-init.gjs
       (apiInitializer "1.2.0") and theme-initializer.gjs (apiInitializer "1.6.0").
       Both ran on every load and double-injected #vc-right-sidebar (duplicate
       observers / race conditions). The 1.6 initializer ALSO injected a second
       left toggle that collided with the left-sidebar component's own left toggle,
       letting an orphan bleed into the open panel.
     ROOT CAUSE:
       (a) Two initializers in one component — the 1.6 file is a strict superset
           of the 1.2 file, so the 1.2 file was dead weight that still executed.
       (b) Cross-component left-toggle ownership.
     WHAT CHANGED:
       - DELETED right-sidebar-init.gjs (the dead 1.2 duplicate). This file (1.6
         logic) is retained and bumped to 1.7.0.
       - REMOVED this component's left toggle entirely. The left chevron now lives
         solely in the left-sidebar component.
     RESULT:
       One initializer, one right chevron, zero left-toggle entanglement.
   ============================================================================ */

import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

export default apiInitializer("1.7.0", (api) => {

  const RIGHT_SIDEBAR_ID = "vc-right-sidebar";
  const RIGHT_SIDEBAR_TOGGLE_ID = "vc-sidebar-toggle";
  const SIDEBAR_OPEN_CLASS = "vc-right-sidebar-open";
  const MEMORY_ENABLED_KEY = "vc-ai-memories-enabled";

  // Get memory enabled state from localStorage (default: true)
  function isMemoryEnabled() {
    const stored = localStorage.getItem(MEMORY_ENABLED_KEY);
    return stored === null ? true : stored === "true";
  }

  // Set memory enabled state
  function setMemoryEnabled(enabled) {
    localStorage.setItem(MEMORY_ENABLED_KEY, enabled.toString());
  }

  // Check if AI Persistent Memory plugin is available
  async function checkMemoryPluginAvailable() {
    try {
      await ajax("/ai-persistent-memory");
      return true;
    } catch (e) {
      return false;
    }
  }

  // Load memories from the API
  async function loadMemories() {
    try {
      const result = await ajax("/ai-persistent-memory");
      return result.memories || [];
    } catch (e) {
      console.warn("[VC Right Sidebar] Failed to load memories:", e);
      return null;
    }
  }

  // Add a memory
  async function addMemory(key, value) {
    try {
      await ajax("/ai-persistent-memory", {
        type: "POST",
        data: { key, value }
      });
      return true;
    } catch (e) {
      console.error("[VC Right Sidebar] Failed to add memory:", e);
      return false;
    }
  }

  // Delete a memory
  async function deleteMemory(key) {
    try {
      await ajax(`/ai-persistent-memory/${encodeURIComponent(key)}`, {
        type: "DELETE"
      });
      return true;
    } catch (e) {
      console.error("[VC Right Sidebar] Failed to delete memory:", e);
      return false;
    }
  }

  function buildRightSidebar() {
    const enabled = isMemoryEnabled();
    const sidebar = document.createElement("div");
    sidebar.id = RIGHT_SIDEBAR_ID;
    sidebar.innerHTML = `
      <div class="vc-sidebar-header">
        <span class="vc-sidebar-title">🧠 AI Memories</span>
        <div class="vc-header-controls">
          <label class="vc-memory-toggle" title="Enable/Disable AI Memories">
            <input type="checkbox" class="vc-toggle-checkbox" ${enabled ? 'checked' : ''} />
            <span class="vc-toggle-slider"></span>
          </label>
          <button class="vc-sidebar-close" aria-label="Close sidebar">×</button>
        </div>
      </div>
      <div class="vc-sidebar-content ${enabled ? '' : 'vc-memories-disabled'}">
        <div class="vc-memories-container">
          <p class="vc-memories-loading">Loading memories...</p>
        </div>
      </div>
    `;
    return sidebar;
  }

  function buildToggleButton() {
    const btn = document.createElement("button");
    btn.id = RIGHT_SIDEBAR_TOGGLE_ID;
    btn.setAttribute("aria-label", "Toggle AI memories panel");
    btn.setAttribute("title", "Open AI memories");
    btn.innerHTML = `<span class="vc-chevron">›</span>`;
    return btn;
  }

  function renderMemoriesUI(container, memories, refreshCallback, enabled) {
    // If memories disabled, show paused message
    if (!enabled) {
      container.innerHTML = `
        <div class="vc-memories-paused">
          <p class="vc-paused-message">AI Memories are paused</p>
          <p class="vc-paused-hint">Toggle the switch above to enable memory features</p>
        </div>
      `;
      return;
    }

    if (memories === null) {
      // Plugin not available
      container.innerHTML = `
        <p class="vc-memories-unavailable">
          AI Persistent Memory plugin is not installed.
        </p>
      `;
      return;
    }

    let html = "";

    // Add Memory form FIRST (at top)
    html += `
      <div class="vc-add-memory">
        <div class="vc-add-memory-title">+ Add Memory</div>
        <input type="text" class="vc-memory-key-input" placeholder="Key (e.g. favorite_color)" />
        <input type="text" class="vc-memory-value-input" placeholder="Value (e.g. blue)" />
        <button class="vc-memory-save-btn">Save</button>
      </div>
    `;

    // Then memories list (scrollable)
    if (memories.length === 0) {
      html += `<p class="vc-memories-empty">No memories saved yet. The AI will remember things you tell it!</p>`;
    } else {
      html += `<div class="vc-memories-list">`;
      memories.forEach((mem, idx) => {
        html += `
          <div class="vc-memory-card" data-key="${mem.key}">
            <div class="vc-memory-key">${mem.key}</div>
            <div class="vc-memory-value">${mem.value}</div>
            <button class="vc-memory-delete" data-key="${mem.key}" aria-label="Delete memory">×</button>
          </div>
        `;
      });
      html += `</div>`;
    }

    container.innerHTML = html;

    // Attach delete handlers
    container.querySelectorAll(".vc-memory-delete").forEach(btn => {
      btn.addEventListener("click", async (e) => {
        const key = e.target.dataset.key;
        if (await deleteMemory(key)) {
          refreshCallback();
        }
      });
    });

    // Attach add handler
    const saveBtn = container.querySelector(".vc-memory-save-btn");
    const keyInput = container.querySelector(".vc-memory-key-input");
    const valueInput = container.querySelector(".vc-memory-value-input");

    saveBtn.addEventListener("click", async () => {
      const key = keyInput.value.trim();
      const value = valueInput.value.trim();
      if (key && value) {
        if (await addMemory(key, value)) {
          keyInput.value = "";
          valueInput.value = "";
          refreshCallback();
        }
      }
    });

    // Allow Enter key to submit
    valueInput.addEventListener("keypress", async (e) => {
      if (e.key === "Enter") {
        saveBtn.click();
      }
    });
  }

  function isEligiblePage() {
    // Show on the AI conversations LISTING page OR inside any AI bot PM
    // (Discourse adds `has-ai-bot-docked-composer` to body for the chat detail).
    return document.body.classList.contains('ai-bot-conversations-page') ||
           document.body.classList.contains('has-ai-bot-docked-composer');
  }

  function removeAll() {
    [RIGHT_SIDEBAR_TOGGLE_ID, RIGHT_SIDEBAR_ID].forEach(id => {
      const el = document.getElementById(id);
      if (el) el.remove();
    });
  }

  async function initRightSidebar() {
    if (!isEligiblePage()) {
      removeAll();
      return;
    }

    // Don't duplicate
    if (document.getElementById(RIGHT_SIDEBAR_ID)) {
      return;
    }

    // Create sidebar
    const sidebar = buildRightSidebar();
    document.body.appendChild(sidebar);

    // Create RIGHT toggle button (AI Memories)
    const toggleBtn = buildToggleButton();
    document.body.appendChild(toggleBtn);

    // Right toggle functionality (opens AI Memories panel)
    toggleBtn.addEventListener("click", () => {
      document.body.classList.toggle(SIDEBAR_OPEN_CLASS);
      const isOpen = document.body.classList.contains(SIDEBAR_OPEN_CLASS);
      toggleBtn.setAttribute("title", isOpen ? "Close AI memories" : "Open AI memories");
      toggleBtn.setAttribute("aria-expanded", isOpen);
    });

    // Close button inside sidebar
    const closeBtn = sidebar.querySelector(".vc-sidebar-close");
    if (closeBtn) {
      closeBtn.addEventListener("click", () => {
        document.body.classList.remove(SIDEBAR_OPEN_CLASS);
        toggleBtn.setAttribute("title", "Open AI memories");
        toggleBtn.setAttribute("aria-expanded", "false");
      });
    }

    // Memory toggle handler
    const memoryToggle = sidebar.querySelector(".vc-toggle-checkbox");
    const contentArea = sidebar.querySelector(".vc-sidebar-content");
    const container = sidebar.querySelector(".vc-memories-container");

    async function refreshMemories() {
      const enabled = isMemoryEnabled();
      contentArea.classList.toggle("vc-memories-disabled", !enabled);
      
      if (enabled) {
        container.innerHTML = `<p class="vc-memories-loading">Loading...</p>`;
        const memories = await loadMemories();
        renderMemoriesUI(container, memories, refreshMemories, enabled);
      } else {
        renderMemoriesUI(container, null, refreshMemories, false);
      }
    }

    memoryToggle.addEventListener("change", (e) => {
      const enabled = e.target.checked;
      setMemoryEnabled(enabled);
      refreshMemories();
    });

    // Initial load
    refreshMemories();

    console.log('[VC Right Sidebar] Initialized v1.7.0 (memories only; left chevron owned by sidebar-search component)');
  }

  // Initial execution with slight delay for DOM readiness
  function tryInit() {
    if (isEligiblePage()) {
      initRightSidebar();
    } else {
      removeAll();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", tryInit);
  } else {
    // Small delay to ensure page class is applied
    setTimeout(tryInit, 50);
  }

  // SPA navigation - with delay for DOM to update
  api.onPageChange(() => {
    setTimeout(tryInit, 150);
  });

  // Fallback: watch for page class to appear/disappear
  const bodyObserver = new MutationObserver(() => {
    if (isEligiblePage() && !document.getElementById(RIGHT_SIDEBAR_ID)) {
      console.log('[VC Right Sidebar] Page class detected, initializing...');
      initRightSidebar();
    } else if (!isEligiblePage() && document.getElementById(RIGHT_SIDEBAR_ID)) {
      removeAll();
    }
  });

  bodyObserver.observe(document.body, {
    attributes: true,
    attributeFilter: ['class']
  });

});
