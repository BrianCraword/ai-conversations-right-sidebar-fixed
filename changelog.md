# Changelog — AI Conversations Right Sidebar

All notable changes to this component are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/). The version here stays in sync with `about.json`
and the `apiInitializer("x.x.x")` call.

---

## [2.0.0] — 2026-05-25

Clean standalone rebuild of the AI Memories right sidebar.

### Prior state
The right-sidebar concern shipped as a patched component that had accumulated
two near-identical initializers (double-injecting `#vc-right-sidebar` and racing
their observers) and a second left toggle (`#vc-sidebar-toggle-left`) that
collided with the left-sidebar component's own chevron, occasionally bleeding an
orphan toggle into the open panel on mobile. A Pass-1 fix (v1.7/v1.8) deduped to
one initializer and dropped the left toggle, but the component still lacked house
standards (no settings, no i18n, no changelog), rendered user-authored memory
key/value via raw `innerHTML` interpolation, and carried a large amount of
styling that belongs to other concerns (title gradient, composer/input framing,
the entire chat-detail polish block, sidebar widening).

### Root cause
The component had grown to own more than its single responsibility, and its
baseline CSS leaned on `!important` and high-reach selectors that would fight the
forthcoming styling layer.

### What changed
- **Rebuilt as a single standalone component** with one initializer
  (`right-sidebar.gjs`), one panel (`#vc-right-sidebar`), and one right chevron
  (`#vc-sidebar-toggle`). No left toggle is injected — the single left chevron is
  owned solely by the left-sidebar component.
- **House standards added:** `settings.yml` (master enable + default-open),
  namespaced `locales/en.yml`, this changelog, and a single responsibility +
  boundary header in every file. Version synced across `about.json`, changelog,
  and `apiInitializer`.
- **DOM-safe memory rendering.** Memory key/value are now written with
  `textContent` instead of being interpolated into an HTML string, removing a
  stored-XSS surface (memories are user-authored).
- **Scope tightened to baseline only.** Removed the title gradient,
  input-wrapper/composer button framing, content-wrapper transform, the entire
  `has-ai-bot-docked-composer` chat-detail polish, sidebar widening, and
  message-card styling. Those migrate to the styling component (built last).
- **Baseline de-escalated.** All `!important` removed from this component's CSS;
  selectors reduced to single-id / single-class so the styling layer can cleanly
  override. The `--vc-*` tokens that remain are minimal, documented fallback
  copies; the authoritative `:root` token block lives in the styling component.
- **Retained verbatim in behavior:** memory enable/disable via localStorage,
  plugin-availability handling, load/add/delete, the paused/empty/unavailable
  states, and the verified persona-dropdown stacking repair
  (`.agent-llm-selector__selection-wrapper { position: relative; z-index: 1 }`).

### Result
One initializer, one right chevron, zero left-toggle entanglement, no injection
surface, fully translatable, and a baseline that the styling component can paint
over without conflict.
