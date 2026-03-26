> **Language:** [English](skills.md) | [日本語](skills.ja.md) | [Português (BR)](skills.pt-br.md) | [Español](skills.es.md) | [Русский](skills.ru.md) | 简体中文 | [हिन्दी](skills.hi.md)

# Godot MCP Pro — AI 助手技能指南

> 将此文件复制到 Godot 项目根目录的 `.claude/skills.md`，以便 Claude Code 获得如何高效使用 Godot MCP Pro 的完整上下文。

## 什么是 Godot MCP Pro？

你可以使用 162 个 MCP 工具直接连接 Godot 4 编辑器。你可以创建场景、编写脚本、模拟玩家输入、检查运行中的游戏等等——所有操作都无需用户离开当前对话。每次更改都通过 Godot 的 UndoRedo 系统进行，因此用户随时可以 Ctrl+Z 撤销。

## 核心工作流

### 1. 探索项目

在进行更改之前，先了解项目全貌：

```
get_project_info          → 项目名称、Godot 版本、渲染器、视口大小
get_filesystem_tree       → 目录结构（可使用 filter: "*.tscn" 或 "*.gd"）
get_scene_tree            → 当前打开场景的节点层级
read_script               → 读取任意 GDScript 文件
get_project_settings      → 检查项目配置
```

### 2. 构建 2D 场景

```
create_scene   → 创建 .tscn 文件并指定根节点类型
add_node       → 添加带属性的子节点
create_script  → 编写游戏逻辑的 GDScript
attach_script  → 将脚本附加到节点
update_property → 设置 position、scale、modulate 等
save_scene     → 保存到磁盘
```

**示例——创建玩家：**
1. `create_scene` 设置 root_type 为 `CharacterBody2D`，path 为 `res://scenes/player.tscn`
2. `add_node` 类型 `Sprite2D` 并设置 texture 属性
3. `add_node` 类型 `CollisionShape2D`
4. `add_resource` 为 CollisionShape2D 分配形状（如 `RectangleShape2D`）
5. `create_script` 编写移动逻辑
6. `attach_script` 附加到根节点
7. `save_scene`

### 3. 构建 3D 场景

```
create_scene         → root_type: Node3D
add_mesh_instance    → 添加基础体（box、sphere、cylinder、plane）或导入 .glb/.gltf
setup_lighting       → 添加 DirectionalLight3D、OmniLight3D 或 SpotLight3D
setup_environment    → 天空、环境光、雾、色调映射
setup_camera_3d      → 摄像机（可选 SpringArm3D 实现第三人称视角）
set_material_3d      → PBR 材质（albedo、metallic、roughness、emission）
setup_collision      → 为物理体添加碰撞形状
setup_physics_body   → 配置质量、摩擦力、重力
```

### 4. 编写和编辑脚本

```
create_script  → 创建新的 .gd 文件（提供完整内容）
edit_script    → 修改现有脚本
  - 使用 `replacements: [{search: "old code", replace: "new code"}]` 进行定向编辑
  - 使用 `content` 完整替换文件
  - 使用 `insert_at_line` + `text` 插入代码
validate_script → 不运行即可检查语法错误
read_script    → 编辑前读取当前内容
```

### 5. 测试与调试

```
play_scene             → 启动游戏（mode: "current"、"main" 或文件路径）
get_game_screenshot    → 查看游戏当前画面
capture_frames         → 捕获多帧以观察运动/动画
get_game_scene_tree    → 检查运行时的场景树
get_game_node_properties → 读取运行时数值（position、health、state 等）
set_game_node_property → 修改运行中游戏的数值
simulate_key           → 按键（WASD、SPACE 等）并指定持续时间
simulate_mouse_click   → 在视口坐标处点击
simulate_action        → 触发 InputMap 动作（move_left、jump 等）
get_editor_errors      → 检查运行时错误
stop_scene             → 停止游戏
```

**测试循环：**
1. `play_scene` → 启动游戏
2. `get_game_screenshot` → 查看当前状态
3. `simulate_key` / `simulate_action` → 与游戏交互
4. `capture_frames` → 观察一段时间内的行为
5. `get_game_node_properties` → 检查特定数值
6. `stop_scene` → 完成后停止
7. 修复脚本问题 → 重复

### 6. 动画

```
# 确保场景中存在 AnimationPlayer 节点
create_animation       → 创建带时长和循环模式的新动画
add_animation_track    → 添加 property/transform/method 轨道
set_animation_keyframe → 在特定时间插入关键帧
get_animation_info     → 查看现有动画信息
```

**示例——弹跳精灵：**
1. `create_animation` name 为 `bounce`，length 为 `1.0`，loop_mode 为 `1`（线性循环）
2. `add_animation_track` track_path 为 `Sprite2D:position`，track_type 为 `value`
3. `set_animation_keyframe` time 为 `0.0`，value 为 `Vector2(0, 0)`
4. `set_animation_keyframe` time 为 `0.5`，value 为 `Vector2(0, -50)`
5. `set_animation_keyframe` time 为 `1.0`，value 为 `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control、Label、Button、TextureRect 等
set_anchor_preset → 定位 Control（full_rect、center、bottom_wide 等）
set_theme_color   → 修改 font_color 等
set_theme_font_size → 调整文字大小
set_theme_stylebox  → 背景、边框、圆角
connect_signal    → 连接 button 的 pressed、value_changed 等信号
```

### 8. TileMap

```
tilemap_get_info      → 检查图块集来源和图集布局
tilemap_set_cell      → 放置单个图块
tilemap_fill_rect     → 填充矩形区域
tilemap_get_used_cells → 查看已放置的内容
tilemap_clear         → 清除所有单元格
```

### 9. 音频

```
add_audio_bus        → 创建音频总线（SFX、Music、UI）
set_audio_bus        → 调整音量、独奏、静音
add_audio_bus_effect → 添加混响、延迟、压缩器等
add_audio_player     → 添加 AudioStreamPlayer(2D/3D) 节点
```

### 10. 项目配置

```
set_project_setting  → 修改视口大小、物理设置等
set_input_action     → 定义输入映射（move_left → KEY_A 等）
add_autoload         → 注册 autoload 单例
set_physics_layers   → 命名碰撞层（player、enemy、world 等）
```

## 重要规则与注意事项

### 属性值
属性会从字符串自动解析。使用以下格式：
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` 或 `"#ff0000"`
- Bool: `"true"` / `"false"`
- 数字: `"42"`、`"3.14"`
- 枚举: 使用整数值（例如第一个枚举值用 `0`）

### 不要直接编辑 project.godot
Godot 编辑器会不断覆盖 `project.godot`。修改项目设置请务必使用 `set_project_setting`。

### GDScript 类型注解
在对无类型数组使用 `for` 循环时，请使用显式类型注解：
```gdscript
# 错误——会导致报错
for item in some_untyped_array:
    var x := item.value  # 类型推断失败

# 正确
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### 脚本更改需要重新加载
创建或大幅修改脚本后，使用 `reload_project` 确保 Godot 识别更改。在 `create_script` 之后尤其重要。

### simulate_key 技巧
- 精确移动使用**短持续时间**（0.3-0.5 秒）
- 长持续时间（1 秒以上）会导致过冲
- 游戏测试时，如果已定义 InputMap 动作，优先使用 `simulate_action` 而非 `simulate_key`

### simulate_mouse_click
- 默认 `auto_release: true` 会同时发送按下和释放事件——UI 按钮必须如此
- UI 按钮在释放时触发，因此两个事件都必不可少

### execute_game_script 限制
- 不支持嵌套函数（`func` 中的 `func`）——会导致编译错误
- 动态访问请使用 `.get("property")` 而非 `.property`
- 运行时错误会暂停调试器（会自动继续，但尽量避免）

### 碰撞与拾取区域
- 可收集物品请使用 Area3D/Area2D 并设置半径 >= 1.5
- 较小的半径几乎无法通过模拟输入触发

### 经常保存
进行重大更改后请调用 `save_scene`。未保存的更改可能在编辑器重新加载时丢失。

## 分析与调试工具

出现问题时，使用以下工具进行排查：

```
get_editor_errors          → 检查脚本错误和运行时异常
get_output_log             → 读取 print() 输出和警告
analyze_scene_complexity   → 查找性能瓶颈
analyze_signal_flow        → 可视化信号连接
detect_circular_dependencies → 查找脚本/场景的循环引用
find_unused_resources      → 清理未使用的文件
get_performance_monitors   → FPS、内存、绘制调用、物理统计
```

## 测试与 QA

```
run_test_scenario   → 定义并运行自动化测试序列
assert_node_state   → 验证节点属性是否匹配预期值
assert_screen_text  → 验证文本是否显示在屏幕上
compare_screenshots → 视觉回归测试（使用文件路径，不要用 base64）
run_stress_test     → 生成大量节点以测试性能
```

## 高级模式

### 跨场景操作
```
cross_scene_set_property → 修改当前未打开场景中的节点
find_node_references     → 查找引用某个模式的所有文件
batch_set_property       → 为某类型的所有节点设置属性
```

### 着色器工作流
```
create_shader        → 编写类 GLSL 的着色器代码
assign_shader_material → 应用到节点
set_shader_param     → 在运行时调整 uniform 参数
get_shader_params    → 查看当前值
```

### 导航（3D）
```
setup_navigation_region → 定义可行走区域
bake_navigation_mesh   → 生成导航网格
setup_navigation_agent → 为角色添加寻路功能
```

### AnimationTree 与状态机
```
create_animation_tree           → 使用状态机或混合树设置 AnimationTree
add_state_machine_state         → 添加状态（idle、walk、run、jump）
add_state_machine_transition    → 定义状态之间的过渡
set_tree_parameter              → 控制混合参数
```

## 推荐工作流顺序

从零开始构建新游戏时：

1. **项目设置** — `get_project_info`、`set_project_setting`（视口、物理）
2. **输入映射** — `set_input_action` 定义所有玩家控制
3. **主场景** — `create_scene`，设为主场景
4. **玩家** — 创建包含精灵、碰撞、脚本的玩家场景
5. **关卡/世界** — 构建环境（TileMap、3D 网格等）
6. **游戏逻辑** — 敌人、道具、UI 的脚本
7. **音频** — 设置总线、添加音频播放器
8. **测试** — `play_scene`，使用模拟输入测试，修复 bug
9. **打磨** — 动画、粒子、着色器、主题
10. **导出** — `list_export_presets`、`export_project`
