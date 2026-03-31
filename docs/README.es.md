> **Language:** [English](../README.md) | [日本語](README.ja.md) | [Português (BR)](README.pt-br.md) | Español | [Русский](README.ru.md) | [简体中文](README.zh.md) | [हिन्दी](README.hi.md)

# Godot MCP Pro

Servidor MCP (Model Context Protocol) premium para desarrollo de juegos con Godot potenciado por IA. Conecta asistentes de IA como Claude directamente a tu editor de Godot con **163 herramientas poderosas**.

## Arquitectura

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Tiempo real**: La conexión WebSocket ofrece retroalimentación instantánea, sin polling de archivos
- **Integración con el editor**: Acceso completo a la API del editor de Godot, sistema UndoRedo y árbol de escenas
- **JSON-RPC 2.0**: Protocolo estándar con códigos de error y sugerencias adecuados

## Inicio Rápido

### 1. Instalar el Plugin de Godot

Copia la carpeta `addons/godot_mcp/` al directorio `addons/` de tu proyecto de Godot.

Activa el plugin: **Proyecto → Configuración del Proyecto → Plugins → Godot MCP Pro → Activar**

### 2. Instalar el Servidor MCP

> **Nota**: El directorio `server/` solo se incluye en el **paquete completo** (de pago).
> Este repositorio de GitHub contiene solo el **addon (plugin)**.
> Adquiere el paquete completo en [godot-mcp.abyo.net](https://godot-mcp.abyo.net/) para obtener el servidor.

```bash
cd server
npm install
npm run build
```

### 3. Configurar Claude Code

Agrega a tu `.mcp.json`:

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

### 4. Auto-Aprobación de Permisos de Herramientas (Recomendado)

Claude Code pide permiso cada vez que se llama a una herramienta. Para omitir estos prompts, copia uno de los presets de permisos incluidos a la configuración de Claude Code:

**Opción A: Conservadora** (predeterminada — bloquea herramientas destructivas)

```bash
cp settings.local.json ~/.claude/settings.local.json
```

Permite 152 de 163 herramientas automáticamente. Las siguientes 11 herramientas seguirán requiriendo aprobación manual:

| Herramienta Bloqueada | Razón |
|---|---|
| `delete_node` | Elimina un nodo de la escena |
| `delete_scene` | Elimina un archivo de escena del disco |
| `remove_animation` | Elimina una animación |
| `remove_autoload` | Elimina un singleton autoload |
| `remove_state_machine_state` | Elimina un estado de la state machine |
| `remove_state_machine_transition` | Elimina una transición de la state machine |
| `execute_editor_script` | Ejecuta código arbitrario en el editor |
| `execute_game_script` | Ejecuta código arbitrario en el juego en ejecución |
| `export_project` | Inicia una exportación del proyecto |
| `tilemap_clear` | Limpia todas las celdas de un TileMapLayer |

**Opción B: Permisiva** (permite todo, deniega comandos peligrosos)

```bash
cp settings.local.permissive.json ~/.claude/settings.local.json
```

Permite las 163 herramientas y todos los comandos Bash. Deniega explícitamente comandos shell destructivos (`rm -rf`, `git push --force`, `git reset --hard`, etc.) y las mismas herramientas MCP destructivas listadas arriba.

> **Nota**: Si ya tienes un `settings.local.json`, fusiona la sección `permissions` manualmente en lugar de sobrescribir.

### 5. Modo Lite (Opcional)

Si tu cliente MCP tiene un límite de herramientas (ej: Windsurf: 100, Cursor: ~40), usa el modo Lite que registra 76 herramientas principales en lugar de 162:

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

El modo Lite incluye: herramientas de project, scene, node, script, editor, input, runtime e input_map.

### 6. Cómo Usar

Abre tu proyecto de Godot con el plugin activado y usa Claude Code para interactuar con el editor.

## Las 162 Herramientas

### Herramientas de Proyecto (7)
| Herramienta | Descripción |
|------|-------------|
| `get_project_info` | Metadatos del proyecto, versión, viewport, autoloads |
| `get_filesystem_tree` | Árbol de archivos recursivo con filtrado |
| `search_files` | Búsqueda de archivos fuzzy/glob |
| `get_project_settings` | Leer configuraciones de project.godot |
| `set_project_setting` | Establecer configuraciones vía API del editor |
| `uid_to_project_path` | Conversión UID → res:// |
| `project_path_to_uid` | Conversión res:// → UID |

### Herramientas de Escena (9)
| Herramienta | Descripción |
|------|-------------|
| `get_scene_tree` | Árbol de escena en vivo con jerarquía |
| `get_scene_file_content` | Contenido bruto del archivo .tscn |
| `create_scene` | Crear nuevos archivos de escena |
| `open_scene` | Abrir escena en el editor |
| `delete_scene` | Eliminar archivo de escena |
| `add_scene_instance` | Instanciar escena como nodo hijo |
| `play_scene` | Ejecutar escena (principal/actual/personalizada) |
| `stop_scene` | Detener escena en ejecución |
| `save_scene` | Guardar escena actual en disco |

### Herramientas de Nodo (14)
| Herramienta | Descripción |
|------|-------------|
| `add_node` | Agregar nodo con tipo y propiedades |
| `delete_node` | Eliminar nodo (con soporte de undo) |
| `duplicate_node` | Duplicar nodo e hijos |
| `move_node` | Mover/reparentar nodo |
| `update_property` | Establecer cualquier propiedad (parseo automático de tipos) |
| `get_node_properties` | Obtener todas las propiedades del nodo |
| `add_resource` | Agregar Shape/Material/etc al nodo |
| `set_anchor_preset` | Establecer preset de ancla del Control |
| `rename_node` | Renombrar un nodo en la escena |
| `connect_signal` | Conectar señal entre nodos |
| `disconnect_signal` | Desconectar conexión de señal |
| `get_node_groups` | Obtener grupos a los que pertenece el nodo |
| `set_node_groups` | Establecer membresía de grupo del nodo |
| `find_nodes_in_group` | Encontrar todos los nodos en un grupo |

### Herramientas de Script (8)
| Herramienta | Descripción |
|------|-------------|
| `list_scripts` | Listar todos los scripts con info de clase |
| `read_script` | Leer contenido del script |
| `create_script` | Crear nuevo script con plantilla |
| `edit_script` | Buscar/reemplazar o edición completa |
| `attach_script` | Adjuntar script al nodo |
| `get_open_scripts` | Listar scripts abiertos en el editor |
| `validate_script` | Validar sintaxis GDScript |
| `search_in_files` | Buscar contenido en archivos del proyecto |

### Herramientas del Editor (9)
| Herramienta | Descripción |
|------|-------------|
| `get_editor_errors` | Obtener errores y stack traces |
| `get_editor_screenshot` | Capturar viewport del editor |
| `get_game_screenshot` | Capturar juego en ejecución |
| `execute_editor_script` | Ejecutar GDScript arbitrario en el editor |
| `clear_output` | Limpiar panel de salida |
| `get_signals` | Obtener todas las señales de un nodo con conexiones |
| `reload_plugin` | Recargar el plugin MCP (reconexión automática) |
| `reload_project` | Reescanear sistema de archivos y recargar scripts |
| `get_output_log` | Obtener contenido del panel de salida |

### Herramientas de Entrada (7)
| Herramienta | Descripción |
|------|-------------|
| `simulate_key` | Simular presión/liberación de tecla |
| `simulate_mouse_click` | Simular clic del mouse en posición |
| `simulate_mouse_move` | Simular movimiento del mouse |
| `simulate_action` | Simular Godot Input Action |
| `simulate_sequence` | Secuencia de eventos de entrada con retrasos de frames |
| `get_input_actions` | Listar todas las acciones de entrada |
| `set_input_action` | Crear/modificar acción de entrada |

### Herramientas de Runtime (19)
| Herramienta | Descripción |
|------|-------------|
| `get_game_scene_tree` | Árbol de escena del juego en ejecución |
| `get_game_node_properties` | Propiedades del nodo en el juego en ejecución |
| `set_game_node_property` | Establecer propiedad del nodo en el juego en ejecución |
| `execute_game_script` | Ejecutar GDScript en contexto del juego |
| `capture_frames` | Captura de screenshots multi-frame |
| `monitor_properties` | Registrar valores de propiedades a lo largo del tiempo |
| `start_recording` | Iniciar grabación de entrada |
| `stop_recording` | Detener grabación de entrada |
| `replay_recording` | Reproducir entrada grabada |
| `find_nodes_by_script` | Encontrar nodos del juego por script |
| `get_autoload` | Obtener propiedades del nodo autoload |
| `batch_get_properties` | Obtener propiedades de múltiples nodos en lote |
| `find_ui_elements` | Encontrar elementos de UI en el juego |
| `click_button_by_text` | Hacer clic en botón por texto |
| `wait_for_node` | Esperar a que aparezca un nodo |
| `find_nearby_nodes` | Encontrar nodos cercanos a una posición |
| `navigate_to` | Navegar a posición objetivo |
| `move_to` | Mover personaje hasta el objetivo |

### Herramientas de Animación (6)
| Herramienta | Descripción |
|------|-------------|
| `list_animations` | Listar todas las animaciones en AnimationPlayer |
| `create_animation` | Crear nueva animación |
| `add_animation_track` | Agregar track (value/position/rotation/method/bezier) |
| `set_animation_keyframe` | Insertar keyframe en track |
| `get_animation_info` | Info detallada de animación con todas las tracks/keys |
| `remove_animation` | Eliminar una animación |

### Herramientas de TileMap (6)
| Herramienta | Descripción |
|------|-------------|
| `tilemap_set_cell` | Establecer una celda de tile |
| `tilemap_fill_rect` | Rellenar región rectangular con tiles |
| `tilemap_get_cell` | Obtener datos del tile en la celda |
| `tilemap_clear` | Limpiar todas las celdas |
| `tilemap_get_info` | Info del TileMapLayer y fuentes del tile set |
| `tilemap_get_used_cells` | Lista de celdas usadas |

### Herramientas de Tema & UI (6)
| Herramienta | Descripción |
|------|-------------|
| `create_theme` | Crear archivo de recurso Theme |
| `set_theme_color` | Establecer override de color del tema |
| `set_theme_constant` | Establecer override de constante del tema |
| `set_theme_font_size` | Establecer override de tamaño de fuente del tema |
| `set_theme_stylebox` | Establecer override de StyleBoxFlat |
| `get_theme_info` | Obtener info de overrides del tema |

### Herramientas de Profiling (2)
| Herramienta | Descripción |
|------|-------------|
| `get_performance_monitors` | Todos los monitores de rendimiento (FPS, memoria, física, etc.) |
| `get_editor_performance` | Resumen rápido de rendimiento |

### Herramientas de Batch & Refactorización (8)
| Herramienta | Descripción |
|------|-------------|
| `find_nodes_by_type` | Encontrar todos los nodos de un tipo |
| `find_signal_connections` | Encontrar todas las conexiones de señal en la escena |
| `batch_set_property` | Establecer propiedad en todos los nodos de un tipo |
| `find_node_references` | Buscar patrón en archivos del proyecto |
| `get_scene_dependencies` | Obtener dependencias de recursos |
| `cross_scene_set_property` | Establecer propiedad en todas las escenas |
| `find_script_references` | Encontrar dónde se usa un script/recurso |
| `detect_circular_dependencies` | Encontrar dependencias circulares de escenas |

### Herramientas de Shader (6)
| Herramienta | Descripción |
|------|-------------|
| `create_shader` | Crear shader con plantilla |
| `read_shader` | Leer archivo de shader |
| `edit_shader` | Editar shader (reemplazar/buscar-reemplazar) |
| `assign_shader_material` | Asignar ShaderMaterial al nodo |
| `set_shader_param` | Establecer parámetro del shader |
| `get_shader_params` | Obtener todos los parámetros del shader |

### Herramientas de Exportación (3)
| Herramienta | Descripción |
|------|-------------|
| `list_export_presets` | Listar presets de exportación |
| `export_project` | Obtener comando de exportación para preset |
| `get_export_info` | Info del proyecto relacionada a exportación |

### Herramientas de Recurso (6)
| Herramienta | Descripción |
|------|-------------|
| `read_resource` | Leer propiedades de recurso .tres |
| `edit_resource` | Editar propiedades de recurso |
| `create_resource` | Crear nuevo recurso .tres |
| `get_resource_preview` | Obtener miniatura del recurso |
| `add_autoload` | Registrar singleton autoload |
| `remove_autoload` | Eliminar singleton autoload |

### Herramientas de Física (6)
| Herramienta | Descripción |
|------|-------------|
| `setup_physics_body` | Configurar propiedades del cuerpo físico |
| `setup_collision` | Agregar formas de colisión a nodos |
| `set_physics_layers` | Establecer capa/máscara de colisión |
| `get_physics_layers` | Obtener info de capa/máscara de colisión |
| `get_collision_info` | Obtener detalles de forma de colisión |
| `add_raycast` | Agregar nodo RayCast2D/3D |

### Herramientas de Escena 3D (6)
| Herramienta | Descripción |
|------|-------------|
| `add_mesh_instance` | Agregar MeshInstance3D con mesh primitiva |
| `setup_camera_3d` | Configurar propiedades de Camera3D |
| `setup_lighting` | Agregar/configurar nodos de luz |
| `setup_environment` | Configurar WorldEnvironment |
| `add_gridmap` | Configurar nodo GridMap |
| `set_material_3d` | Establecer propiedades de StandardMaterial3D |

### Herramientas de Partículas (5)
| Herramienta | Descripción |
|------|-------------|
| `create_particles` | Crear GPUParticles2D/3D |
| `set_particle_material` | Configurar ParticleProcessMaterial |
| `set_particle_color_gradient` | Establecer gradiente de color para partículas |
| `apply_particle_preset` | Aplicar preset (fire, smoke, sparks, etc.) |
| `get_particle_info` | Obtener detalles del sistema de partículas |

### Herramientas de Navegación (6)
| Herramienta | Descripción |
|------|-------------|
| `setup_navigation_region` | Configurar NavigationRegion |
| `setup_navigation_agent` | Configurar NavigationAgent |
| `bake_navigation_mesh` | Hornear mesh de navegación |
| `set_navigation_layers` | Establecer capas de navegación |
| `get_navigation_info` | Obtener info de configuración de navegación |

### Herramientas de Audio (6)
| Herramienta | Descripción |
|------|-------------|
| `add_audio_player` | Agregar nodo AudioStreamPlayer |
| `add_audio_bus` | Agregar bus de audio |
| `add_audio_bus_effect` | Agregar efecto al bus de audio |
| `set_audio_bus` | Configurar propiedades del bus de audio |
| `get_audio_bus_layout` | Obtener info del layout de bus de audio |
| `get_audio_info` | Obtener info de nodos relacionados a audio |

### Herramientas de AnimationTree (4)
| Herramienta | Descripción |
|------|-------------|
| `create_animation_tree` | Crear AnimationTree |
| `get_animation_tree_structure` | Obtener estructura del árbol |
| `set_tree_parameter` | Establecer parámetro de AnimationTree |
| `add_state_machine_state` | Agregar estado a la state machine |

### Herramientas de State Machine (3)
| Herramienta | Descripción |
|------|-------------|
| `remove_state_machine_state` | Eliminar estado de la state machine |
| `add_state_machine_transition` | Agregar transición entre estados |
| `remove_state_machine_transition` | Eliminar transición de estado |

### Herramientas de Blend Tree (1)
| Herramienta | Descripción |
|------|-------------|
| `set_blend_tree_node` | Configurar nodos del blend tree |

### Herramientas de Análisis & Búsqueda (4)
| Herramienta | Descripción |
|------|-------------|
| `analyze_scene_complexity` | Analizar rendimiento de la escena |
| `analyze_signal_flow` | Mapear conexiones de señales |
| `find_unused_resources` | Encontrar recursos no referenciados |
| `get_project_statistics` | Obtener estadísticas del proyecto |

### Herramientas de Testing & QA (6)
| Herramienta | Descripción |
|------|-------------|
| `run_test_scenario` | Ejecutar escenario de prueba automatizado |
| `assert_node_state` | Verificar valores de propiedad del nodo |
| `assert_screen_text` | Verificar texto en pantalla |
| `compare_screenshots` | Comparar dos screenshots |
| `run_stress_test` | Ejecutar prueba de estrés de rendimiento |
| `get_test_report` | Obtener reporte de resultados de prueba |

## Características Principales

- **Integración UndoRedo**: Todas las operaciones de nodo/propiedad soportan Ctrl+Z
- **Parseo Inteligente de Tipos**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` se convierten automáticamente
- **Reconexión Automática**: Reconexión con backoff exponencial (1s → 2s → 4s ... → 60s máx)
- **Heartbeat**: Ping/pong cada 10s mantiene la conexión activa
- **Errores Útiles**: Las respuestas de error incluyen sugerencias para los próximos pasos

## Comparación con Competidores

### Cantidad de Herramientas

| Categoría | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) | ee0pdt (free) | bradypp (free) |
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
| **Total** | **162** | ~30 | **32** | **39** | **13** | **19** | **10** |

### Matriz de Funcionalidades

| Funcionalidad | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **Conexión** | WebSocket (tiempo real) | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | Sí | Sí | No | No | No |
| **JSON-RPC 2.0** | Sí | Personalizado | Personalizado | Personalizado | N/A |
| **Reconexión automática** | Sí (backoff exponencial) | N/A | No | No | N/A |
| **Heartbeat** | Sí (ping/pong 10s) | No | No | No | No |
| **Sugerencias de error** | Sí (pistas contextuales) | No | No | No | No |
| **Captura de pantalla** | Sí (editor + juego) | Sí | No | No | No |
| **Simulación de entrada** | Sí (tecla/mouse/acción/secuencia) | Sí (básico) | No | No | No |
| **Inspección en runtime** | Sí (árbol de escena + propiedades + monitor) | No | No | No | No |
| **Gestión de señales** | Sí (conectar/desconectar/inspeccionar) | No | No | No | No |
| **Visualizador en navegador** | No | No | Sí | No | No |
| **Generación de mesh 3D por IA** | No | No | No | Sí (Meshy API) | No |

### Categorías Exclusivas (Ningún Competidor las Tiene)

| Categoría | Herramientas | Por Qué Importa |
|----------|-------|----------------|
| **Animation** | 6 herramientas | Crear animaciones, agregar tracks, establecer keyframes — todo programáticamente |
| **TileMap** | 6 herramientas | Establecer celdas, rellenar rectángulos, consultar datos de tiles — esencial para diseño de niveles 2D |
| **Theme/UI** | 6 herramientas | StyleBox, colores, fuentes — construir temas de UI sin trabajo manual en el editor |
| **Profiling** | 2 herramientas | FPS, memoria, draw calls, física — monitoreo de rendimiento |
| **Batch/Refactor** | 8 herramientas | Buscar por tipo, cambios de propiedad en lote, actualizaciones entre escenas, análisis de dependencias |
| **Shader** | 6 herramientas | Crear/editar shaders, asignar materiales, establecer parámetros |
| **Export** | 3 herramientas | Listar presets, obtener comandos de exportación, verificar plantillas |
| **Physics** | 6 herramientas | Configurar formas de colisión, cuerpos, raycasts y gestión de capas |
| **3D Scene** | 6 herramientas | Agregar meshes, cámaras, luces, ambiente, soporte GridMap |
| **Particle** | 5 herramientas | Crear partículas con materiales personalizados, presets y gradientes |
| **Navigation** | 6 herramientas | Configurar regiones de navegación, agentes, pathfinding, baking |
| **Audio** | 6 herramientas | Sistema completo de bus de audio, efectos, reproductores, gestión en vivo |
| **AnimationTree** | 4 herramientas | Construir state machines con transiciones y blend trees |
| **State Machine** | 3 herramientas | Gestión avanzada de state machine para animaciones complejas |
| **Testing/QA** | 6 herramientas | Pruebas automatizadas, assertions, pruebas de estrés, comparación de screenshots |
| **Runtime** | 19 herramientas | Inspeccionar y controlar el juego en tiempo de ejecución: inspeccionar, grabar, reproducir, navegar |

### Ventajas de Arquitectura

| Aspecto | Godot MCP Pro | Competidor Típico |
|--------|--------------|-------------------|
| **Protocolo** | JSON-RPC 2.0 (estándar, extensible) | JSON personalizado o basado en CLI |
| **Conexión** | WebSocket persistente con heartbeat | Subproceso por comando o TCP sin procesar |
| **Confiabilidad** | Reconexión automática con backoff exponencial (1s→60s) | Reconexión manual requerida |
| **Seguridad de tipos** | Parseo inteligente de tipos (Vector2, Color, Rect2, colores hex) | Solo strings o tipos limitados |
| **Manejo de errores** | Errores estructurados con códigos + sugerencias | Mensajes de error genéricos |
| **Soporte de Undo** | Todas las mutaciones pasan por el sistema UndoRedo | Modificaciones directas (sin undo) |
| **Gestión de puertos** | Auto-escaneo de puertos 6505-6509 | Puerto fijo, posibles conflictos |

## Licencia

Propietario — consulta [LICENSE](../LICENSE) para más detalles. La compra incluye actualizaciones de por vida para v1.x.
