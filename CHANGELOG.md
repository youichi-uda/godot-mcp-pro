# Changelog

All notable changes to Godot MCP Pro will be documented in this file.

---

## Unreleased

### Fixed — High
- **Every runtime command timed out for projects whose name contains a period** (issue #39, reported by mpergami). `get_game_user_dir()` rebuilt the running game's `user://` directory from `application/config/name` with `validate_filename().replace(".", "_")`, which is not how Godot derives it: "MyGame_V0.04" really lives under `app_userdata/MyGame_V0.04`, but request files were written to `MyGame_V0_04`, so the game never saw them. The sanitisation is now a port of Godot's own `OS::get_safe_dir_name` (replace `: * ? " < > | / \` with `-`, trim whitespace, keep everything else), which also fixes names containing `%` or the other characters `validate_filename` handled differently.
- **`get_editor_errors` reported compile errors that did not exist** (issue #40, reported by nidarian). The scan paired the focused tab's path with the line numbers and text of whichever `CodeEdit` came first in the tree, and treated any red-ish line background as an error, so a warning in one tab surfaced as `COMPILE ERROR` in another, sometimes on a blank line. That scan is gone; errors and warnings now come only from each open editor's analyzer panels, which already attribute them to the right file.
- **`edit_script` could report success for an edit that never persisted** (PR #42, aallnneess). The write path called `store_string()`, counted the replacements and validated the new text — but nothing ever looked at the file again, so a second writer that overwrote the file right after the write (a parallel MCP session riding the same editor through another server port, a stale duplicate tool call, an editor buffer save) silently reverted the edit while the caller had been told it landed. Reported against a live setup with four MCP server processes attached to one editor, where edits vanished intermittently with the file's mtime advancing but its md5 staying identical to the pre-edit content. `edit_script` / `create_script` / `edit_shader` / `create_shader` now read the file back after writing and return a `-32003` error carrying `md5_expected` / `md5_on_disk` when the bytes on disk do not match what was just written; a fire-and-forget re-check ~5s later logs a diagnosis to the editor Output when a late overwrite still happens; and `edit_script` answers include `disk_verified: true` to say the result was proven, not assumed.
- **Concurrent text-file edits could interleave into a lost update** (PR #42, aallnneess). Several MCP sessions can be attached to one editor at once (each through its own server port), and command handlers run as overlapping coroutines — two read-modify-write cycles on the same file could race. `edit_script` and `edit_shader` now run their read-to-write section exclusively per file path (`run_path_serialized`), so one session's edit completes before the next one reads the file.
- **The delayed persistence re-check no longer reports the addon's own follow-up writes.** A `create_script` followed within 5s by an `edit_script` of the same file is the normal workflow, not a lost edit; the check is skipped when a later MCP write has superseded it, and a genuine late overwrite is reported as a warning (not an error) carrying both md5s.

### Added
- **Bottom-panel tab icon** (issue #38, requested by gikari). On Godot 4.6+ the icon is set through the `EditorDock` wrapper and shows when *Editor Settings > Interface > Editor > Bottom Dock Tab Style* includes icons; older versions get it on the tab button. The SVG is rasterised at the editor scale, so it also works on the very first enable before the import pipeline has seen the file.

### Changed
- **`execute_game_script` wrapper no longer declares an unused `_mcp_error`** (PR #41, oxeron; issue #43, emirhanaydin), which raised `UNUSED_PRIVATE_CLASS_VARIABLE` in the debugger on every call.
- **`edit_script` internals:** the read-modify-write helper returns the same `success()` / error shape as every other handler.


---

## v1.16.0 — 2026-08-01

**Minor** — a follow-up audit from the same reporter as v1.15.1, then a sweep of every file the audit touched and several it did not. 44 commits. Adds a headless execution path, an optional connection token, and a `SECURITY.md`.

Thanks again to the reporter of the external audit, and to @Hkattelu for issue #37.

### Added
- **`run_headless_scene` / `run_headless_script` / `get_godot_executable`** — run a scene or an `extends SceneTree` script in a separate headless Godot process and get back stdout/stderr, the exit code and the duration. This is how to run a project's own CLI test suite, which the editor-driven tools could never see. Output goes through a generated runner script (a pipe deadlocks a verbose child), the deadline is measured against the clock, and a timeout kills the whole process tree and reports whether the kill was confirmed.
- **Optional connection token**, default off. Enable via the new `godot_mcp_pro/require_connection_token` project setting or `GODOT_MCP_REQUIRE_TOKEN=1`; servers present it via `GODOT_MCP_TOKEN` or `GODOT_MCP_TOKEN_FILE`. Inert unless enabled — existing client configurations are unaffected.
- **`SECURITY.md`** — states the trust model plainly, including the dial-out topology users cannot reasonably infer, and the limits of the `execute_editor_script` guard.
- `search_in_files` gained `include_addons`, matching its four sibling analysis tools.
- `edit_script` now reports `valid_after_edit`, `parse_errors` and `indentation_warning`.

### Fixed — Critical
- **`set_project_setting` silently changed value types.** Any numeric-looking string became an int or float with no way to force a String, and container types could not be written at all — an array smuggled through as a string was stored as a quoted String while the tool reported success. This corrupted `editor_plugins/enabled` on a user's project, which would have disabled every plugin including this one. Existing keys now keep their declared type, a `type` parameter covers new keys, arrays build container types, and anything that cannot be represented is rejected instead of degraded. `editor_plugins/enabled` is refused outright.
- **A malformed request hung the caller instead of erroring.** GDScript raises on `42 == "ping"` rather than returning false, and the method was compared before its type was checked — so a request with a numeric method aborted dispatch with no response at all. Non-object `params`, a handler returning a non-Dictionary, and roughly 160 unchecked `int()`/`float()`/`bool()` conversions across all 27 command files had the same effect. All now answer with a specific error.
- **`delete_scene` deleted any file.** It checked only that the path existed, so a mistyped path permanently removed a script, an image or `project.godot`. It now requires `.tscn`/`.scn` and refuses a scene open in the editor. `create_shader`, `create_theme` and `create_resource` had the same hole and now refuse a destination whose extension does not match.
- **The POSIX process-tree kill never worked**, and reported success while doing nothing. `OS.execute` destroys `$1`, `$c` and `$#` in a script passed inline, so `pgrep -P ""` killed nothing. Verified fixed on Linux.

### Fixed — High
- **`validate_script` failed on every `class_name` script**, and then, after the first fix, on every script with live instances (`@tool`, autoloads, plugin code). It uses `CACHE_MODE_IGNORE` + `reload(keep_state=true)`, returns the real parser message, and reports `valid: null` with `indeterminate: true` when Godot skips the compile rather than guessing.
- **Port exhaustion killed the whole session.** `connect()` ran once at startup; if 6505–6509 were all held, every later call reported that the editor was not connected. `sendCommand` re-binds lazily and the error now distinguishes "could not bind a port" from "no editor attached". `disconnect()` is also final — a bind still in flight can no longer resurrect the server.
- **The injected autoloads ran in exported games**, stat'ing `user://` every frame. They guard on `OS.has_feature("editor")` now, and stand down inside a headless child so they cannot race the editor's own session.
- **Stale autoloads were never reclaimed.** A crashed editor left its three entries in `project.godot` forever, producing the "Can't autoload" spam reported in v1.15.1. They are reclaimed and cleaned up, while an autoload pointing at someone else's script is left alone with a warning.
- **`godot-cli project set-setting` had never worked** — it sent `setting` where the addon reads `key` — and its `autoType()` reintroduced the v1.15.1 type-punning through a second door. Six more CLI commands sent parameter names the addon does not read, including `input key`, which could never have worked.

### Fixed — Medium
- `execute_editor_script` returned its output twice; the sentinel is now an object identity that no caller value can collide with, and an explicit `return null` stays distinguishable from no return.
- `get_performance_monitors` reported throttled FPS without saying so. It reports `fps_throttled` explicitly — `false` in a separate window, focus-derived when embedded, and `null` in a floating Game workspace whose focus cannot be read.
- Colors did not round-trip: reading one and writing it straight back set the property to white. All five structured types round-trip now, and JSON text is accepted for clients that stringify structured arguments.
- `duplicate_node` on the scene root produced a node attached outside the scene and lost on save.
- The game IPC channel had no correlation or mutual exclusion; two runtime commands at once could consume each other's replies.
- Open-resource guards compared paths case-sensitively, so on Windows and macOS a differently cased path slipped past them.
- The status panel stacked duplicate signal connections on every reload.
- Windows runner quoting: an argument ending in a backslash swallowed its closing quote and merged with the next; delayed expansion was not disabled.

### Notes
- Tool count is now **178** (Full mode). Minimal, Lite and 3D modes are unchanged.
- POSIX behaviour was verified on Linux (WSL Ubuntu, Godot 4.6.2) this cycle. macOS remains untested; the code paths are shared with Linux.
- Known limitation: a grandchild whose own parent has already exited is reparented to init before a timeout kill runs, so no parent-walking approach can reach it.

---

## v1.15.1 — 2026-07-19

**Patch** — 15 fixes from an external user's full-toolset audit (all 174 tools tested against a live editor). Huge thanks to the reporter.

### Fixed — Critical
- **`set_particle_color_gradient` infinite loop / editor hang**: clearing a fresh `Gradient` point-by-point never terminates because `Gradient.remove_point` refuses to drop below 2 points. Gradients are now built by assigning `offsets` / `colors` wholesale. The same root cause also produced a spurious opaque-black stop at offset 0 in every `apply_particle_preset` color ramp — both fixed via the same change.
- **`connect_signal` connections were never saved to the `.tscn`**: `Object.connect()` was called without `CONNECT_PERSIST`, so `PackedScene.pack()` dropped the connection on save. Connections are now persistent; new optional `deferred` / `one_shot` parameters, and the response echoes `flags` / `persistent`.
- **`update_property` destroyed Resource-typed properties**: assigning e.g. `texture` by `"res://..."` path passed the raw String through, which the engine coerced to `null` — silently wiping the existing value. `PropertyParser` now loads `res://` / `uid://` paths into Resources (also fixes `batch_add_nodes` properties), and `update_property` fails loudly when a string cannot be resolved instead of committing a `null`.

### Fixed — High
- **`create_theme` returned `{}` and never wrote the file**: a `!= null` check on a `Dictionary` guard made the guard branch unconditional. Now uses `is_empty()` like every other call site. Also creates parent directories.
- **`get_performance_monitors` reported the editor process's metrics as the game's**: `Performance` is per-process. The tool now routes through the game IPC channel (requires a playing scene) and returns `"process": "game"`; use `get_editor_performance` for editor metrics.
- **`get_test_report` counted passing assertions as failures**: non-assertion steps (input/wait/screenshot) were scored as failed, and game replies were stored still double-wrapped so their `passed` key was never found. Only assertion results are stored now, and the envelope is unwrapped defensively. Empty reports return `no_results: true` instead of a misleading `all_passed: false`.
- **`run_test_scenario` reported `all_passed: false` on green runs**: same double-wrapped envelope, unwrapped one level too few in `_execute_assert_step`. Assertion results now surface `passed` at the top level with a consistent shape.

### Fixed — Medium
- **`get_scene_tree` returned editor-internal absolute paths** (`/root/@EditorNode@.../...`): paths are now scene-relative (root = `"."`), directly usable as `node_path` input for other tools, and ~10× smaller.
- **`analyze_signal_flow` dumped editor-internal connections** (~8k tokens of dock bookkeeping): now filters to persistent connections targeting nodes inside the edited scene.
- **`find_unused_resources` ignored `uid://` references**: `preload("uid://…")` and `uid=` references are now resolved back to their `res://` paths (self-referencing file-header uids excluded). References held via `ProjectSettings` defaults (main scene, audio bus layout, icon, autoloads) are also seeded, so `default_bus_layout.tres` and friends are no longer reported deletable.
- **`get_input_actions(include_builtin: false)` leaked 16 editor actions** (`spatial_editor/*`): actions not declared in the project's `ProjectSettings` are now excluded.
- **`create_resource` failed on missing parent directories**: directories are created recursively; the error message now includes the path.
- **`run_test_scenario` `keycode` input steps never released the key**, corrupting later assertions: keycode steps now auto-release like `action` steps (disable with `auto_release: false`).

### Fixed — Minor
- **`set_particle_material`**: emission sub-parameters (`emission_sphere_radius`, box extents, ring radii/height) are now listed in `changes[]`.
- `run_test_scenario` screen-text assertions no longer lose their result type to a key collision (`assert_type` field).

---

## v1.14.1 — 2026-05-24

**Patch** — `assert_node_state` regression fix

### Fixed
- **`assert_node_state` "Unknown command" regression**: The game-side handler in `mcp_game_inspector_service.gd` had been removed during the v1.7.0 refactor (`4ea3989`, 2026-03-29) that introduced `batch_add_nodes` / `watch_signals` / `setup_control`. The TypeScript server and editor-side GDScript still routed the call, but the runtime match statement no longer recognized it — so `assert_node_state` (and any `type:"assert"` step inside `run_test_scenario`) returned `Unknown command: assert_node_state` on every call from v1.7.0 through v1.14.0. Restored the handler with all 8 operators (`eq`, `neq`, `gt`, `lt`, `gte`, `lte`, `contains`, `type_is`) and sub-property access via `get_indexed()` (e.g. `position:y`). Reported by **Z_runner [CRWN]** on Discord.

---

## v1.14.0 — 2026-05-18

**Feature / Safety** — File-conflict safety overhaul (community contribution)

This release is a coordinated overhaul of how the addon interacts with editor-owned resources. It prevents the "external change" dialog and silent in-memory/disk divergence that could occur when MCP commands wrote scenes, scripts, shaders, or resources while Godot still had them open. Contributed by **[@aallnneess](https://github.com/aallnneess)** (PR #31), with the design and patch reviewed and tested locally with GitHub Copilot using GPT-5.5 xhigh. Reported and validated against the previous v1.13.x behavior.

### Added — safety primitives in `base_command.gd`
- `guard_offline_scene_save(path)`: blocks `ResourceSaver.save(...)` to a `.tscn`/`.scn` path when that scene is currently open in the editor. Returns a structured conflict error (JSON-RPC code `-32009`) including the path, open-scenes list, and a recovery suggestion.
- `guard_text_resource_write(path, force)`: blocks writes to a script/shader file that is currently open in Godot's script editor (or, for shaders, currently loaded/cached in `ResourceLoader`). Override with `force=true`.
- `add_child_with_undo(...)` / `set_property_with_undo(...)`: register live scene mutations through `EditorUndoRedoManager` with correct `add_do_reference` / `add_undo_reference` retention for `Resource` values so they survive GC across the undo history.
- `get_open_scene_paths()` / `is_scene_path_open()` / `is_active_scene_path()` / `is_text_resource_open_in_script_editor()`: shared checks so per-command code never re-implements the same logic.
- `normalize_project_path()`: consistent comparison key for `res://`, project-relative, and absolute paths.

### Changed — scene saves go through `EditorInterface`
- `save_scene`: when the target path matches the active edited scene, calls `EditorInterface.save_scene()`; when the target differs or the active scene has no path yet, calls `EditorInterface.save_scene_as(path)`. Refuses to save an inactive open scene tab. No more silent `ResourceSaver.save` to an open path.
- `create_scene` / `create_theme` / `edit_resource`: all guarded against accidentally targeting an open scene path.

### Changed — broad cross-scene edits are opt-in
- **`cross_scene_set_property` defaults to `dry_run=true`** (breaking change). Real writes now require `dry_run=false` **and** `force=true`. The response includes a per-scene `mode` field (`dry_run` / `offline_saved` / `live_open_scene`) and a `skipped_open_scenes` list so callers can see exactly what happened.
- The active open scene is live-edited via `EditorUndoRedoManager` instead of being offline-overwritten, so changes are visible in the editor and undoable.
- Inactive open scenes are skipped and reported rather than silently overwritten.

### Changed — live scene mutations participate in UndoRedo
- `batch_add_nodes`, `batch_set_property`: routed through the shared UndoRedo helpers.
- `node_commands`: node creation, `set_anchor_preset` (computed on a duplicate Control before applying), signal connect/disconnect, group add/remove — all undoable.
- `animation_commands`: animation create/remove, track add, and keyframe edits. `_upsert_animation_key` / `_restore_animation_key` give round-trip undo for keyframe edits (including the previously-present-key replacement case) using `is_equal_approx` time matching.
- `animation_tree_commands`: AnimationTree create, state machine state/transition edits, blend tree node changes, tree parameter edits.
- `tilemap_commands`: single-cell set, rect fill, and clear capture the affected cells' old state and apply via UndoRedo. Round-trip undoable.
- `theme_commands`: color, constant, font-size, and stylebox theme overrides; `setup_control` computes target state on a duplicate Control before applying.
- `audio_commands`, `navigation_commands`, `particle_commands`: node creation and resource assignment go through UndoRedo. Navigation bake also marks the active scene unsaved.
- `shader_commands`: shader material assignment via `set_property_with_undo`.

### Fixed — open script/shader writes
- `create_script` / `edit_script`: refuse to write when the target is open in the script editor, unless `force=true` is explicitly passed. Also restricted to `.gd` / `.cs` extensions — scene and shader paths are rejected with a clear suggestion (added in `6d8d650`).
- `edit_script` now actually implements the 1-based inclusive `start_line` / `end_line` range replacement that the CLI had been advertising. The TypeScript `edit_script` schema and CLI `script edit` both expose the new parameters.
- `create_shader` / `edit_shader`: same open-file guard, with `force=true` to override.
- Shader cache refresh fixed: `_refresh_loaded_shader` uses `take_over_path()` + `emit_changed()` to update any cached/live `Shader` resource, replacing the unreliable `Shader.reload_from_file()` call. Live materials referencing the shader now pick up edits immediately.

### Fixed — `execute_editor_script` escape hatch
- Submitted code is scanned for direct file/resource write APIs (`ResourceSaver.save`, `FileAccess WRITE`, `ProjectSettings.save`, `ConfigFile.save`, `DirAccess` filesystem mutations). If present, the call is refused with a structured conflict error unless `allow_unsafe_editor_io=true` is explicitly passed. Closes the obvious workaround where an AI client could route around the per-command guards by submitting raw script.

### Changed — server schemas
- `create_script` / `edit_script` / `create_shader` / `edit_shader`: added optional `force` parameter and updated tool descriptions.
- `cross_scene_set_property`: added optional `dry_run` / `force` parameters and a description that reflects the new dry-run-by-default semantics.
- `execute_editor_script`: added optional `allow_unsafe_editor_io` parameter.
- `cli.ts`: `script create` and `script edit` accept `--force` flag.

### Migration notes
- **Breaking**: scripts/agents that previously relied on `cross_scene_set_property` writing on first call now need to add `dry_run=false force=true` to perform writes. Without those, the call returns a dry-run preview. This is intentional — silent project-wide writes were a footgun.
- **Soft-breaking**: scripts/agents that previously overwrote open files (scenes, scripts, shaders) without checking now hit a `-32009` conflict error. The fix is to either close the file in the editor first, save through the editor (for scenes), or pass `force=true` (for scripts/shaders, when you've verified no buffer holds unsaved changes).
- Existing wire-compatible calls that did *not* target open resources continue to work unchanged.

---

## v1.13.2 — 2026-05-13

**Bug Fix** — Port allocation race when multiple Claude Code sessions start at the same time

### Fixed
- **Parallel-session port collision** (Discord report by CrusherEAGLE): Two Claude Code sessions starting nearly simultaneously could both pre-check port 6505 as free, both attempt to bind, the loser would get `EADDRINUSE` and give up without retrying the next port. The session that lost the race had a server that never started, so every tool call failed for the remainder of that session with no way to recover short of restart. The fallback path in `index.ts` claimed it would "retry on first command" but no such retry existed.
- The fix replaces the racy pre-check + single bind with a proper bind-retry loop: each port in `6505–6509` is tried in turn, and `EADDRINUSE` triggers a fall-through to the next port. Only when the entire range is exhausted does `connect()` reject, with a clear error message and remediation hint.
- Cleaned up the misleading "will retry on first command" log line in `index.ts`.

### Tests
- New `tests/godot-connection.test.ts` covers: first-port allocation, sequential fall-through, **simultaneous parallel connects** (the exact regression scenario), range exhaustion, and `fixedPort=true` fail-fast behavior. 5 new tests, 62 total.

---

## v1.13.1 — 2026-05-12

**Bug Fix** — Silent disconnect / dead-connection recovery

### Fixed
- **Heartbeat now actually detects dead connections** (Discord report by CrusherEAGLE): The `ping`/`pong` heartbeat was being sent every 10s but neither side tracked whether responses were arriving, so a half-open TCP connection (common on Windows after sleep/wake, VPN toggle, or a brief editor hang) left both sides holding a dead socket. `isConnected()` continued to return `true`, every command timed out at 30s, and the only way back was to restart Claude Code **and** the Godot editor. Fixed on both sides:
  - **Server**: tracks the last `pong` timestamp; if 30s passes with no pong, forcibly destroys the socket (`terminate()`, vs `close()` which waits for a FIN ack that never comes on a dead link). Pending requests are rejected immediately rather than hanging for 30s.
  - **Editor**: sends its own `ping` every 5s, tracks per-port inactivity, and after 30s of inbound silence force-closes the peer so the existing 3s reconnect cycle takes over.
  - **OS-level TCP keepalive** enabled on the server socket (5s initial delay), surfacing half-open links faster than Windows' ~2-hour default.
- **Status panel surfaces stale state**: New yellow ⚠ indicator when a port is reconnecting from a stale state, plus per-port idle time (seconds since last received message) in the Clients tab. No more "looks fine while everything is broken" UI.

### Notes
- Recovery is automatic within ~30s after the connection dies. Watch the Output panel for `[MCP] Port NNNN silent for X.Xs — forcing reconnect` if you want to see it happen.
- No API or tool changes — same 172 tools, same behavior in the healthy path.

---

## v1.13.0 — 2026-05-05

**Bug Fixes & Polish** — Mouse motion dispatch, setup config, site pricing

### Fixed
- **`simulate_mouse_move` honors explicit `unhandled: false`** (#24, #25): Drag motions (`button_mask > 0`) auto-promote to `push_input` so camera-pan use cases bypass GUI consumption. But callers writing UI drag-and-drop tests need events to reach the GUI dispatcher (so `_get_drag_data` / `_drop_data` fire). Now: if the caller explicitly passes `unhandled: false`, that wins; auto-promotion only happens when `unhandled` was omitted. Default behavior preserved.
- **v1.12.0 build blocker**: Restored missing `mcp/server/src/utils/load-instructions.ts` referenced by `index.ts` since v1.12.0. Fresh clones of v1.12.0 failed `npm run build` with `Cannot find module './utils/load-instructions.js'`. v1.13.0 now builds clean.

### Changed
- **`setup` no longer pins `GODOT_MCP_PORT`** (#27): Generated MCP client config (Claude Desktop, Cursor, etc.) omits the `GODOT_MCP_PORT` env var so the server can auto-scan ports `6505–6509`. Pinning a fixed port caused silent failures when a stale process held the port. Users who need a fixed port can still set it manually.
- **Site JSON-LD price → $15** (#26): Structured data on the landing page now reflects the current price.

### Improved
- **README clarity** (issue #7 follow-up): More prominent note that the public repo ships the addon only — the MCP server is distributed via Buy Me a Coffee / itch.io.
- **`build-release.sh` portability**: Falls back to system `zip` and `python3` when 7-Zip is not on PATH.

---

## v1.12.0 — 2026-04-19

**Feature** — Android Remote Deploy · **Bug Fix** — Runtime IPC on custom user dirs

### Added
- **Android Remote Deploy** (3 tools, Full mode only — #20):
  - `list_android_devices` — wraps `adb devices -l`, returns serial/state/model/product. Resolves adb from Editor Settings > Export > Android > Adb, falling back to `adb` on PATH.
  - `get_android_preset_info` — reads metadata (package name, export path, runnable) from an Android preset in `export_presets.cfg`.
  - `deploy_to_android` — one-shot pipeline: Godot CLI export → `adb install -r` → `adb shell monkey` launch. Options: `preset_name`, `device_serial`, `debug`, `launch`, `skip_export`. Synchronous; export step can take tens of seconds.
- Full mode tool count: **169 → 172**. LITE / 3D / MINIMAL modes are unchanged.

### Fixed
- **`get_game_user_dir()`** (`commands/base_command.gd`) — #21: Runtime IPC commands (`get_game_scene_tree`, `get_game_node_properties`, `simulate_*`, etc.) failed with `Could not create game request file` when the project used `application/config/use_custom_user_dir=true`, or when `application/config/name` contained characters illegal on the host OS (e.g. `:` on Windows). Editor and game now resolve to the same dir: early-return `OS.get_user_data_dir()` for custom user dirs, and sanitize `config/name` via `xml_unescape().validate_filename().replace(".", "_")` — matching Godot's own logic in `ProjectSettings::_init`. Thanks @asim9834 for the detailed repro + patch.

---

## v1.11.0 — 2026-04-15

**Feature** — New `--3d` mode for 100-tool-limit clients

### Added
- **`--3d` mode**: Registers exactly 100 tools — the 81 core LITE tools plus Physics (6), AnimationTree (8), and Navigation (5). Designed for clients with a 100-tool cap (e.g. Google Antigravity with Claude Code proxy) that need full 3D game development capabilities. Usage: `node build/index.js --3d`

### Improved
- **Troubleshooting docs**: Clarified port conflict advice in INSTALL.md — recommends letting the server auto-scan ports 6505–6509 instead of setting a fixed `GODOT_MCP_PORT`, which can cause silent failures with stale processes

### Mode comparison

| Flag | Tools | Use case |
|------|-------|----------|
| *(none)* | 169 | Full mode — all tools |
| `--3d` | 100 | 3D game dev under 100-tool limit |
| `--lite` | 81 | Tight tool limits (Cursor, etc.) |
| `--minimal` | 35 | Ultra-tight limits (local LLMs) |

---

## v1.10.3 — 2026-04-11

**Bug Fixes** — Autoload preservation, Windows build, port conflict warning

### Fixed
- **Autoload deletion on `--import` / shutdown**: Plugin no longer removes pre-existing MCP autoloads from `project.godot`. Previously, `_remove_autoloads()` deleted all managed autoload keys unconditionally — even if they were project-owned. Now only autoloads injected by the current plugin session are removed. (#17)
- **Windows build failure**: Removed Unix-only `chmod -R a+x build || true` from the `build` script in `package.json`. The `chmod` and `true` commands don't exist on Windows cmd/PowerShell, causing `node build/setup.js install` to fail with "Build failed" even though TypeScript compilation succeeded. The fix is simply `"build": "tsc"` — execute permissions are not needed since the server runs via `node`. (#Discord)

### Improved
- **Port conflict warning for explicit port**: When `GODOT_MCP_PORT` is set and the port is already occupied (e.g. by a stale process), the server now logs a clear warning with remediation steps instead of silently failing to bind. (#15)

---

## v1.10.2 — 2026-04-11

**Fix** — Linux permission issue for build files

### Fixed
- **Linux permission denied**: Added `chmod -R a+x` to build process so that `build/index.js` and other compiled files have execute permission out of the box on Linux/macOS. Previously, users had to manually run `chmod -R a+x build` after installation. (Thanks to kflamsted for reporting!)

---

## v1.10.1 — 2026-04-08

**UX Improvement** — Bottom panel renamed, INSTALL.md rewritten

### Improved
- **Bottom panel renamed**: "MCP Server" → "MCP Pro" for consistency with the product name. Status label also updated.
- **INSTALL.md rewritten**: Added zip structure diagram, clear separation of addon vs server, Claude Desktop config paths, and better troubleshooting. Clarified that `configure` must be run from the Godot project directory.

---

## v1.10.0 — 2026-04-07

**New Tools & Quality Sweep** — Editor camera control, 169 tools, comprehensive audit fixes

### New Tools
- **`get_editor_camera`**: Get the 3D editor viewport camera position, rotation, and FOV. Useful for understanding the current view before taking screenshots.
- **`set_editor_camera`**: Move the 3D editor viewport camera to a specific position and orientation. Supports position, rotation, look_at target, and FOV. Use this to frame a view before screenshots to validate changes visually.

### Fixed
- **`plugin.gd` version display**: Was hardcoded to "v1.6.0" since initial release. Now dynamically reads from `plugin.cfg` — always shows the correct version.
- **Tool count inconsistency**: Was showing 162/163/167 across different files. All references now correctly say 169.
- **`node setup.js` path**: All docs and help text now correctly say `node build/setup.js`.
- **`configure` cwd issue**: INSTALL.md now clearly separates `install` (run from server/) and `configure` (run from Godot project root) to avoid `.mcp.json` being placed in the wrong directory.
- **INSTALL.md**: Fixed step numbering skip, stale tool count (49→169), port range (6505-6514).
- **README.md**: Replaced hardcoded dev paths with `/path/to/` placeholders.

### Improved
- **"v1.x" wording removed**: All pricing and marketing text now says "lifetime updates" without version scope.
- **Plugin port range**: WebSocket comment and connection range expanded to 6505-6514 (6510-6514 reserved for CLI).
- **Pre-built JS in release zip**: `build/setup.js` and `build/cli.js` work immediately after extract + `npm install`.
- **Claude Desktop support**: Confirmed working, added to configure auto-detection.

---

## v1.9.4 — 2026-04-06

**Bug Fixes** — State enum type regression, zip plugin version

### Fixed
- **`mcp_game_inspector_service.gd` State enum type error (regression)**: `var _state: State = State.IDLE` caused "Cannot assign a value of type mcp_game_inspector_service.gd.State to variable with specified type State" in some Godot versions. Changed back to `var _state := State.IDLE` (type inference). This was originally fixed in v1.6.4 but regressed. (Thanks @kalish)
- **Release zip contained wrong plugin version**: v1.9.3 zip shipped with plugin.cfg showing v1.9.2 due to a build order issue. Fixed build pipeline to ensure public repo is synced before zip creation.

---

## v1.9.3 — 2026-04-06

**Improvement** — Pre-built JS in release zip, docs cleanup

### Improved
- **Pre-built JS files included in release zip**: `build/setup.js`, `build/cli.js`, and all other compiled files are now included. Users can run `node build/setup.js install` immediately after extracting — no need to manually run `npm run build` first.
- **CLI naming unified in docs**: Removed `godot-cli` shorthand. All docs consistently use `node build/cli.js`. Added note that server must be built before CLI use.
- **CLI help port range fixed**: `--help` output now correctly shows 6510-6514 (CLI range), not 6505-6509 (MCP server range).

---

## v1.9.2 — 2026-04-06

**New Features** — Setup CLI, code-to-inspector workflow, CLI click fix

### New Features
- **Setup CLI (`setup.js`)**: One-command server setup and management. Commands: `install` (npm install + build), `check-update` (GitHub release check with semver comparison), `configure` (auto-detect AI client and generate .mcp.json), `doctor` (environment diagnostics).
- **Code-to-inspector migration workflow**: New guideline in AGENTS.md and skills.md instructing AI to prefer `update_property` over hardcoded GDScript for visual properties (colors, sizes, theme overrides). Includes step-by-step migration pattern.

### Fixed
- **CLI `input click --button` mapping**: The CLI sent string values ("left", "right", "middle") but the plugin expects numeric indices (1, 2, 3). Now correctly maps `left`→1, `right`→2, `middle`→3. (Thanks @Gogomy)

### Improved
- **INSTALL.md**: Added quick setup flow using `setup.js` for both fresh install and updates.
- **Instruction files**: All 12 client instruction files updated with new workflow patterns.

---

## v1.9.1 — 2026-04-05

**Bug Fix** — GODOT_MCP_PORT env var now respected + Cursor Full mode

### Fixed
- **`GODOT_MCP_PORT` env var ignored**: The server always scanned ports 6505-6509 for the first free port, ignoring the explicitly configured port. Now when `GODOT_MCP_PORT` is set, the server uses that port directly without scanning. (Fixes #13)

### Changed
- **Cursor moved to Full mode**: Cursor removed its 40-tool limit with Dynamic Context Discovery — all 167 tools now work in Full mode. (Thanks to @CrossBread for PR #14)

---

## v1.9.0 — 2026-04-05

**Universal Compatibility** — Minimal mode, CLI tool, and test suite

### New Features
- **Minimal mode (`--minimal`)**: Registers only 35 essential tools for clients with tight tool limits (Cursor ~40, OpenCode, local LLMs with small context windows). Covers project info, scene management, node CRUD, script editing, editor errors, input simulation, and runtime inspection.
- **CLI tool (`godot-cli`)**: Command-line interface for controlling Godot directly from a terminal. LLMs discover capabilities progressively via `--help` instead of loading all tool definitions upfront — zero context overhead, works with any client that has bash/terminal access. 7 command groups: project, scene, node, script, editor, input, runtime.
- **Test suite**: Added vitest with 47 unit tests covering tool-filter, error utilities, zod coercion, and CLI help/error handling.

### Improved
- **Client compatibility guide**: README and landing page now include a compatibility matrix for 12+ MCP clients with recommended mode for each (Full/Lite/Minimal/CLI).
- **Landing page**: Added "Choose Your Mode" setup step, CLI documentation, and new FAQ entry for tool count limits.
- **`print_verbose` for connect/disconnect**: WebSocket connect/disconnect messages in the Godot plugin now use `print_verbose()` instead of `print()`, eliminating terminal spam during normal operation.
- **Per-client instruction files**: `instructions/` folder with ready-to-copy instruction files for 12 AI clients (Claude Code, Cursor, Cline, Windsurf, Gemini CLI, Codex CLI, OpenCode, Roo Code, JetBrains/Junie, Amazon Q, Continue, Augment). Includes CLI usage documentation.

---

## v1.8.1 — 2026-04-04

**Bug Fix** — @export node reference support in update_property

### Fixed
- **`update_property` @export node references**: Setting `@export var` node references (e.g. `@export var hud: HUD`) via `update_property` now correctly resolves string paths to actual node references. Previously, `typeof(old_value)` returned `TYPE_NIL` for unset exports and `TYPE_OBJECT` for set ones, neither of which resolved the path string to a node. The fix checks `PROPERTY_HINT_NODE_TYPE` from the property's metadata to detect node reference exports and resolve accordingly. (Fixes #12)

---

## v1.8.0 — 2026-04-02

**New Features** — HTTP transport, screenshot file saving, custom class support

### New Features
- **Streamable HTTP transport**: New `--http` and `--http-port` flags for MCP clients that need HTTP instead of stdio. Starts an HTTP server at `http://127.0.0.1:8001/mcp` (default port).
- **Screenshot `save_path` option**: `get_editor_screenshot` and `get_game_screenshot` now accept an optional `save_path` parameter (e.g. `res://screenshot.png`) to save directly to disk instead of returning base64, avoiding MCP response cache bloat.
- **`add_node` custom class support**: `add_node` now resolves script-defined classes (`class_name`) in addition to built-in ClassDB types via `ProjectSettings.get_global_class_list()`.

### Improved
- **INSTALL.md**: Added "Updating to a New Version" section with step-by-step upgrade instructions.

---

## v1.7.2 — 2026-03-31

**Bug Fixes & Improvements** — execute_game_script robustness + auto-dismiss control

### Fixed
- **`execute_game_script` mixed indentation error**: User code with space indentation was prepended with tabs, causing "Mixed use of tabs and spaces" parse errors. Now auto-detects indent width and normalizes all leading spaces to tabs before wrapping.
- **`execute_game_script` standalone lambda error**: Top-level `func` definitions in user code were nested inside the wrapper's `run()` function, triggering "Standalone lambdas cannot be accessed" parse errors. Now extracts top-level functions to class level.
- **`command_router` crash on missing config section**: `_load_tool_config()` called `get_section_keys("disabled_tools")` without checking if the section exists, causing "Cannot get keys from nonexistent section" errors on fresh installs.

### Changed
- **Auto-dismiss dialogs now opt-in**: Previously auto-dismissed blocking editor dialogs whenever an MCP client was connected. Now disabled by default — AI must explicitly enable via the new `set_auto_dismiss` tool before operations that trigger reload/save dialogs.

### New Tools
- **`set_auto_dismiss`**: Enable or disable automatic dismissal of blocking editor dialogs (e.g., "Reload from disk?", "Save changes?"). Use before external file modifications, disable when done.

---

## v1.7.1 — 2026-03-30

**Bug Fixes** — Scene transition crash fix and deprecated API cleanup

### Fixed
- **`click_button_by_text` crash on scene transition**: Clicking a button that triggers a scene change (e.g., navigating from main menu to options) caused "Cannot get path of node as it is not in a scene tree" errors. Now caches button info before emitting the pressed signal and guards with `is_instance_valid()` / `is_inside_tree()` after the click.
- **Deprecated `push_unhandled_input()` warning**: Replaced with `push_input()` in `mcp_input_service.gd` per Godot 4.x API updates.

---

## v1.7.0 — 2026-03-29

**New Tools & Multi-Client Support** — 3 new tools for faster scene building, runtime signal debugging, and UI layout + instructions for non-Claude AI clients

### New Tools
- **`batch_add_nodes`**: Add multiple nodes in a single call. Nodes are processed in order so earlier nodes can be referenced as parents — build entire node trees in one shot instead of calling `add_node` repeatedly.
- **`watch_signals`**: Monitor signal emissions on specified nodes in the running game for a set duration. Returns a timestamped log of every signal fired with arguments — great for debugging event flow and verifying signal connections.
- **`setup_control`**: Configure a Control/Container node's layout in one call: anchor preset, min size, size flags, margins (MarginContainer), separation (VBox/HBoxContainer), and grow direction. Replaces 5+ `update_property` calls.

### New
- **`AGENTS.md` template**: Custom instructions for non-Claude AI clients (OpenAI Codex, opencode/ollama, Cursor, etc.). Includes editor vs runtime tool categorization, workflow patterns, formatting rules, and common pitfalls. Included in release zip.

---

## v1.6.5 — 2026-03-27

**assert_node_state Fix** — Game-side handler was missing, causing "Unknown command" error

### Fixed
- **`assert_node_state` missing game-side handler**: The command was registered in the TypeScript server and editor-side GDScript, but `mcp_game_inspector_service.gd` had no handler — returning "Unknown command" at runtime. This also broke node assertions within `run_test_scenario`. All 8 operators (eq, neq, gt, lt, gte, lte, contains, type_is) now work correctly.
- **Sub-property access in assertions**: Properties like `position:y` now use `get_indexed()` instead of `get()`, enabling assertions on vector components and nested properties.

---

## v1.6.4 — 2026-03-25

**Enum Type Fix** — Fixes script error on play in certain Godot versions

### Fixed
- **`mcp_game_inspector_service.gd` State enum type error**: Explicit `State` type annotation on `_state` variable caused "Cannot assign a value of type mcp_game_inspector_service.gd.State to variable with specified type State" errors in some Godot versions. Changed to type inference (`:=`) which resolves the mismatch.

---

## v1.6.3 — 2026-03-24

**Camera Pan Fix** — Mouse drag events now bypass GUI layer to reach `_unhandled_input()`

### Fixed
- **Mouse drag not reaching `_unhandled_input()`**: `simulate_mouse_move` with `button_mask` (drag simulation) was consumed by GUI Controls (`mouse_filter=STOP`) before reaching `_unhandled_input()`. Camera pan, drag-to-select, and other drag-based mechanics that rely on `_unhandled_input()` now work correctly. Events with `button_mask > 0` automatically use `push_unhandled_input()` to bypass the GUI layer.

### New
- **`simulate_mouse_move` `unhandled` parameter**: Optional `unhandled` flag to force any mouse motion event to bypass GUI and go directly to `_unhandled_input()`. Auto-enabled when `button_mask > 0`.
- **`simulate_sequence` `unhandled` support**: Sequence `mouse_motion` events also support the `unhandled` flag.

---

## v1.6.2 — 2026-03-24

**Animation Easing & Mouse Drag Simulation** — Community-requested fixes

### New
- **`set_animation_keyframe` easing parameter**: Optional `easing` param (default 1.0) to control keyframe transition curves. Values: 1.0=linear, <1.0=ease-in, >1.0=ease-out, negative=in-out variants.
- **`get_animation_info` easing field**: Each keyframe now returns its `easing` value.
- **`simulate_mouse_move` button_mask**: New `button_mask` parameter (1=left, 2=right, 4=middle) enables drag simulation. Required for games that check `InputEventMouseMotion.button_mask` (e.g. camera pan with mouse drag).
- **`simulate_sequence` button_mask**: Sequence events also support `button_mask` for drag operations.

### Fixed
- **Mouse sequence events**: `simulate_sequence` now correctly handles flat key format (`relative_x`, `relative_y`, `x`, `y`) in addition to nested format. Previously, mouse motion events in sequences had `relative=(0,0)` because the flat-to-nested conversion was missing.

---

## v1.6.1 — 2026-03-21

**Permission Presets** — Auto-approve tool permissions for Claude Code

### New
- **`settings.local.json`** (conservative): Pre-configured permission file that auto-approves 152 of 163 tools. Destructive tools (`delete_node`, `delete_scene`, `execute_editor_script`, etc.) still require manual approval.
- **`settings.local.permissive.json`**: Allows all 163 tools and all Bash commands, with an explicit deny list for dangerous shell commands (`rm -rf`, `git push --force`, `git reset --hard`, etc.) and destructive MCP tools.
- Copy either file to `~/.claude/settings.local.json` to skip per-tool permission prompts.

---

## v1.6.0 — 2026-03-21

**Enhanced Editor Panel** — Activity log with response details, client monitor, and tool management

### New
- **Activity tab**: Full command log showing method name, status, port, and timestamp. Toggle "Show Response Details" to inspect the JSON responses sent back to AI clients. Clear button to reset the log.
- **Clients tab**: Real-time view of all 5 WebSocket ports (6505-6509) with connection status and elapsed time since connection.
- **Tools tab**: Searchable list of all 163 tools with individual enable/disable checkboxes. Bulk "Enable All" / "Disable All" buttons. Disabled tools are persisted across sessions (`user://mcp_tool_config.cfg`) and return a clear error message to AI clients.

### Changed
- Status panel rebuilt with TabContainer (Activity / Clients / Tools)
- WebSocket server now emits `command_completed` signal with full response data and source port
- Connection time tracking per port for uptime display

---

## v1.5.3 — 2026-03-15

**New tool** — `record_frames` for long-running debug observation

### New
- **`record_frames`**: Capture up to 600 screenshots saved as PNG files to `user://mcp_recorded_frames/`. Unlike `capture_frames` (which returns base64 images directly, max 30), this tool saves to disk and returns file paths — ideal for long-running debug sessions without flooding the AI context with image data. Supports optional `node_data` tracking for per-frame property snapshots (position, velocity, etc.).

---

## v1.5.2 — 2026-03-13

**Bugfix** — Screenshot capture now works when the SceneTree is paused

### Fixed
- **`mcp_screenshot_service.gd`**: Added `process_mode = Node.PROCESS_MODE_ALWAYS` so the file-polling loop in `_process()` keeps running during pause. The other two autoloads (`mcp_input_service.gd`, `mcp_game_inspector_service.gd`) already had this — screenshot service was the only one missing it.
- **`mcp_screenshot_service.gd`**: Replaced `await get_tree().process_frame` with `await get_tree().create_timer(0.05).timeout` — `process_frame` never fires when the tree is paused, but `create_timer()` with default `process_always=true` does.

Thanks to **mrkielbasa** for reporting this bug!

---

## v1.5.1 — 2026-03-08

**Patch release** — AI Skills file for better out-of-the-box experience

### New
- **`skills.md`**: Added `addons/godot_mcp/skills.md` — a comprehensive guide for AI assistants covering all 162 tools, 10 practical workflows, best practices, and common pitfalls. Users can copy this to `.claude/skills.md` in their project root so Claude Code knows how to use the MCP tools effectively from the start.
- **README**: Added setup step for copying `skills.md` to `.claude/skills.md`.

---

## v1.5.0 — 2026-03-04

**Feature** — Lite mode for MCP clients with tool count limits

### New Features
- **Lite mode (`--lite`)**: Launch with `--lite` flag to register only 76 core tools instead of 162. Designed for MCP clients with tool count limits (Windsurf: 100, Cursor: ~40, Antigravity: 100).
  - Core categories (always loaded): project, scene, node, script, editor, input, runtime, input_map
  - Extended categories (Full mode only): animation, animation_tree, audio, batch, export, navigation, particle, physics, profiling, resource, scene_3d, shader, test, theme, tilemap, analysis
  - Usage: Add `"--lite"` to args in your MCP config

---

## v1.4.5 — 2026-03-04

**Patch release** — Godot 4.3 compatibility fix

### Bug Fixes
- **Godot 4.3 compatibility**: Fixed `scene_3d_commands.gd` parse error caused by `Environment.TONE_MAPPER_AGX` enum (added in Godot 4.4). Now uses integer value for backward compatibility. This was a blocking error that prevented the entire plugin from loading on Godot 4.3.

---

## v1.4.4 — 2026-03-04

**Patch release** — Revert Output panel filter expansion

### Bug Fixes
- **`get_editor_errors`**: Removed `W `, `WARN`, `GDScript` Output panel filters added in v1.4.3 — these patterns don't actually appear in Godot's Output panel (`push_warning` uses `WARNING:` prefix) and caused false positives on normal text.

---

## v1.4.3 — 2026-03-04

**Patch release** — Comprehensive error/warning detection

### Improvements
- **`get_editor_errors`**: Now reads runtime errors from the debugger Errors tab (ScriptEditorDebugger), returned with `DEBUGGER:` prefix including stack traces. Previously only static analysis and Output panel errors were captured.

### Bug Fixes
- **`get_editor_errors`**: Fixed debugger Errors tab not being found because the tab name includes a count suffix (e.g. "Errors (1)") — now uses prefix matching.

---

## v1.4.2 — 2026-03-04

**Patch release** — Improved error detection in script editor

### Improvements
- **`get_editor_errors`**: Now reads GDScript analyzer errors and warnings from the script editor's error/warning panels (VSplitContainer RichTextLabels), in addition to the Output panel and CodeEdit line highlights. Catches static analysis messages like type mismatches and autoload name conflicts that were previously missed.

---

## v1.4.1 — 2026-03-02

**Patch release** — Bug fixes found during comprehensive tool audit

### Bug Fixes
- **`replay_recording`**: Fixed false crash recovery error (`_pending_command` flag not cleared for async replay loop)
- **`wait_for_node`**: Fixed false crash recovery error when polling for node appearance
- **`apply_particle_preset`**: Fixed editor crash in `gl_compatibility` renderer caused by immediate `GradientTexture1D` assignment — now uses `set_deferred` and reduced texture width

---

## v1.4.0 — 2026-03-01

**162 tools** across 23 categories (+15 new tools)

### New Tools
- **`move_to`** — Autopilot: automatically walk a character to target coordinates using pathfinding
- **`navigate_to`** — High-level navigation command for AI-driven movement
- **`find_nearby_nodes`** — Find nodes within a radius of a given position
- **`get_node_groups`** / **`set_node_groups`** — Read and write node group memberships
- **`find_nodes_in_group`** — Query all nodes belonging to a specific group
- **`get_output_log`** — Retrieve Godot's Output panel contents
- **`get_input_actions`** / **`set_input_action`** — Read and configure Input Map actions
- **`search_in_files`** — Full-text search across project files
- **`validate_script`** — Check GDScript for errors without running
- **`get_resource_preview`** — Get thumbnail previews of resources
- **`get_scene_exports`** — List exported variables in a scene's root script
- **`add_autoload`** / **`remove_autoload`** — Manage autoload singletons

### Bug Fixes & Improvements
- **Crash recovery**: `capture_frames` no longer triggers false crash recovery (`_pending_command` flag fix)
- **`capture_frames` node_data**: Optional per-frame property snapshots via `node_data` parameter
- **Debugger auto-continue**: Automatically presses Continue when runtime errors pause the debugger
- **`simulate_key` duration**: Now accepts fractional seconds (e.g., 0.3s) for precise movement
- **Command router fix**: All 8 command classes now properly registered (~47 tools were previously unreachable)

---

## v1.3.1 — 2026-02-27

**Patch release**

### Bug Fixes
- **`get_editor_errors`**: Now reads from Output panel and CodeEdit error gutter (previously returned empty results)
- **Tonemap enum**: Fixed environment tonemap mode enum name mapping

---

## v1.3.0 — 2026-02-26

**147 tools** across 23 categories (+63 new tools)

### New Tool Categories

#### AnimationTree & State Machine (8 tools)
- `create_animation_tree`, `get_animation_tree_structure`, `set_tree_parameter`
- `add_state_machine_state`, `remove_state_machine_state`
- `add_state_machine_transition`, `remove_state_machine_transition`
- `set_blend_tree_node`

#### Physics & Collision (6 tools)
- `setup_collision`, `setup_physics_body`, `get_collision_info`
- `get_physics_layers`, `set_physics_layers`, `add_raycast`

#### 3D Scene (6 tools)
- `add_mesh_instance`, `setup_lighting`, `set_material_3d`
- `setup_environment`, `setup_camera_3d`, `add_gridmap`

#### Particles (5 tools)
- `create_particles`, `set_particle_material`, `set_particle_color_gradient`
- `get_particle_info`, `apply_particle_preset` (8 built-in presets: fire, smoke, sparks, rain, snow, explosion, magic, dust)

#### Navigation (5 tools)
- `setup_navigation_region`, `bake_navigation_mesh`, `setup_navigation_agent`
- `set_navigation_layers`, `get_navigation_info`

#### Audio (6 tools)
- `get_audio_bus_layout`, `add_audio_bus`, `set_audio_bus`
- `add_audio_bus_effect`, `add_audio_player`, `get_audio_info`

#### Testing & QA (5 tools)
- `run_test_scenario`, `assert_node_state`, `assert_screen_text`
- `run_stress_test`, `get_test_report`

#### Project Analysis (6 tools)
- `find_unused_resources`, `analyze_signal_flow`, `analyze_scene_complexity`
- `detect_circular_dependencies`, `get_scene_dependencies`, `get_project_statistics`

### Expanded: Runtime Analysis
- `find_ui_elements`, `click_button_by_text`, `wait_for_node`
- Runtime tools expanded from 4 to 15 tools

### Other Additions
- `add_resource`, `create_resource`, `edit_resource`, `read_resource` — Resource management tools

---

## v1.2.0 — 2026-02-24

**84 tools** across 14 categories (+34 new tools)

### New Tool Categories

#### Animation (6 tools)
- `list_animations`, `create_animation`, `add_animation_track`
- `set_animation_keyframe`, `get_animation_info`, `remove_animation`

#### TileMap (6 tools)
- `tilemap_set_cell`, `tilemap_fill_rect`, `tilemap_get_cell`
- `tilemap_clear`, `tilemap_get_info`, `tilemap_get_used_cells`

#### Theme & UI (6 tools)
- `create_theme`, `set_theme_color`, `set_theme_constant`
- `set_theme_font_size`, `set_theme_stylebox`, `get_theme_info`

#### Profiling (2 tools)
- `get_performance_monitors`, `get_editor_performance`

#### Batch Operations & Refactoring (5 tools)
- `find_nodes_by_type`, `find_signal_connections`, `batch_set_property`
- `find_node_references`, `get_scene_dependencies`

#### Shader (6 tools)
- `create_shader`, `read_shader`, `edit_shader`
- `assign_shader_material`, `set_shader_param`, `get_shader_params`

#### Export (3 tools)
- `list_export_presets`, `export_project`, `get_export_info`

### Bug Fixes
- Fixed game IPC connection when project name changes
- Added `set_project_setting` tool for safe project.godot modifications via EditorSettings API
- Fixed script reload behavior

---

## v1.1.0 — 2026-02-23

**49 tools** across 8 categories (+16 new tools)

### New Tool Categories

#### Input Simulation (4 tools)
- `simulate_key`, `simulate_mouse_click`, `simulate_mouse_move`, `simulate_sequence`

#### Runtime Analysis (4 tools)
- `play_scene`, `stop_scene`, `get_game_scene_tree`, `get_game_screenshot`
- `execute_game_script`, `get_game_node_properties`, `set_game_node_property`
- `monitor_properties`, `capture_frames`

### Other
- Added `build-release.sh` for reproducible release packaging
- `start_recording` / `stop_recording` / `replay_recording` for input recording

---

## v1.0.0 — 2026-02-22

**~33 tools** across 6 categories — Initial release

### Tool Categories
- **Scene Management**: `create_scene`, `open_scene`, `save_scene`, `get_scene_tree`, `delete_scene`, `get_scene_file_content`, `add_scene_instance`
- **Node Operations**: `add_node`, `delete_node`, `rename_node`, `move_node`, `duplicate_node`, `update_property`, `get_node_properties`, `batch_get_properties`, `connect_signal`, `disconnect_signal`, `get_signals`
- **Script**: `create_script`, `read_script`, `edit_script`, `attach_script`, `list_scripts`, `find_nodes_by_script`, `find_script_references`, `get_open_scripts`
- **Editor**: `get_editor_screenshot`, `get_editor_errors`, `clear_output`, `execute_editor_script`, `reload_plugin`
- **Project**: `get_project_info`, `get_project_settings`, `get_filesystem_tree`, `search_files`
- **UI**: Anchor presets (`set_anchor_preset`)

### Architecture
- WebSocket-based communication between Godot editor plugin and MCP TypeScript server
- Supports Claude Code, Cursor, Windsurf, and any MCP-compatible AI coding tool
- Screenshot capture from both editor and game viewports
