> **Language:** [English](../README.md) | [日本語](README.ja.md) | [Português (BR)](README.pt-br.md) | [Español](README.es.md) | [Русский](README.ru.md) | 简体中文 | [हिन्दी](README.hi.md)

# Godot MCP Pro

用于 AI 驱动 Godot 游戏开发的高级 MCP（Model Context Protocol）服务器。将 Claude 等 AI 助手直接连接到你的 Godot 编辑器，提供 **187 个强大工具**。

## 架构

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **实时**：WebSocket 连接带来即时反馈，无需轮询文件
- **编辑器集成**：完整访问 Godot 编辑器 API、UndoRedo 系统和场景树
- **JSON-RPC 2.0**：标准协议，提供规范的错误码和建议

## 本仓库包含的内容

> ⚠️ **本公开仓库仅包含免费的 Godot 插件（addon/plugin）。** MCP 服务器（Node.js，连接 AI 助手所必需）作为付费套件的一部分分发 — **一次性购买**，终身更新：
>
> - **Buy Me a Coffee**: <https://buymeacoffee.com/y1uda/extras>
> - **itch.io**: <https://y1uda.itch.io/godot-mcp-pro>
>
> 付费 zip 包含插件、带有预构建 JavaScript 的 `server/` 目录、`INSTALL.md` 以及 AI 客户端使用说明。如果你克隆了本仓库却没有看到 `server/` 文件夹，**这是正常的** — 请从上面的链接之一获取完整套件。

## 快速开始

### 1. 安装 Godot 插件

将 `addons/godot_mcp/` 文件夹复制到你的 Godot 项目的 `addons/` 目录中。

启用插件：**Project → Project Settings → Plugins → Godot MCP Pro → Enable**

### 2. 安装 MCP 服务器

> `server/` 目录仅包含在**完整付费套件**中（见上文）。下载并解压 zip 后，运行：

```bash
cd server
npm install
npm run build
```

### 3. 配置 Claude Code

添加到你的 `.mcp.json`：

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

### 4. 选择模式

Godot MCP Pro 提供四种模式，以适应各客户端的工具数量限制：

| 模式 | 工具数 | 最适合 |
|------|-------|----------|
| **Full**（默认） | 187 | Claude Code, Cline, VS Code Copilot, Cursor |
| **3D** (`--3d`) | 100 | Antigravity 及其他需要 3D 功能的 100 工具上限客户端 |
| **Lite** (`--lite`) | 88 | Windsurf, JetBrains Junie, Gemini CLI |
| **Minimal** (`--minimal`) | 35 | OpenCode、上下文较小的本地 LLM |

`--3d` 包含核心工具以及物理、AnimationTree 和导航工具，但省略了 `uid_to_project_path`、`project_path_to_uid`、`compare_screenshots`、`clear_output`、`close_script`、`reload_open_scripts`、`set_anchor_preset` 和 `click_button_by_text`，以保持在 100 个工具的上限内。

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

将 `--lite` 替换为 `--minimal` 可获得最小的占用。

- **Lite** 包含：project、scene、node、script、editor、input、runtime 和 input_map 工具。
- **Minimal** 包含：35 个核心工具 — 项目信息、场景管理、节点 CRUD、脚本编辑、编辑器错误、输入模拟和运行时检查。

### 5. CLI 模式（MCP 的替代方案）

对于不支持 MCP 的客户端，或希望零上下文开销时，可以直接从终端/bash 工具使用 CLI。CLI 需要先构建服务器（第 2 步）。

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

将 `/path/to/` 替换为你解压文件的实际路径。

CLI 通过 WebSocket 直接连接到 Godot 编辑器插件。需要：
- Godot 编辑器正在运行且已启用 MCP 插件
- 服务器已构建（`node build/setup.js install`）
- 6510-6514 范围内有可用端口

**优势**：LLM 通过 `--help` 逐步发现功能，而不是预先加载所有工具定义。这适用于任何具有终端访问能力的 LLM 客户端，不受工具数量限制影响。

### 6. 客户端兼容性

| 客户端 | 推荐模式 | 备注 |
|--------|-----------------|-------|
| Claude Code | Full（默认） | 延迟加载工具 — 上下文开销极小 |
| VS Code Copilot | Full | Virtual Tools 自动对工具分组 |
| OpenAI Codex CLI | Full | MCPSearch 延迟加载超出部分 |
| Cline | Full | 无硬性限制；使用 `enabledTools` 设置白名单 |
| Roo Code | Full | 无硬性限制 |
| Windsurf | Lite | 100 个工具上限 |
| JetBrains Junie | Lite | 100 个工具上限 |
| Gemini CLI | Lite | 客户端上限约 100；使用 `excludeTools` 进行更精细的控制 |
| Cursor | Full | 已取消工具上限（Dynamic Context Discovery） |
| OpenCode | Minimal 或 CLI | 超过约 40 个工具后模型表现下降 |
| 本地 LLM（LM Studio 等） | Minimal 或 CLI | 上下文窗口是瓶颈 |

### 7. 开始使用

在启用插件的状态下打开你的 Godot 项目，然后使用 Claude Code 与编辑器交互。

## 全部 187 个工具

### 项目工具 (10)
| 工具 | 描述 |
|------|-------------|
| `get_project_info` | 项目元数据、版本、视口、自动加载 |
| `get_filesystem_tree` | 带过滤的递归文件树 |
| `search_files` | 模糊/glob 文件搜索 |
| `search_in_files` | 在项目文件中搜索内容 |
| `get_project_settings` | 读取 project.godot 设置 |
| `set_project_setting` | 通过编辑器 API 设置项目设置 |
| `uid_to_project_path` | UID → res:// 转换 |
| `project_path_to_uid` | res:// → UID 转换 |
| `add_autoload` | 注册自动加载单例 |
| `remove_autoload` | 移除自动加载单例 |

### 场景工具 (10)
| 工具 | 描述 |
|------|-------------|
| `get_scene_tree` | 带层级结构的实时场景树 |
| `get_scene_file_content` | .tscn 文件原始内容 |
| `create_scene` | 创建新场景文件 |
| `open_scene` | 在编辑器中打开场景 |
| `delete_scene` | 删除场景文件 |
| `add_scene_instance` | 将场景实例化为子节点 |
| `play_scene` | 运行场景（main/current/custom） |
| `stop_scene` | 停止正在运行的场景 |
| `save_scene` | 将当前场景保存到磁盘 |
| `get_scene_exports` | 列出场景文件中所有带脚本节点的 @export 变量 |

### 节点工具 (17)
| 工具 | 描述 |
|------|-------------|
| `add_node` | 按类型和属性添加节点 |
| `delete_node` | 删除节点（支持撤销） |
| `duplicate_node` | 复制节点及其子节点 |
| `move_node` | 移动/重设父节点 |
| `update_property` | 设置任意属性（自动类型解析） |
| `get_node_properties` | 获取节点的所有属性 |
| `add_resource` | 为节点添加 Shape/Material 等 |
| `set_anchor_preset` | 设置 Control 锚点预设 |
| `rename_node` | 重命名场景中的节点 |
| `connect_signal` | 连接节点之间的信号 |
| `disconnect_signal` | 断开信号连接 |
| `get_node_groups` | 获取节点所属的分组 |
| `set_node_groups` | 设置节点的分组成员关系 |
| `find_nodes_in_group` | 查找分组中的所有节点 |
| `get_editor_selection` | 获取 Scene 面板中选中的节点 |
| `select_nodes` | 在 Scene 面板中选中节点（可选聚焦/检查） |
| `clear_editor_selection` | 清除 Scene 面板中的选择 |

### 脚本工具 (9)
| 工具 | 描述 |
|------|-------------|
| `list_scripts` | 列出所有脚本及类信息 |
| `read_script` | 读取脚本内容 |
| `create_script` | 使用模板创建新脚本 |
| `edit_script` | 搜索/替换或完整编辑 |
| `attach_script` | 将脚本附加到节点 |
| `validate_script` | 验证 GDScript 语法 |
| `close_script` | 关闭脚本编辑器标签页；有未保存修改时拒绝关闭，除非明确要求丢弃（Godot 4.7+） |
| `reload_open_scripts` | 从磁盘重新加载已打开的脚本，保留未保存的缓冲区（Godot 4.7+） |
| `get_open_scripts` | 列出编辑器中已打开的脚本 |

### 编辑器工具 (15)
| 工具 | 描述 |
|------|-------------|
| `get_editor_errors` | 获取错误和堆栈跟踪 |
| `get_output_log` | 获取输出面板内容 |
| `get_editor_screenshot` | 截取编辑器视口 |
| `get_game_screenshot` | 截取运行中的游戏 |
| `execute_editor_script` | 在编辑器中运行任意 GDScript |
| `clear_output` | 清空输出面板 |
| `get_signals` | 获取节点的所有信号及其连接 |
| `reload_plugin` | 重新加载 MCP 插件（自动重连） |
| `reload_project` | 重新扫描文件系统并重新加载脚本 |
| `compare_screenshots` | 比较两张截图 |
| `set_auto_dismiss` | 自动关闭阻塞性的编辑器对话框（"Reload from disk?" 等） |
| `get_editor_camera` | 获取 3D 编辑器相机的位置/旋转/FOV（4.6+ 还包括吸附设置） |
| `set_editor_camera` | 移动 3D 编辑器相机以框选视图 |
| `get_unsaved_state` | 报告有未保存更改的已打开场景/脚本（未保存列表需要 Godot 4.7+） |
| `save_all` | 保存所有已打开的场景和已修改的脚本缓冲区，并报告保存内容（脚本需要 Godot 4.7+） |

### 输入工具 (5)
| 工具 | 描述 |
|------|-------------|
| `simulate_key` | 模拟键盘按键按下/释放 |
| `simulate_mouse_click` | 在指定位置模拟鼠标点击 |
| `simulate_mouse_move` | 模拟鼠标移动 |
| `simulate_action` | 模拟 Godot Input Action |
| `simulate_sequence` | 带帧延迟的输入事件序列 |

### 输入映射工具 (2)
| 工具 | 描述 |
|------|-------------|
| `get_input_actions` | 列出所有输入动作 |
| `set_input_action` | 创建/修改输入动作 |

### 运行时工具 (20)
| 工具 | 描述 |
|------|-------------|
| `get_game_scene_tree` | 运行中游戏的场景树 |
| `get_game_node_properties` | 运行中游戏的节点属性 |
| `set_game_node_property` | 在运行中游戏里设置节点属性 |
| `execute_game_script` | 在游戏上下文中运行 GDScript |
| `capture_frames` | 多帧截图捕获 |
| `record_frames` | 将大量帧录制为磁盘上的 PNG 文件 |
| `monitor_properties` | 随时间记录属性值 |
| `watch_signals` | 在一段时间内记录节点的信号发射 |
| `start_recording` | 开始录制输入 |
| `stop_recording` | 停止录制输入 |
| `replay_recording` | 回放录制的输入 |
| `find_nodes_by_script` | 按脚本查找游戏节点 |
| `get_autoload` | 获取自动加载节点的属性 |
| `find_ui_elements` | 查找游戏中的 UI 元素 |
| `click_button_by_text` | 按文本内容点击按钮 |
| `wait_for_node` | 等待节点出现 |
| `find_nearby_nodes` | 查找指定位置附近的节点 |
| `navigate_to` | 导航到目标位置 |
| `move_to` | 让角色走到目标位置 |
| `batch_get_properties` | 批量获取多个节点的属性 |

### 动画工具 (6)
| 工具 | 描述 |
|------|-------------|
| `list_animations` | 列出 AnimationPlayer 中的所有动画 |
| `create_animation` | 创建新动画 |
| `add_animation_track` | 添加轨道（value/position/rotation/method/bezier） |
| `set_animation_keyframe` | 向轨道插入关键帧 |
| `get_animation_info` | 包含所有轨道/关键帧的详细动画信息 |
| `remove_animation` | 移除动画 |

### TileMap 工具 (6)
| 工具 | 描述 |
|------|-------------|
| `tilemap_set_cell` | 设置单个图块单元格 |
| `tilemap_fill_rect` | 用图块填充矩形区域 |
| `tilemap_get_cell` | 获取单元格的图块数据 |
| `tilemap_clear` | 清除所有单元格 |
| `tilemap_get_info` | TileMapLayer 信息和 tile set 源 |
| `tilemap_get_used_cells` | 已使用单元格列表 |

### 主题 & UI 工具 (8)
| 工具 | 描述 |
|------|-------------|
| `create_theme` | 创建 Theme 资源文件 |
| `set_theme_color` | 设置主题颜色覆盖 |
| `set_theme_constant` | 设置主题常量覆盖 |
| `set_theme_font_size` | 设置主题字体大小覆盖 |
| `set_theme_stylebox` | 设置 StyleBoxFlat 覆盖 |
| `setup_control` | 一次调用配置 Control/Container 布局 |
| `add_virtual_joystick` | 添加绑定到输入动作的屏幕 VirtualJoystick（Godot 4.7+） |
| `get_theme_info` | 获取主题覆盖信息 |

### 性能分析工具 (2)
| 工具 | 描述 |
|------|-------------|
| `get_performance_monitors` | 所有性能监视器（FPS、内存、物理等） |
| `get_editor_performance` | 快速性能摘要 |

### 批量 & 重构工具 (7)
| 工具 | 描述 |
|------|-------------|
| `find_nodes_by_type` | 查找某类型的所有节点 |
| `find_signal_connections` | 查找场景中的所有信号连接 |
| `batch_set_property` | 为某类型的所有节点设置属性 |
| `batch_add_nodes` | 一次调用添加整棵节点树 |
| `find_node_references` | 在项目文件中搜索模式 |
| `get_scene_dependencies` | 获取资源依赖 |
| `cross_scene_set_property` | 跨所有场景设置属性 |

### 着色器工具 (6)
| 工具 | 描述 |
|------|-------------|
| `create_shader` | 使用模板创建着色器 |
| `read_shader` | 读取着色器文件 |
| `edit_shader` | 编辑着色器（替换/搜索替换） |
| `assign_shader_material` | 为节点分配 ShaderMaterial |
| `set_shader_param` | 设置着色器参数 |
| `get_shader_params` | 获取所有着色器参数 |

### 导出工具 (4)
| 工具 | 描述 |
|------|-------------|
| `list_export_presets` | 列出导出预设 |
| `export_project` | 获取预设的导出命令 |
| `export_patch_pck` | 导出仅包含相对于指定基础包有变更文件的补丁 PCK |
| `get_export_info` | 导出相关的项目信息 |

### 资源工具 (4)
| 工具 | 描述 |
|------|-------------|
| `read_resource` | 读取 .tres 资源属性 |
| `edit_resource` | 编辑资源属性 |
| `create_resource` | 创建新的 .tres 资源 |
| `get_resource_preview` | 获取资源缩略图 |

### 物理工具 (6)
| 工具 | 描述 |
|------|-------------|
| `setup_collision` | 为节点添加碰撞形状 |
| `set_physics_layers` | 设置碰撞层/掩码 |
| `get_physics_layers` | 获取碰撞层/掩码信息 |
| `add_raycast` | 添加 RayCast2D/3D 节点 |
| `setup_physics_body` | 配置物理体属性 |
| `get_collision_info` | 获取碰撞形状详情 |

### 3D 场景工具 (7)
| 工具 | 描述 |
|------|-------------|
| `add_mesh_instance` | 添加带基本网格的 MeshInstance3D |
| `setup_lighting` | 添加/配置灯光节点 |
| `set_material_3d` | 设置 StandardMaterial3D 属性 |
| `setup_environment` | 配置 WorldEnvironment |
| `setup_camera_3d` | 配置 Camera3D 属性 |
| `add_gridmap` | 设置 GridMap 节点 |
| `get_gridmap_info` | 检查 GridMap：MeshLibrary、边界、各项计数、过滤后的单元格（4.7+ 提供 octant 摘要） |

### 粒子工具 (5)
| 工具 | 描述 |
|------|-------------|
| `create_particles` | 创建 GPUParticles2D/3D |
| `set_particle_material` | 配置 ParticleProcessMaterial |
| `set_particle_color_gradient` | 设置粒子颜色渐变 |
| `apply_particle_preset` | 应用预设（火焰、烟雾、火花等） |
| `get_particle_info` | 获取粒子系统详情 |

### 导航工具 (5)
| 工具 | 描述 |
|------|-------------|
| `setup_navigation_region` | 配置 NavigationRegion |
| `bake_navigation_mesh` | 烘焙导航网格 |
| `setup_navigation_agent` | 配置 NavigationAgent |
| `set_navigation_layers` | 设置导航层 |
| `get_navigation_info` | 获取导航设置信息 |

### 音频工具 (6)
| 工具 | 描述 |
|------|-------------|
| `get_audio_bus_layout` | 获取音频总线布局信息 |
| `add_audio_bus` | 添加音频总线 |
| `set_audio_bus` | 配置音频总线属性 |
| `add_audio_bus_effect` | 为音频总线添加效果 |
| `add_audio_player` | 添加 AudioStreamPlayer 节点 |
| `get_audio_info` | 获取音频相关节点信息 |

### AnimationTree 工具 (9)
| 工具 | 描述 |
|------|-------------|
| `create_animation_tree` | 创建 AnimationTree |
| `get_animation_tree_structure` | 获取树结构 |
| `add_state_machine_state` | 向状态机添加状态 |
| `remove_state_machine_state` | 从状态机移除状态 |
| `add_state_machine_transition` | 添加状态之间的过渡 |
| `remove_state_machine_transition` | 移除状态过渡 |
| `set_blend_tree_node` | 配置混合树节点 |
| `set_tree_parameter` | 设置 AnimationTree 参数 |
| `setup_ik_modifier` | 在 Skeleton3D 上添加并配置 IK SkeletonModifier3D（TwoBoneIK3D、CCDIK3D、FABRIK3D 等）（Godot 4.6+） |

### 分析 & 搜索工具 (6)
| 工具 | 描述 |
|------|-------------|
| `find_unused_resources` | 查找未被引用的资源 |
| `analyze_signal_flow` | 映射信号连接 |
| `analyze_scene_complexity` | 分析场景性能 |
| `find_script_references` | 查找脚本/资源的使用位置 |
| `detect_circular_dependencies` | 查找场景循环依赖 |
| `get_project_statistics` | 获取项目整体统计信息 |

### 测试 & QA 工具 (6)
| 工具 | 描述 |
|------|-------------|
| `run_test_scenario` | 运行自动化测试场景 |
| `assert_node_state` | 断言节点属性值 |
| `assert_screen_text` | 检查屏幕上的文本 |
| `run_stress_test` | 运行性能压力测试 |
| `set_game_speed` | 读取/设置运行中游戏的 Engine.time_scale（慢动作 / 快进） |
| `get_test_report` | 获取测试结果报告 |

### Headless 工具 (3)
| 工具 | 描述 |
|------|-------------|
| `run_headless_scene` | 在独立的 headless Godot 进程中运行场景（例如项目的测试套件） |
| `run_headless_script` | 使用 `godot --headless --script` 运行 `extends SceneTree` 脚本 |
| `get_godot_executable` | 编辑器的 Godot 可执行文件路径、项目路径和平台 |

### Android 工具 (3)
| 工具 | 描述 |
|------|-------------|
| `list_android_devices` | 列出 adb 可见的 Android 设备 |
| `get_android_preset_info` | 读取 Android 导出预设的包名/导出路径 |
| `deploy_to_android` | 导出 APK、通过 adb 安装并启动（类似 Remote Deploy） |

## 主要特性

- **UndoRedo 集成**：所有节点/属性操作都支持 Ctrl+Z
- **智能类型解析**：`"Vector2(100, 200)"`、`"#ff0000"`、`"Color(1,0,0)"` 自动转换
- **自动重连**：指数退避重连（1s → 2s → 4s ... → 60s max）
- **心跳**：10s 的 ping/pong 保持连接存活
- **友好的错误信息**：错误响应包含后续步骤建议

## 竞品对比

### 工具数量

| 类别 | Godot MCP Pro | GDAI MCP ($19) | tomyud1（免费） | Dokujaa（免费） | Coding-Solo（免费） | ee0pdt（免费） | bradypp（免费） |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 项目 | 10 | 5 | 4 | 0 | 2 | 2 | 2 |
| 场景 | 10 | 8 | 11 | 9 | 3 | 4 | 5 |
| 节点 | **17** | 8 | 0 | 8 | 2 | 3 | 0 |
| 脚本 | **9** | 5 | 6 | 4 | 0 | 5 | 0 |
| 编辑器 | **15** | 5 | 1 | 5 | 1 | 3 | 2 |
| 输入 | **7** | 2 | 0 | 0 | 0 | 0 | 0 |
| 运行时 | **20** | 0 | 0 | 0 | 0 | 0 | 0 |
| 动画 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| TileMap | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 主题/UI | **8** | 0 | 0 | 0 | 0 | 0 | 0 |
| 性能分析 | **2** | 0 | 0 | 0 | 0 | 0 | 0 |
| 批量/重构 | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| 着色器 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 导出 | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| 资源 | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| 物理 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 3D 场景 | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| 粒子 | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| 导航 | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| 音频 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| AnimationTree | **9** | 0 | 0 | 0 | 0 | 0 | 0 |
| 分析 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 测试/QA | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 资产/AI | 0 | 0 | 1 | 6 | 0 | 0 | 0 |
| 材质 | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| 其他 | 0 | 0 | 9 | 5 | 5 | 2 | 1 |
| Headless | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Android 部署 | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| **合计** | **187** | ~30 | **32** | **39** | **13** | **19** | **10** |

### 功能矩阵

| 功能 | Godot MCP Pro | GDAI MCP ($19) | tomyud1（免费） | Dokujaa（免费） | Coding-Solo（免费） |
|---------|:---:|:---:|:---:|:---:|:---:|
| **连接方式** | WebSocket（实时） | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **撤销/重做** | 是 | 是 | 否 | 否 | 否 |
| **JSON-RPC 2.0** | 是 | 自定义 | 自定义 | 自定义 | N/A |
| **自动重连** | 是（指数退避） | N/A | 否 | 否 | N/A |
| **心跳** | 是（10s ping/pong） | 否 | 否 | 否 | 否 |
| **错误建议** | 是（上下文提示） | 否 | 否 | 否 | 否 |
| **截图捕获** | 是（编辑器 + 游戏） | 是 | 否 | 否 | 否 |
| **游戏输入模拟** | 是（key/mouse/action/sequence） | 是（基础） | 否 | 否 | 否 |
| **运行时检查** | 是（场景树 + 属性 + 监视） | 否 | 否 | 否 | 否 |
| **信号管理** | 是（connect/disconnect/inspect） | 否 | 否 | 否 | 否 |
| **浏览器可视化** | 否 | 否 | 是 | 否 | 否 |
| **AI 3D 网格生成** | 否 | 否 | 否 | 是（Meshy API） | 否 |

### 独有类别（竞品均不具备）

| 类别 | 工具 | 重要性 |
|----------|-------|----------------|
| **动画** | 6 个工具 | 创建动画、添加轨道、设置关键帧 — 全部可编程完成 |
| **TileMap** | 6 个工具 | 设置单元格、填充矩形、查询图块数据 — 2D 关卡设计必备 |
| **主题/UI** | 8 个工具 | StyleBox、颜色、字体 — 无需手动编辑器操作即可构建 UI 主题 |
| **性能分析** | 2 个工具 | FPS、内存、绘制调用、物理 — 性能监控 |
| **批量/重构** | 7 个工具 | 按类型查找、批量修改属性、跨场景更新、依赖分析 |
| **着色器** | 6 个工具 | 创建/编辑着色器、分配材质、设置参数 |
| **导出** | 4 个工具 | 列出预设、获取导出命令、检查模板 |
| **物理** | 6 个工具 | 设置碰撞形状、物理体、射线检测和层管理 |
| **3D 场景** | 7 个工具 | 添加网格、相机、灯光、环境，支持 GridMap |
| **粒子** | 5 个工具 | 使用自定义材质、预设和渐变创建粒子 |
| **导航** | 5 个工具 | 配置导航区域、代理、寻路、烘焙 |
| **音频** | 6 个工具 | 完整的音频总线系统、效果、播放器、实时管理 |
| **AnimationTree** | 9 个工具 | 状态机、过渡、混合树和 IK 修改器 |
| **测试/QA** | 6 个工具 | 自动化测试、断言、压力测试、截图比较 |
| **运行时** | 20 个工具 | 在运行时检查和控制游戏：检查、录制、回放、导航 |

### 架构优势

| 方面 | Godot MCP Pro | 典型竞品 |
|--------|--------------|-------------------|
| **协议** | JSON-RPC 2.0（标准、可扩展） | 自定义 JSON 或基于 CLI |
| **连接** | 带心跳的持久 WebSocket | 每条命令一个子进程或原始 TCP |
| **可靠性** | 指数退避自动重连（1s→60s） | 需要手动重连 |
| **类型安全** | 智能类型解析（Vector2、Color、Rect2、十六进制颜色） | 仅字符串或类型有限 |
| **错误处理** | 带错误码 + 建议的结构化错误 | 通用错误信息 |
| **撤销支持** | 所有修改都经过 UndoRedo 系统 | 直接修改（无撤销） |
| **端口管理** | 自动扫描端口 6505-6509 | 固定端口，可能冲突 |

## 许可证

专有软件 — 详情请参阅 [LICENSE](../LICENSE)。购买包含终身更新。
