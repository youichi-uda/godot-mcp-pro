> **Language:** [English](../README.md) | [日本語](README.ja.md) | Português (BR) | [Español](README.es.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | [हिन्दी](README.hi.md)

# Godot MCP Pro

Servidor MCP (Model Context Protocol) premium para desenvolvimento de jogos Godot com IA. Conecta assistentes de IA como o Claude diretamente ao seu editor Godot com **187 ferramentas poderosas**.

## Arquitetura

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Tempo real**: a conexão WebSocket garante feedback instantâneo, sem polling de arquivos
- **Integração com o editor**: acesso completo à API do editor do Godot, ao sistema UndoRedo e à árvore de cena
- **JSON-RPC 2.0**: protocolo padrão com códigos de erro e sugestões adequados

## O que há neste repositório

> ⚠️ **Este repositório público contém apenas o addon/plugin gratuito do Godot.** O servidor MCP (Node.js, necessário para conectar assistentes de IA) é distribuído como parte do pacote pago — **compra única**, atualizações vitalícias:
>
> - **Buy Me a Coffee**: <https://buymeacoffee.com/y1uda/extras>
> - **itch.io**: <https://y1uda.itch.io/godot-mcp-pro>
>
> O zip pago inclui o addon, o diretório `server/` com JavaScript pré-compilado, `INSTALL.md` e instruções para clientes de IA. Se você clonou este repositório e não vê uma pasta `server/`, **isso é esperado** — obtenha o pacote completo em um dos links acima.

## Início rápido

### 1. Instale o plugin do Godot

Copie a pasta `addons/godot_mcp/` para o diretório `addons/` do seu projeto Godot.

Ative o plugin: **Project → Project Settings → Plugins → Godot MCP Pro → Enable**

### 2. Instale o servidor MCP

> O diretório `server/` só está incluído no **pacote pago completo** (veja acima). Depois de baixar e extrair o zip, execute:

```bash
cd server
npm install
npm run build
```

### 3. Configure o Claude Code

Adicione ao seu `.mcp.json`:

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

### 4. Escolha seu modo

O Godot MCP Pro oferece quatro modos para se adequar ao limite de ferramentas de qualquer cliente:

| Modo | Ferramentas | Ideal para |
|------|-------|----------|
| **Full** (padrão) | 187 | Claude Code, Cline, VS Code Copilot, Cursor |
| **3D** (`--3d`) | 100 | Antigravity e outros clientes com limite de 100 ferramentas que precisam de 3D |
| **Lite** (`--lite`) | 88 | Windsurf, JetBrains Junie, Gemini CLI |
| **Minimal** (`--minimal`) | 35 | OpenCode, LLMs locais com contexto pequeno |

`--3d` inclui as ferramentas principais mais física, AnimationTree e navegação, mas omite `uid_to_project_path`, `project_path_to_uid`, `compare_screenshots`, `clear_output`, `close_script`, `reload_open_scripts`, `set_anchor_preset` e `click_button_by_text` para ficar dentro do limite de 100 ferramentas.

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

Substitua `--lite` por `--minimal` para o menor footprint possível.

- **Lite** inclui: ferramentas de project, scene, node, script, editor, input, runtime e input_map.
- **Minimal** inclui: 35 ferramentas essenciais — informações do projeto, gerenciamento de cenas, CRUD de nós, edição de scripts, erros do editor, simulação de entrada e inspeção em tempo de execução.

### 5. Modo CLI (alternativa ao MCP)

Para clientes sem suporte a MCP, ou quando você quer zero overhead de contexto, use a CLI diretamente de um terminal/ferramenta bash. A CLI exige que o servidor seja compilado primeiro (Passo 2).

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

Substitua `/path/to/` pelo caminho real onde você extraiu os arquivos.

A CLI se conecta diretamente ao plugin do editor Godot via WebSocket. Ela exige:
- Editor Godot em execução com o plugin MCP ativado
- Servidor compilado (`node build/setup.js install`)
- Uma porta disponível na faixa 6510-6514

**Vantagem**: os LLMs descobrem as capacidades progressivamente via `--help` em vez de carregar todas as definições de ferramentas de uma vez. Funciona com qualquer cliente LLM que tenha acesso ao terminal, independentemente de limites de ferramentas.

### 6. Compatibilidade de clientes

| Cliente | Modo recomendado | Observações |
|--------|-----------------|-------|
| Claude Code | Full (padrão) | Carregamento adiado de ferramentas — custo de contexto mínimo |
| VS Code Copilot | Full | Virtual Tools agrupa as ferramentas automaticamente |
| OpenAI Codex CLI | Full | MCPSearch adia o excedente |
| Cline | Full | Sem limite rígido; use `enabledTools` como whitelist |
| Roo Code | Full | Sem limite rígido |
| Windsurf | Lite | Limite de 100 ferramentas |
| JetBrains Junie | Lite | Limite de 100 ferramentas |
| Gemini CLI | Lite | Limite do cliente de ~100; use `excludeTools` para controle mais fino |
| Cursor | Full | Limite de ferramentas removido (Dynamic Context Discovery) |
| OpenCode | Minimal ou CLI | Os modelos pioram acima de ~40 ferramentas |
| LLMs locais (LM Studio, etc.) | Minimal ou CLI | A janela de contexto é o gargalo |

### 7. Use

Abra seu projeto Godot com o plugin ativado e use o Claude Code para interagir com o editor.

## Todas as 187 ferramentas

### Ferramentas de projeto (10)
| Ferramenta | Descrição |
|------|-------------|
| `get_project_info` | Metadados do projeto, versão, viewport, autoloads |
| `get_filesystem_tree` | Árvore de arquivos recursiva com filtragem |
| `search_files` | Busca de arquivos fuzzy/glob |
| `search_in_files` | Buscar conteúdo nos arquivos do projeto |
| `get_project_settings` | Ler configurações do project.godot |
| `set_project_setting` | Definir configurações do projeto via API do editor |
| `uid_to_project_path` | Conversão UID → res:// |
| `project_path_to_uid` | Conversão res:// → UID |
| `add_autoload` | Registrar singleton autoload |
| `remove_autoload` | Remover singleton autoload |

### Ferramentas de cena (10)
| Ferramenta | Descrição |
|------|-------------|
| `get_scene_tree` | Árvore de cena ao vivo com hierarquia |
| `get_scene_file_content` | Conteúdo bruto do arquivo .tscn |
| `create_scene` | Criar novos arquivos de cena |
| `open_scene` | Abrir cena no editor |
| `delete_scene` | Excluir arquivo de cena |
| `add_scene_instance` | Instanciar cena como nó filho |
| `play_scene` | Executar cena (main/current/custom) |
| `stop_scene` | Parar a cena em execução |
| `save_scene` | Salvar a cena atual em disco |
| `get_scene_exports` | Listar as variáveis @export de todos os nós com script em um arquivo de cena |

### Ferramentas de nós (17)
| Ferramenta | Descrição |
|------|-------------|
| `add_node` | Adicionar nó com tipo e propriedades |
| `delete_node` | Excluir nó (com suporte a desfazer) |
| `duplicate_node` | Duplicar nó e filhos |
| `move_node` | Mover/alterar o pai de um nó |
| `update_property` | Definir qualquer propriedade (parsing automático de tipos) |
| `get_node_properties` | Obter todas as propriedades do nó |
| `add_resource` | Adicionar Shape/Material/etc. ao nó |
| `set_anchor_preset` | Definir preset de âncora de um Control |
| `rename_node` | Renomear um nó na cena |
| `connect_signal` | Conectar sinal entre nós |
| `disconnect_signal` | Desconectar conexão de sinal |
| `get_node_groups` | Obter os grupos aos quais um nó pertence |
| `set_node_groups` | Definir a participação do nó em grupos |
| `find_nodes_in_group` | Encontrar todos os nós de um grupo |
| `get_editor_selection` | Obter os nós selecionados no dock Scene |
| `select_nodes` | Selecionar (e opcionalmente focar/inspecionar) nós no dock Scene |
| `clear_editor_selection` | Limpar a seleção do dock Scene |

### Ferramentas de script (9)
| Ferramenta | Descrição |
|------|-------------|
| `list_scripts` | Listar todos os scripts com informações de classe |
| `read_script` | Ler conteúdo do script |
| `create_script` | Criar novo script a partir de template |
| `edit_script` | Buscar/substituir ou edição completa |
| `attach_script` | Anexar script a um nó |
| `validate_script` | Validar sintaxe GDScript |
| `close_script` | Fechar uma aba do editor de scripts; recusa se houver edições não salvas, a menos que seja instruído a descartá-las (Godot 4.7+) |
| `reload_open_scripts` | Recarregar do disco os scripts abertos, mantendo os buffers não salvos (Godot 4.7+) |
| `get_open_scripts` | Listar scripts abertos no editor |

### Ferramentas do editor (15)
| Ferramenta | Descrição |
|------|-------------|
| `get_editor_errors` | Obter erros e stack traces |
| `get_output_log` | Obter o conteúdo do painel de saída |
| `get_editor_screenshot` | Capturar o viewport do editor |
| `get_game_screenshot` | Capturar o jogo em execução |
| `execute_editor_script` | Executar GDScript arbitrário no editor |
| `clear_output` | Limpar o painel de saída |
| `get_signals` | Obter todos os sinais de um nó com suas conexões |
| `reload_plugin` | Recarregar o plugin MCP (reconexão automática) |
| `reload_project` | Reescanear o sistema de arquivos e recarregar scripts |
| `compare_screenshots` | Comparar duas capturas de tela |
| `set_auto_dismiss` | Fechar automaticamente diálogos bloqueantes do editor ("Reload from disk?" etc.) |
| `get_editor_camera` | Obter posição/rotação/FOV da câmera do editor 3D (+ configurações de snap no 4.6+) |
| `set_editor_camera` | Mover a câmera do editor 3D para enquadrar uma vista |
| `get_unsaved_state` | Informar cenas/scripts abertos com alterações não salvas (as listas de não salvos exigem Godot 4.7+) |
| `save_all` | Salvar todas as cenas abertas e os buffers de scripts modificados, informando o que foi salvo (scripts exigem Godot 4.7+) |

### Ferramentas de entrada (5)
| Ferramenta | Descrição |
|------|-------------|
| `simulate_key` | Simular pressionar/soltar tecla |
| `simulate_mouse_click` | Simular clique do mouse em uma posição |
| `simulate_mouse_move` | Simular movimento do mouse |
| `simulate_action` | Simular uma Input Action do Godot |
| `simulate_sequence` | Sequência de eventos de entrada com atrasos em frames |

### Ferramentas de Input Map (2)
| Ferramenta | Descrição |
|------|-------------|
| `get_input_actions` | Listar todas as ações de entrada |
| `set_input_action` | Criar/modificar ação de entrada |

### Ferramentas de runtime (20)
| Ferramenta | Descrição |
|------|-------------|
| `get_game_scene_tree` | Árvore de cena do jogo em execução |
| `get_game_node_properties` | Propriedades de nós no jogo em execução |
| `set_game_node_property` | Definir propriedade de nó no jogo em execução |
| `execute_game_script` | Executar GDScript no contexto do jogo |
| `capture_frames` | Captura de tela de múltiplos frames |
| `record_frames` | Gravar muitos frames como arquivos PNG em disco |
| `monitor_properties` | Registrar valores de propriedades ao longo do tempo |
| `watch_signals` | Registrar emissões de sinais de nós durante um período |
| `start_recording` | Iniciar gravação de entrada |
| `stop_recording` | Parar gravação de entrada |
| `replay_recording` | Reproduzir a entrada gravada |
| `find_nodes_by_script` | Encontrar nós do jogo por script |
| `get_autoload` | Obter propriedades de um nó autoload |
| `find_ui_elements` | Encontrar elementos de UI no jogo |
| `click_button_by_text` | Clicar em um botão pelo texto |
| `wait_for_node` | Aguardar um nó aparecer |
| `find_nearby_nodes` | Encontrar nós próximos a uma posição |
| `navigate_to` | Navegar até a posição alvo |
| `move_to` | Fazer o personagem andar até o alvo |
| `batch_get_properties` | Obter em lote propriedades de vários nós |

### Ferramentas de animação (6)
| Ferramenta | Descrição |
|------|-------------|
| `list_animations` | Listar todas as animações de um AnimationPlayer |
| `create_animation` | Criar nova animação |
| `add_animation_track` | Adicionar trilha (value/position/rotation/method/bezier) |
| `set_animation_keyframe` | Inserir keyframe em uma trilha |
| `get_animation_info` | Informações detalhadas da animação com todas as trilhas/chaves |
| `remove_animation` | Remover uma animação |

### Ferramentas de TileMap (6)
| Ferramenta | Descrição |
|------|-------------|
| `tilemap_set_cell` | Definir uma única célula |
| `tilemap_fill_rect` | Preencher região retangular com tiles |
| `tilemap_get_cell` | Obter dados do tile de uma célula |
| `tilemap_clear` | Limpar todas as células |
| `tilemap_get_info` | Informações do TileMapLayer e fontes do tile set |
| `tilemap_get_used_cells` | Lista de células usadas |

### Ferramentas de tema e UI (8)
| Ferramenta | Descrição |
|------|-------------|
| `create_theme` | Criar arquivo de recurso Theme |
| `set_theme_color` | Definir override de cor do tema |
| `set_theme_constant` | Definir override de constante do tema |
| `set_theme_font_size` | Definir override de tamanho de fonte do tema |
| `set_theme_stylebox` | Definir override de StyleBoxFlat |
| `setup_control` | Configurar o layout de Control/Container em uma única chamada |
| `add_virtual_joystick` | Adicionar um VirtualJoystick na tela vinculado a ações de entrada (Godot 4.7+) |
| `get_theme_info` | Obter informações de overrides do tema |

### Ferramentas de profiling (2)
| Ferramenta | Descrição |
|------|-------------|
| `get_performance_monitors` | Todos os monitores de desempenho (FPS, memória, física, etc.) |
| `get_editor_performance` | Resumo rápido de desempenho |

### Ferramentas de lote e refatoração (7)
| Ferramenta | Descrição |
|------|-------------|
| `find_nodes_by_type` | Encontrar todos os nós de um tipo |
| `find_signal_connections` | Encontrar todas as conexões de sinais na cena |
| `batch_set_property` | Definir propriedade em todos os nós de um tipo |
| `batch_add_nodes` | Adicionar uma árvore de nós inteira em uma única chamada |
| `find_node_references` | Buscar um padrão nos arquivos do projeto |
| `get_scene_dependencies` | Obter dependências de recursos |
| `cross_scene_set_property` | Definir propriedade em todas as cenas |

### Ferramentas de shader (6)
| Ferramenta | Descrição |
|------|-------------|
| `create_shader` | Criar shader a partir de template |
| `read_shader` | Ler arquivo de shader |
| `edit_shader` | Editar shader (substituir/buscar-substituir) |
| `assign_shader_material` | Atribuir ShaderMaterial a um nó |
| `set_shader_param` | Definir parâmetro do shader |
| `get_shader_params` | Obter todos os parâmetros do shader |

### Ferramentas de exportação (4)
| Ferramenta | Descrição |
|------|-------------|
| `list_export_presets` | Listar presets de exportação |
| `export_project` | Obter o comando de exportação para um preset |
| `export_patch_pck` | Exportar um PCK de patch apenas com os arquivos alterados desde os packs base informados |
| `get_export_info` | Informações do projeto relacionadas à exportação |

### Ferramentas de recursos (4)
| Ferramenta | Descrição |
|------|-------------|
| `read_resource` | Ler propriedades de um recurso .tres |
| `edit_resource` | Editar propriedades de um recurso |
| `create_resource` | Criar novo recurso .tres |
| `get_resource_preview` | Obter miniatura do recurso |

### Ferramentas de física (6)
| Ferramenta | Descrição |
|------|-------------|
| `setup_collision` | Adicionar formas de colisão a nós |
| `set_physics_layers` | Definir layer/mask de colisão |
| `get_physics_layers` | Obter informações de layer/mask de colisão |
| `add_raycast` | Adicionar nó RayCast2D/3D |
| `setup_physics_body` | Configurar propriedades do corpo físico |
| `get_collision_info` | Obter detalhes das formas de colisão |

### Ferramentas de cena 3D (7)
| Ferramenta | Descrição |
|------|-------------|
| `add_mesh_instance` | Adicionar MeshInstance3D com malha primitiva |
| `setup_lighting` | Adicionar/configurar nós de luz |
| `set_material_3d` | Definir propriedades de StandardMaterial3D |
| `setup_environment` | Configurar WorldEnvironment |
| `setup_camera_3d` | Configurar propriedades de Camera3D |
| `add_gridmap` | Configurar nó GridMap |
| `get_gridmap_info` | Inspecionar um GridMap: MeshLibrary, limites, contagem por item, células filtradas (resumo de octantes no 4.7+) |

### Ferramentas de partículas (5)
| Ferramenta | Descrição |
|------|-------------|
| `create_particles` | Criar GPUParticles2D/3D |
| `set_particle_material` | Configurar ParticleProcessMaterial |
| `set_particle_color_gradient` | Definir gradiente de cor para partículas |
| `apply_particle_preset` | Aplicar preset (fire, smoke, sparks, etc.) |
| `get_particle_info` | Obter detalhes do sistema de partículas |

### Ferramentas de navegação (5)
| Ferramenta | Descrição |
|------|-------------|
| `setup_navigation_region` | Configurar NavigationRegion |
| `bake_navigation_mesh` | Fazer bake da malha de navegação |
| `setup_navigation_agent` | Configurar NavigationAgent |
| `set_navigation_layers` | Definir camadas de navegação |
| `get_navigation_info` | Obter informações da configuração de navegação |

### Ferramentas de áudio (6)
| Ferramenta | Descrição |
|------|-------------|
| `get_audio_bus_layout` | Obter informações do layout de barramentos de áudio |
| `add_audio_bus` | Adicionar barramento de áudio |
| `set_audio_bus` | Configurar propriedades do barramento de áudio |
| `add_audio_bus_effect` | Adicionar efeito a um barramento de áudio |
| `add_audio_player` | Adicionar nó AudioStreamPlayer |
| `get_audio_info` | Obter informações de nós relacionados a áudio |

### Ferramentas de AnimationTree (9)
| Ferramenta | Descrição |
|------|-------------|
| `create_animation_tree` | Criar AnimationTree |
| `get_animation_tree_structure` | Obter a estrutura da árvore |
| `add_state_machine_state` | Adicionar estado à máquina de estados |
| `remove_state_machine_state` | Remover estado da máquina de estados |
| `add_state_machine_transition` | Adicionar transição entre estados |
| `remove_state_machine_transition` | Remover transição de estado |
| `set_blend_tree_node` | Configurar nós da blend tree |
| `set_tree_parameter` | Definir parâmetro do AnimationTree |
| `setup_ik_modifier` | Adicionar e configurar um SkeletonModifier3D de IK (TwoBoneIK3D, CCDIK3D, FABRIK3D, ...) em um Skeleton3D (Godot 4.6+) |

### Ferramentas de análise e busca (6)
| Ferramenta | Descrição |
|------|-------------|
| `find_unused_resources` | Encontrar recursos não referenciados |
| `analyze_signal_flow` | Mapear conexões de sinais |
| `analyze_scene_complexity` | Analisar o desempenho da cena |
| `find_script_references` | Encontrar onde um script/recurso é usado |
| `detect_circular_dependencies` | Encontrar dependências circulares entre cenas |
| `get_project_statistics` | Obter estatísticas de todo o projeto |

### Ferramentas de testes e QA (6)
| Ferramenta | Descrição |
|------|-------------|
| `run_test_scenario` | Executar cenário de teste automatizado |
| `assert_node_state` | Verificar valores de propriedades de nós |
| `assert_screen_text` | Verificar texto na tela |
| `run_stress_test` | Executar teste de estresse de desempenho |
| `set_game_speed` | Ler/definir o Engine.time_scale do jogo em execução (câmera lenta / avanço rápido) |
| `get_test_report` | Obter relatório de resultados dos testes |

### Ferramentas headless (3)
| Ferramenta | Descrição |
|------|-------------|
| `run_headless_scene` | Executar uma cena em um processo Godot headless separado (ex.: a suíte de testes de um projeto) |
| `run_headless_script` | Executar um script `extends SceneTree` com `godot --headless --script` |
| `get_godot_executable` | Caminho do binário Godot do editor, caminho do projeto e plataforma |

### Ferramentas de Android (3)
| Ferramenta | Descrição |
|------|-------------|
| `list_android_devices` | Listar dispositivos Android visíveis ao adb |
| `get_android_preset_info` | Ler o nome do pacote/caminho de exportação de um preset de exportação Android |
| `deploy_to_android` | Exportar APK, instalar via adb e iniciar (como o Remote Deploy) |

## Principais recursos

- **Integração com UndoRedo**: todas as operações de nós/propriedades suportam Ctrl+Z
- **Parsing inteligente de tipos**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` são convertidos automaticamente
- **Reconexão automática**: reconexão com backoff exponencial (1s → 2s → 4s ... → 60s máx.)
- **Heartbeat**: ping/pong a cada 10s mantém a conexão ativa
- **Erros úteis**: as respostas de erro incluem sugestões de próximos passos

## Comparação com concorrentes

### Número de ferramentas

| Categoria | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (grátis) | Dokujaa (grátis) | Coding-Solo (grátis) | ee0pdt (grátis) | bradypp (grátis) |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Projeto | 10 | 5 | 4 | 0 | 2 | 2 | 2 |
| Cena | 10 | 8 | 11 | 9 | 3 | 4 | 5 |
| Nós | **17** | 8 | 0 | 8 | 2 | 3 | 0 |
| Script | **9** | 5 | 6 | 4 | 0 | 5 | 0 |
| Editor | **15** | 5 | 1 | 5 | 1 | 3 | 2 |
| Entrada | **7** | 2 | 0 | 0 | 0 | 0 | 0 |
| Runtime | **20** | 0 | 0 | 0 | 0 | 0 | 0 |
| Animação | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| TileMap | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Tema/UI | **8** | 0 | 0 | 0 | 0 | 0 | 0 |
| Profiling | **2** | 0 | 0 | 0 | 0 | 0 | 0 |
| Lote/Refatoração | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| Shader | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Exportação | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Recursos | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| Física | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Cena 3D | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| Partículas | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Navegação | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| Áudio | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| AnimationTree | **9** | 0 | 0 | 0 | 0 | 0 | 0 |
| Análise | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Testes/QA | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| Assets/IA | 0 | 0 | 1 | 6 | 0 | 0 | 0 |
| Materiais | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| Outros | 0 | 0 | 9 | 5 | 5 | 2 | 1 |
| Headless | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Deploy Android | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **187** | ~30 | **32** | **39** | **13** | **19** | **10** |

### Matriz de recursos

| Recurso | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (grátis) | Dokujaa (grátis) | Coding-Solo (grátis) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **Conexão** | WebSocket (tempo real) | stdio (Python) | WebSocket | Socket TCP | CLI headless |
| **Desfazer/Refazer** | Sim | Sim | Não | Não | Não |
| **JSON-RPC 2.0** | Sim | Próprio | Próprio | Próprio | N/A |
| **Reconexão automática** | Sim (backoff exponencial) | N/A | Não | Não | N/A |
| **Heartbeat** | Sim (ping/pong a cada 10s) | Não | Não | Não | Não |
| **Sugestões em erros** | Sim (dicas contextuais) | Não | Não | Não | Não |
| **Captura de tela** | Sim (editor + jogo) | Sim | Não | Não | Não |
| **Simulação de entrada no jogo** | Sim (tecla/mouse/ação/sequência) | Sim (básica) | Não | Não | Não |
| **Inspeção em runtime** | Sim (árvore de cena + propriedades + monitoramento) | Não | Não | Não | Não |
| **Gerenciamento de sinais** | Sim (conectar/desconectar/inspecionar) | Não | Não | Não | Não |
| **Visualizador no navegador** | Não | Não | Sim | Não | Não |
| **Geração de malhas 3D com IA** | Não | Não | Não | Sim (Meshy API) | Não |

### Categorias exclusivas (nenhum concorrente as tem)

| Categoria | Ferramentas | Por que importa |
|----------|-------|----------------|
| **Animação** | 6 ferramentas | Criar animações, adicionar trilhas, definir keyframes — tudo programaticamente |
| **TileMap** | 6 ferramentas | Definir células, preencher retângulos, consultar dados de tiles — essencial para level design 2D |
| **Tema/UI** | 8 ferramentas | StyleBox, cores, fontes — crie temas de UI sem trabalho manual no editor |
| **Profiling** | 2 ferramentas | FPS, memória, draw calls, física — monitoramento de desempenho |
| **Lote/Refatoração** | 7 ferramentas | Busca por tipo, alterações de propriedades em lote, atualizações entre cenas, análise de dependências |
| **Shader** | 6 ferramentas | Criar/editar shaders, atribuir materiais, definir parâmetros |
| **Exportação** | 4 ferramentas | Listar presets, obter comandos de exportação, verificar templates |
| **Física** | 6 ferramentas | Configurar formas de colisão, corpos, raycasts e gerenciamento de camadas |
| **Cena 3D** | 7 ferramentas | Adicionar malhas, câmeras, luzes, ambiente, suporte a GridMap |
| **Partículas** | 5 ferramentas | Criar partículas com materiais personalizados, presets e gradientes |
| **Navegação** | 5 ferramentas | Configurar regiões de navegação, agentes, pathfinding, bake |
| **Áudio** | 6 ferramentas | Sistema completo de barramentos de áudio, efeitos, players, gerenciamento ao vivo |
| **AnimationTree** | 9 ferramentas | Máquinas de estados, transições, blend trees e modificadores de IK |
| **Testes/QA** | 6 ferramentas | Testes automatizados, asserções, testes de estresse, comparação de capturas de tela |
| **Runtime** | 20 ferramentas | Inspecionar e controlar o jogo em execução: inspecionar, gravar, reproduzir, navegar |

### Vantagens de arquitetura

| Aspecto | Godot MCP Pro | Concorrente típico |
|--------|--------------|-------------------|
| **Protocolo** | JSON-RPC 2.0 (padrão, extensível) | JSON próprio ou baseado em CLI |
| **Conexão** | WebSocket persistente com heartbeat | Subprocesso por comando ou TCP bruto |
| **Confiabilidade** | Reconexão automática com backoff exponencial (1s→60s) | Reconexão manual necessária |
| **Segurança de tipos** | Parsing inteligente de tipos (Vector2, Color, Rect2, cores hex) | Apenas strings ou tipos limitados |
| **Tratamento de erros** | Erros estruturados com códigos + sugestões | Mensagens de erro genéricas |
| **Suporte a desfazer** | Todas as mutações passam pelo sistema UndoRedo | Modificações diretas (sem desfazer) |
| **Gerenciamento de portas** | Varredura automática das portas 6505-6509 | Porta fixa, possíveis conflitos |

## Licença

Proprietária — veja [LICENSE](../LICENSE) para detalhes. A compra inclui atualizações vitalícias.
