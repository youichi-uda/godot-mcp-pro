# Changelog

All notable changes to Godot MCP Pro will be documented in this file.

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
