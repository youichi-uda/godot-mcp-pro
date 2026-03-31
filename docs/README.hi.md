> **Language:** [English](../README.md) | [日本語](README.ja.md) | [Português (BR)](README.pt-br.md) | [Español](README.es.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | हिन्दी

# Godot MCP Pro

AI-powered Godot गेम डेवलपमेंट के लिए प्रीमियम MCP (Model Context Protocol) सर्वर। Claude जैसे AI assistants को सीधे आपके Godot editor से जोड़ता है, **163 powerful tools** के साथ।

## Architecture

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Real-time**: WebSocket connection से instant feedback मिलता है, file polling की जरूरत नहीं
- **Editor Integration**: Godot के editor API, UndoRedo system और scene tree तक पूरी access
- **JSON-RPC 2.0**: Proper error codes और suggestions के साथ standard protocol

## Quick Start

### 1. Godot Plugin Install करें

`addons/godot_mcp/` folder को अपने Godot project की `addons/` directory में copy करें।

Plugin enable करें: **Project → Project Settings → Plugins → Godot MCP Pro → Enable**

### 2. MCP Server Install करें

> **नोट**: `server/` डायरेक्टरी केवल **फुल पैकेज** (पेड) में शामिल है।
> इस GitHub रिपॉजिटरी में केवल **addon (plugin)** है।
> सर्वर प्राप्त करने के लिए [godot-mcp.abyo.net](https://godot-mcp.abyo.net/) पर फुल पैकेज खरीदें।

```bash
cd server
npm install
npm run build
```

### 3. Claude Code Configure करें

अपनी `.mcp.json` में add करें:

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

### 4. Tool Permissions Auto-Approve करें (Recommended)

Claude Code हर tool call पर permission मांगता है। इन prompts को skip करने के लिए, included permission presets को अपनी Claude Code settings में copy करें:

**Option A: Conservative** (default — destructive tools को block करता है)

```bash
cp settings.local.json ~/.claude/settings.local.json
```

163 में से 152 tools को automatically allow करता है। नीचे दिए गए 11 tools को हर बार manual approval की जरूरत होगी:

| Blocked Tool | कारण |
|---|---|
| `delete_node` | Scene से node delete करता है |
| `delete_scene` | Disk से scene file delete करता है |
| `remove_animation` | Animation remove करता है |
| `remove_autoload` | Autoload singleton remove करता है |
| `remove_state_machine_state` | State machine state remove करता है |
| `remove_state_machine_transition` | State machine transition remove करता है |
| `execute_editor_script` | Editor में arbitrary code run करता है |
| `execute_game_script` | Running game में arbitrary code run करता है |
| `export_project` | Project export trigger करता है |
| `tilemap_clear` | TileMapLayer की सभी cells clear करता है |

**Option B: Permissive** (सब allow, dangerous commands deny)

```bash
cp settings.local.permissive.json ~/.claude/settings.local.json
```

सभी 163 tools और सभी Bash commands allow करता है। Destructive shell commands (`rm -rf`, `git push --force`, `git reset --hard`, etc.) और ऊपर listed destructive MCP tools को explicitly deny करता है।

> **Note**: अगर आपके पास पहले से `settings.local.json` है, तो overwrite करने की बजाय `permissions` section को manually merge करें।

### 5. Lite Mode (Optional)

अगर आपके MCP client में tool count limit है (जैसे Windsurf: 100, Cursor: ~40), तो Lite mode use करें जो 162 की बजाय 76 core tools register करता है:

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

Lite mode में शामिल: project, scene, node, script, editor, input, runtime और input_map tools।

### 6. Use करना शुरू करें

Plugin enabled state में अपना Godot project खोलें, फिर editor के साथ interact करने के लिए Claude Code use करें।

## सभी 162 Tools

### Project Tools (7)
| Tool | विवरण |
|------|-------------|
| `get_project_info` | Project metadata, version, viewport, autoloads |
| `get_filesystem_tree` | Filtering के साथ recursive file tree |
| `search_files` | Fuzzy/glob file search |
| `get_project_settings` | project.godot settings पढ़ें |
| `set_project_setting` | Editor API से project settings set करें |
| `uid_to_project_path` | UID → res:// conversion |
| `project_path_to_uid` | res:// → UID conversion |

### Scene Tools (9)
| Tool | विवरण |
|------|-------------|
| `get_scene_tree` | Hierarchy के साथ live scene tree |
| `get_scene_file_content` | .tscn file का raw content |
| `create_scene` | नई scene files बनाएं |
| `open_scene` | Editor में scene खोलें |
| `delete_scene` | Scene file delete करें |
| `add_scene_instance` | Scene को child node के रूप में instance करें |
| `play_scene` | Scene run करें (main/current/custom) |
| `stop_scene` | Running scene stop करें |
| `save_scene` | Current scene disk पर save करें |

### Node Tools (14)
| Tool | विवरण |
|------|-------------|
| `add_node` | Type और properties के साथ node add करें |
| `delete_node` | Node delete करें (undo support के साथ) |
| `duplicate_node` | Node और children duplicate करें |
| `move_node` | Node move/reparent करें |
| `update_property` | कोई भी property set करें (auto type parsing) |
| `get_node_properties` | Node की सभी properties पाएं |
| `add_resource` | Node में Shape/Material/etc add करें |
| `set_anchor_preset` | Control anchor preset set करें |
| `rename_node` | Scene में node rename करें |
| `connect_signal` | Nodes के बीच signal connect करें |
| `disconnect_signal` | Signal connection disconnect करें |
| `get_node_groups` | Node किन groups में है, जानें |
| `set_node_groups` | Node group membership set करें |
| `find_nodes_in_group` | Group में सभी nodes खोजें |

### Script Tools (8)
| Tool | विवरण |
|------|-------------|
| `list_scripts` | Class info के साथ सभी scripts list करें |
| `read_script` | Script content पढ़ें |
| `create_script` | Template के साथ नया script बनाएं |
| `edit_script` | Search/replace या full edit |
| `attach_script` | Node को script attach करें |
| `get_open_scripts` | Editor में open scripts list करें |
| `validate_script` | GDScript syntax validate करें |
| `search_in_files` | Project files में content search करें |

### Editor Tools (9)
| Tool | विवरण |
|------|-------------|
| `get_editor_errors` | Errors और stack traces पाएं |
| `get_editor_screenshot` | Editor viewport capture करें |
| `get_game_screenshot` | Running game capture करें |
| `execute_editor_script` | Editor में arbitrary GDScript run करें |
| `clear_output` | Output panel clear करें |
| `get_signals` | Node के सभी signals connections के साथ पाएं |
| `reload_plugin` | MCP plugin reload करें (auto-reconnect) |
| `reload_project` | Filesystem rescan करें और scripts reload करें |
| `get_output_log` | Output panel content पाएं |

### Input Tools (7)
| Tool | विवरण |
|------|-------------|
| `simulate_key` | Keyboard key press/release simulate करें |
| `simulate_mouse_click` | Position पर mouse click simulate करें |
| `simulate_mouse_move` | Mouse movement simulate करें |
| `simulate_action` | Godot Input Action simulate करें |
| `simulate_sequence` | Frame delays के साथ input event sequence |
| `get_input_actions` | सभी input actions list करें |
| `set_input_action` | Input action create/modify करें |

### Runtime Tools (19)
| Tool | विवरण |
|------|-------------|
| `get_game_scene_tree` | Running game का scene tree |
| `get_game_node_properties` | Running game में node properties |
| `set_game_node_property` | Running game में node property set करें |
| `execute_game_script` | Game context में GDScript run करें |
| `capture_frames` | Multi-frame screenshot capture |
| `monitor_properties` | समय के साथ property values record करें |
| `start_recording` | Input recording शुरू करें |
| `stop_recording` | Input recording बंद करें |
| `replay_recording` | Recorded input replay करें |
| `find_nodes_by_script` | Script से game nodes खोजें |
| `get_autoload` | Autoload node properties पाएं |
| `batch_get_properties` | Multiple nodes की properties batch में पाएं |
| `find_ui_elements` | Game में UI elements खोजें |
| `click_button_by_text` | Text से button click करें |
| `wait_for_node` | Node appear होने का wait करें |
| `find_nearby_nodes` | Position के पास nodes खोजें |
| `navigate_to` | Target position तक navigate करें |
| `move_to` | Character को target तक walk कराएं |

### Animation Tools (6)
| Tool | विवरण |
|------|-------------|
| `list_animations` | AnimationPlayer की सभी animations list करें |
| `create_animation` | नई animation बनाएं |
| `add_animation_track` | Track add करें (value/position/rotation/method/bezier) |
| `set_animation_keyframe` | Track में keyframe insert करें |
| `get_animation_info` | सभी tracks/keys के साथ detailed animation info |
| `remove_animation` | Animation remove करें |

### TileMap Tools (6)
| Tool | विवरण |
|------|-------------|
| `tilemap_set_cell` | Single tile cell set करें |
| `tilemap_fill_rect` | Rectangular region tiles से fill करें |
| `tilemap_get_cell` | Cell का tile data पाएं |
| `tilemap_clear` | सभी cells clear करें |
| `tilemap_get_info` | TileMapLayer info और tile set sources |
| `tilemap_get_used_cells` | Used cells की list |

### Theme & UI Tools (6)
| Tool | विवरण |
|------|-------------|
| `create_theme` | Theme resource file बनाएं |
| `set_theme_color` | Theme color override set करें |
| `set_theme_constant` | Theme constant override set करें |
| `set_theme_font_size` | Theme font size override set करें |
| `set_theme_stylebox` | StyleBoxFlat override set करें |
| `get_theme_info` | Theme overrides info पाएं |

### Profiling Tools (2)
| Tool | विवरण |
|------|-------------|
| `get_performance_monitors` | सभी performance monitors (FPS, memory, physics, etc.) |
| `get_editor_performance` | Quick performance summary |

### Batch & Refactoring Tools (8)
| Tool | विवरण |
|------|-------------|
| `find_nodes_by_type` | Type से सभी nodes खोजें |
| `find_signal_connections` | Scene में सभी signal connections खोजें |
| `batch_set_property` | एक type के सभी nodes पर property set करें |
| `find_node_references` | Project files में pattern search करें |
| `get_scene_dependencies` | Resource dependencies पाएं |
| `cross_scene_set_property` | सभी scenes में property set करें |
| `find_script_references` | Script/resource कहां use हो रहा है, खोजें |
| `detect_circular_dependencies` | Scene circular dependencies detect करें |

### Shader Tools (6)
| Tool | विवरण |
|------|-------------|
| `create_shader` | Template के साथ shader बनाएं |
| `read_shader` | Shader file पढ़ें |
| `edit_shader` | Shader edit करें (replace/search-replace) |
| `assign_shader_material` | Node को ShaderMaterial assign करें |
| `set_shader_param` | Shader parameter set करें |
| `get_shader_params` | सभी shader parameters पाएं |

### Export Tools (3)
| Tool | विवरण |
|------|-------------|
| `list_export_presets` | Export presets list करें |
| `export_project` | Preset के लिए export command पाएं |
| `get_export_info` | Export-related project info |

### Resource Tools (6)
| Tool | विवरण |
|------|-------------|
| `read_resource` | .tres resource properties पढ़ें |
| `edit_resource` | Resource properties edit करें |
| `create_resource` | नया .tres resource बनाएं |
| `get_resource_preview` | Resource thumbnail पाएं |
| `add_autoload` | Autoload singleton register करें |
| `remove_autoload` | Autoload singleton remove करें |

### Physics Tools (6)
| Tool | विवरण |
|------|-------------|
| `setup_physics_body` | Physics body properties configure करें |
| `setup_collision` | Nodes में collision shapes add करें |
| `set_physics_layers` | Collision layer/mask set करें |
| `get_physics_layers` | Collision layer/mask info पाएं |
| `get_collision_info` | Collision shape details पाएं |
| `add_raycast` | RayCast2D/3D node add करें |

### 3D Scene Tools (6)
| Tool | विवरण |
|------|-------------|
| `add_mesh_instance` | Primitive mesh के साथ MeshInstance3D add करें |
| `setup_camera_3d` | Camera3D properties configure करें |
| `setup_lighting` | Light nodes add/configure करें |
| `setup_environment` | WorldEnvironment configure करें |
| `add_gridmap` | GridMap node setup करें |
| `set_material_3d` | StandardMaterial3D properties set करें |

### Particle Tools (5)
| Tool | विवरण |
|------|-------------|
| `create_particles` | GPUParticles2D/3D बनाएं |
| `set_particle_material` | ParticleProcessMaterial configure करें |
| `set_particle_color_gradient` | Particles के लिए color gradient set करें |
| `apply_particle_preset` | Preset apply करें (fire, smoke, sparks, etc.) |
| `get_particle_info` | Particle system details पाएं |

### Navigation Tools (6)
| Tool | विवरण |
|------|-------------|
| `setup_navigation_region` | NavigationRegion configure करें |
| `setup_navigation_agent` | NavigationAgent configure करें |
| `bake_navigation_mesh` | Navigation mesh bake करें |
| `set_navigation_layers` | Navigation layers set करें |
| `get_navigation_info` | Navigation setup info पाएं |

### Audio Tools (6)
| Tool | विवरण |
|------|-------------|
| `add_audio_player` | AudioStreamPlayer node add करें |
| `add_audio_bus` | Audio bus add करें |
| `add_audio_bus_effect` | Audio bus में effect add करें |
| `set_audio_bus` | Audio bus properties configure करें |
| `get_audio_bus_layout` | Audio bus layout info पाएं |
| `get_audio_info` | Audio-related node info पाएं |

### AnimationTree Tools (4)
| Tool | विवरण |
|------|-------------|
| `create_animation_tree` | AnimationTree बनाएं |
| `get_animation_tree_structure` | Tree structure पाएं |
| `set_tree_parameter` | AnimationTree parameter set करें |
| `add_state_machine_state` | State machine में state add करें |

### State Machine Tools (3)
| Tool | विवरण |
|------|-------------|
| `remove_state_machine_state` | State machine से state remove करें |
| `add_state_machine_transition` | States के बीच transition add करें |
| `remove_state_machine_transition` | State transition remove करें |

### Blend Tree Tools (1)
| Tool | विवरण |
|------|-------------|
| `set_blend_tree_node` | Blend tree nodes configure करें |

### Analysis & Search Tools (4)
| Tool | विवरण |
|------|-------------|
| `analyze_scene_complexity` | Scene performance analyze करें |
| `analyze_signal_flow` | Signal connections map करें |
| `find_unused_resources` | Unreferenced resources खोजें |
| `get_project_statistics` | Project-wide statistics पाएं |

### Testing & QA Tools (6)
| Tool | विवरण |
|------|-------------|
| `run_test_scenario` | Automated test scenario run करें |
| `assert_node_state` | Node property values assert करें |
| `assert_screen_text` | Screen पर text check करें |
| `compare_screenshots` | दो screenshots compare करें |
| `run_stress_test` | Performance stress test run करें |
| `get_test_report` | Test results report पाएं |

## मुख्य Features

- **UndoRedo Integration**: सभी node/property operations Ctrl+Z support करती हैं
- **Smart Type Parsing**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` auto-converted
- **Auto-Reconnect**: Exponential backoff reconnection (1s → 2s → 4s ... → 60s max)
- **Heartbeat**: 10s ping/pong connection alive रखता है
- **Helpful Errors**: Error responses में अगले steps के लिए suggestions शामिल

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
| **Undo/Redo** | हां | हां | नहीं | नहीं | नहीं |
| **JSON-RPC 2.0** | हां | Custom | Custom | Custom | N/A |
| **Auto-reconnect** | हां (exponential backoff) | N/A | नहीं | नहीं | N/A |
| **Heartbeat** | हां (10s ping/pong) | नहीं | नहीं | नहीं | नहीं |
| **Error suggestions** | हां (contextual hints) | नहीं | नहीं | नहीं | नहीं |
| **Screenshot capture** | हां (editor + game) | हां | नहीं | नहीं | नहीं |
| **Game input simulation** | हां (key/mouse/action/sequence) | हां (basic) | नहीं | नहीं | नहीं |
| **Runtime inspection** | हां (scene tree + properties + monitor) | नहीं | नहीं | नहीं | नहीं |
| **Signal management** | हां (connect/disconnect/inspect) | नहीं | नहीं | नहीं | नहीं |
| **Browser visualizer** | नहीं | नहीं | हां | नहीं | नहीं |
| **AI 3D mesh generation** | नहीं | नहीं | नहीं | हां (Meshy API) | नहीं |

### Exclusive Categories (किसी Competitor के पास नहीं)

| Category | Tools | क्यों Important है |
|----------|-------|----------------|
| **Animation** | 6 tools | Animations बनाएं, tracks add करें, keyframes set करें — सब programmatically |
| **TileMap** | 6 tools | Cells set करें, rects fill करें, tile data query करें — 2D level design के लिए essential |
| **Theme/UI** | 6 tools | StyleBox, colors, fonts — बिना manual editor work के UI themes बनाएं |
| **Profiling** | 2 tools | FPS, memory, draw calls, physics — performance monitoring |
| **Batch/Refactor** | 8 tools | Type से खोजें, batch property changes, cross-scene updates, dependency analysis |
| **Shader** | 6 tools | Shaders create/edit करें, materials assign करें, parameters set करें |
| **Export** | 3 tools | Presets list करें, export commands पाएं, templates check करें |
| **Physics** | 6 tools | Collision shapes, bodies, raycasts और layer management setup करें |
| **3D Scene** | 6 tools | Meshes, cameras, lights, environment, GridMap support add करें |
| **Particle** | 5 tools | Custom materials, presets और gradients के साथ particles बनाएं |
| **Navigation** | 6 tools | Navigation regions, agents, pathfinding, baking configure करें |
| **Audio** | 6 tools | Complete audio bus system, effects, players, live management |
| **AnimationTree** | 4 tools | Transitions और blend trees के साथ state machines बनाएं |
| **State Machine** | 3 tools | Complex animations के लिए advanced state machine management |
| **Testing/QA** | 6 tools | Automated testing, assertions, stress testing, screenshot comparison |
| **Runtime** | 19 tools | Runtime पर game inspect और control करें: inspect, record, replay, navigate |

### Architecture Advantages

| पहलू | Godot MCP Pro | Typical Competitor |
|--------|--------------|-------------------|
| **Protocol** | JSON-RPC 2.0 (standard, extensible) | Custom JSON या CLI-based |
| **Connection** | Heartbeat के साथ persistent WebSocket | Per-command subprocess या raw TCP |
| **Reliability** | Exponential backoff के साथ auto-reconnect (1s→60s) | Manual reconnection required |
| **Type Safety** | Smart type parsing (Vector2, Color, Rect2, hex colors) | String-only या limited types |
| **Error Handling** | Codes + suggestions के साथ structured errors | Generic error messages |
| **Undo Support** | सभी mutations UndoRedo system से गुजरती हैं | Direct modifications (no undo) |
| **Port Management** | Ports 6505-6509 auto-scan | Fixed port, conflicts possible |

## License

Proprietary — details के लिए [LICENSE](../LICENSE) देखें। Purchase में v1.x के lifetime updates शामिल हैं।
