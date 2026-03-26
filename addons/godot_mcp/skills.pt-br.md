> **Language:** [English](skills.md) | [日本語](skills.ja.md) | Português (BR) | [Español](skills.es.md) | [Русский](skills.ru.md) | [简体中文](skills.zh.md) | [हिन्दी](skills.hi.md)

# Godot MCP Pro — Skills para Assistentes de IA

> Copie este arquivo para `.claude/skills.md` na raiz do seu projeto Godot para dar ao Claude Code o contexto completo de como usar o Godot MCP Pro de forma eficiente.

## O que é o Godot MCP Pro?

Você tem acesso a 162 ferramentas MCP que se conectam diretamente ao editor Godot 4. Você pode criar cenas, escrever scripts, simular entrada do jogador, inspecionar jogos em execução e muito mais — tudo sem que o usuário precise sair desta conversa. Todas as alterações passam pelo sistema UndoRedo do Godot, então o usuário pode sempre usar Ctrl+Z.

## Fluxos de Trabalho Essenciais

### 1. Explorar um Projeto

Sempre comece entendendo o projeto antes de fazer alterações:

```
get_project_info          → nome do projeto, versão do Godot, renderizador, tamanho do viewport
get_filesystem_tree       → estrutura de diretórios (use filter: "*.tscn" ou "*.gd")
get_scene_tree            → hierarquia de nós da cena atualmente aberta
read_script               → ler qualquer arquivo GDScript
get_project_settings      → verificar configuração do projeto
```

### 2. Construir uma Cena 2D

```
create_scene   → criar arquivo .tscn com tipo de nó raiz
add_node       → adicionar nós filhos com propriedades
create_script  → escrever GDScript para lógica do jogo
attach_script  → anexar script a um nó
update_property → definir position, scale, modulate, etc.
save_scene     → salvar no disco
```

**Exemplo — criando um jogador:**
1. `create_scene` com root_type `CharacterBody2D`, path `res://scenes/player.tscn`
2. `add_node` tipo `Sprite2D` com propriedade texture
3. `add_node` tipo `CollisionShape2D`
4. `add_resource` para atribuir uma shape (ex: `RectangleShape2D`) ao CollisionShape2D
5. `create_script` com lógica de movimento
6. `attach_script` ao nó raiz
7. `save_scene`

### 3. Construir uma Cena 3D

```
create_scene         → root_type: Node3D
add_mesh_instance    → adicionar primitivas (box, sphere, cylinder, plane) ou importar .glb/.gltf
setup_lighting       → adicionar DirectionalLight3D, OmniLight3D ou SpotLight3D
setup_environment    → céu, luz ambiente, neblina, tonemap
setup_camera_3d      → câmera com SpringArm3D opcional para terceira pessoa
set_material_3d      → materiais PBR (albedo, metallic, roughness, emission)
setup_collision      → adicionar shapes de colisão a corpos físicos
setup_physics_body   → configurar massa, atrito, gravidade
```

### 4. Escrever e Editar Scripts

```
create_script  → criar novo arquivo .gd (forneça o conteúdo completo)
edit_script    → modificar scripts existentes
  - Use `replacements: [{search: "old code", replace: "new code"}]` para edições pontuais
  - Use `content` para substituição completa do arquivo
  - Use `insert_at_line` + `text` para inserir código
validate_script → verificar erros de sintaxe sem executar
read_script    → ler conteúdo atual antes de editar
```

### 5. Testar e Depurar

```
play_scene             → iniciar o jogo (mode: "current", "main" ou caminho do arquivo)
get_game_screenshot    → ver como o jogo está neste momento
capture_frames         → capturar múltiplos frames para observar movimento/animação
get_game_scene_tree    → inspecionar a árvore de cena em tempo de execução
get_game_node_properties → ler valores em runtime (position, health, state, etc.)
set_game_node_property → modificar valores no jogo em execução
simulate_key           → pressionar teclas (WASD, SPACE, etc.) com duração
simulate_mouse_click   → clicar em coordenadas do viewport
simulate_action        → disparar ações do InputMap (move_left, jump, etc.)
get_editor_errors      → verificar erros de execução
stop_scene             → parar o jogo
```

**Loop de playtesting:**
1. `play_scene` → iniciar o jogo
2. `get_game_screenshot` → ver estado atual
3. `simulate_key` / `simulate_action` → interagir com o jogo
4. `capture_frames` → observar comportamento ao longo do tempo
5. `get_game_node_properties` → verificar valores específicos
6. `stop_scene` → parar quando terminar
7. Corrigir problemas nos scripts → repetir

### 6. Animações

```
# Certifique-se de que existe um nó AnimationPlayer na cena
create_animation       → nova animação com duração e modo de loop
add_animation_track    → adicionar tracks de property/transform/method
set_animation_keyframe → inserir keyframes em tempos específicos
get_animation_info     → inspecionar animações existentes
```

**Exemplo — sprite quicando:**
1. `create_animation` name `bounce`, length `1.0`, loop_mode `1` (loop linear)
2. `add_animation_track` track_path `Sprite2D:position`, track_type `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control, Label, Button, TextureRect, etc.
set_anchor_preset → posicionar Controls (full_rect, center, bottom_wide, etc.)
set_theme_color   → alterar font_color, etc.
set_theme_font_size → ajustar tamanho do texto
set_theme_stylebox  → fundos, bordas, cantos arredondados
connect_signal    → conectar pressed do button, value_changed, etc.
```

### 8. TileMap

```
tilemap_get_info      → verificar fontes do tile set e layout do atlas
tilemap_set_cell      → colocar tiles individuais
tilemap_fill_rect     → preencher regiões retangulares
tilemap_get_used_cells → ver o que já está colocado
tilemap_clear         → limpar todas as células
```

### 9. Áudio

```
add_audio_bus        → criar buses de áudio (SFX, Music, UI)
set_audio_bus        → ajustar volume, solo, mute
add_audio_bus_effect → adicionar reverb, delay, compressor, etc.
add_audio_player     → adicionar nós AudioStreamPlayer(2D/3D)
```

### 10. Configuração do Projeto

```
set_project_setting  → alterar tamanho do viewport, configurações de física, etc.
set_input_action     → definir mapeamentos de entrada (move_left → KEY_A, etc.)
add_autoload         → registrar singletons autoload
set_physics_layers   → nomear camadas de colisão (player, enemy, world, etc.)
```

## Regras Importantes e Armadilhas

### Valores de Propriedade
Propriedades são parseadas automaticamente de strings. Use estes formatos:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` ou `"#ff0000"`
- Bool: `"true"` / `"false"`
- Números: `"42"`, `"3.14"`
- Enums: Use valores inteiros (ex: `0` para o primeiro valor do enum)

### Nunca Edite project.godot Diretamente
O editor Godot sobrescreve `project.godot` constantemente. Sempre use `set_project_setting` para alterar configurações do projeto.

### Anotações de Tipo em GDScript
Ao escrever GDScript com loops `for` sobre arrays sem tipo, use anotações de tipo explícitas:
```gdscript
# RUIM — vai causar erros
for item in some_untyped_array:
    var x := item.value  # inferência de tipo falha

# BOM
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### Alterações em Scripts Precisam de Reload
Após criar ou modificar scripts significativamente, use `reload_project` para garantir que o Godot reconheça as alterações. Isso é especialmente importante após `create_script`.

### Dicas para simulate_key
- Use **durações curtas** (0.3–0.5 segundos) para movimentos precisos
- Durações longas (1+ segundo) causam overshooting
- Para testes de gameplay, prefira `simulate_action` em vez de `simulate_key` quando ações do InputMap estiverem definidas

### simulate_mouse_click
- O padrão `auto_release: true` envia press e release — necessário para botões de UI
- Botões de UI disparam no release, então ambos os eventos são necessários

### Limitações do execute_game_script
- Sem funções aninhadas (`func` dentro de `func`) — causa erro de compilação
- Use `.get("property")` em vez de `.property` para acesso dinâmico
- Erros de runtime pausam o debugger (continuado automaticamente, mas evite se possível)

### Colisão e Áreas de Coleta
- Para itens coletáveis, use Area3D/Area2D com raio >= 1.5
- Raios menores são quase impossíveis de acionar com entrada simulada

### Salve com Frequência
Chame `save_scene` após fazer alterações significativas. Alterações não salvas podem ser perdidas se o editor recarregar.

## Ferramentas de Análise e Depuração

Quando algo der errado, use estas ferramentas para investigar:

```
get_editor_errors          → verificar erros de script e exceções de runtime
get_output_log             → ler saída de print() e avisos
analyze_scene_complexity   → encontrar gargalos de performance
analyze_signal_flow        → visualizar conexões de signals
detect_circular_dependencies → encontrar referências circulares de script/cena
find_unused_resources      → limpar arquivos não utilizados
get_performance_monitors   → FPS, memória, draw calls, estatísticas de física
```

## Testes e QA

```
run_test_scenario   → definir e executar sequências de teste automatizadas
assert_node_state   → verificar se propriedades de nós correspondem aos valores esperados
assert_screen_text  → verificar se texto está exibido na tela
compare_screenshots → teste de regressão visual (use caminhos de arquivo, não base64)
run_stress_test     → gerar muitos nós para testar performance
```

## Padrões Avançados

### Operações entre Cenas
```
cross_scene_set_property → modificar nós em cenas que não estão abertas atualmente
find_node_references     → encontrar todos os arquivos que referenciam um padrão
batch_set_property       → definir uma propriedade em todos os nós de um tipo
```

### Fluxo de Trabalho com Shaders
```
create_shader        → escrever código shader estilo GLSL
assign_shader_material → aplicar a um nó
set_shader_param     → ajustar uniforms em runtime
get_shader_params    → inspecionar valores atuais
```

### Navegação (3D)
```
setup_navigation_region → definir área caminhável
bake_navigation_mesh   → gerar navmesh
setup_navigation_agent → adicionar pathfinding a personagens
```

### AnimationTree e Máquinas de Estado
```
create_animation_tree           → configurar AnimationTree com máquina de estado ou blend tree
add_state_machine_state         → adicionar estados (idle, walk, run, jump)
add_state_machine_transition    → definir transições entre estados
set_tree_parameter              → controlar parâmetros de blend
```

## Ordem de Fluxo de Trabalho Recomendada

Ao construir um novo jogo do zero:

1. **Configuração do projeto** — `get_project_info`, `set_project_setting` (viewport, física)
2. **Mapeamento de entrada** — `set_input_action` para todos os controles do jogador
3. **Cena principal** — `create_scene`, definir como cena principal
4. **Jogador** — criar cena do jogador com sprite, colisão, script
5. **Nível/Mundo** — construir o ambiente (TileMap, meshes 3D, etc.)
6. **Lógica do jogo** — scripts para inimigos, itens, UI
7. **Áudio** — configurar buses, adicionar audio players
8. **Playtesting** — `play_scene`, testar com entrada simulada, corrigir bugs
9. **Polimento** — animações, partículas, shaders, temas
10. **Exportação** — `list_export_presets`, `export_project`
