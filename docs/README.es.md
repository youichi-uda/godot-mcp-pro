> **Language:** [English](../README.md) | [日本語](README.ja.md) | [Português (BR)](README.pt-br.md) | Español | [Русский](README.ru.md) | [简体中文](README.zh.md) | [हिन्दी](README.hi.md)

# Godot MCP Pro

Servidor MCP (Model Context Protocol) premium para desarrollo de juegos con Godot potenciado por IA. Conecta asistentes de IA como Claude directamente a tu editor de Godot con **187 herramientas potentes**.

## Arquitectura

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Tiempo real**: la conexión WebSocket ofrece respuesta instantánea, sin sondeo de archivos
- **Integración con el editor**: acceso completo a la API del editor de Godot, al sistema UndoRedo y al árbol de escena
- **JSON-RPC 2.0**: protocolo estándar con códigos de error y sugerencias adecuados

## Qué contiene este repositorio

> ⚠️ **Este repositorio público solo contiene el addon/plugin gratuito de Godot.** El servidor MCP (Node.js, necesario para conectar asistentes de IA) se distribuye como parte del paquete de pago — **pago único**, actualizaciones de por vida:
>
> - **Buy Me a Coffee**: <https://buymeacoffee.com/y1uda/extras>
> - **itch.io**: <https://y1uda.itch.io/godot-mcp-pro>
>
> El zip de pago incluye el addon, el directorio `server/` con JavaScript precompilado, `INSTALL.md` e instrucciones para clientes de IA. Si clonaste este repositorio y no ves una carpeta `server/`, **es lo esperado** — descarga el paquete completo desde uno de los enlaces anteriores.

## Inicio rápido

### 1. Instalar el plugin de Godot

Copia la carpeta `addons/godot_mcp/` en el directorio `addons/` de tu proyecto de Godot.

Activa el plugin: **Project → Project Settings → Plugins → Godot MCP Pro → Enable**

### 2. Instalar el servidor MCP

> El directorio `server/` solo se incluye en el **paquete completo de pago** (ver arriba). Después de descargar y extraer el zip, ejecuta:

```bash
cd server
npm install
npm run build
```

### 3. Configurar Claude Code

Añade a tu `.mcp.json`:

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

### 4. Elige tu modo

Godot MCP Pro ofrece cuatro modos para adaptarse al límite de herramientas de cualquier cliente:

| Modo | Herramientas | Ideal para |
|------|-------|----------|
| **Full** (predeterminado) | 187 | Claude Code, Cline, VS Code Copilot, Cursor |
| **3D** (`--3d`) | 100 | Antigravity y otros clientes con límite de 100 herramientas que necesitan 3D |
| **Lite** (`--lite`) | 88 | Windsurf, JetBrains Junie, Gemini CLI |
| **Minimal** (`--minimal`) | 35 | OpenCode, LLM locales con contexto pequeño |

`--3d` incluye las herramientas principales más física, AnimationTree y navegación, pero omite `uid_to_project_path`, `project_path_to_uid`, `compare_screenshots`, `clear_output`, `close_script`, `reload_open_scripts`, `set_anchor_preset` y `click_button_by_text` para no superar el límite de 100 herramientas.

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

Sustituye `--lite` por `--minimal` para la menor huella posible.

- **Lite** incluye: herramientas de project, scene, node, script, editor, input, runtime e input_map.
- **Minimal** incluye: 35 herramientas esenciales — información del proyecto, gestión de escenas, CRUD de nodos, edición de scripts, errores del editor, simulación de entrada e inspección en tiempo de ejecución.

### 5. Modo CLI (alternativa a MCP)

Para clientes sin soporte MCP, o cuando quieres cero sobrecarga de contexto, usa la CLI directamente desde una terminal/herramienta bash. La CLI requiere que el servidor esté compilado primero (Paso 2).

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

Sustituye `/path/to/` por la ruta real donde extrajiste los archivos.

La CLI se conecta directamente al plugin del editor de Godot mediante WebSocket. Requiere:
- El editor de Godot en ejecución con el plugin MCP activado
- El servidor compilado (`node build/setup.js install`)
- Un puerto disponible en el rango 6510-6514

**Ventaja**: los LLM descubren las capacidades de forma progresiva mediante `--help` en lugar de cargar todas las definiciones de herramientas de antemano. Funciona con cualquier cliente LLM que tenga acceso a terminal, independientemente de los límites de herramientas.

### 6. Compatibilidad de clientes

| Cliente | Modo recomendado | Notas |
|--------|-----------------|-------|
| Claude Code | Full (predeterminado) | Carga diferida de herramientas — coste de contexto mínimo |
| VS Code Copilot | Full | Virtual Tools agrupa las herramientas automáticamente |
| OpenAI Codex CLI | Full | MCPSearch difiere el exceso |
| Cline | Full | Sin límite estricto; usa `enabledTools` como lista blanca |
| Roo Code | Full | Sin límite estricto |
| Windsurf | Lite | Límite de 100 herramientas |
| JetBrains Junie | Lite | Límite de 100 herramientas |
| Gemini CLI | Lite | Límite del cliente de ~100; usa `excludeTools` para un control más fino |
| Cursor | Full | Límite de herramientas eliminado (Dynamic Context Discovery) |
| OpenCode | Minimal o CLI | Los modelos empeoran a partir de ~40 herramientas |
| LLM locales (LM Studio, etc.) | Minimal o CLI | La ventana de contexto es el cuello de botella |

### 7. Úsalo

Abre tu proyecto de Godot con el plugin activado y usa Claude Code para interactuar con el editor.

## Las 187 herramientas

### Herramientas de proyecto (10)
| Herramienta | Descripción |
|------|-------------|
| `get_project_info` | Metadatos del proyecto, versión, viewport, autoloads |
| `get_filesystem_tree` | Árbol de archivos recursivo con filtrado |
| `search_files` | Búsqueda de archivos fuzzy/glob |
| `search_in_files` | Buscar contenido en los archivos del proyecto |
| `get_project_settings` | Leer la configuración de project.godot |
| `set_project_setting` | Establecer ajustes del proyecto mediante la API del editor |
| `uid_to_project_path` | Conversión UID → res:// |
| `project_path_to_uid` | Conversión res:// → UID |
| `add_autoload` | Registrar un singleton autoload |
| `remove_autoload` | Eliminar un singleton autoload |

### Herramientas de escena (10)
| Herramienta | Descripción |
|------|-------------|
| `get_scene_tree` | Árbol de escena en vivo con jerarquía |
| `get_scene_file_content` | Contenido sin procesar del archivo .tscn |
| `create_scene` | Crear nuevos archivos de escena |
| `open_scene` | Abrir escena en el editor |
| `delete_scene` | Eliminar archivo de escena |
| `add_scene_instance` | Instanciar escena como nodo hijo |
| `play_scene` | Ejecutar escena (main/current/custom) |
| `stop_scene` | Detener la escena en ejecución |
| `save_scene` | Guardar la escena actual en disco |
| `get_scene_exports` | Listar las variables @export de todos los nodos con script de un archivo de escena |

### Herramientas de nodos (17)
| Herramienta | Descripción |
|------|-------------|
| `add_node` | Añadir nodo con tipo y propiedades |
| `delete_node` | Eliminar nodo (con soporte de deshacer) |
| `duplicate_node` | Duplicar nodo e hijos |
| `move_node` | Mover/cambiar el padre de un nodo |
| `update_property` | Establecer cualquier propiedad (análisis automático de tipos) |
| `get_node_properties` | Obtener todas las propiedades del nodo |
| `add_resource` | Añadir Shape/Material/etc. al nodo |
| `set_anchor_preset` | Establecer el preset de anclaje de un Control |
| `rename_node` | Renombrar un nodo de la escena |
| `connect_signal` | Conectar señal entre nodos |
| `disconnect_signal` | Desconectar conexión de señal |
| `get_node_groups` | Obtener los grupos a los que pertenece un nodo |
| `set_node_groups` | Establecer la pertenencia del nodo a grupos |
| `find_nodes_in_group` | Encontrar todos los nodos de un grupo |
| `get_editor_selection` | Obtener los nodos seleccionados en el dock Scene |
| `select_nodes` | Seleccionar (y opcionalmente enfocar/inspeccionar) nodos en el dock Scene |
| `clear_editor_selection` | Limpiar la selección del dock Scene |

### Herramientas de scripts (9)
| Herramienta | Descripción |
|------|-------------|
| `list_scripts` | Listar todos los scripts con información de clase |
| `read_script` | Leer el contenido de un script |
| `create_script` | Crear nuevo script con plantilla |
| `edit_script` | Buscar/reemplazar o edición completa |
| `attach_script` | Asignar script a un nodo |
| `validate_script` | Validar la sintaxis de GDScript |
| `close_script` | Cerrar una pestaña del editor de scripts; se niega si hay cambios sin guardar salvo que se indique descartarlos (Godot 4.7+) |
| `reload_open_scripts` | Recargar desde disco los scripts abiertos, conservando los búferes sin guardar (Godot 4.7+) |
| `get_open_scripts` | Listar los scripts abiertos en el editor |

### Herramientas del editor (15)
| Herramienta | Descripción |
|------|-------------|
| `get_editor_errors` | Obtener errores y stack traces |
| `get_output_log` | Obtener el contenido del panel de salida |
| `get_editor_screenshot` | Capturar el viewport del editor |
| `get_game_screenshot` | Capturar el juego en ejecución |
| `execute_editor_script` | Ejecutar GDScript arbitrario en el editor |
| `clear_output` | Limpiar el panel de salida |
| `get_signals` | Obtener todas las señales de un nodo con sus conexiones |
| `reload_plugin` | Recargar el plugin MCP (reconexión automática) |
| `reload_project` | Volver a escanear el sistema de archivos y recargar scripts |
| `compare_screenshots` | Comparar dos capturas de pantalla |
| `set_auto_dismiss` | Cerrar automáticamente diálogos bloqueantes del editor ("Reload from disk?", etc.) |
| `get_editor_camera` | Obtener posición/rotación/FOV de la cámara del editor 3D (+ ajustes de snap en 4.6+) |
| `set_editor_camera` | Mover la cámara del editor 3D para encuadrar una vista |
| `get_unsaved_state` | Informar de escenas/scripts abiertos con cambios sin guardar (las listas de cambios sin guardar requieren Godot 4.7+) |
| `save_all` | Guardar todas las escenas abiertas y los búferes de scripts modificados, e informar de lo guardado (los scripts requieren Godot 4.7+) |

### Herramientas de entrada (5)
| Herramienta | Descripción |
|------|-------------|
| `simulate_key` | Simular pulsación/liberación de tecla |
| `simulate_mouse_click` | Simular clic del ratón en una posición |
| `simulate_mouse_move` | Simular movimiento del ratón |
| `simulate_action` | Simular una Input Action de Godot |
| `simulate_sequence` | Secuencia de eventos de entrada con retardos por frames |

### Herramientas de Input Map (2)
| Herramienta | Descripción |
|------|-------------|
| `get_input_actions` | Listar todas las acciones de entrada |
| `set_input_action` | Crear/modificar acción de entrada |

### Herramientas de runtime (20)
| Herramienta | Descripción |
|------|-------------|
| `get_game_scene_tree` | Árbol de escena del juego en ejecución |
| `get_game_node_properties` | Propiedades de nodos en el juego en ejecución |
| `set_game_node_property` | Establecer propiedad de nodo en el juego en ejecución |
| `execute_game_script` | Ejecutar GDScript en el contexto del juego |
| `capture_frames` | Captura de pantalla de múltiples frames |
| `record_frames` | Grabar muchos frames como archivos PNG en disco |
| `monitor_properties` | Registrar valores de propiedades a lo largo del tiempo |
| `watch_signals` | Registrar las emisiones de señales de nodos durante un periodo |
| `start_recording` | Iniciar grabación de entrada |
| `stop_recording` | Detener grabación de entrada |
| `replay_recording` | Reproducir la entrada grabada |
| `find_nodes_by_script` | Encontrar nodos del juego por script |
| `get_autoload` | Obtener propiedades de un nodo autoload |
| `find_ui_elements` | Encontrar elementos de UI en el juego |
| `click_button_by_text` | Hacer clic en un botón por su texto |
| `wait_for_node` | Esperar a que aparezca un nodo |
| `find_nearby_nodes` | Encontrar nodos cerca de una posición |
| `navigate_to` | Navegar a una posición objetivo |
| `move_to` | Hacer caminar al personaje hasta el objetivo |
| `batch_get_properties` | Obtener en lote propiedades de varios nodos |

### Herramientas de animación (6)
| Herramienta | Descripción |
|------|-------------|
| `list_animations` | Listar todas las animaciones de un AnimationPlayer |
| `create_animation` | Crear nueva animación |
| `add_animation_track` | Añadir pista (value/position/rotation/method/bezier) |
| `set_animation_keyframe` | Insertar keyframe en una pista |
| `get_animation_info` | Información detallada de la animación con todas las pistas/claves |
| `remove_animation` | Eliminar una animación |

### Herramientas de TileMap (6)
| Herramienta | Descripción |
|------|-------------|
| `tilemap_set_cell` | Establecer una sola celda |
| `tilemap_fill_rect` | Rellenar una región rectangular con tiles |
| `tilemap_get_cell` | Obtener los datos del tile de una celda |
| `tilemap_clear` | Limpiar todas las celdas |
| `tilemap_get_info` | Información del TileMapLayer y fuentes del tile set |
| `tilemap_get_used_cells` | Lista de celdas usadas |

### Herramientas de tema y UI (8)
| Herramienta | Descripción |
|------|-------------|
| `create_theme` | Crear archivo de recurso Theme |
| `set_theme_color` | Establecer override de color del tema |
| `set_theme_constant` | Establecer override de constante del tema |
| `set_theme_font_size` | Establecer override de tamaño de fuente del tema |
| `set_theme_stylebox` | Establecer override de StyleBoxFlat |
| `setup_control` | Configurar el layout de Control/Container en una sola llamada |
| `add_virtual_joystick` | Añadir un VirtualJoystick en pantalla vinculado a acciones de entrada (Godot 4.7+) |
| `get_theme_info` | Obtener información de overrides del tema |

### Herramientas de profiling (2)
| Herramienta | Descripción |
|------|-------------|
| `get_performance_monitors` | Todos los monitores de rendimiento (FPS, memoria, física, etc.) |
| `get_editor_performance` | Resumen rápido de rendimiento |

### Herramientas de lotes y refactorización (7)
| Herramienta | Descripción |
|------|-------------|
| `find_nodes_by_type` | Encontrar todos los nodos de un tipo |
| `find_signal_connections` | Encontrar todas las conexiones de señales de la escena |
| `batch_set_property` | Establecer una propiedad en todos los nodos de un tipo |
| `batch_add_nodes` | Añadir un árbol de nodos completo en una sola llamada |
| `find_node_references` | Buscar un patrón en los archivos del proyecto |
| `get_scene_dependencies` | Obtener dependencias de recursos |
| `cross_scene_set_property` | Establecer una propiedad en todas las escenas |

### Herramientas de shaders (6)
| Herramienta | Descripción |
|------|-------------|
| `create_shader` | Crear shader con plantilla |
| `read_shader` | Leer archivo de shader |
| `edit_shader` | Editar shader (reemplazar/buscar-reemplazar) |
| `assign_shader_material` | Asignar ShaderMaterial a un nodo |
| `set_shader_param` | Establecer parámetro del shader |
| `get_shader_params` | Obtener todos los parámetros del shader |

### Herramientas de exportación (4)
| Herramienta | Descripción |
|------|-------------|
| `list_export_presets` | Listar presets de exportación |
| `export_project` | Obtener el comando de exportación para un preset |
| `export_patch_pck` | Exportar un PCK de parche solo con los archivos modificados desde los packs base indicados |
| `get_export_info` | Información del proyecto relacionada con la exportación |

### Herramientas de recursos (4)
| Herramienta | Descripción |
|------|-------------|
| `read_resource` | Leer propiedades de un recurso .tres |
| `edit_resource` | Editar propiedades de un recurso |
| `create_resource` | Crear nuevo recurso .tres |
| `get_resource_preview` | Obtener miniatura del recurso |

### Herramientas de física (6)
| Herramienta | Descripción |
|------|-------------|
| `setup_collision` | Añadir formas de colisión a nodos |
| `set_physics_layers` | Establecer capa/máscara de colisión |
| `get_physics_layers` | Obtener información de capa/máscara de colisión |
| `add_raycast` | Añadir nodo RayCast2D/3D |
| `setup_physics_body` | Configurar propiedades del cuerpo físico |
| `get_collision_info` | Obtener detalles de las formas de colisión |

### Herramientas de escena 3D (7)
| Herramienta | Descripción |
|------|-------------|
| `add_mesh_instance` | Añadir MeshInstance3D con malla primitiva |
| `setup_lighting` | Añadir/configurar nodos de luz |
| `set_material_3d` | Establecer propiedades de StandardMaterial3D |
| `setup_environment` | Configurar WorldEnvironment |
| `setup_camera_3d` | Configurar propiedades de Camera3D |
| `add_gridmap` | Configurar nodo GridMap |
| `get_gridmap_info` | Inspeccionar un GridMap: MeshLibrary, límites, recuento por ítem, celdas filtradas (resumen de octantes en 4.7+) |

### Herramientas de partículas (5)
| Herramienta | Descripción |
|------|-------------|
| `create_particles` | Crear GPUParticles2D/3D |
| `set_particle_material` | Configurar ParticleProcessMaterial |
| `set_particle_color_gradient` | Establecer gradiente de color para partículas |
| `apply_particle_preset` | Aplicar preset (fire, smoke, sparks, etc.) |
| `get_particle_info` | Obtener detalles del sistema de partículas |

### Herramientas de navegación (5)
| Herramienta | Descripción |
|------|-------------|
| `setup_navigation_region` | Configurar NavigationRegion |
| `bake_navigation_mesh` | Hornear (bake) la malla de navegación |
| `setup_navigation_agent` | Configurar NavigationAgent |
| `set_navigation_layers` | Establecer capas de navegación |
| `get_navigation_info` | Obtener información de la configuración de navegación |

### Herramientas de audio (6)
| Herramienta | Descripción |
|------|-------------|
| `get_audio_bus_layout` | Obtener información del layout de buses de audio |
| `add_audio_bus` | Añadir bus de audio |
| `set_audio_bus` | Configurar propiedades del bus de audio |
| `add_audio_bus_effect` | Añadir efecto a un bus de audio |
| `add_audio_player` | Añadir nodo AudioStreamPlayer |
| `get_audio_info` | Obtener información de nodos relacionados con audio |

### Herramientas de AnimationTree (9)
| Herramienta | Descripción |
|------|-------------|
| `create_animation_tree` | Crear AnimationTree |
| `get_animation_tree_structure` | Obtener la estructura del árbol |
| `add_state_machine_state` | Añadir estado a la máquina de estados |
| `remove_state_machine_state` | Eliminar estado de la máquina de estados |
| `add_state_machine_transition` | Añadir transición entre estados |
| `remove_state_machine_transition` | Eliminar transición de estado |
| `set_blend_tree_node` | Configurar nodos del blend tree |
| `set_tree_parameter` | Establecer parámetro del AnimationTree |
| `setup_ik_modifier` | Añadir y configurar un SkeletonModifier3D de IK (TwoBoneIK3D, CCDIK3D, FABRIK3D, ...) en un Skeleton3D (Godot 4.6+) |

### Herramientas de análisis y búsqueda (6)
| Herramienta | Descripción |
|------|-------------|
| `find_unused_resources` | Encontrar recursos no referenciados |
| `analyze_signal_flow` | Mapear las conexiones de señales |
| `analyze_scene_complexity` | Analizar el rendimiento de la escena |
| `find_script_references` | Encontrar dónde se usa un script/recurso |
| `detect_circular_dependencies` | Encontrar dependencias circulares entre escenas |
| `get_project_statistics` | Obtener estadísticas de todo el proyecto |

### Herramientas de testing y QA (6)
| Herramienta | Descripción |
|------|-------------|
| `run_test_scenario` | Ejecutar escenario de prueba automatizado |
| `assert_node_state` | Verificar valores de propiedades de nodos |
| `assert_screen_text` | Comprobar texto en pantalla |
| `run_stress_test` | Ejecutar prueba de estrés de rendimiento |
| `set_game_speed` | Leer/establecer el Engine.time_scale del juego en ejecución (cámara lenta / avance rápido) |
| `get_test_report` | Obtener informe de resultados de pruebas |

### Herramientas headless (3)
| Herramienta | Descripción |
|------|-------------|
| `run_headless_scene` | Ejecutar una escena en un proceso de Godot headless separado (p. ej., la suite de pruebas de un proyecto) |
| `run_headless_script` | Ejecutar un script `extends SceneTree` con `godot --headless --script` |
| `get_godot_executable` | Ruta del binario de Godot del editor, ruta del proyecto y plataforma |

### Herramientas de Android (3)
| Herramienta | Descripción |
|------|-------------|
| `list_android_devices` | Listar dispositivos Android visibles para adb |
| `get_android_preset_info` | Leer el nombre de paquete/ruta de exportación de un preset de exportación Android |
| `deploy_to_android` | Exportar APK, instalar mediante adb y lanzar (como Remote Deploy) |

## Características principales

- **Integración con UndoRedo**: todas las operaciones de nodos/propiedades admiten Ctrl+Z
- **Análisis inteligente de tipos**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` se convierten automáticamente
- **Reconexión automática**: reconexión con backoff exponencial (1s → 2s → 4s ... → 60s máx.)
- **Heartbeat**: ping/pong cada 10s mantiene la conexión activa
- **Errores útiles**: las respuestas de error incluyen sugerencias de siguientes pasos

## Comparativa con la competencia

### Número de herramientas

| Categoría | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (gratis) | Dokujaa (gratis) | Coding-Solo (gratis) | ee0pdt (gratis) | bradypp (gratis) |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Proyecto | 10 | 5 | 4 | 0 | 2 | 2 | 2 |
| Escena | 10 | 8 | 11 | 9 | 3 | 4 | 5 |
| Nodos | **17** | 8 | 0 | 8 | 2 | 3 | 0 |
| Scripts | **9** | 5 | 6 | 4 | 0 | 5 | 0 |
| Editor | **15** | 5 | 1 | 5 | 1 | 3 | 2 |
| Entrada | **7** | 2 | 0 | 0 | 0 | 0 | 0 |
| Runtime | **20** | 0 | 0 | 0 | 0 | 0 | 0 |
| Animación | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| TileMap | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Tema/UI | **8** | 0 | 0 | 0 | 0 | 0 | 0 |
| Profiling | **2** | 0 | 0 | 0 | 0 | 0 | 0 |
| Lotes/Refactorización | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| Shaders | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Exportación | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Recursos | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Física | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Escena 3D | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| Partículas | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Navegación | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Audio | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| AnimationTree | **9** | 0 | 0 | 0 | 0 | 0 | 0 |
| Análisis | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Testing/QA | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Assets/IA | 0 | 0 | 1 | 6 | 0 | 0 | 0 |
| Materiales | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| Otros | 0 | 0 | 9 | 5 | 5 | 2 | 1 |
| Headless | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Despliegue Android | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **187** | ~30 | **32** | **39** | **13** | **19** | **10** |

### Matriz de funciones

| Función | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (gratis) | Dokujaa (gratis) | Coding-Solo (gratis) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **Conexión** | WebSocket (tiempo real) | stdio (Python) | WebSocket | Socket TCP | CLI headless |
| **Deshacer/Rehacer** | Sí | Sí | No | No | No |
| **JSON-RPC 2.0** | Sí | Propio | Propio | Propio | N/A |
| **Reconexión automática** | Sí (backoff exponencial) | N/A | No | No | N/A |
| **Heartbeat** | Sí (ping/pong cada 10s) | No | No | No | No |
| **Sugerencias en errores** | Sí (pistas contextuales) | No | No | No | No |
| **Captura de pantalla** | Sí (editor + juego) | Sí | No | No | No |
| **Simulación de entrada en el juego** | Sí (tecla/ratón/acción/secuencia) | Sí (básica) | No | No | No |
| **Inspección en runtime** | Sí (árbol de escena + propiedades + monitorización) | No | No | No | No |
| **Gestión de señales** | Sí (conectar/desconectar/inspeccionar) | No | No | No | No |
| **Visualizador en navegador** | No | No | Sí | No | No |
| **Generación de mallas 3D con IA** | No | No | No | Sí (Meshy API) | No |

### Categorías exclusivas (ningún competidor las tiene)

| Categoría | Herramientas | Por qué importa |
|----------|-------|----------------|
| **Animación** | 6 herramientas | Crear animaciones, añadir pistas, establecer keyframes — todo de forma programática |
| **TileMap** | 6 herramientas | Establecer celdas, rellenar rectángulos, consultar datos de tiles — esencial para el diseño de niveles 2D |
| **Tema/UI** | 8 herramientas | StyleBox, colores, fuentes — crea temas de UI sin trabajo manual en el editor |
| **Profiling** | 2 herramientas | FPS, memoria, draw calls, física — monitorización del rendimiento |
| **Lotes/Refactorización** | 7 herramientas | Búsqueda por tipo, cambios de propiedades en lote, actualizaciones entre escenas, análisis de dependencias |
| **Shaders** | 6 herramientas | Crear/editar shaders, asignar materiales, establecer parámetros |
| **Exportación** | 4 herramientas | Listar presets, obtener comandos de exportación, comprobar plantillas |
| **Física** | 6 herramientas | Configurar formas de colisión, cuerpos, raycasts y gestión de capas |
| **Escena 3D** | 7 herramientas | Añadir mallas, cámaras, luces, entorno, soporte de GridMap |
| **Partículas** | 5 herramientas | Crear partículas con materiales personalizados, presets y gradientes |
| **Navegación** | 5 herramientas | Configurar regiones de navegación, agentes, pathfinding, horneado |
| **Audio** | 6 herramientas | Sistema completo de buses de audio, efectos, reproductores, gestión en vivo |
| **AnimationTree** | 9 herramientas | Máquinas de estados, transiciones, blend trees y modificadores de IK |
| **Testing/QA** | 6 herramientas | Pruebas automatizadas, aserciones, pruebas de estrés, comparación de capturas |
| **Runtime** | 20 herramientas | Inspeccionar y controlar el juego en ejecución: inspeccionar, grabar, reproducir, navegar |

### Ventajas de arquitectura

| Aspecto | Godot MCP Pro | Competidor típico |
|--------|--------------|-------------------|
| **Protocolo** | JSON-RPC 2.0 (estándar, extensible) | JSON propio o basado en CLI |
| **Conexión** | WebSocket persistente con heartbeat | Subproceso por comando o TCP sin procesar |
| **Fiabilidad** | Reconexión automática con backoff exponencial (1s→60s) | Requiere reconexión manual |
| **Seguridad de tipos** | Análisis inteligente de tipos (Vector2, Color, Rect2, colores hex) | Solo cadenas o tipos limitados |
| **Manejo de errores** | Errores estructurados con códigos + sugerencias | Mensajes de error genéricos |
| **Soporte de deshacer** | Todas las mutaciones pasan por el sistema UndoRedo | Modificaciones directas (sin deshacer) |
| **Gestión de puertos** | Escaneo automático de los puertos 6505-6509 | Puerto fijo, posibles conflictos |

## Licencia

Propietaria — consulta [LICENSE](../LICENSE) para más detalles. La compra incluye actualizaciones de por vida.
