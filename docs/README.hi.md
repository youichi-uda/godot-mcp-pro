> **Language:** [English](../README.md) | [日本語](README.ja.md) | [Português (BR)](README.pt-br.md) | [Español](README.es.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | हिन्दी

# Godot MCP Pro

AI-powered Godot गेम डेवलपमेंट के लिए प्रीमियम MCP (Model Context Protocol) सर्वर। Claude जैसे AI assistants को सीधे आपके Godot editor से जोड़ता है, **187 powerful tools** के साथ।

## Architecture

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Real-time**: WebSocket connection से instant feedback मिलता है, file polling की जरूरत नहीं
- **Editor Integration**: Godot के editor API, UndoRedo system और scene tree तक पूरी access
- **JSON-RPC 2.0**: सही error codes और suggestions के साथ standard protocol

## इस repo में क्या है

> ⚠️ **इस public repo में सिर्फ free Godot addon/plugin है।** MCP server (Node.js, AI assistants को connect करने के लिए जरूरी) paid package के हिस्से के रूप में distribute होता है — **one-time purchase**, lifetime updates:
>
> - **Buy Me a Coffee**: <https://buymeacoffee.com/y1uda/extras>
> - **itch.io**: <https://y1uda.itch.io/godot-mcp-pro>
>
> Paid zip में addon, pre-built JavaScript वाली `server/` directory, `INSTALL.md` और AI-client instructions शामिल हैं। अगर आपने यह repo clone किया है और `server/` folder नहीं दिख रहा, तो **यह expected है** — ऊपर दिए गए links में से किसी एक से full package लें।

## Quick Start

### 1. Godot Plugin Install करें

`addons/godot_mcp/` folder को अपने Godot project की `addons/` directory में copy करें।

Plugin enable करें: **Project → Project Settings → Plugins → Godot MCP Pro → Enable**

### 2. MCP Server Install करें

> `server/` directory सिर्फ **full paid package** में शामिल है (ऊपर देखें)। Zip download और extract करने के बाद, run करें:

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
      "args": ["/path/to/server/build/index.js"],
      "env": {
        "GODOT_MCP_PORT": "6505"
      }
    }
  }
}
```

### 4. अपना Mode चुनें

Godot MCP Pro हर client की tool limit के हिसाब से चार modes देता है:

| Mode | Tools | किसके लिए सबसे अच्छा |
|------|-------|----------|
| **Full** (default) | 187 | Claude Code, Cline, VS Code Copilot, Cursor |
| **3D** (`--3d`) | 100 | Antigravity और 3D की जरूरत वाले अन्य 100-tool-limit clients |
| **Lite** (`--lite`) | 88 | Windsurf, JetBrains Junie, Gemini CLI |
| **Minimal** (`--minimal`) | 35 | OpenCode, छोटे context वाले local LLMs |

`--3d` में core tools के साथ physics, AnimationTree और navigation शामिल हैं, लेकिन 100-tool cap के अंदर रहने के लिए `uid_to_project_path`, `project_path_to_uid`, `compare_screenshots`, `clear_output`, `close_script`, `reload_open_scripts`, `set_anchor_preset` और `click_button_by_text` को छोड़ दिया गया है।

```json
{
  "mcpServers": {
    "godot-mcp-pro": {
      "command": "node",
      "args": ["/path/to/server/build/index.js", "--lite"]
    }
  }
}
```

सबसे छोटे footprint के लिए `--lite` को `--minimal` से replace करें।

- **Lite** में शामिल: project, scene, node, script, editor, input, runtime और input_map tools।
- **Minimal** में शामिल: 35 essential tools — project info, scene management, node CRUD, script editing, editor errors, input simulation और runtime inspection।

### 5. CLI Mode (MCP का विकल्प)

MCP support न रखने वाले clients के लिए, या जब आप zero context overhead चाहते हैं, terminal/bash tool से सीधे CLI use करें। CLI के लिए पहले server build होना जरूरी है (Step 2)।

```bash
# Top-level help — shows all command groups
node /path/to/server/build/cli.js --help

# Group help — shows commands in a group
node /path/to/server/build/cli.js node --help

# Command help — shows options for a command
node /path/to/server/build/cli.js node add --help

# Execute
node /path/to/server/build/cli.js project info
node /path/to/server/build/cli.js scene play
node /path/to/server/build/cli.js node add --type CharacterBody3D --name Player
```

`/path/to/` को उस actual path से replace करें जहाँ आपने files extract की हैं।

CLI WebSocket के जरिए सीधे Godot editor plugin से connect होता है। इसके लिए जरूरी है:
- MCP plugin enabled के साथ Godot editor चल रहा हो
- Server build हो (`node build/setup.js install`)
- 6510-6514 range में एक available port

**फायदा**: LLMs सभी tool definitions पहले से load करने की बजाय `--help` के जरिए capabilities को धीरे-धीरे discover करते हैं। यह terminal access वाले किसी भी LLM client के साथ काम करता है, tool count limits चाहे जो हों।

### 6. Client Compatibility

| Client | Recommended Mode | Notes |
|--------|-----------------|-------|
| Claude Code | Full (default) | Deferred tool loading — minimal context cost |
| VS Code Copilot | Full | Virtual Tools, tools को auto-group करते हैं |
| OpenAI Codex CLI | Full | MCPSearch overflow को defer करता है |
| Cline | Full | कोई hard limit नहीं; whitelist के लिए `enabledTools` use करें |
| Roo Code | Full | कोई hard limit नहीं |
| Windsurf | Lite | 100 tool limit |
| JetBrains Junie | Lite | 100 tool limit |
| Gemini CLI | Lite | ~100 client limit; finer control के लिए `excludeTools` use करें |
| Cursor | Full | Tool limit हटा दी गई (Dynamic Context Discovery) |
| OpenCode | Minimal or CLI | ~40 tools के बाद models degrade होते हैं |
| Local LLMs (LM Studio, etc.) | Minimal or CLI | Context window bottleneck है |

### 7. Use करना शुरू करें

Plugin enabled state में अपना Godot project खोलें, फिर editor के साथ interact करने के लिए Claude Code use करें।

## सभी 187 Tools

### Project Tools (10)
| Tool | विवरण |
|------|-------------|
| `get_project_info` | Project metadata, version, viewport, autoloads |
| `get_filesystem_tree` | Filtering के साथ recursive file tree |
| `search_files` | Fuzzy/glob file search |
| `search_in_files` | Project files में content search करें |
| `get_project_settings` | project.godot settings पढ़ें |
| `set_project_setting` | Editor API से project settings set करें |
| `uid_to_project_path` | UID → res:// conversion |
| `project_path_to_uid` | res:// → UID conversion |
| `add_autoload` | Autoload singleton register करें |
| `remove_autoload` | Autoload singleton remove करें |

### Scene Tools (10)
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
| `get_scene_exports` | Scene file के सभी scripted nodes के @export variables list करें |

### Node Tools (17)
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
| `get_node_groups` | Node किन groups में है, यह पाएं |
| `set_node_groups` | Node group membership set करें |
| `find_nodes_in_group` | Group के सभी nodes खोजें |
| `get_editor_selection` | Scene dock में selected nodes पाएं |
| `select_nodes` | Scene dock में nodes select करें (और optionally focus/inspect करें) |
| `clear_editor_selection` | Scene dock selection clear करें |

### Script Tools (9)
| Tool | विवरण |
|------|-------------|
| `list_scripts` | Class info के साथ सभी scripts list करें |
| `read_script` | Script content पढ़ें |
| `create_script` | Template के साथ नई script बनाएं |
| `edit_script` | Search/replace या full edit |
| `attach_script` | Node में script attach करें |
| `validate_script` | GDScript syntax validate करें |
| `close_script` | Script editor tab close करें; unsaved edits होने पर मना करता है, जब तक discard करने को न कहा जाए (Godot 4.7+) |
| `reload_open_scripts` | Unsaved buffers रखते हुए open scripts को disk से reload करें (Godot 4.7+) |
| `get_open_scripts` | Editor में open scripts list करें |

### Editor Tools (15)
| Tool | विवरण |
|------|-------------|
| `get_editor_errors` | Errors और stack traces पाएं |
| `get_output_log` | Output panel content पाएं |
| `get_editor_screenshot` | Editor viewport capture करें |
| `get_game_screenshot` | Running game capture करें |
| `execute_editor_script` | Editor में arbitrary GDScript run करें |
| `clear_output` | Output panel clear करें |
| `get_signals` | Connections के साथ node के सभी signals पाएं |
| `reload_plugin` | MCP plugin reload करें (auto-reconnect) |
| `reload_project` | Filesystem rescan करें और scripts reload करें |
| `compare_screenshots` | दो screenshots compare करें |
| `set_auto_dismiss` | Blocking editor dialogs ("Reload from disk?" आदि) को auto-dismiss करें |
| `get_editor_camera` | 3D editor camera की position/rotation/FOV पाएं (4.6+ पर snap settings भी) |
| `set_editor_camera` | View frame करने के लिए 3D editor camera move करें |
| `get_unsaved_state` | Unsaved changes वाले open scenes/scripts report करें (unsaved lists के लिए Godot 4.7+ जरूरी) |
| `save_all` | सभी open scenes और modified script buffers save करें, क्या save हुआ यह report करें (scripts के लिए Godot 4.7+ जरूरी) |

### Input Tools (5)
| Tool | विवरण |
|------|-------------|
| `simulate_key` | Keyboard key press/release simulate करें |
| `simulate_mouse_click` | Position पर mouse click simulate करें |
| `simulate_mouse_move` | Mouse movement simulate करें |
| `simulate_action` | Godot Input Action simulate करें |
| `simulate_sequence` | Frame delays के साथ input events का sequence |

### Input Map Tools (2)
| Tool | विवरण |
|------|-------------|
| `get_input_actions` | सभी input actions list करें |
| `set_input_action` | Input action create/modify करें |

### Runtime Tools (20)
| Tool | विवरण |
|------|-------------|
| `get_game_scene_tree` | Running game का scene tree |
| `get_game_node_properties` | Running game में node properties |
| `set_game_node_property` | Running game में node property set करें |
| `execute_game_script` | Game context में GDScript run करें |
| `capture_frames` | Multi-frame screenshot capture |
| `record_frames` | कई frames को disk पर PNG files में record करें |
| `monitor_properties` | समय के साथ property values record करें |
| `watch_signals` | एक duration तक nodes पर signal emissions log करें |
| `start_recording` | Input recording शुरू करें |
| `stop_recording` | Input recording बंद करें |
| `replay_recording` | Recorded input replay करें |
| `find_nodes_by_script` | Script से game nodes खोजें |
| `get_autoload` | Autoload node properties पाएं |
| `find_ui_elements` | Game में UI elements खोजें |
| `click_button_by_text` | Text content से button click करें |
| `wait_for_node` | Node के appear होने का इंतजार करें |
| `find_nearby_nodes` | Position के पास nodes खोजें |
| `navigate_to` | Target position पर navigate करें |
| `move_to` | Character को target तक चलाएं |
| `batch_get_properties` | एक साथ कई node properties पाएं |

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
| `tilemap_set_cell` | एक tile cell set करें |
| `tilemap_fill_rect` | Rectangular region को tiles से भरें |
| `tilemap_get_cell` | Cell का tile data पाएं |
| `tilemap_clear` | सभी cells clear करें |
| `tilemap_get_info` | TileMapLayer info और tile set sources |
| `tilemap_get_used_cells` | Used cells की list |

### Theme & UI Tools (8)
| Tool | विवरण |
|------|-------------|
| `create_theme` | Theme resource file बनाएं |
| `set_theme_color` | Theme color override set करें |
| `set_theme_constant` | Theme constant override set करें |
| `set_theme_font_size` | Theme font size override set करें |
| `set_theme_stylebox` | StyleBoxFlat override set करें |
| `setup_control` | एक call में Control/Container layout configure करें |
| `add_virtual_joystick` | Input actions से bound on-screen VirtualJoystick add करें (Godot 4.7+) |
| `get_theme_info` | Theme overrides info पाएं |

### Profiling Tools (2)
| Tool | विवरण |
|------|-------------|
| `get_performance_monitors` | सभी performance monitors (FPS, memory, physics, etc.) |
| `get_editor_performance` | Quick performance summary |

### Batch & Refactoring Tools (7)
| Tool | विवरण |
|------|-------------|
| `find_nodes_by_type` | किसी type के सभी nodes खोजें |
| `find_signal_connections` | Scene में सभी signal connections खोजें |
| `batch_set_property` | किसी type के सभी nodes पर property set करें |
| `batch_add_nodes` | एक call में पूरा node tree add करें |
| `find_node_references` | Project files में pattern search करें |
| `get_scene_dependencies` | Resource dependencies पाएं |
| `cross_scene_set_property` | सभी scenes में property set करें |

### Shader Tools (6)
| Tool | विवरण |
|------|-------------|
| `create_shader` | Template के साथ shader बनाएं |
| `read_shader` | Shader file पढ़ें |
| `edit_shader` | Shader edit करें (replace/search-replace) |
| `assign_shader_material` | Node को ShaderMaterial assign करें |
| `set_shader_param` | Shader parameter set करें |
| `get_shader_params` | सभी shader parameters पाएं |

### Export Tools (4)
| Tool | विवरण |
|------|-------------|
| `list_export_presets` | Export presets list करें |
| `export_project` | Preset के लिए export command पाएं |
| `export_patch_pck` | दिए गए base packs के बाद बदली हुई files वाला patch PCK export करें |
| `get_export_info` | Export से जुड़ी project info |

### Resource Tools (4)
| Tool | विवरण |
|------|-------------|
| `read_resource` | .tres resource properties पढ़ें |
| `edit_resource` | Resource properties edit करें |
| `create_resource` | नया .tres resource बनाएं |
| `get_resource_preview` | Resource thumbnail पाएं |

### Physics Tools (6)
| Tool | विवरण |
|------|-------------|
| `setup_collision` | Nodes में collision shapes add करें |
| `set_physics_layers` | Collision layer/mask set करें |
| `get_physics_layers` | Collision layer/mask info पाएं |
| `add_raycast` | RayCast2D/3D node add करें |
| `setup_physics_body` | Physics body properties configure करें |
| `get_collision_info` | Collision shape details पाएं |

### 3D Scene Tools (7)
| Tool | विवरण |
|------|-------------|
| `add_mesh_instance` | Primitive mesh के साथ MeshInstance3D add करें |
| `setup_lighting` | Light nodes add/configure करें |
| `set_material_3d` | StandardMaterial3D properties set करें |
| `setup_environment` | WorldEnvironment configure करें |
| `setup_camera_3d` | Camera3D properties configure करें |
| `add_gridmap` | GridMap node set up करें |
| `get_gridmap_info` | GridMap inspect करें: MeshLibrary, bounds, per-item counts, filtered cells (4.7+ पर octant summary) |

### Particle Tools (5)
| Tool | विवरण |
|------|-------------|
| `create_particles` | GPUParticles2D/3D बनाएं |
| `set_particle_material` | ParticleProcessMaterial configure करें |
| `set_particle_color_gradient` | Particles के लिए color gradient set करें |
| `apply_particle_preset` | Preset apply करें (fire, smoke, sparks, etc.) |
| `get_particle_info` | Particle system details पाएं |

### Navigation Tools (5)
| Tool | विवरण |
|------|-------------|
| `setup_navigation_region` | NavigationRegion configure करें |
| `bake_navigation_mesh` | Navigation mesh bake करें |
| `setup_navigation_agent` | NavigationAgent configure करें |
| `set_navigation_layers` | Navigation layers set करें |
| `get_navigation_info` | Navigation setup info पाएं |

### Audio Tools (6)
| Tool | विवरण |
|------|-------------|
| `get_audio_bus_layout` | Audio bus layout info पाएं |
| `add_audio_bus` | Audio bus add करें |
| `set_audio_bus` | Audio bus properties configure करें |
| `add_audio_bus_effect` | Audio bus में effect add करें |
| `add_audio_player` | AudioStreamPlayer node add करें |
| `get_audio_info` | Audio से जुड़ी node info पाएं |

### AnimationTree Tools (9)
| Tool | विवरण |
|------|-------------|
| `create_animation_tree` | AnimationTree बनाएं |
| `get_animation_tree_structure` | Tree structure पाएं |
| `add_state_machine_state` | State machine में state add करें |
| `remove_state_machine_state` | State machine से state remove करें |
| `add_state_machine_transition` | States के बीच transition add करें |
| `remove_state_machine_transition` | State transition remove करें |
| `set_blend_tree_node` | Blend tree nodes configure करें |
| `set_tree_parameter` | AnimationTree parameter set करें |
| `setup_ik_modifier` | Skeleton3D पर IK SkeletonModifier3D (TwoBoneIK3D, CCDIK3D, FABRIK3D, ...) add और configure करें (Godot 4.6+) |

### Analysis & Search Tools (6)
| Tool | विवरण |
|------|-------------|
| `find_unused_resources` | Unreferenced resources खोजें |
| `analyze_signal_flow` | Signal connections map करें |
| `analyze_scene_complexity` | Scene performance analyze करें |
| `find_script_references` | Script/resource कहाँ use हुआ है, यह खोजें |
| `detect_circular_dependencies` | Circular scene dependencies खोजें |
| `get_project_statistics` | Project-wide statistics पाएं |

### Testing & QA Tools (6)
| Tool | विवरण |
|------|-------------|
| `run_test_scenario` | Automated test scenario run करें |
| `assert_node_state` | Node property values assert करें |
| `assert_screen_text` | Screen पर text check करें |
| `run_stress_test` | Performance stress test run करें |
| `set_game_speed` | Running game का Engine.time_scale पढ़ें/set करें (slow motion / fast-forward) |
| `get_test_report` | Test results report पाएं |

### Headless Tools (3)
| Tool | विवरण |
|------|-------------|
| `run_headless_scene` | अलग headless Godot process में scene run करें (जैसे किसी project का test suite) |
| `run_headless_script` | `godot --headless --script` से `extends SceneTree` script run करें |
| `get_godot_executable` | Editor के Godot binary का path, project path और platform |

### Android Tools (3)
| Tool | विवरण |
|------|-------------|
| `list_android_devices` | adb को दिखने वाले Android devices list करें |
| `get_android_preset_info` | Android export preset का package name/export path पढ़ें |
| `deploy_to_android` | APK export करें, adb से install करें और launch करें (Remote Deploy की तरह) |

## मुख्य Features

- **UndoRedo Integration**: सभी node/property operations Ctrl+Z support करते हैं
- **Smart Type Parsing**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` auto-convert होते हैं
- **Auto-Reconnect**: Exponential backoff reconnection (1s → 2s → 4s ... → 60s max)
- **Heartbeat**: 10s ping/pong connection को alive रखता है
- **Helpful Errors**: Error responses में next steps के लिए suggestions शामिल होते हैं

## Competitive Comparison

### Tool Count

| Category | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) | ee0pdt (free) | bradypp (free) |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Project | 10 | 5 | 4 | 0 | 2 | 2 | 2 |
| Scene | 10 | 8 | 11 | 9 | 3 | 4 | 5 |
| Node | **17** | 8 | 0 | 8 | 2 | 3 | 0 |
| Script | **9** | 5 | 6 | 4 | 0 | 5 | 0 |
| Editor | **15** | 5 | 1 | 5 | 1 | 3 | 2 |
| Input | **7** | 2 | 0 | 0 | 0 | 0 | 0 |
| Runtime | **20** | 0 | 0 | 0 | 0 | 0 | 0 |
| Animation | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| TileMap | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Theme/UI | **8** | 0 | 0 | 0 | 0 | 0 | 0 |
| Profiling | **2** | 0 | 0 | 0 | 0 | 0 | 0 |
| Batch/Refactor | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| Shader | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Export | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Resource | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Physics | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 3D Scene | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| Particle | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Navigation | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Audio | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| AnimationTree | **9** | 0 | 0 | 0 | 0 | 0 | 0 |
| Analysis | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Testing/QA | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Asset/AI | 0 | 0 | 1 | 6 | 0 | 0 | 0 |
| Material | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| Other | 0 | 0 | 9 | 5 | 5 | 2 | 1 |
| Headless | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Android Deploy | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **187** | ~30 | **32** | **39** | **13** | **19** | **10** |

### Feature Matrix

| Feature | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **Connection** | WebSocket (real-time) | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | हाँ | हाँ | नहीं | नहीं | नहीं |
| **JSON-RPC 2.0** | हाँ | Custom | Custom | Custom | N/A |
| **Auto-reconnect** | हाँ (exponential backoff) | N/A | नहीं | नहीं | N/A |
| **Heartbeat** | हाँ (10s ping/pong) | नहीं | नहीं | नहीं | नहीं |
| **Error suggestions** | हाँ (contextual hints) | नहीं | नहीं | नहीं | नहीं |
| **Screenshot capture** | हाँ (editor + game) | हाँ | नहीं | नहीं | नहीं |
| **Game input simulation** | हाँ (key/mouse/action/sequence) | हाँ (basic) | नहीं | नहीं | नहीं |
| **Runtime inspection** | हाँ (scene tree + properties + monitor) | नहीं | नहीं | नहीं | नहीं |
| **Signal management** | हाँ (connect/disconnect/inspect) | नहीं | नहीं | नहीं | नहीं |
| **Browser visualizer** | नहीं | नहीं | हाँ | नहीं | नहीं |
| **AI 3D mesh generation** | नहीं | नहीं | नहीं | हाँ (Meshy API) | नहीं |

### Exclusive Categories (किसी competitor के पास ये नहीं हैं)

| Category | Tools | यह क्यों मायने रखता है |
|----------|-------|----------------|
| **Animation** | 6 tools | Animations बनाएं, tracks add करें, keyframes set करें — सब programmatically |
| **TileMap** | 6 tools | Cells set करें, rects fill करें, tile data query करें — 2D level design के लिए जरूरी |
| **Theme/UI** | 8 tools | StyleBox, colors, fonts — manual editor work के बिना UI themes बनाएं |
| **Profiling** | 2 tools | FPS, memory, draw calls, physics — performance monitoring |
| **Batch/Refactor** | 7 tools | Type से खोजें, batch property changes, cross-scene updates, dependency analysis |
| **Shader** | 6 tools | Shaders create/edit करें, materials assign करें, parameters set करें |
| **Export** | 4 tools | Presets list करें, export commands पाएं, templates check करें |
| **Physics** | 6 tools | Collision shapes, bodies, raycasts और layer management set up करें |
| **3D Scene** | 7 tools | Meshes, cameras, lights, environment add करें, GridMap support |
| **Particle** | 5 tools | Custom materials, presets और gradients के साथ particles बनाएं |
| **Navigation** | 5 tools | Navigation regions, agents, pathfinding, baking configure करें |
| **Audio** | 6 tools | Complete audio bus system, effects, players, live management |
| **AnimationTree** | 9 tools | State machines, transitions, blend trees और IK modifiers |
| **Testing/QA** | 6 tools | Automated testing, assertions, stress testing, screenshot comparison |
| **Runtime** | 20 tools | Runtime पर game को inspect और control करें: inspect, record, replay, navigate |

### Architecture के फायदे

| Aspect | Godot MCP Pro | Typical Competitor |
|--------|--------------|-------------------|
| **Protocol** | JSON-RPC 2.0 (standard, extensible) | Custom JSON या CLI-based |
| **Connection** | Heartbeat के साथ persistent WebSocket | Per-command subprocess या raw TCP |
| **Reliability** | Exponential backoff के साथ auto-reconnect (1s→60s) | Manual reconnection जरूरी |
| **Type Safety** | Smart type parsing (Vector2, Color, Rect2, hex colors) | सिर्फ string या limited types |
| **Error Handling** | Codes + suggestions के साथ structured errors | Generic error messages |
| **Undo Support** | सभी mutations UndoRedo system से होकर जाते हैं | Direct modifications (undo नहीं) |
| **Port Management** | Ports 6505-6509 का auto-scan | Fixed port, conflicts संभव |

## License

Proprietary — details के लिए [LICENSE](../LICENSE) देखें। Purchase में lifetime updates शामिल हैं।
