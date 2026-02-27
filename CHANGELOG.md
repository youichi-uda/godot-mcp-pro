# Changelog

All notable changes to Godot MCP Pro will be documented in this file.

## [1.3.1] - 2026-02-27

### Fixed
- `get_editor_errors` now reads from the editor's Output panel (RichTextLabel) and script editor compile errors (CodeEdit red background lines) instead of relying on `godot.log`, which is empty in Godot 4.6
- `scene_3d_commands` tonemap enum names updated for Godot 4.6 (`TONE_MAP_*` → `TONE_MAPPER_*`)
- Added AGX tonemap mode support

## [1.3.0] - 2026-02-25

### Added
- **AnimationTree** (8 tools): State machines, transitions with conditions, blend trees, tree parameters
- **3D Scene** (6 tools): Mesh primitives & .glb/.gltf import, lighting presets, PBR materials, environment (sky/fog/SSAO/SSR), cameras, GridMap
- **Physics** (6 tools): Collision shapes (auto 2D/3D), physics layers/masks, raycasts, body configuration
- **Particles** (5 tools): GPU particles 2D/3D, material config, color gradients, presets (fire/smoke/rain/snow/sparks)
- **Navigation** (5 tools): Navigation regions, mesh baking, pathfinding agents, layer management
- **Audio** (6 tools): Audio bus layout, effects (reverb/delay/compressor/EQ), 2D/3D players
- **Resource** (3 tools): Read/edit/create .tres resource files of any type
- **Testing & QA** (5 tools): Automated test scenarios, property assertions, screen text verification, stress testing
- **Code Analysis** (6 tools): Unused resource detection, signal flow mapping, scene complexity, circular dependencies
- Runtime tools: `find_ui_elements`, `click_button_by_text`, `wait_for_node`, `batch_get_properties`
- Editor tools: `compare_screenshots` (visual diff), `set_project_setting`
- Batch tools: `cross_scene_set_property`
- Total tools: 84 → 147 across 14 → 23 categories

## [1.2.0] - 2026-02-20

### Added
- **Input Simulation** (5 tools): Keyboard, mouse, InputAction, multi-event sequences
- **Runtime Analysis** (11 tools): Game scene tree, runtime properties, frame capture, input recording/replay
- **Animation** (6 tools): Create animations, add tracks, insert keyframes
- **TileMap** (6 tools): Set/fill/query cells, tile set info
- **Theme & UI** (6 tools): Colors, constants, font sizes, StyleBoxFlat
- **Shader** (6 tools): Create/edit shaders, assign materials, set/get uniforms
- **Batch & Refactoring** (5 tools): Find by type, signal audit, batch property set
- **Profiling** (2 tools): Performance monitors
- **Export** (3 tools): Export presets and commands
- Total tools: 32 → 84 across 5 → 14 categories

## [1.1.0] - 2026-02-15

### Added
- Signal management: `connect_signal`, `disconnect_signal`, `get_signals`
- Node operations: `rename_node`, `duplicate_node`, `move_node`, `set_anchor_preset`
- Smart type parsing for Vector2, Vector3, Color, Rect2, etc.
- Full Undo/Redo support via EditorUndoRedoManager
- Port auto-scanning (6505-6509)
- Heartbeat with auto-reconnect

## [1.0.0] - 2026-02-10

### Added
- Initial release
- **Project** (5 tools): Project info, filesystem tree, file search
- **Scene** (7 tools): Scene tree, create/open/delete/save, play/stop
- **Node** (4 tools): Add/delete nodes, update properties, get properties
- **Script** (5 tools): List/read/create/edit scripts, attach to nodes
- **Editor** (5 tools): Screenshots, GDScript execution, error log
- WebSocket connection with exponential backoff reconnect
