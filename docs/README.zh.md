> **Language:** [English](../README.md) | [日本語](README.ja.md) | [Português (BR)](README.pt-br.md) | [Español](README.es.md) | [Русский](README.ru.md) | 简体中文 | [हिन्दी](README.hi.md)

# Godot MCP Pro

用于 AI 驱动 Godot 游戏开发的高级 MCP（Model Context Protocol）服务器。将 Claude 等 AI 助手直接连接到你的 Godot 编辑器，提供 **163 个强大工具**。

## 架构

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **实时通信**：WebSocket 连接意味着即时反馈，无需文件轮询
- **编辑器集成**：完全访问 Godot 编辑器 API、UndoRedo 系统和场景树
- **JSON-RPC 2.0**：带有正确错误代码和建议的标准协议

## 快速开始

### 1. 安装 Godot 插件

将 `addons/godot_mcp/` 文件夹复制到你的 Godot 项目的 `addons/` 目录中。

启用插件：**项目 → 项目设置 → 插件 → Godot MCP Pro → 启用**

### 2. 安装 MCP 服务器

```bash
cd server
npm install
npm run build
```

### 3. 配置 Claude Code

在你的 `.mcp.json` 中添加：

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

### 4. 自动审批工具权限（推荐）

Claude Code 每次调用工具时都会请求权限。要跳过这些提示，请将附带的权限预设复制到 Claude Code 设置中：

**选项 A：保守模式**（默认 — 阻止破坏性工具）

```bash
cp settings.local.json ~/.claude/settings.local.json
```

自动允许 163 个工具中的 152 个。以下 11 个工具仍需每次手动批准：

| 被阻止的工具 | 原因 |
|---|---|
| `delete_node` | 从场景中删除节点 |
| `delete_scene` | 从磁盘删除场景文件 |
| `remove_animation` | 删除动画 |
| `remove_autoload` | 删除 autoload 单例 |
| `remove_state_machine_state` | 删除状态机状态 |
| `remove_state_machine_transition` | 删除状态机转换 |
| `execute_editor_script` | 在编辑器中运行任意代码 |
| `execute_game_script` | 在运行中的游戏中运行任意代码 |
| `export_project` | 触发项目导出 |
| `tilemap_clear` | 清除 TileMapLayer 的所有单元格 |

**选项 B：宽松模式**（允许所有，拒绝危险命令）

```bash
cp settings.local.permissive.json ~/.claude/settings.local.json
```

允许所有 163 个工具和所有 Bash 命令。显式拒绝破坏性 shell 命令（`rm -rf`、`git push --force`、`git reset --hard` 等）以及上述相同的破坏性 MCP 工具。

> **注意**：如果你已有 `settings.local.json`，请手动合并 `permissions` 部分，而不是覆盖。

### 5. Lite 模式（可选）

如果你的 MCP 客户端有工具数量限制（例如 Windsurf：100，Cursor：~40），可以使用 Lite 模式，注册 76 个核心工具而不是 162 个：

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

Lite 模式包含：project、scene、node、script、editor、input、runtime 和 input_map 工具。

### 6. 开始使用

在启用插件的状态下打开你的 Godot 项目，然后使用 Claude Code 与编辑器交互。

## 全部 162 个工具

### 项目工具 (7)
| 工具 | 描述 |
|------|-------------|
| `get_project_info` | 项目元数据、版本、视口、autoloads |
| `get_filesystem_tree` | 带过滤的递归文件树 |
| `search_files` | 模糊/glob 文件搜索 |
| `get_project_settings` | 读取 project.godot 设置 |
| `set_project_setting` | 通过编辑器 API 设置项目设置 |
| `uid_to_project_path` | UID → res:// 转换 |
| `project_path_to_uid` | res:// → UID 转换 |

### 场景工具 (9)
| 工具 | 描述 |
|------|-------------|
| `get_scene_tree` | 带层级的实时场景树 |
| `get_scene_file_content` | .tscn 文件原始内容 |
| `create_scene` | 创建新场景文件 |
| `open_scene` | 在编辑器中打开场景 |
| `delete_scene` | 删除场景文件 |
| `add_scene_instance` | 将场景实例化为子节点 |
| `play_scene` | 运行场景（主场景/当前/自定义） |
| `stop_scene` | 停止运行中的场景 |
| `save_scene` | 将当前场景保存到磁盘 |

### 节点工具 (14)
| 工具 | 描述 |
|------|-------------|
| `add_node` | 添加指定类型和属性的节点 |
| `delete_node` | 删除节点（支持撤销） |
| `duplicate_node` | 复制节点及子节点 |
| `move_node` | 移动/重新设置父节点 |
| `update_property` | 设置任意属性（自动类型解析） |
| `get_node_properties` | 获取节点的所有属性 |
| `add_resource` | 向节点添加 Shape/Material 等 |
| `set_anchor_preset` | 设置 Control 锚点预设 |
| `rename_node` | 重命名场景中的节点 |
| `connect_signal` | 连接节点间的信号 |
| `disconnect_signal` | 断开信号连接 |
| `get_node_groups` | 获取节点所属的组 |
| `set_node_groups` | 设置节点的组成员关系 |
| `find_nodes_in_group` | 查找组中的所有节点 |

### 脚本工具 (8)
| 工具 | 描述 |
|------|-------------|
| `list_scripts` | 列出所有脚本及类信息 |
| `read_script` | 读取脚本内容 |
| `create_script` | 使用模板创建新脚本 |
| `edit_script` | 搜索/替换或完整编辑 |
| `attach_script` | 将脚本附加到节点 |
| `get_open_scripts` | 列出编辑器中打开的脚本 |
| `validate_script` | 验证 GDScript 语法 |
| `search_in_files` | 在项目文件中搜索内容 |

### 编辑器工具 (9)
| 工具 | 描述 |
|------|-------------|
| `get_editor_errors` | 获取错误和堆栈跟踪 |
| `get_editor_screenshot` | 截取编辑器视口 |
| `get_game_screenshot` | 截取运行中的游戏 |
| `execute_editor_script` | 在编辑器中运行任意 GDScript |
| `clear_output` | 清除输出面板 |
| `get_signals` | 获取节点的所有信号及连接 |
| `reload_plugin` | 重新加载 MCP 插件（自动重连） |
| `reload_project` | 重新扫描文件系统并重新加载脚本 |
| `get_output_log` | 获取输出面板内容 |

### 输入工具 (7)
| 工具 | 描述 |
|------|-------------|
| `simulate_key` | 模拟键盘按键按下/释放 |
| `simulate_mouse_click` | 模拟在指定位置的鼠标点击 |
| `simulate_mouse_move` | 模拟鼠标移动 |
| `simulate_action` | 模拟 Godot Input Action |
| `simulate_sequence` | 带帧延迟的输入事件序列 |
| `get_input_actions` | 列出所有输入动作 |
| `set_input_action` | 创建/修改输入动作 |

### 运行时工具 (19)
| 工具 | 描述 |
|------|-------------|
| `get_game_scene_tree` | 运行中游戏的场景树 |
| `get_game_node_properties` | 运行中游戏的节点属性 |
| `set_game_node_property` | 设置运行中游戏的节点属性 |
| `execute_game_script` | 在游戏上下文中运行 GDScript |
| `capture_frames` | 多帧截图捕获 |
| `monitor_properties` | 随时间记录属性值 |
| `start_recording` | 开始输入录制 |
| `stop_recording` | 停止输入录制 |
| `replay_recording` | 回放录制的输入 |
| `find_nodes_by_script` | 按脚本查找游戏节点 |
| `get_autoload` | 获取 autoload 节点属性 |
| `batch_get_properties` | 批量获取多个节点属性 |
| `find_ui_elements` | 查找游戏中的 UI 元素 |
| `click_button_by_text` | 通过文本点击按钮 |
| `wait_for_node` | 等待节点出现 |
| `find_nearby_nodes` | 查找位置附近的节点 |
| `navigate_to` | 导航到目标位置 |
| `move_to` | 移动角色到目标 |

### 动画工具 (6)
| 工具 | 描述 |
|------|-------------|
| `list_animations` | 列出 AnimationPlayer 中的所有动画 |
| `create_animation` | 创建新动画 |
| `add_animation_track` | 添加轨道（value/position/rotation/method/bezier） |
| `set_animation_keyframe` | 在轨道中插入关键帧 |
| `get_animation_info` | 包含所有轨道/关键帧的详细动画信息 |
| `remove_animation` | 删除动画 |

### TileMap 工具 (6)
| 工具 | 描述 |
|------|-------------|
| `tilemap_set_cell` | 设置单个瓦片单元格 |
| `tilemap_fill_rect` | 用瓦片填充矩形区域 |
| `tilemap_get_cell` | 获取单元格的瓦片数据 |
| `tilemap_clear` | 清除所有单元格 |
| `tilemap_get_info` | TileMapLayer 信息和瓦片集来源 |
| `tilemap_get_used_cells` | 已使用单元格列表 |

### 主题与 UI 工具 (6)
| 工具 | 描述 |
|------|-------------|
| `create_theme` | 创建 Theme 资源文件 |
| `set_theme_color` | 设置主题颜色覆盖 |
| `set_theme_constant` | 设置主题常量覆盖 |
| `set_theme_font_size` | 设置主题字体大小覆盖 |
| `set_theme_stylebox` | 设置 StyleBoxFlat 覆盖 |
| `get_theme_info` | 获取主题覆盖信息 |

### 性能分析工具 (2)
| 工具 | 描述 |
|------|-------------|
| `get_performance_monitors` | 所有性能监视器（FPS、内存、物理等） |
| `get_editor_performance` | 快速性能概览 |

### 批处理与重构工具 (8)
| 工具 | 描述 |
|------|-------------|
| `find_nodes_by_type` | 按类型查找所有节点 |
| `find_signal_connections` | 查找场景中所有信号连接 |
| `batch_set_property` | 为某类型的所有节点设置属性 |
| `find_node_references` | 在项目文件中搜索模式 |
| `get_scene_dependencies` | 获取资源依赖关系 |
| `cross_scene_set_property` | 跨所有场景设置属性 |
| `find_script_references` | 查找脚本/资源的使用位置 |
| `detect_circular_dependencies` | 检测场景循环依赖 |

### 着色器工具 (6)
| 工具 | 描述 |
|------|-------------|
| `create_shader` | 使用模板创建着色器 |
| `read_shader` | 读取着色器文件 |
| `edit_shader` | 编辑着色器（替换/搜索替换） |
| `assign_shader_material` | 将 ShaderMaterial 分配给节点 |
| `set_shader_param` | 设置着色器参数 |
| `get_shader_params` | 获取所有着色器参数 |

### 导出工具 (3)
| 工具 | 描述 |
|------|-------------|
| `list_export_presets` | 列出导出预设 |
| `export_project` | 获取预设的导出命令 |
| `get_export_info` | 与导出相关的项目信息 |

### 资源工具 (6)
| 工具 | 描述 |
|------|-------------|
| `read_resource` | 读取 .tres 资源属性 |
| `edit_resource` | 编辑资源属性 |
| `create_resource` | 创建新的 .tres 资源 |
| `get_resource_preview` | 获取资源缩略图 |
| `add_autoload` | 注册 autoload 单例 |
| `remove_autoload` | 删除 autoload 单例 |

### 物理工具 (6)
| 工具 | 描述 |
|------|-------------|
| `setup_physics_body` | 配置物理体属性 |
| `setup_collision` | 向节点添加碰撞形状 |
| `set_physics_layers` | 设置碰撞层/掩码 |
| `get_physics_layers` | 获取碰撞层/掩码信息 |
| `get_collision_info` | 获取碰撞形状详情 |
| `add_raycast` | 添加 RayCast2D/3D 节点 |

### 3D 场景工具 (6)
| 工具 | 描述 |
|------|-------------|
| `add_mesh_instance` | 添加带基本网格的 MeshInstance3D |
| `setup_camera_3d` | 配置 Camera3D 属性 |
| `setup_lighting` | 添加/配置灯光节点 |
| `setup_environment` | 配置 WorldEnvironment |
| `add_gridmap` | 设置 GridMap 节点 |
| `set_material_3d` | 设置 StandardMaterial3D 属性 |

### 粒子工具 (5)
| 工具 | 描述 |
|------|-------------|
| `create_particles` | 创建 GPUParticles2D/3D |
| `set_particle_material` | 配置 ParticleProcessMaterial |
| `set_particle_color_gradient` | 设置粒子颜色渐变 |
| `apply_particle_preset` | 应用预设（fire、smoke、sparks 等） |
| `get_particle_info` | 获取粒子系统详情 |

### 导航工具 (6)
| 工具 | 描述 |
|------|-------------|
| `setup_navigation_region` | 配置 NavigationRegion |
| `setup_navigation_agent` | 配置 NavigationAgent |
| `bake_navigation_mesh` | 烘焙导航网格 |
| `set_navigation_layers` | 设置导航层 |
| `get_navigation_info` | 获取导航设置信息 |

### 音频工具 (6)
| 工具 | 描述 |
|------|-------------|
| `add_audio_player` | 添加 AudioStreamPlayer 节点 |
| `add_audio_bus` | 添加音频总线 |
| `add_audio_bus_effect` | 向音频总线添加效果 |
| `set_audio_bus` | 配置音频总线属性 |
| `get_audio_bus_layout` | 获取音频总线布局信息 |
| `get_audio_info` | 获取音频相关节点信息 |

### AnimationTree 工具 (4)
| 工具 | 描述 |
|------|-------------|
| `create_animation_tree` | 创建 AnimationTree |
| `get_animation_tree_structure` | 获取树结构 |
| `set_tree_parameter` | 设置 AnimationTree 参数 |
| `add_state_machine_state` | 向状态机添加状态 |

### 状态机工具 (3)
| 工具 | 描述 |
|------|-------------|
| `remove_state_machine_state` | 从状态机中删除状态 |
| `add_state_machine_transition` | 添加状态间的转换 |
| `remove_state_machine_transition` | 删除状态转换 |

### 混合树工具 (1)
| 工具 | 描述 |
|------|-------------|
| `set_blend_tree_node` | 配置混合树节点 |

### 分析与搜索工具 (4)
| 工具 | 描述 |
|------|-------------|
| `analyze_scene_complexity` | 分析场景性能 |
| `analyze_signal_flow` | 映射信号连接 |
| `find_unused_resources` | 查找未引用的资源 |
| `get_project_statistics` | 获取项目整体统计 |

### 测试与 QA 工具 (6)
| 工具 | 描述 |
|------|-------------|
| `run_test_scenario` | 运行自动化测试场景 |
| `assert_node_state` | 断言节点属性值 |
| `assert_screen_text` | 检查屏幕上的文字 |
| `compare_screenshots` | 比较两张截图 |
| `run_stress_test` | 运行性能压力测试 |
| `get_test_report` | 获取测试结果报告 |

## 主要特性

- **UndoRedo 集成**：所有节点/属性操作支持 Ctrl+Z
- **智能类型解析**：`"Vector2(100, 200)"`、`"#ff0000"`、`"Color(1,0,0)"` 自动转换
- **自动重连**：指数退避重连（1秒 → 2秒 → 4秒 ... → 最大60秒）
- **心跳检测**：10秒 ping/pong 保持连接活跃
- **友好的错误提示**：错误响应包含下一步操作建议

## 竞品对比

### 工具数量

| 分类 | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) | ee0pdt (free) | bradypp (free) |
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
| **总计** | **162** | ~30 | **32** | **39** | **13** | **19** | **10** |

### 功能矩阵

| 功能 | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **连接方式** | WebSocket（实时） | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | 支持 | 支持 | 不支持 | 不支持 | 不支持 |
| **JSON-RPC 2.0** | 支持 | 自定义 | 自定义 | 自定义 | N/A |
| **自动重连** | 支持（指数退避） | N/A | 不支持 | 不支持 | N/A |
| **心跳检测** | 支持（10秒 ping/pong） | 不支持 | 不支持 | 不支持 | 不支持 |
| **错误建议** | 支持（上下文提示） | 不支持 | 不支持 | 不支持 | 不支持 |
| **截图捕获** | 支持（编辑器 + 游戏） | 支持 | 不支持 | 不支持 | 不支持 |
| **游戏输入模拟** | 支持（键盘/鼠标/动作/序列） | 支持（基础） | 不支持 | 不支持 | 不支持 |
| **运行时检查** | 支持（场景树 + 属性 + 监控） | 不支持 | 不支持 | 不支持 | 不支持 |
| **信号管理** | 支持（连接/断开/检查） | 不支持 | 不支持 | 不支持 | 不支持 |
| **浏览器可视化** | 不支持 | 不支持 | 支持 | 不支持 | 不支持 |
| **AI 3D 网格生成** | 不支持 | 不支持 | 不支持 | 支持（Meshy API） | 不支持 |

### 独占分类（竞品没有的功能）

| 分类 | 工具数 | 重要性 |
|----------|-------|----------------|
| **Animation** | 6 个工具 | 创建动画、添加轨道、设置关键帧 — 全部通过编程实现 |
| **TileMap** | 6 个工具 | 设置单元格、填充矩形、查询瓦片数据 — 2D 关卡设计必备 |
| **Theme/UI** | 6 个工具 | StyleBox、颜色、字体 — 无需手动编辑器操作即可构建 UI 主题 |
| **Profiling** | 2 个工具 | FPS、内存、绘制调用、物理 — 性能监控 |
| **Batch/Refactor** | 8 个工具 | 按类型查找、批量属性修改、跨场景更新、依赖分析 |
| **Shader** | 6 个工具 | 创建/编辑着色器、分配材质、设置参数 |
| **Export** | 3 个工具 | 列出预设、获取导出命令、检查模板 |
| **Physics** | 6 个工具 | 设置碰撞形状、物理体、射线检测和层管理 |
| **3D Scene** | 6 个工具 | 添加网格、摄像机、灯光、环境、GridMap 支持 |
| **Particle** | 5 个工具 | 创建带自定义材质、预设和渐变的粒子 |
| **Navigation** | 6 个工具 | 配置导航区域、代理、寻路、烘焙 |
| **Audio** | 6 个工具 | 完整的音频总线系统、效果、播放器、实时管理 |
| **AnimationTree** | 4 个工具 | 构建带转换和混合树的状态机 |
| **State Machine** | 3 个工具 | 复杂动画的高级状态机管理 |
| **Testing/QA** | 6 个工具 | 自动化测试、断言、压力测试、截图对比 |
| **Runtime** | 19 个工具 | 运行时检查和控制游戏：检查、录制、回放、导航 |

### 架构优势

| 方面 | Godot MCP Pro | 典型竞品 |
|--------|--------------|-------------------|
| **协议** | JSON-RPC 2.0（标准、可扩展） | 自定义 JSON 或基于 CLI |
| **连接** | 带心跳的持久 WebSocket | 每命令子进程或原始 TCP |
| **可靠性** | 指数退避自动重连（1秒→60秒） | 需要手动重连 |
| **类型安全** | 智能类型解析（Vector2、Color、Rect2、十六进制颜色） | 仅字符串或有限类型 |
| **错误处理** | 带代码 + 建议的结构化错误 | 通用错误消息 |
| **撤销支持** | 所有修改通过 UndoRedo 系统 | 直接修改（无法撤销） |
| **端口管理** | 自动扫描端口 6505-6509 | 固定端口，可能冲突 |

## 许可证

专有许可 — 详见 [LICENSE](../LICENSE)。购买包含 v1.x 终身更新。
