> **Language:** [English](skills.md) | [日本語](skills.ja.md) | [Português (BR)](skills.pt-br.md) | [Español](skills.es.md) | Русский | [简体中文](skills.zh.md) | [हिन्दी](skills.hi.md)

# Godot MCP Pro — Навыки для ИИ-ассистентов

> Скопируйте этот файл в `.claude/skills.md` в корне вашего проекта Godot, чтобы дать Claude Code полный контекст по эффективному использованию Godot MCP Pro.

## Что такое Godot MCP Pro?

Вам доступны 169 MCP-инструмента, которые напрямую подключаются к редактору Godot 4. Вы можете создавать сцены, писать скрипты, симулировать ввод игрока, инспектировать запущенные игры и многое другое — всё это без выхода пользователя из данного разговора. Все изменения проходят через систему UndoRedo Godot, поэтому пользователь всегда может нажать Ctrl+Z.

## Основные рабочие процессы

### 1. Изучение проекта

Всегда начинайте с понимания проекта перед внесением изменений:

```
get_project_info          → название проекта, версия Godot, рендерер, размер viewport
get_filesystem_tree       → структура директорий (используйте filter: "*.tscn" или "*.gd")
get_scene_tree            → иерархия нод текущей открытой сцены
read_script               → прочитать любой файл GDScript
get_project_settings      → проверить конфигурацию проекта
```

### 2. Создание 2D-сцены

```
create_scene   → создать файл .tscn с указанием типа корневой ноды
add_node       → добавить дочерние ноды со свойствами
create_script  → написать GDScript для игровой логики
attach_script  → прикрепить скрипт к ноде
update_property → установить position, scale, modulate и т.д.
save_scene     → сохранить на диск
```

**Пример — создание игрока:**
1. `create_scene` с root_type `CharacterBody2D`, path `res://scenes/player.tscn`
2. `add_node` типа `Sprite2D` со свойством texture
3. `add_node` типа `CollisionShape2D`
4. `add_resource` для назначения формы (например, `RectangleShape2D`) на CollisionShape2D
5. `create_script` с логикой движения
6. `attach_script` на корневую ноду
7. `save_scene`

### 3. Создание 3D-сцены

```
create_scene         → root_type: Node3D
add_mesh_instance    → добавить примитивы (box, sphere, cylinder, plane) или импортировать .glb/.gltf
setup_lighting       → добавить DirectionalLight3D, OmniLight3D или SpotLight3D
setup_environment    → небо, окружающий свет, туман, tonemap
setup_camera_3d      → камера с опциональным SpringArm3D для вида от третьего лица
set_material_3d      → PBR-материалы (albedo, metallic, roughness, emission)
setup_collision      → добавить формы столкновений к физическим телам
setup_physics_body   → настроить массу, трение, гравитацию
```

### 4. Написание и редактирование скриптов

```
create_script  → создать новый файл .gd (укажите полное содержимое)
edit_script    → изменить существующие скрипты
  - Используйте `replacements: [{search: "old code", replace: "new code"}]` для точечных правок
  - Используйте `content` для полной замены файла
  - Используйте `insert_at_line` + `text` для вставки кода
validate_script → проверить синтаксические ошибки без запуска
read_script    → прочитать текущее содержимое перед редактированием
```

### 5. Тестирование и отладка

```
play_scene             → запустить игру (mode: "current", "main" или путь к файлу)
get_game_screenshot    → увидеть, как игра выглядит прямо сейчас
capture_frames         → захватить несколько кадров для наблюдения за движением/анимацией
get_game_scene_tree    → инспектировать дерево сцены в runtime
get_game_node_properties → прочитать значения в runtime (position, health, state и т.д.)
set_game_node_property → изменить значения в запущенной игре
simulate_key           → нажать клавиши (WASD, SPACE и т.д.) с указанием длительности
simulate_mouse_click   → кликнуть по координатам viewport
simulate_action        → вызвать действия InputMap (move_left, jump и т.д.)
get_editor_errors      → проверить ошибки выполнения
stop_scene             → остановить игру
```

**Цикл плейтестинга:**
1. `play_scene` → запустить игру
2. `get_game_screenshot` → увидеть текущее состояние
3. `simulate_key` / `simulate_action` → взаимодействовать с игрой
4. `capture_frames` → наблюдать поведение во времени
5. `get_game_node_properties` → проверить конкретные значения
6. `stop_scene` → остановить по завершении
7. Исправить проблемы в скриптах → повторить

### 6. Анимации

```
# Убедитесь, что в сцене есть нода AnimationPlayer
create_animation       → новая анимация с длительностью и режимом зацикливания
add_animation_track    → добавить треки property/transform/method
set_animation_keyframe → вставить ключевые кадры в определённые моменты
get_animation_info     → просмотреть существующие анимации
```

**Пример — прыгающий спрайт:**
1. `create_animation` name `bounce`, length `1.0`, loop_mode `1` (линейный цикл)
2. `add_animation_track` track_path `Sprite2D:position`, track_type `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control, Label, Button, TextureRect и т.д.
set_anchor_preset → позиционирование Controls (full_rect, center, bottom_wide и т.д.)
set_theme_color   → изменить font_color и т.д.
set_theme_font_size → настроить размер текста
set_theme_stylebox  → фоны, рамки, скруглённые углы
connect_signal    → подключить pressed кнопки, value_changed и т.д.
```

### 8. TileMap

```
tilemap_get_info      → проверить источники набора тайлов и раскладку атласа
tilemap_set_cell      → разместить отдельные тайлы
tilemap_fill_rect     → заполнить прямоугольные области
tilemap_get_used_cells → посмотреть, что уже размещено
tilemap_clear         → очистить все ячейки
```

### 9. Аудио

```
add_audio_bus        → создать аудио-шины (SFX, Music, UI)
set_audio_bus        → настроить громкость, соло, заглушение
add_audio_bus_effect → добавить реверберацию, задержку, компрессор и т.д.
add_audio_player     → добавить ноды AudioStreamPlayer(2D/3D)
```

### 10. Конфигурация проекта

```
set_project_setting  → изменить размер viewport, настройки физики и т.д.
set_input_action     → определить маппинг ввода (move_left → KEY_A и т.д.)
add_autoload         → зарегистрировать синглтоны autoload
set_physics_layers   → именовать слои столкновений (player, enemy, world и т.д.)
```

## Важные правила и подводные камни

### Значения свойств
Свойства автоматически парсятся из строк. Используйте следующие форматы:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` или `"#ff0000"`
- Bool: `"true"` / `"false"`
- Числа: `"42"`, `"3.14"`
- Enum: Используйте целочисленные значения (например, `0` для первого значения enum)

### Никогда не редактируйте project.godot напрямую
Редактор Godot постоянно перезаписывает `project.godot`. Всегда используйте `set_project_setting` для изменения настроек проекта.

### Аннотации типов в GDScript
При написании GDScript с циклами `for` по нетипизированным массивам используйте явные аннотации типов:
```gdscript
# ПЛОХО — приведёт к ошибкам
for item in some_untyped_array:
    var x := item.value  # вывод типов не работает

# ХОРОШО
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### Изменения скриптов требуют перезагрузки
После создания или значительного изменения скриптов используйте `reload_project`, чтобы Godot подхватил изменения. Особенно важно после `create_script`.

### Советы по simulate_key
- Используйте **короткие длительности** (0.3–0.5 секунд) для точного перемещения
- Длинные длительности (1+ секунда) приводят к промахам
- Для тестирования геймплея предпочитайте `simulate_action` вместо `simulate_key`, когда определены действия InputMap

### simulate_mouse_click
- По умолчанию `auto_release: true` отправляет press и release — необходимо для UI-кнопок
- UI-кнопки срабатывают на release, поэтому нужны оба события

### Ограничения execute_game_script
- Нельзя использовать вложенные функции (`func` внутри `func`) — вызывает ошибку компиляции
- Используйте `.get("property")` вместо `.property` для динамического доступа
- Ошибки выполнения приостанавливают отладчик (автоматически продолжается, но лучше избегать)

### Коллизии и области подбора
- Для собираемых предметов используйте Area3D/Area2D с радиусом >= 1.5
- Меньшие радиусы почти невозможно активировать симулированным вводом

### Сохраняйте часто
Вызывайте `save_scene` после значительных изменений. Несохранённые изменения могут быть потеряны при перезагрузке редактора.

## Инструменты анализа и отладки

Когда что-то пошло не так, используйте эти инструменты для расследования:

```
get_editor_errors          → проверить ошибки скриптов и исключения runtime
get_output_log             → прочитать вывод print() и предупреждения
analyze_scene_complexity   → найти узкие места производительности
analyze_signal_flow        → визуализировать соединения сигналов
detect_circular_dependencies → найти циклические ссылки скриптов/сцен
find_unused_resources      → очистить неиспользуемые файлы
get_performance_monitors   → FPS, память, draw calls, статистика физики
```

## Тестирование и QA

```
run_test_scenario   → определить и запустить автоматизированные тестовые сценарии
assert_node_state   → проверить, что свойства нод соответствуют ожидаемым значениям
assert_screen_text  → проверить, что текст отображается на экране
compare_screenshots → визуальное регрессионное тестирование (используйте пути к файлам, не base64)
run_stress_test     → создать множество нод для тестирования производительности
```

## Продвинутые паттерны

### Операции между сценами
```
cross_scene_set_property → изменить ноды в сценах, которые сейчас не открыты
find_node_references     → найти все файлы, ссылающиеся на паттерн
batch_set_property       → установить свойство для всех нод определённого типа
```

### Работа с шейдерами
```
create_shader        → написать шейдерный код в стиле GLSL
assign_shader_material → применить к ноде
set_shader_param     → настроить uniform-параметры в runtime
get_shader_params    → просмотреть текущие значения
```

### Навигация (3D)
```
setup_navigation_region → определить проходимую область
bake_navigation_mesh   → сгенерировать навигационную сетку
setup_navigation_agent → добавить поиск пути для персонажей
```

### AnimationTree и конечные автоматы
```
create_animation_tree           → настроить AnimationTree с конечным автоматом или деревом смешивания
add_state_machine_state         → добавить состояния (idle, walk, run, jump)
add_state_machine_transition    → определить переходы между состояниями
set_tree_parameter              → управлять параметрами смешивания
```

## Рекомендуемый порядок работы

При создании новой игры с нуля:

1. **Настройка проекта** — `get_project_info`, `set_project_setting` (viewport, физика)
2. **Маппинг ввода** — `set_input_action` для всех управлений игрока
3. **Главная сцена** — `create_scene`, установить как главную сцену
4. **Игрок** — создать сцену игрока со спрайтом, коллизией, скриптом
5. **Уровень/Мир** — построить окружение (TileMap, 3D-меши и т.д.)
6. **Игровая логика** — скрипты для врагов, предметов, UI
7. **Аудио** — настроить шины, добавить аудиоплееры
8. **Плейтестинг** — `play_scene`, тест с симулированным вводом, исправление багов
9. **Полировка** — анимации, частицы, шейдеры, темы
10. **Экспорт** — `list_export_presets`, `export_project`
