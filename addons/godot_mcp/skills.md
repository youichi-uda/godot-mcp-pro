# Godot MCP Pro — Skills for AI Assistants

> Copy this file to `.claude/skills.md` in your Godot project root to give Claude Code full context on how to use Godot MCP Pro effectively.

## What is Godot MCP Pro?

You have access to 162 MCP tools that connect directly to the Godot 4 editor. You can create scenes, write scripts, simulate player input, inspect running games, and more — all without the user leaving this conversation. Every change goes through Godot's UndoRedo system, so the user can always Ctrl+Z.

## Essential Workflows

### 1. Explore a Project

Always start by understanding the project before making changes:

```
get_project_info          → project name, Godot version, renderer, viewport size
get_filesystem_tree       → directory structure (use filter: "*.tscn" or "*.gd")
get_scene_tree            → node hierarchy of the currently open scene
read_script               → read any GDScript file
get_project_settings      → check project configuration
```

### 2. Build a 2D Scene

```
create_scene   → create .tscn file with root node type
add_node       → add child nodes with properties
create_script  → write GDScript for game logic
attach_script  → attach script to a node
update_property → set position, scale, modulate, etc.
save_scene     → save to disk
```

**Example — creating a player:**
1. `create_scene` with root_type `CharacterBody2D`, path `res://scenes/player.tscn`
2. `add_node` type `Sprite2D` with texture property
3. `add_node` type `CollisionShape2D`
4. `add_resource` to assign a shape (e.g., `RectangleShape2D`) to the CollisionShape2D
5. `create_script` with movement logic
6. `attach_script` to the root node
7. `save_scene`

### 3. Build a 3D Scene

```
create_scene         → root_type: Node3D
add_mesh_instance    → add primitives (box, sphere, cylinder, plane) or import .glb/.gltf
setup_lighting       → add DirectionalLight3D, OmniLight3D, or SpotLight3D
setup_environment    → sky, ambient light, fog, tonemap
setup_camera_3d      → camera with optional SpringArm3D for third-person
set_material_3d      → PBR materials (albedo, metallic, roughness, emission)
setup_collision      → add collision shapes to physics bodies
setup_physics_body   → configure mass, friction, gravity
```

### 4. Write & Edit Scripts

```
create_script  → create new .gd file (provide full content)
edit_script    → modify existing scripts
  - Use `replacements: [{search: "old code", replace: "new code"}]` for targeted edits
  - Use `content` for full file replacement
  - Use `insert_at_line` + `text` for inserting code
validate_script → check for syntax errors without running
read_script    → read current content before editing
```

### 5. Playtest & Debug

```
play_scene             → launch the game (mode: "current", "main", or file path)
get_game_screenshot    → see what the game looks like right now
capture_frames         → capture multiple frames to observe motion/animation
get_game_scene_tree    → inspect the live scene tree at runtime
get_game_node_properties → read runtime values (position, health, state, etc.)
set_game_node_property → modify values in the running game
simulate_key           → press keys (WASD, SPACE, etc.) with duration
simulate_mouse_click   → click at viewport coordinates
simulate_action        → trigger InputMap actions (move_left, jump, etc.)
get_editor_errors      → check for runtime errors
stop_scene             → stop the game
```

**Playtesting loop:**
1. `play_scene` → start the game
2. `get_game_screenshot` → see current state
3. `simulate_key` / `simulate_action` → interact with the game
4. `capture_frames` → observe behavior over time
5. `get_game_node_properties` → check specific values
6. `stop_scene` → stop when done
7. Fix issues in scripts → repeat

### 6. Animations

```
# Ensure an AnimationPlayer node exists in the scene
create_animation       → new animation with length and loop mode
add_animation_track    → add property/transform/method tracks
set_animation_keyframe → insert keyframes at specific times
get_animation_info     → inspect existing animations
```

**Example — bouncing sprite:**
1. `create_animation` name `bounce`, length `1.0`, loop_mode `1` (linear loop)
2. `add_animation_track` track_path `Sprite2D:position`, track_type `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control, Label, Button, TextureRect, etc.
set_anchor_preset → position Controls (full_rect, center, bottom_wide, etc.)
set_theme_color   → change font_color, etc.
set_theme_font_size → adjust text size
set_theme_stylebox  → backgrounds, borders, rounded corners
connect_signal    → wire up button pressed, value_changed, etc.
```

### 8. TileMap

```
tilemap_get_info      → check tile set sources and atlas layout
tilemap_set_cell      → place individual tiles
tilemap_fill_rect     → fill rectangular regions
tilemap_get_used_cells → see what's already placed
tilemap_clear         → clear all cells
```

### 9. Audio

```
add_audio_bus        → create audio buses (SFX, Music, UI)
set_audio_bus        → adjust volume, solo, mute
add_audio_bus_effect → add reverb, delay, compressor, etc.
add_audio_player     → add AudioStreamPlayer(2D/3D) nodes
```

### 10. Project Configuration

```
set_project_setting  → change viewport size, physics settings, etc.
set_input_action     → define input mappings (move_left → KEY_A, etc.)
add_autoload         → register autoload singletons
set_physics_layers   → name collision layers (player, enemy, world, etc.)
```

## Important Rules & Pitfalls

### Property Values
Properties are auto-parsed from strings. Use these formats:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` or `"#ff0000"`
- Bool: `"true"` / `"false"`
- Numbers: `"42"`, `"3.14"`
- Enums: Use integer values (e.g., `0` for the first enum value)

### Never Edit project.godot Directly
Godot editor constantly overwrites `project.godot`. Always use `set_project_setting` to change project settings.

### GDScript Type Annotations
When writing GDScript with `for` loops over untyped arrays, use explicit type annotations:
```gdscript
# BAD — will cause errors
for item in some_untyped_array:
    var x := item.value  # type inference fails

# GOOD
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### Script Changes Need Reload
After creating or significantly modifying scripts, use `reload_project` to ensure Godot picks up the changes. This is especially important after `create_script`.

### simulate_key Tips
- Use **short durations** (0.3–0.5 seconds) for precise movement
- Long durations (1+ seconds) cause overshooting
- For gameplay testing, prefer `simulate_action` over `simulate_key` when InputMap actions are defined

### simulate_mouse_click
- Default `auto_release: true` sends both press and release — required for UI buttons
- UI buttons fire on release, so both events are needed

### execute_game_script Limitations
- No nested functions (`func` inside `func`) — causes compile error
- Use `.get("property")` instead of `.property` for dynamic access
- Runtime errors will pause the debugger (auto-continued, but avoid if possible)

### Collision & Pickup Areas
- For collectible items, use Area3D/Area2D with radius ≥ 1.5
- Smaller radii are nearly impossible to trigger with simulated input

### Save Frequently
Call `save_scene` after making significant changes. Unsaved changes can be lost if the editor reloads.

## Analysis & Debugging Tools

When something goes wrong, use these tools to investigate:

```
get_editor_errors          → check for script errors and runtime exceptions
get_output_log             → read print() output and warnings
analyze_scene_complexity   → find performance bottlenecks
analyze_signal_flow        → visualize signal connections
detect_circular_dependencies → find circular script/scene references
find_unused_resources      → clean up unused files
get_performance_monitors   → FPS, memory, draw calls, physics stats
```

## Testing & QA

```
run_test_scenario   → define and run automated test sequences
assert_node_state   → verify node properties match expected values
assert_screen_text  → verify text is displayed on screen
compare_screenshots → visual regression testing (use file paths, not base64)
run_stress_test     → spawn many nodes to test performance
```

## Advanced Patterns

### Cross-Scene Operations
```
cross_scene_set_property → modify nodes in scenes that aren't currently open
find_node_references     → find all files referencing a pattern
batch_set_property       → set a property on all nodes of a type
```

### Shader Workflow
```
create_shader        → write GLSL-like shader code
assign_shader_material → apply to a node
set_shader_param     → adjust uniforms at runtime
get_shader_params    → inspect current values
```

### Navigation (3D)
```
setup_navigation_region → define walkable area
bake_navigation_mesh   → generate navmesh
setup_navigation_agent → add pathfinding to characters
```

### AnimationTree & State Machines
```
create_animation_tree           → set up AnimationTree with state machine or blend tree
add_state_machine_state         → add states (idle, walk, run, jump)
add_state_machine_transition    → define transitions between states
set_tree_parameter              → control blend parameters
```

## Recommended Workflow Order

When building a new game from scratch:

1. **Project setup** — `get_project_info`, `set_project_setting` (viewport, physics)
2. **Input mapping** — `set_input_action` for all player controls
3. **Main scene** — `create_scene`, set as main scene
4. **Player** — create player scene with sprite, collision, script
5. **Level/World** — build environment (TileMap, 3D meshes, etc.)
6. **Game logic** — scripts for enemies, items, UI
7. **Audio** — set up buses, add audio players
8. **Playtest** — `play_scene`, test with simulated input, fix bugs
9. **Polish** — animations, particles, shaders, themes
10. **Export** — `list_export_presets`, `export_project`
