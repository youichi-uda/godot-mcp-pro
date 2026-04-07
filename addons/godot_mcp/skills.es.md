> **Language:** [English](skills.md) | [日本語](skills.ja.md) | [Português (BR)](skills.pt-br.md) | Español | [Русский](skills.ru.md) | [简体中文](skills.zh.md) | [हिन्दी](skills.hi.md)

# Godot MCP Pro — Skills para Asistentes de IA

> Copia este archivo a `.claude/skills.md` en la raíz de tu proyecto Godot para darle a Claude Code el contexto completo sobre cómo usar Godot MCP Pro de forma efectiva.

## ¿Qué es Godot MCP Pro?

Tienes acceso a 169 herramientas MCP que se conectan directamente al editor de Godot 4. Puedes crear escenas, escribir scripts, simular entrada del jugador, inspeccionar juegos en ejecución y más — todo sin que el usuario salga de esta conversación. Cada cambio pasa por el sistema UndoRedo de Godot, así que el usuario siempre puede hacer Ctrl+Z.

## Flujos de Trabajo Esenciales

### 1. Explorar un Proyecto

Siempre empieza entendiendo el proyecto antes de hacer cambios:

```
get_project_info          → nombre del proyecto, versión de Godot, renderizador, tamaño del viewport
get_filesystem_tree       → estructura de directorios (usa filter: "*.tscn" o "*.gd")
get_scene_tree            → jerarquía de nodos de la escena abierta actualmente
read_script               → leer cualquier archivo GDScript
get_project_settings      → revisar la configuración del proyecto
```

### 2. Construir una Escena 2D

```
create_scene   → crear archivo .tscn con tipo de nodo raíz
add_node       → agregar nodos hijos con propiedades
create_script  → escribir GDScript para lógica del juego
attach_script  → adjuntar script a un nodo
update_property → establecer position, scale, modulate, etc.
save_scene     → guardar en disco
```

**Ejemplo — creando un jugador:**
1. `create_scene` con root_type `CharacterBody2D`, path `res://scenes/player.tscn`
2. `add_node` tipo `Sprite2D` con propiedad texture
3. `add_node` tipo `CollisionShape2D`
4. `add_resource` para asignar una shape (ej: `RectangleShape2D`) al CollisionShape2D
5. `create_script` con lógica de movimiento
6. `attach_script` al nodo raíz
7. `save_scene`

### 3. Construir una Escena 3D

```
create_scene         → root_type: Node3D
add_mesh_instance    → agregar primitivas (box, sphere, cylinder, plane) o importar .glb/.gltf
setup_lighting       → agregar DirectionalLight3D, OmniLight3D o SpotLight3D
setup_environment    → cielo, luz ambiental, niebla, tonemap
setup_camera_3d      → cámara con SpringArm3D opcional para tercera persona
set_material_3d      → materiales PBR (albedo, metallic, roughness, emission)
setup_collision      → agregar shapes de colisión a cuerpos físicos
setup_physics_body   → configurar masa, fricción, gravedad
```

### 4. Escribir y Editar Scripts

```
create_script  → crear nuevo archivo .gd (proporciona el contenido completo)
edit_script    → modificar scripts existentes
  - Usa `replacements: [{search: "old code", replace: "new code"}]` para ediciones específicas
  - Usa `content` para reemplazo completo del archivo
  - Usa `insert_at_line` + `text` para insertar código
validate_script → verificar errores de sintaxis sin ejecutar
read_script    → leer contenido actual antes de editar
```

### 5. Probar y Depurar

```
play_scene             → lanzar el juego (mode: "current", "main" o ruta de archivo)
get_game_screenshot    → ver cómo luce el juego en este momento
capture_frames         → capturar múltiples frames para observar movimiento/animación
get_game_scene_tree    → inspeccionar el árbol de escena en tiempo de ejecución
get_game_node_properties → leer valores en runtime (position, health, state, etc.)
set_game_node_property → modificar valores en el juego en ejecución
simulate_key           → presionar teclas (WASD, SPACE, etc.) con duración
simulate_mouse_click   → hacer clic en coordenadas del viewport
simulate_action        → disparar acciones del InputMap (move_left, jump, etc.)
get_editor_errors      → revisar errores de ejecución
stop_scene             → detener el juego
```

**Ciclo de playtesting:**
1. `play_scene` → iniciar el juego
2. `get_game_screenshot` → ver estado actual
3. `simulate_key` / `simulate_action` → interactuar con el juego
4. `capture_frames` → observar comportamiento a lo largo del tiempo
5. `get_game_node_properties` → verificar valores específicos
6. `stop_scene` → detener cuando termines
7. Corregir problemas en scripts → repetir

### 6. Animaciones

```
# Asegúrate de que exista un nodo AnimationPlayer en la escena
create_animation       → nueva animación con duración y modo de loop
add_animation_track    → agregar tracks de property/transform/method
set_animation_keyframe → insertar keyframes en tiempos específicos
get_animation_info     → inspeccionar animaciones existentes
```

**Ejemplo — sprite rebotando:**
1. `create_animation` name `bounce`, length `1.0`, loop_mode `1` (loop lineal)
2. `add_animation_track` track_path `Sprite2D:position`, track_type `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control, Label, Button, TextureRect, etc.
set_anchor_preset → posicionar Controls (full_rect, center, bottom_wide, etc.)
set_theme_color   → cambiar font_color, etc.
set_theme_font_size → ajustar tamaño de texto
set_theme_stylebox  → fondos, bordes, esquinas redondeadas
connect_signal    → conectar pressed del button, value_changed, etc.
```

### 8. TileMap

```
tilemap_get_info      → revisar fuentes del tile set y disposición del atlas
tilemap_set_cell      → colocar tiles individuales
tilemap_fill_rect     → rellenar regiones rectangulares
tilemap_get_used_cells → ver qué ya está colocado
tilemap_clear         → limpiar todas las celdas
```

### 9. Audio

```
add_audio_bus        → crear buses de audio (SFX, Music, UI)
set_audio_bus        → ajustar volumen, solo, mute
add_audio_bus_effect → agregar reverb, delay, compressor, etc.
add_audio_player     → agregar nodos AudioStreamPlayer(2D/3D)
```

### 10. Configuración del Proyecto

```
set_project_setting  → cambiar tamaño del viewport, configuraciones de física, etc.
set_input_action     → definir mapeos de entrada (move_left → KEY_A, etc.)
add_autoload         → registrar singletons autoload
set_physics_layers   → nombrar capas de colisión (player, enemy, world, etc.)
```

## Reglas Importantes y Trampas

### Valores de Propiedades
Las propiedades se parsean automáticamente desde strings. Usa estos formatos:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` o `"#ff0000"`
- Bool: `"true"` / `"false"`
- Números: `"42"`, `"3.14"`
- Enums: Usa valores enteros (ej: `0` para el primer valor del enum)

### Nunca Edites project.godot Directamente
El editor de Godot sobrescribe `project.godot` constantemente. Siempre usa `set_project_setting` para cambiar configuraciones del proyecto.

### Anotaciones de Tipo en GDScript
Al escribir GDScript con loops `for` sobre arrays sin tipo, usa anotaciones de tipo explícitas:
```gdscript
# MAL — causará errores
for item in some_untyped_array:
    var x := item.value  # la inferencia de tipos falla

# BIEN
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### Los Cambios en Scripts Necesitan Reload
Después de crear o modificar scripts significativamente, usa `reload_project` para asegurar que Godot reconozca los cambios. Esto es especialmente importante después de `create_script`.

### Consejos para simulate_key
- Usa **duraciones cortas** (0.3–0.5 segundos) para movimiento preciso
- Duraciones largas (1+ segundo) causan overshooting
- Para pruebas de gameplay, prefiere `simulate_action` sobre `simulate_key` cuando haya acciones del InputMap definidas

### simulate_mouse_click
- El valor por defecto `auto_release: true` envía press y release — requerido para botones de UI
- Los botones de UI se activan en release, por lo que ambos eventos son necesarios

### Limitaciones de execute_game_script
- Sin funciones anidadas (`func` dentro de `func`) — causa error de compilación
- Usa `.get("property")` en lugar de `.property` para acceso dinámico
- Los errores de runtime pausan el debugger (se continúa automáticamente, pero evítalo si es posible)

### Colisión y Áreas de Recolección
- Para ítems recolectables, usa Area3D/Area2D con radio >= 1.5
- Radios más pequeños son casi imposibles de activar con entrada simulada

### Guarda Frecuentemente
Llama a `save_scene` después de hacer cambios significativos. Los cambios no guardados pueden perderse si el editor se recarga.

## Herramientas de Análisis y Depuración

Cuando algo sale mal, usa estas herramientas para investigar:

```
get_editor_errors          → revisar errores de script y excepciones de runtime
get_output_log             → leer salida de print() y advertencias
analyze_scene_complexity   → encontrar cuellos de botella de rendimiento
analyze_signal_flow        → visualizar conexiones de signals
detect_circular_dependencies → encontrar referencias circulares de script/escena
find_unused_resources      → limpiar archivos no utilizados
get_performance_monitors   → FPS, memoria, draw calls, estadísticas de física
```

## Pruebas y QA

```
run_test_scenario   → definir y ejecutar secuencias de prueba automatizadas
assert_node_state   → verificar que las propiedades de nodos coincidan con valores esperados
assert_screen_text  → verificar que el texto se muestre en pantalla
compare_screenshots → pruebas de regresión visual (usa rutas de archivo, no base64)
run_stress_test     → generar muchos nodos para probar rendimiento
```

## Patrones Avanzados

### Operaciones entre Escenas
```
cross_scene_set_property → modificar nodos en escenas que no están abiertas actualmente
find_node_references     → encontrar todos los archivos que referencian un patrón
batch_set_property       → establecer una propiedad en todos los nodos de un tipo
```

### Flujo de Trabajo con Shaders
```
create_shader        → escribir código shader estilo GLSL
assign_shader_material → aplicar a un nodo
set_shader_param     → ajustar uniforms en runtime
get_shader_params    → inspeccionar valores actuales
```

### Navegación (3D)
```
setup_navigation_region → definir área transitable
bake_navigation_mesh   → generar navmesh
setup_navigation_agent → agregar pathfinding a personajes
```

### AnimationTree y Máquinas de Estado
```
create_animation_tree           → configurar AnimationTree con máquina de estado o blend tree
add_state_machine_state         → agregar estados (idle, walk, run, jump)
add_state_machine_transition    → definir transiciones entre estados
set_tree_parameter              → controlar parámetros de blend
```

## Orden de Flujo de Trabajo Recomendado

Al construir un juego nuevo desde cero:

1. **Configuración del proyecto** — `get_project_info`, `set_project_setting` (viewport, física)
2. **Mapeo de entrada** — `set_input_action` para todos los controles del jugador
3. **Escena principal** — `create_scene`, establecer como escena principal
4. **Jugador** — crear escena del jugador con sprite, colisión, script
5. **Nivel/Mundo** — construir el entorno (TileMap, meshes 3D, etc.)
6. **Lógica del juego** — scripts para enemigos, ítems, UI
7. **Audio** — configurar buses, agregar audio players
8. **Playtesting** — `play_scene`, probar con entrada simulada, corregir bugs
9. **Pulido** — animaciones, partículas, shaders, temas
10. **Exportación** — `list_export_presets`, `export_project`
