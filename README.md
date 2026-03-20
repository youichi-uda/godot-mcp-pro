# Godot MCP Pro

Premium MCP (Model Context Protocol) server for AI-powered Godot game development. Connects AI assistants like Claude directly to your Godot editor with **163 powerful tools**.

## Architecture

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Real-time**: WebSocket connection means instant feedback, no file polling
- **Editor Integration**: Full access to Godot's editor API, UndoRedo system, and scene tree
- **JSON-RPC 2.0**: Standard protocol with proper error codes and suggestions

## Quick Start

### 1. Install the Godot Plugin

Copy the `addons/godot_mcp/` folder into your Godot project's `addons/` directory.

Enable the plugin: **Project → Project Settings → Plugins → Godot MCP Pro → Enable**

### 2. Install the MCP Server

```bash
cd server
npm install
npm run build
```

### 3. Configure Claude Code

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "godot-mcp-pro": {
      "command": "node",
      "args": ["D:/dev/godot-mcp-pro/server/build/index.js"],
      "env": {
        "GODOT_MCP_PORT": "6505"
      }
    }
  }
}
```

### 4. Lite Mode (Optional)

If your MCP client has a tool count limit (e.g., Windsurf: 100, Cursor: ~40), use Lite mode which registers 76 core tools instead of 162:

```json
{
  "mcpServers": {
    "godot-mcp-pro": {
      "command": "node",
      "args": ["D:/dev/godot-mcp-pro/server/build/index.js", "--lite"]
    }
  }
}
```

Lite mode includes: project, scene, node, script, editor, input, runtime, and input_map tools.

### 5. Use It

Open your Godot project with the plugin enabled, then use Claude Code to interact with the editor.

## All 162 Tools

### Project Tools (7)
| Tool | Description |
|------|-------------|
| `get_project_info` | Project metadata, version, viewport, autoloads |
| `get_filesystem_tree` | Recursive file tree with filtering |
| `search_files` | Fuzzy/glob file search |
| `get_project_settings` | Read project.godot settings |
| `set_project_setting` | Set project settings via editor API |
| `uid_to_project_path` | UID → res:// conversion |
| `project_path_to_uid` | res:// → UID conversion |

### Scene Tools (9)
| Tool | Description |
|------|-------------|
| `get_scene_tree` | Live scene tree with hierarchy |
| `get_scene_file_content` | Raw .tscn file content |
| `create_scene` | Create new scene files |
| `open_scene` | Open scene in editor |
| `delete_scene` | Delete scene file |
| `add_scene_instance` | Instance scene as child node |
| `play_scene` | Run scene (main/current/custom) |
| `stop_scene` | Stop running scene |
| `save_scene` | Save current scene to disk |

### Node Tools (14)
| Tool | Description |
|------|-------------|
| `add_node` | Add node with type and properties |
| `delete_node` | Delete node (with undo support) |
| `duplicate_node` | Duplicate node and children |
| `move_node` | Move/reparent node |
| `update_property` | Set any property (auto type parsing) |
| `get_node_properties` | Get all node properties |
| `add_resource` | Add Shape/Material/etc to node |
| `set_anchor_preset` | Set Control anchor preset |
| `rename_node` | Rename a node in the scene |
| `connect_signal` | Connect signal between nodes |
| `disconnect_signal` | Disconnect signal connection |
| `get_node_groups` | Get groups a node belongs to |
| `set_node_groups` | Set node group membership |
| `find_nodes_in_group` | Find all nodes in a group |

### Script Tools (8)
| Tool | Description |
|------|-------------|
| `list_scripts` | List all scripts with class info |
| `read_script` | Read script content |
| `create_script` | Create new script with template |
| `edit_script` | Search/replace or full edit |
| `attach_script` | Attach script to node |
| `get_open_scripts` | List scripts open in editor |
| `validate_script` | Validate GDScript syntax |
| `search_in_files` | Search content in project files |

### Editor Tools (9)
| Tool | Description |
|------|-------------|
| `get_editor_errors` | Get errors and stack traces |
| `get_editor_screenshot` | Capture editor viewport |
| `get_game_screenshot` | Capture running game |
| `execute_editor_script` | Run arbitrary GDScript in editor |
| `clear_output` | Clear output panel |
| `get_signals` | Get all signals of a node with connections |
| `reload_plugin` | Reload the MCP plugin (auto-reconnect) |
| `reload_project` | Rescan filesystem and reload scripts |
| `get_output_log` | Get output panel content |

### Input Tools (7)
| Tool | Description |
|------|-------------|
| `simulate_key` | Simulate keyboard key press/release |
| `simulate_mouse_click` | Simulate mouse click at position |
| `simulate_mouse_move` | Simulate mouse movement |
| `simulate_action` | Simulate Godot Input Action |
| `simulate_sequence` | Sequence of input events with frame delays |
| `get_input_actions` | List all input actions |
| `set_input_action` | Create/modify input action |

### Runtime Tools (19)
| Tool | Description |
|------|-------------|
| `get_game_scene_tree` | Scene tree of running game |
| `get_game_node_properties` | Node properties in running game |
| `set_game_node_property` | Set node property in running game |
| `execute_game_script` | Run GDScript in game context |
| `capture_frames` | Multi-frame screenshot capture |
| `monitor_properties` | Record property values over time |
| `start_recording` | Start input recording |
| `stop_recording` | Stop input recording |
| `replay_recording` | Replay recorded input |
| `find_nodes_by_script` | Find game nodes by script |
| `get_autoload` | Get autoload node properties |
| `batch_get_properties` | Batch get multiple node properties |
| `find_ui_elements` | Find UI elements in game |
| `click_button_by_text` | Click button by text content |
| `wait_for_node` | Wait for node to appear |
| `find_nearby_nodes` | Find nodes near position |
| `navigate_to` | Navigate to target position |
| `move_to` | Walk character to target |

### Animation Tools (6)
| Tool | Description |
|------|-------------|
| `list_animations` | List all animations in AnimationPlayer |
| `create_animation` | Create new animation |
| `add_animation_track` | Add track (value/position/rotation/method/bezier) |
| `set_animation_keyframe` | Insert keyframe into track |
| `get_animation_info` | Detailed animation info with all tracks/keys |
| `remove_animation` | Remove an animation |

### TileMap Tools (6)
| Tool | Description |
|------|-------------|
| `tilemap_set_cell` | Set a single tile cell |
| `tilemap_fill_rect` | Fill rectangular region with tiles |
| `tilemap_get_cell` | Get tile data at cell |
| `tilemap_clear` | Clear all cells |
| `tilemap_get_info` | TileMapLayer info and tile set sources |
| `tilemap_get_used_cells` | List of used cells |

### Theme & UI Tools (6)
| Tool | Description |
|------|-------------|
| `create_theme` | Create Theme resource file |
| `set_theme_color` | Set theme color override |
| `set_theme_constant` | Set theme constant override |
| `set_theme_font_size` | Set theme font size override |
| `set_theme_stylebox` | Set StyleBoxFlat override |
| `get_theme_info` | Get theme overrides info |

### Profiling Tools (2)
| Tool | Description |
|------|-------------|
| `get_performance_monitors` | All performance monitors (FPS, memory, physics, etc.) |
| `get_editor_performance` | Quick performance summary |

### Batch & Refactoring Tools (8)
| Tool | Description |
|------|-------------|
| `find_nodes_by_type` | Find all nodes of a type |
| `find_signal_connections` | Find all signal connections in scene |
| `batch_set_property` | Set property on all nodes of a type |
| `find_node_references` | Search project files for pattern |
| `get_scene_dependencies` | Get resource dependencies |
| `cross_scene_set_property` | Set property across all scenes |
| `find_script_references` | Find where script/resource is used |
| `detect_circular_dependencies` | Find circular scene dependencies |

### Shader Tools (6)
| Tool | Description |
|------|-------------|
| `create_shader` | Create shader with template |
| `read_shader` | Read shader file |
| `edit_shader` | Edit shader (replace/search-replace) |
| `assign_shader_material` | Assign ShaderMaterial to node |
| `set_shader_param` | Set shader parameter |
| `get_shader_params` | Get all shader parameters |

### Export Tools (3)
| Tool | Description |
|------|-------------|
| `list_export_presets` | List export presets |
| `export_project` | Get export command for preset |
| `get_export_info` | Export-related project info |

### Resource Tools (6)
| Tool | Description |
|------|-------------|
| `read_resource` | Read .tres resource properties |
| `edit_resource` | Edit resource properties |
| `create_resource` | Create new .tres resource |
| `get_resource_preview` | Get resource thumbnail |
| `add_autoload` | Register autoload singleton |
| `remove_autoload` | Remove autoload singleton |

### Physics Tools (6)
| Tool | Description |
|------|-------------|
| `setup_physics_body` | Configure physics body properties |
| `setup_collision` | Add collision shapes to nodes |
| `set_physics_layers` | Set collision layer/mask |
| `get_physics_layers` | Get collision layer/mask info |
| `get_collision_info` | Get collision shape details |
| `add_raycast` | Add RayCast2D/3D node |

### 3D Scene Tools (6)
| Tool | Description |
|------|-------------|
| `add_mesh_instance` | Add MeshInstance3D with primitive mesh |
| `setup_camera_3d` | Configure Camera3D properties |
| `setup_lighting` | Add/configure light nodes |
| `setup_environment` | Configure WorldEnvironment |
| `add_gridmap` | Set up GridMap node |
| `set_material_3d` | Set StandardMaterial3D properties |

### Particle Tools (5)
| Tool | Description |
|------|-------------|
| `create_particles` | Create GPUParticles2D/3D |
| `set_particle_material` | Configure ParticleProcessMaterial |
| `set_particle_color_gradient` | Set color gradient for particles |
| `apply_particle_preset` | Apply preset (fire, smoke, sparks, etc.) |
| `get_particle_info` | Get particle system details |

### Navigation Tools (6)
| Tool | Description |
|------|-------------|
| `setup_navigation_region` | Configure NavigationRegion |
| `setup_navigation_agent` | Configure NavigationAgent |
| `bake_navigation_mesh` | Bake navigation mesh |
| `set_navigation_layers` | Set navigation layers |
| `get_navigation_info` | Get navigation setup info |

### Audio Tools (6)
| Tool | Description |
|------|-------------|
| `add_audio_player` | Add AudioStreamPlayer node |
| `add_audio_bus` | Add audio bus |
| `add_audio_bus_effect` | Add effect to audio bus |
| `set_audio_bus` | Configure audio bus properties |
| `get_audio_bus_layout` | Get audio bus layout info |
| `get_audio_info` | Get audio-related node info |

### AnimationTree Tools (4)
| Tool | Description |
|------|-------------|
| `create_animation_tree` | Create AnimationTree |
| `get_animation_tree_structure` | Get tree structure |
| `set_tree_parameter` | Set AnimationTree parameter |
| `add_state_machine_state` | Add state to state machine |

### State Machine Tools (3)
| Tool | Description |
|------|-------------|
| `remove_state_machine_state` | Remove state from state machine |
| `add_state_machine_transition` | Add transition between states |
| `remove_state_machine_transition` | Remove state transition |

### Blend Tree Tools (1)
| Tool | Description |
|------|-------------|
| `set_blend_tree_node` | Configure blend tree nodes |

### Analysis & Search Tools (4)
| Tool | Description |
|------|-------------|
| `analyze_scene_complexity` | Analyze scene performance |
| `analyze_signal_flow` | Map signal connections |
| `find_unused_resources` | Find unreferenced resources |
| `get_project_statistics` | Get project-wide statistics |

### Testing & QA Tools (6)
| Tool | Description |
|------|-------------|
| `run_test_scenario` | Run automated test scenario |
| `assert_node_state` | Assert node property values |
| `assert_screen_text` | Check for text on screen |
| `compare_screenshots` | Compare two screenshots |
| `run_stress_test` | Run performance stress test |
| `get_test_report` | Get test results report |

## Key Features

- **UndoRedo Integration**: All node/property operations support Ctrl+Z
- **Smart Type Parsing**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` auto-converted
- **Auto-Reconnect**: Exponential backoff reconnection (1s → 2s → 4s ... → 60s max)
- **Heartbeat**: 10s ping/pong keeps connection alive
- **Helpful Errors**: Error responses include suggestions for next steps

## Competitive Comparison

### Tool Count

| Category | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) | ee0pdt (free) | bradypp (free) |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Project | 7 | 5 | 4 | 0 | 2 | 2 | 2 |
| Scene | 9 | 8 | 11 | 9 | 3 | 4 | 5 |
| Node | **14** | 8 | 0 | 8 | 2 | 3 | 0 |
| Script | **8** | 5 | 6 | 4 | 0 | 5 | 0 |
| Editor | **9** | 5 | 1 | 5 | 1 | 3 | 2 |
| Input | **7** | 2 | 0 | 0 | 0 | 0 | 0 |
| Runtime | **19** | 0 | 0 | 0 | 0 | 0 | 0 |
| Animation | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| TileMap | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Theme/UI | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Profiling | **2** | 0 | 0 | 0 | 0 | 0 | 0 |
| Batch/Refactor | **8** | 0 | 0 | 0 | 0 | 0 | 0 |
| Shader | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Export | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Resource | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Physics | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 3D Scene | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Particle | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Navigation | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Audio | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| AnimationTree | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| State Machine | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Blend Tree | **1** | 0 | 0 | 0 | 0 | 0 | 0 |
| Analysis | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Testing/QA | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Asset/AI | 0 | 0 | 1 | 6 | 0 | 0 | 0 |
| Material | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| Other | 0 | 0 | 9 | 5 | 5 | 2 | 1 |
| **Total** | **162** | ~30 | **32** | **39** | **13** | **19** | **10** |

### Feature Matrix

| Feature | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **Connection** | WebSocket (real-time) | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | Yes | Yes | No | No | No |
| **JSON-RPC 2.0** | Yes | Custom | Custom | Custom | N/A |
| **Auto-reconnect** | Yes (exponential backoff) | N/A | No | No | N/A |
| **Heartbeat** | Yes (10s ping/pong) | No | No | No | No |
| **Error suggestions** | Yes (contextual hints) | No | No | No | No |
| **Screenshot capture** | Yes (editor + game) | Yes | No | No | No |
| **Game input simulation** | Yes (key/mouse/action/sequence) | Yes (basic) | No | No | No |
| **Runtime inspection** | Yes (scene tree + properties + monitor) | No | No | No | No |
| **Signal management** | Yes (connect/disconnect/inspect) | No | No | No | No |
| **Browser visualizer** | No | No | Yes | No | No |
| **AI 3D mesh generation** | No | No | No | Yes (Meshy API) | No |

### Exclusive Categories (No Competitor Has These)

| Category | Tools | Why It Matters |
|----------|-------|----------------|
| **Animation** | 6 tools | Create animations, add tracks, set keyframes — all programmatically |
| **TileMap** | 6 tools | Set cells, fill rects, query tile data — essential for 2D level design |
| **Theme/UI** | 6 tools | StyleBox, colors, fonts — build UI themes without manual editor work |
| **Profiling** | 2 tools | FPS, memory, draw calls, physics — performance monitoring |
| **Batch/Refactor** | 8 tools | Find by type, batch property changes, cross-scene updates, dependency analysis |
| **Shader** | 6 tools | Create/edit shaders, assign materials, set parameters |
| **Export** | 3 tools | List presets, get export commands, check templates |
| **Physics** | 6 tools | Set up collision shapes, bodies, raycasts, and layer management |
| **3D Scene** | 6 tools | Add meshes, cameras, lights, environment, GridMap support |
| **Particle** | 5 tools | Create particles with custom materials, presets, and gradients |
| **Navigation** | 6 tools | Configure navigation regions, agents, pathfinding, baking |
| **Audio** | 6 tools | Complete audio bus system, effects, players, live management |
| **AnimationTree** | 4 tools | Build state machines with transitions and blend trees |
| **State Machine** | 3 tools | Advanced state machine management for complex animations |
| **Testing/QA** | 6 tools | Automated testing, assertions, stress testing, screenshot comparison |
| **Runtime** | 19 tools | Inspect and control game at runtime: inspect, record, replay, navigate |

### Architecture Advantages

| Aspect | Godot MCP Pro | Typical Competitor |
|--------|--------------|-------------------|
| **Protocol** | JSON-RPC 2.0 (standard, extensible) | Custom JSON or CLI-based |
| **Connection** | Persistent WebSocket with heartbeat | Per-command subprocess or raw TCP |
| **Reliability** | Auto-reconnect with exponential backoff (1s→60s) | Manual reconnection required |
| **Type Safety** | Smart type parsing (Vector2, Color, Rect2, hex colors) | String-only or limited types |
| **Error Handling** | Structured errors with codes + suggestions | Generic error messages |
| **Undo Support** | All mutations go through UndoRedo system | Direct modifications (no undo) |
| **Port Management** | Auto-scan ports 6505-6509 | Fixed port, conflicts possible |

## License

Proprietary — see [LICENSE](LICENSE) for details. Purchase includes lifetime updates for v1.x.
