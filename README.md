# Godot MCP Pro

**147 AI-powered tools** connecting Claude, Cursor, and other AI assistants directly to your Godot 4 editor.

[![Buy on Buy Me a Coffee](https://img.shields.io/badge/Buy-$5_one--time-478cbf?style=for-the-badge)](https://buymeacoffee.com/y1uda/e/512940)
[![Website](https://img.shields.io/badge/Website-godot--mcp.abyo.net-478cbf?style=for-the-badge)](https://godot-mcp.abyo.net/)

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
- [Issues & Feature Requests](https://github.com/youichi-uda/godot-mcp-pro/issues)

## License

Proprietary. One-time purchase includes lifetime updates for v1.x. Unlimited projects and machines.
