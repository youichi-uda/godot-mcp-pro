> **Language:** [English](skills.md) | [日本語](skills.ja.md) | [Português (BR)](skills.pt-br.md) | [Español](skills.es.md) | [Русский](skills.ru.md) | [简体中文](skills.zh.md) | हिन्दी

# Godot MCP Pro — AI Assistants के लिए Skills

> इस फ़ाइल को अपने Godot प्रोजेक्ट रूट में `.claude/skills.md` पर कॉपी करें ताकि Claude Code को Godot MCP Pro को प्रभावी ढंग से उपयोग करने का पूरा context मिल सके।

## Godot MCP Pro क्या है?

आपके पास 169 MCP tools उपलब्ध हैं जो सीधे Godot 4 editor से कनेक्ट होते हैं। आप scenes बना सकते हैं, scripts लिख सकते हैं, player input simulate कर सकते हैं, running games को inspect कर सकते हैं, और बहुत कुछ — सब कुछ बिना user को इस conversation से बाहर जाए। हर बदलाव Godot के UndoRedo system से होता है, इसलिए user हमेशा Ctrl+Z कर सकता है।

## ज़रूरी Workflows

### 1. प्रोजेक्ट को Explore करें

बदलाव करने से पहले हमेशा प्रोजेक्ट को समझें:

```
get_project_info          → प्रोजेक्ट का नाम, Godot version, renderer, viewport size
get_filesystem_tree       → directory structure (filter: "*.tscn" या "*.gd" use करें)
get_scene_tree            → currently open scene की node hierarchy
read_script               → कोई भी GDScript फ़ाइल पढ़ें
get_project_settings      → project configuration चेक करें
```

### 2. 2D Scene बनाएं

```
create_scene   → root node type के साथ .tscn फ़ाइल बनाएं
add_node       → properties के साथ child nodes जोड़ें
create_script  → game logic के लिए GDScript लिखें
attach_script  → node पर script attach करें
update_property → position, scale, modulate आदि सेट करें
save_scene     → disk पर save करें
```

**उदाहरण — player बनाना:**
1. `create_scene` root_type `CharacterBody2D` के साथ, path `res://scenes/player.tscn`
2. `add_node` type `Sprite2D` texture property के साथ
3. `add_node` type `CollisionShape2D`
4. `add_resource` CollisionShape2D को shape assign करने के लिए (जैसे `RectangleShape2D`)
5. `create_script` movement logic के साथ
6. `attach_script` root node पर
7. `save_scene`

### 3. 3D Scene बनाएं

```
create_scene         → root_type: Node3D
add_mesh_instance    → primitives (box, sphere, cylinder, plane) जोड़ें या .glb/.gltf import करें
setup_lighting       → DirectionalLight3D, OmniLight3D, या SpotLight3D जोड़ें
setup_environment    → sky, ambient light, fog, tonemap
setup_camera_3d      → camera, optional SpringArm3D के साथ third-person के लिए
set_material_3d      → PBR materials (albedo, metallic, roughness, emission)
setup_collision      → physics bodies में collision shapes जोड़ें
setup_physics_body   → mass, friction, gravity configure करें
```

### 4. Scripts लिखें और Edit करें

```
create_script  → नई .gd फ़ाइल बनाएं (पूरा content दें)
edit_script    → existing scripts modify करें
  - `replacements: [{search: "old code", replace: "new code"}]` targeted edits के लिए
  - `content` पूरी फ़ाइल replace करने के लिए
  - `insert_at_line` + `text` code insert करने के लिए
validate_script → बिना run किए syntax errors चेक करें
read_script    → edit करने से पहले current content पढ़ें
```

### 5. Playtest और Debug करें

```
play_scene             → game launch करें (mode: "current", "main", या file path)
get_game_screenshot    → अभी game कैसा दिख रहा है देखें
capture_frames         → motion/animation observe करने के लिए multiple frames capture करें
get_game_scene_tree    → runtime पर live scene tree inspect करें
get_game_node_properties → runtime values पढ़ें (position, health, state आदि)
set_game_node_property → running game में values modify करें
simulate_key           → keys press करें (WASD, SPACE आदि) duration के साथ
simulate_mouse_click   → viewport coordinates पर click करें
simulate_action        → InputMap actions trigger करें (move_left, jump आदि)
get_editor_errors      → runtime errors चेक करें
stop_scene             → game बंद करें
```

**Playtesting loop:**
1. `play_scene` → game शुरू करें
2. `get_game_screenshot` → current state देखें
3. `simulate_key` / `simulate_action` → game के साथ interact करें
4. `capture_frames` → समय के साथ behavior observe करें
5. `get_game_node_properties` → specific values चेक करें
6. `stop_scene` → काम हो जाए तो बंद करें
7. Scripts में issues fix करें → दोहराएं

### 6. Animations

```
# Scene में AnimationPlayer node होना ज़रूरी है
create_animation       → length और loop mode के साथ नई animation
add_animation_track    → property/transform/method tracks जोड़ें
set_animation_keyframe → specific times पर keyframes insert करें
get_animation_info     → existing animations inspect करें
```

**उदाहरण — bouncing sprite:**
1. `create_animation` name `bounce`, length `1.0`, loop_mode `1` (linear loop)
2. `add_animation_track` track_path `Sprite2D:position`, track_type `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control, Label, Button, TextureRect आदि
set_anchor_preset → Controls position करें (full_rect, center, bottom_wide आदि)
set_theme_color   → font_color आदि बदलें
set_theme_font_size → text size adjust करें
set_theme_stylebox  → backgrounds, borders, rounded corners
connect_signal    → button pressed, value_changed आदि wire up करें
```

### 8. TileMap

```
tilemap_get_info      → tile set sources और atlas layout चेक करें
tilemap_set_cell      → individual tiles place करें
tilemap_fill_rect     → rectangular regions fill करें
tilemap_get_used_cells → देखें क्या पहले से placed है
tilemap_clear         → सभी cells clear करें
```

### 9. Audio

```
add_audio_bus        → audio buses बनाएं (SFX, Music, UI)
set_audio_bus        → volume, solo, mute adjust करें
add_audio_bus_effect → reverb, delay, compressor आदि जोड़ें
add_audio_player     → AudioStreamPlayer(2D/3D) nodes जोड़ें
```

### 10. Project Configuration

```
set_project_setting  → viewport size, physics settings आदि बदलें
set_input_action     → input mappings define करें (move_left → KEY_A आदि)
add_autoload         → autoload singletons register करें
set_physics_layers   → collision layers name करें (player, enemy, world आदि)
```

## ज़रूरी Rules और Pitfalls

### Property Values
Properties strings से auto-parse होती हैं। ये formats use करें:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` या `"#ff0000"`
- Bool: `"true"` / `"false"`
- Numbers: `"42"`, `"3.14"`
- Enums: Integer values use करें (जैसे पहले enum value के लिए `0`)

### project.godot को कभी सीधे Edit न करें
Godot editor लगातार `project.godot` को overwrite करता है। Project settings बदलने के लिए हमेशा `set_project_setting` use करें।

### GDScript Type Annotations
Untyped arrays पर `for` loops लिखते समय, explicit type annotations use करें:
```gdscript
# गलत — errors आएंगे
for item in some_untyped_array:
    var x := item.value  # type inference fail होता है

# सही
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### Script Changes के लिए Reload ज़रूरी
Scripts create या significantly modify करने के बाद, `reload_project` use करें ताकि Godot changes को pick up करे। `create_script` के बाद ये खासकर ज़रूरी है।

### simulate_key Tips
- Precise movement के लिए **छोटी duration** (0.3–0.5 seconds) use करें
- लंबी duration (1+ second) से overshooting होती है
- Gameplay testing के लिए, जब InputMap actions defined हों तो `simulate_key` की जगह `simulate_action` prefer करें

### simulate_mouse_click
- Default `auto_release: true` press और release दोनों भेजता है — UI buttons के लिए ज़रूरी है
- UI buttons release पर fire होते हैं, इसलिए दोनों events चाहिए

### execute_game_script की Limitations
- Nested functions (`func` के अंदर `func`) नहीं चलतीं — compile error आता है
- Dynamic access के लिए `.property` की जगह `.get("property")` use करें
- Runtime errors debugger को pause करती हैं (auto-continue होता है, लेकिन बचना बेहतर)

### Collision और Pickup Areas
- Collectible items के लिए Area3D/Area2D radius >= 1.5 रखें
- छोटे radius को simulated input से trigger करना लगभग impossible है

### बार-बार Save करें
बड़े बदलावों के बाद `save_scene` call करें। Unsaved changes editor reload होने पर खो सकते हैं।

## Analysis और Debugging Tools

कुछ गलत होने पर, इन tools से investigate करें:

```
get_editor_errors          → script errors और runtime exceptions चेक करें
get_output_log             → print() output और warnings पढ़ें
analyze_scene_complexity   → performance bottlenecks खोजें
analyze_signal_flow        → signal connections visualize करें
detect_circular_dependencies → circular script/scene references खोजें
find_unused_resources      → unused files clean up करें
get_performance_monitors   → FPS, memory, draw calls, physics stats
```

## Testing और QA

```
run_test_scenario   → automated test sequences define और run करें
assert_node_state   → verify करें कि node properties expected values से match करती हैं
assert_screen_text  → verify करें कि text screen पर display हो रहा है
compare_screenshots → visual regression testing (file paths use करें, base64 नहीं)
run_stress_test     → performance test के लिए बहुत सारे nodes spawn करें
```

## Advanced Patterns

### Cross-Scene Operations
```
cross_scene_set_property → उन scenes के nodes modify करें जो अभी open नहीं हैं
find_node_references     → किसी pattern को reference करने वाली सभी files खोजें
batch_set_property       → किसी type के सभी nodes पर property set करें
```

### Shader Workflow
```
create_shader        → GLSL-like shader code लिखें
assign_shader_material → node पर apply करें
set_shader_param     → runtime पर uniforms adjust करें
get_shader_params    → current values inspect करें
```

### Navigation (3D)
```
setup_navigation_region → walkable area define करें
bake_navigation_mesh   → navmesh generate करें
setup_navigation_agent → characters में pathfinding जोड़ें
```

### AnimationTree और State Machines
```
create_animation_tree           → state machine या blend tree के साथ AnimationTree set up करें
add_state_machine_state         → states जोड़ें (idle, walk, run, jump)
add_state_machine_transition    → states के बीच transitions define करें
set_tree_parameter              → blend parameters control करें
```

## Recommended Workflow Order

नया game scratch से बनाते समय:

1. **Project setup** — `get_project_info`, `set_project_setting` (viewport, physics)
2. **Input mapping** — `set_input_action` सभी player controls के लिए
3. **Main scene** — `create_scene`, main scene के रूप में set करें
4. **Player** — sprite, collision, script के साथ player scene बनाएं
5. **Level/World** — environment build करें (TileMap, 3D meshes आदि)
6. **Game logic** — enemies, items, UI के लिए scripts
7. **Audio** — buses set up करें, audio players जोड़ें
8. **Playtest** — `play_scene`, simulated input से test करें, bugs fix करें
9. **Polish** — animations, particles, shaders, themes
10. **Export** — `list_export_presets`, `export_project`
