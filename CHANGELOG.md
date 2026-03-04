# Changelog

All notable changes to Godot MCP Pro will be documented in this file.

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
