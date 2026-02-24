# Godot MCP Pro

**84 AI-powered tools** connecting Claude, Cursor, and other AI assistants directly to your Godot editor.

[![Buy on Buy Me a Coffee](https://img.shields.io/badge/Buy-$5_one--time-478cbf?style=for-the-badge)](https://buymeacoffee.com/y1uda/e/512940)
[![Website](https://img.shields.io/badge/Website-godot--mcp.abyo.net-478cbf?style=for-the-badge)](https://godot-mcp.abyo.net/)

## Architecture

```
AI Assistant <--stdio/MCP--> Node.js Server <--WebSocket:6505--> Godot Editor Plugin
```

Real-time bidirectional communication. No file polling. No CLI subprocess spawning.

## 84 Tools across 14 Categories

| Category | Tools | Highlights |
|----------|:-----:|------------|
| **Project** | 7 | Read/write project settings, file search, UID conversion |
| **Scene** | 9 | Live scene tree, create/open/delete, play/stop, instancing |
| **Node** | 11 | Add/delete/rename/duplicate/move, properties, signals, anchors |
| **Script** | 6 | List/read/create/edit scripts, attach to nodes |
| **Editor** | 8 | Screenshots, GDScript execution, error log, signals inspector |
| **Input Simulation** | 5 | Keyboard, mouse, InputAction, multi-event sequences |
| **Runtime Analysis** | 4 | Game scene tree, runtime properties, frame capture, property monitor |
| **Animation** | 6 | Create animations, add tracks, insert keyframes programmatically |
| **TileMap** | 6 | Set/fill/query cells, tile set info, bulk operations |
| **Theme & UI** | 6 | Colors, constants, font sizes, StyleBoxFlat, theme inspector |
| **Shader** | 6 | Create/edit shaders, assign materials, set/get uniforms |
| **Batch & Refactoring** | 5 | Find by type, signal audit, batch property set, dependency analysis |
| **Profiling** | 2 | FPS, memory, draw calls, physics monitors |
| **Export** | 3 | List presets, export commands, template info |

## Key Features

- **Full Undo/Redo** - All mutations go through Godot's UndoRedo system
- **Smart Type Parsing** - `"Vector2(100,200)"`, `"#ff0000"`, `"Color(1,0,0)"` auto-converted
- **Auto-Reconnect** - Exponential backoff (1s -> 60s max)
- **Heartbeat** - 10s ping/pong keeps connection alive
- **Contextual Errors** - Structured error codes with actionable suggestions
- **Port Auto-Scan** - Tries ports 6505-6509, no configuration needed

## Comparison

| | Godot MCP Pro | Best Free Alternative |
|---|:---:|:---:|
| **Total Tools** | **84** | 32 |
| **Undo/Redo** | Yes | No |
| **Signal Management** | Yes | No |
| **Input Simulation** | Key/Mouse/Action/Sequence | No |
| **Runtime Inspection** | Scene tree + Properties + Frames | No |
| **Animation Tools** | Yes | No |
| **TileMap Tools** | Yes | No |
| **Shader Tools** | Yes | No |
| **Profiling** | Yes | No |

## Requirements

- Godot 4.4+ (tested on 4.6)
- Node.js 18+
- Any MCP-compatible AI client (Claude Code, Claude Desktop, Cursor, VS Code + Cline, etc.)

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
