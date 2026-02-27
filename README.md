# Godot MCP Pro

**147 AI-powered tools** connecting Claude, Cursor, and other AI assistants directly to your Godot 4 editor.

[![Buy on Buy Me a Coffee](https://img.shields.io/badge/Buy-$5_one--time-478cbf?style=for-the-badge)](https://buymeacoffee.com/y1uda/e/512940)
[![Website](https://img.shields.io/badge/Website-godot--mcp.abyo.net-478cbf?style=for-the-badge)](https://godot-mcp.abyo.net/)
[![Discord](https://img.shields.io/badge/Discord-Support-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/F4gR739y)

## Demo: AI Builds a Reversi Game from Scratch

> One prompt → AI creates the scene, writes GDScript, launches the game, and play-tests it with mouse clicks.

https://github.com/user-attachments/assets/30dc19c6-e4d6-43e8-9961-ed902f5951d9

[Watch the full 5-minute demo on YouTube](https://www.youtube.com/watch?v=0h2u6mMBm-Q)

## Architecture

```
AI Assistant <--stdio/MCP--> Node.js Server <--WebSocket:6505--> Godot Editor Plugin
```

Real-time bidirectional communication. No file polling. No CLI subprocess spawning.

## 147 Tools across 23 Categories

| Category | Tools | Highlights |
|----------|:-----:|------------|
| **Project** | 7 | Read/write project settings, file search, UID conversion |
| **Scene** | 9 | Live scene tree, create/open/delete, play/stop, instancing |
| **Node** | 11 | Add/delete/rename/duplicate/move, properties, signals, anchors |
| **Script** | 6 | List/read/create/edit scripts, attach to nodes |
| **Editor** | 9 | Screenshots, visual diff, GDScript execution, error log, signals inspector |
| **Input Simulation** | 5 | Keyboard, mouse, InputAction, multi-event sequences |
| **Runtime Analysis** | 15 | Game scene tree, runtime properties, frame capture, input recording/replay, UI element detection, click buttons by text, wait for nodes |
| **Animation** | 6 | Create animations, add tracks, insert keyframes programmatically |
| **AnimationTree** | 8 | State machines, transitions with conditions, blend trees, tree parameters |
| **TileMap** | 6 | Set/fill/query cells, tile set info, bulk operations |
| **3D Scene** | 6 | Mesh primitives & .glb/.gltf import, lighting presets, PBR materials, environment (sky/fog/SSAO/SSR), cameras, GridMap |
| **Physics** | 6 | Collision shapes (auto 2D/3D), physics layers/masks, raycasts, body configuration |
| **Particles** | 5 | GPU particles 2D/3D, material config, color gradients, presets (fire/smoke/rain/snow/sparks) |
| **Navigation** | 5 | Navigation regions, mesh baking, pathfinding agents, layer management |
| **Audio** | 6 | Audio bus layout, effects (reverb/delay/compressor/EQ), 2D/3D players |
| **Theme & UI** | 6 | Colors, constants, font sizes, StyleBoxFlat, theme inspector |
| **Shader** | 6 | Create/edit shaders, assign materials, set/get uniforms |
| **Resource** | 3 | Read/edit/create .tres resource files of any type |
| **Batch & Refactoring** | 6 | Find by type, signal audit, batch property set, cross-scene changes, dependency analysis |
| **Testing & QA** | 5 | Automated test scenarios, property assertions, screen text verification, stress testing, test reports |
| **Code Analysis** | 6 | Unused resource detection, signal flow mapping, scene complexity, circular dependency detection, project statistics |
| **Profiling** | 2 | FPS, memory, draw calls, physics monitors |
| **Export** | 3 | List presets, export commands, template info |

## Key Features

- **Full Undo/Redo** - All mutations go through Godot's UndoRedo system
- **Smart Type Parsing** - `"Vector2(100,200)"`, `"#ff0000"`, `"Color(1,0,0)"` auto-converted
- **Auto-Reconnect** - Exponential backoff (1s -> 60s max)
- **Heartbeat** - 10s ping/pong keeps connection alive
- **Contextual Errors** - Structured error codes with actionable suggestions
- **Port Auto-Scan** - Tries ports 6505-6509, no configuration needed
- **Input Recording & Replay** - Record test sessions, replay for regression testing
- **Visual Diff** - Compare screenshots pixel-by-pixel for visual regression testing
- **2D and 3D Support** - Full tooling for both 2D and 3D game development

## Comparison

| | Godot MCP Pro | Best Free Alternative |
|---|:---:|:---:|
| **Total Tools** | **147** | 32 |
| **Categories** | **23** | ~4 |
| **Undo/Redo** | Yes | No |
| **Signal Management** | Yes | No |
| **Input Simulation** | Key/Mouse/Action/Sequence + Recording | No |
| **Runtime Inspection** | 15 tools (tree, props, frames, UI, recording) | No |
| **3D Scene Tools** | Mesh, Lighting, PBR, Environment, Camera | No |
| **Physics Setup** | Collision, Layers, Raycasts, Bodies | No |
| **Particles** | GPU 2D/3D with presets | No |
| **Navigation** | Region, Mesh baking, Agent | No |
| **Audio** | Buses, Effects, Players | No |
| **AnimationTree** | State machine, Blend tree | No |
| **Animation Tools** | Yes | No |
| **TileMap Tools** | Yes | No |
| **Shader Tools** | Yes | No |
| **Testing & QA** | Scenarios, Assertions, Stress test | No |
| **Code Analysis** | Unused resources, Signal flow, Complexity | No |
| **Profiling** | Yes | No |

## Plugin Architecture

The Godot editor plugin (`addons/godot_mcp/`) is the bridge between the MCP server and the Godot editor. It runs a WebSocket server inside the editor, receives commands from the MCP server, executes them using Godot's editor APIs, and returns results.

```
addons/godot_mcp/
├── plugin.gd                  # EditorPlugin entry point - registers autoloads, starts WebSocket
├── plugin.cfg                 # Plugin metadata (name, version, description)
├── websocket_server.gd        # WebSocket server (port 6505-6509) - handles connections, routing
├── command_router.gd          # Routes incoming commands to the correct command handler
│
├── commands/                  # 23 command handler modules (one per tool category)
│   ├── base_command.gd        # Base class - provides success/error helpers, type parsing
│   ├── project_commands.gd    # Project settings, file search, UID conversion
│   ├── scene_commands.gd      # Scene tree, create/open/delete, play/stop
│   ├── node_commands.gd       # Node CRUD, properties, signals, anchors
│   ├── script_commands.gd     # Script list/read/create/edit, attach to nodes
│   ├── editor_commands.gd     # Screenshots, visual diff, GDScript execution, error log
│   ├── input_commands.gd      # Keyboard, mouse, InputAction simulation
│   ├── runtime_commands.gd    # Game scene tree, runtime props, frame capture, UI detection
│   ├── animation_commands.gd  # Animation creation, tracks, keyframes
│   ├── animation_tree_commands.gd  # State machines, blend trees, transitions
│   ├── tilemap_commands.gd    # Cell operations, tile set info
│   ├── scene_3d_commands.gd   # Mesh, lighting, PBR materials, environment, cameras
│   ├── physics_commands.gd    # Collision shapes, physics layers, raycasts
│   ├── particle_commands.gd   # GPU particles 2D/3D, presets
│   ├── navigation_commands.gd # Navigation regions, mesh baking, agents
│   ├── audio_commands.gd      # Audio buses, effects, players
│   ├── theme_commands.gd      # Theme colors, constants, font sizes, StyleBox
│   ├── shader_commands.gd     # Shader create/edit, uniforms, material assignment
│   ├── resource_commands.gd   # Generic .tres resource read/edit/create
│   ├── batch_commands.gd      # Find by type, batch property set, cross-scene changes
│   ├── test_commands.gd       # Automated test scenarios, assertions, stress testing
│   ├── analysis_commands.gd   # Unused resources, signal flow, complexity analysis
│   ├── export_commands.gd     # Export presets, export commands
│   └── profiling_commands.gd  # Performance monitors (FPS, memory, draw calls)
│
├── utils/
│   ├── node_utils.gd          # Node path resolution, scene tree traversal helpers
│   └── property_parser.gd     # Smart type parsing (Vector2, Color, etc. from strings)
│
├── ui/
│   ├── status_panel.gd        # Connection status indicator in editor dock
│   └── status_panel.tscn      # Status panel scene
│
├── mcp_game_inspector_service.gd  # Autoload: runtime scene tree inspection during play
├── mcp_screenshot_service.gd      # Autoload: captures screenshots during play
└── mcp_input_service.gd           # Autoload: injects input events during play
```

### How It Works

1. **Plugin activation** (`plugin.gd`): Registers 3 autoloads (GameInspector, Screenshot, InputService) and starts the WebSocket server
2. **Connection** (`websocket_server.gd`): Listens on ports 6505-6509, maintains heartbeat (10s ping/pong), auto-reconnects with exponential backoff
3. **Command routing** (`command_router.gd`): Parses incoming JSON commands and dispatches to the appropriate command handler
4. **Command execution** (`commands/*.gd`): Each handler extends `BaseCommand`, which provides utilities like `success()`, `error()`, UndoRedo integration, and smart type parsing
5. **Runtime tools** (autoload services): Three autoloads are injected into the running game to enable runtime inspection, screenshots, and input simulation without modifying the user's project code

### Key Design Decisions

- **All mutations use UndoRedo**: Every change to the scene tree goes through Godot's `EditorUndoRedoManager`, ensuring full undo/redo support
- **Smart type parsing**: String values like `"Vector2(100,200)"`, `"#ff0000"`, `"Color(1,0,0,0.5)"` are automatically converted to native Godot types
- **No project modification**: The 3 autoloads are registered/unregistered by the plugin at editor startup/shutdown — they don't appear in `project.godot`
- **Port scanning**: The server tries ports 6505-6509 sequentially, allowing multiple Godot instances to run simultaneously

## Requirements

- Godot 4.4+ (tested on 4.6)
- Node.js 18+
- Any MCP-compatible AI client (Claude Code, Claude Desktop, Cursor, VS Code + Cline, Windsurf, etc.)

## Installation

1. **Download** from [Buy Me a Coffee](https://buymeacoffee.com/y1uda/e/512940) ($5 one-time, lifetime updates for v1.x)
2. **Copy** `addons/godot_mcp/` into your Godot project
3. **Enable** the plugin: Project > Project Settings > Plugins > Godot MCP Pro
4. **Install** the MCP server:
   ```bash
   cd server
   npm install
   npm run build
   ```
5. **Configure** your AI client's `.mcp.json`:
   ```json
   {
     "mcpServers": {
       "godot-mcp-pro": {
         "command": "node",
         "args": ["/path/to/server/build/index.js"]
       }
     }
   }
   ```
6. **Use it** - Open Godot with the plugin enabled, then interact via your AI assistant

## Links

- [Website](https://godot-mcp.abyo.net/)
- [Buy ($5)](https://buymeacoffee.com/y1uda/e/512940)
- [Discord](https://discord.gg/F4gR739y)
- [Issues & Feature Requests](https://github.com/youichi-uda/godot-mcp-pro/issues)

## License

Proprietary. One-time purchase includes lifetime updates for v1.x. Unlimited projects and machines.
