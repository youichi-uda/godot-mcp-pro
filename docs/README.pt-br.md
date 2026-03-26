> **Language:** [English](../README.md) | [日本語](README.ja.md) | Português (BR) | [Español](README.es.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | [हिन्दी](README.hi.md)

# Godot MCP Pro

Servidor MCP (Model Context Protocol) premium para desenvolvimento de jogos Godot com IA. Conecta assistentes de IA como Claude diretamente ao seu editor Godot com **163 ferramentas poderosas**.

## Arquitetura

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **Tempo real**: Conexão WebSocket significa feedback instantâneo, sem polling de arquivos
- **Integração com o editor**: Acesso completo à API do editor Godot, sistema UndoRedo e árvore de cenas
- **JSON-RPC 2.0**: Protocolo padrão com códigos de erro e sugestões adequados

## Início Rápido

### 1. Instalar o Plugin do Godot

Copie a pasta `addons/godot_mcp/` para o diretório `addons/` do seu projeto Godot.

Ative o plugin: **Projeto → Configurações do Projeto → Plugins → Godot MCP Pro → Ativar**

### 2. Instalar o Servidor MCP

```bash
cd server
npm install
npm run build
```

### 3. Configurar o Claude Code

Adicione ao seu `.mcp.json`:

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

### 4. Auto-Aprovação de Permissões de Ferramentas (Recomendado)

O Claude Code pede permissão cada vez que uma ferramenta é chamada. Para pular esses prompts, copie um dos presets de permissão incluídos para as configurações do Claude Code:

**Opção A: Conservadora** (padrão — bloqueia ferramentas destrutivas)

```bash
cp settings.local.json ~/.claude/settings.local.json
```

Permite 152 de 163 ferramentas automaticamente. As seguintes 11 ferramentas ainda exigirão aprovação manual:

| Ferramenta Bloqueada | Motivo |
|---|---|
| `delete_node` | Exclui um nó da cena |
| `delete_scene` | Exclui um arquivo de cena do disco |
| `remove_animation` | Remove uma animação |
| `remove_autoload` | Remove um singleton autoload |
| `remove_state_machine_state` | Remove um estado da state machine |
| `remove_state_machine_transition` | Remove uma transição da state machine |
| `execute_editor_script` | Executa código arbitrário no editor |
| `execute_game_script` | Executa código arbitrário no jogo em execução |
| `export_project` | Aciona uma exportação do projeto |
| `tilemap_clear` | Limpa todas as células de um TileMapLayer |

**Opção B: Permissiva** (permite tudo, nega comandos perigosos)

```bash
cp settings.local.permissive.json ~/.claude/settings.local.json
```

Permite todas as 163 ferramentas e todos os comandos Bash. Nega explicitamente comandos shell destrutivos (`rm -rf`, `git push --force`, `git reset --hard`, etc.) e as mesmas ferramentas MCP destrutivas listadas acima.

> **Nota**: Se você já tem um `settings.local.json`, mescle a seção `permissions` manualmente em vez de sobrescrever.

### 5. Modo Lite (Opcional)

Se seu cliente MCP tem limite de ferramentas (ex: Windsurf: 100, Cursor: ~40), use o modo Lite que registra 76 ferramentas principais em vez de 162:

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

O modo Lite inclui: ferramentas de project, scene, node, script, editor, input, runtime e input_map.

### 6. Como Usar

Abra seu projeto Godot com o plugin ativado e use o Claude Code para interagir com o editor.

## Todas as 162 Ferramentas

### Ferramentas de Projeto (7)
| Ferramenta | Descrição |
|------|-------------|
| `get_project_info` | Metadados do projeto, versão, viewport, autoloads |
| `get_filesystem_tree` | Árvore de arquivos recursiva com filtragem |
| `search_files` | Busca de arquivos fuzzy/glob |
| `get_project_settings` | Ler configurações do project.godot |
| `set_project_setting` | Definir configurações via API do editor |
| `uid_to_project_path` | Conversão UID → res:// |
| `project_path_to_uid` | Conversão res:// → UID |

### Ferramentas de Cena (9)
| Ferramenta | Descrição |
|------|-------------|
| `get_scene_tree` | Árvore de cena ao vivo com hierarquia |
| `get_scene_file_content` | Conteúdo bruto do arquivo .tscn |
| `create_scene` | Criar novos arquivos de cena |
| `open_scene` | Abrir cena no editor |
| `delete_scene` | Excluir arquivo de cena |
| `add_scene_instance` | Instanciar cena como nó filho |
| `play_scene` | Executar cena (principal/atual/personalizada) |
| `stop_scene` | Parar cena em execução |
| `save_scene` | Salvar cena atual no disco |

### Ferramentas de Nó (14)
| Ferramenta | Descrição |
|------|-------------|
| `add_node` | Adicionar nó com tipo e propriedades |
| `delete_node` | Excluir nó (com suporte a undo) |
| `duplicate_node` | Duplicar nó e filhos |
| `move_node` | Mover/reparentar nó |
| `update_property` | Definir qualquer propriedade (parsing automático de tipo) |
| `get_node_properties` | Obter todas as propriedades do nó |
| `add_resource` | Adicionar Shape/Material/etc ao nó |
| `set_anchor_preset` | Definir preset de âncora do Control |
| `rename_node` | Renomear um nó na cena |
| `connect_signal` | Conectar sinal entre nós |
| `disconnect_signal` | Desconectar conexão de sinal |
| `get_node_groups` | Obter grupos aos quais o nó pertence |
| `set_node_groups` | Definir associação de grupo do nó |
| `find_nodes_in_group` | Encontrar todos os nós em um grupo |

### Ferramentas de Script (8)
| Ferramenta | Descrição |
|------|-------------|
| `list_scripts` | Listar todos os scripts com info de classe |
| `read_script` | Ler conteúdo do script |
| `create_script` | Criar novo script com template |
| `edit_script` | Buscar/substituir ou edição completa |
| `attach_script` | Anexar script ao nó |
| `get_open_scripts` | Listar scripts abertos no editor |
| `validate_script` | Validar sintaxe GDScript |
| `search_in_files` | Buscar conteúdo em arquivos do projeto |

### Ferramentas do Editor (9)
| Ferramenta | Descrição |
|------|-------------|
| `get_editor_errors` | Obter erros e stack traces |
| `get_editor_screenshot` | Capturar viewport do editor |
| `get_game_screenshot` | Capturar jogo em execução |
| `execute_editor_script` | Executar GDScript arbitrário no editor |
| `clear_output` | Limpar painel de saída |
| `get_signals` | Obter todos os sinais de um nó com conexões |
| `reload_plugin` | Recarregar o plugin MCP (reconexão automática) |
| `reload_project` | Reescanear sistema de arquivos e recarregar scripts |
| `get_output_log` | Obter conteúdo do painel de saída |

### Ferramentas de Entrada (7)
| Ferramenta | Descrição |
|------|-------------|
| `simulate_key` | Simular pressionar/soltar tecla do teclado |
| `simulate_mouse_click` | Simular clique do mouse na posição |
| `simulate_mouse_move` | Simular movimento do mouse |
| `simulate_action` | Simular Godot Input Action |
| `simulate_sequence` | Sequência de eventos de entrada com delays de frames |
| `get_input_actions` | Listar todas as ações de entrada |
| `set_input_action` | Criar/modificar ação de entrada |

### Ferramentas de Runtime (19)
| Ferramenta | Descrição |
|------|-------------|
| `get_game_scene_tree` | Árvore de cena do jogo em execução |
| `get_game_node_properties` | Propriedades de nó no jogo em execução |
| `set_game_node_property` | Definir propriedade de nó no jogo em execução |
| `execute_game_script` | Executar GDScript no contexto do jogo |
| `capture_frames` | Captura de screenshots multi-frame |
| `monitor_properties` | Registrar valores de propriedades ao longo do tempo |
| `start_recording` | Iniciar gravação de entrada |
| `stop_recording` | Parar gravação de entrada |
| `replay_recording` | Reproduzir entrada gravada |
| `find_nodes_by_script` | Encontrar nós do jogo por script |
| `get_autoload` | Obter propriedades do nó autoload |
| `batch_get_properties` | Obter propriedades de múltiplos nós em lote |
| `find_ui_elements` | Encontrar elementos de UI no jogo |
| `click_button_by_text` | Clicar em botão pelo texto |
| `wait_for_node` | Aguardar aparecimento de nó |
| `find_nearby_nodes` | Encontrar nós próximos a uma posição |
| `navigate_to` | Navegar até posição alvo |
| `move_to` | Mover personagem até o alvo |

### Ferramentas de Animação (6)
| Ferramenta | Descrição |
|------|-------------|
| `list_animations` | Listar todas as animações no AnimationPlayer |
| `create_animation` | Criar nova animação |
| `add_animation_track` | Adicionar track (value/position/rotation/method/bezier) |
| `set_animation_keyframe` | Inserir keyframe na track |
| `get_animation_info` | Info detalhada de animação com todas as tracks/keys |
| `remove_animation` | Remover uma animação |

### Ferramentas de TileMap (6)
| Ferramenta | Descrição |
|------|-------------|
| `tilemap_set_cell` | Definir uma célula de tile |
| `tilemap_fill_rect` | Preencher região retangular com tiles |
| `tilemap_get_cell` | Obter dados do tile na célula |
| `tilemap_clear` | Limpar todas as células |
| `tilemap_get_info` | Info do TileMapLayer e fontes do tile set |
| `tilemap_get_used_cells` | Lista de células usadas |

### Ferramentas de Tema & UI (6)
| Ferramenta | Descrição |
|------|-------------|
| `create_theme` | Criar arquivo de recurso Theme |
| `set_theme_color` | Definir override de cor do tema |
| `set_theme_constant` | Definir override de constante do tema |
| `set_theme_font_size` | Definir override de tamanho de fonte do tema |
| `set_theme_stylebox` | Definir override de StyleBoxFlat |
| `get_theme_info` | Obter info de overrides do tema |

### Ferramentas de Profiling (2)
| Ferramenta | Descrição |
|------|-------------|
| `get_performance_monitors` | Todos os monitores de desempenho (FPS, memória, física, etc.) |
| `get_editor_performance` | Resumo rápido de desempenho |

### Ferramentas de Batch & Refatoração (8)
| Ferramenta | Descrição |
|------|-------------|
| `find_nodes_by_type` | Encontrar todos os nós de um tipo |
| `find_signal_connections` | Encontrar todas as conexões de sinal na cena |
| `batch_set_property` | Definir propriedade em todos os nós de um tipo |
| `find_node_references` | Buscar padrão em arquivos do projeto |
| `get_scene_dependencies` | Obter dependências de recursos |
| `cross_scene_set_property` | Definir propriedade em todas as cenas |
| `find_script_references` | Encontrar onde script/recurso é usado |
| `detect_circular_dependencies` | Encontrar dependências circulares de cena |

### Ferramentas de Shader (6)
| Ferramenta | Descrição |
|------|-------------|
| `create_shader` | Criar shader com template |
| `read_shader` | Ler arquivo de shader |
| `edit_shader` | Editar shader (substituir/buscar-substituir) |
| `assign_shader_material` | Atribuir ShaderMaterial ao nó |
| `set_shader_param` | Definir parâmetro do shader |
| `get_shader_params` | Obter todos os parâmetros do shader |

### Ferramentas de Exportação (3)
| Ferramenta | Descrição |
|------|-------------|
| `list_export_presets` | Listar presets de exportação |
| `export_project` | Obter comando de exportação para preset |
| `get_export_info` | Info do projeto relacionada à exportação |

### Ferramentas de Recurso (6)
| Ferramenta | Descrição |
|------|-------------|
| `read_resource` | Ler propriedades de recurso .tres |
| `edit_resource` | Editar propriedades de recurso |
| `create_resource` | Criar novo recurso .tres |
| `get_resource_preview` | Obter miniatura do recurso |
| `add_autoload` | Registrar singleton autoload |
| `remove_autoload` | Remover singleton autoload |

### Ferramentas de Física (6)
| Ferramenta | Descrição |
|------|-------------|
| `setup_physics_body` | Configurar propriedades do corpo físico |
| `setup_collision` | Adicionar formas de colisão aos nós |
| `set_physics_layers` | Definir camada/máscara de colisão |
| `get_physics_layers` | Obter info de camada/máscara de colisão |
| `get_collision_info` | Obter detalhes da forma de colisão |
| `add_raycast` | Adicionar nó RayCast2D/3D |

### Ferramentas de Cena 3D (6)
| Ferramenta | Descrição |
|------|-------------|
| `add_mesh_instance` | Adicionar MeshInstance3D com mesh primitiva |
| `setup_camera_3d` | Configurar propriedades da Camera3D |
| `setup_lighting` | Adicionar/configurar nós de luz |
| `setup_environment` | Configurar WorldEnvironment |
| `add_gridmap` | Configurar nó GridMap |
| `set_material_3d` | Definir propriedades de StandardMaterial3D |

### Ferramentas de Partículas (5)
| Ferramenta | Descrição |
|------|-------------|
| `create_particles` | Criar GPUParticles2D/3D |
| `set_particle_material` | Configurar ParticleProcessMaterial |
| `set_particle_color_gradient` | Definir gradiente de cor para partículas |
| `apply_particle_preset` | Aplicar preset (fire, smoke, sparks, etc.) |
| `get_particle_info` | Obter detalhes do sistema de partículas |

### Ferramentas de Navegação (6)
| Ferramenta | Descrição |
|------|-------------|
| `setup_navigation_region` | Configurar NavigationRegion |
| `setup_navigation_agent` | Configurar NavigationAgent |
| `bake_navigation_mesh` | Assar mesh de navegação |
| `set_navigation_layers` | Definir camadas de navegação |
| `get_navigation_info` | Obter info de configuração de navegação |

### Ferramentas de Áudio (6)
| Ferramenta | Descrição |
|------|-------------|
| `add_audio_player` | Adicionar nó AudioStreamPlayer |
| `add_audio_bus` | Adicionar bus de áudio |
| `add_audio_bus_effect` | Adicionar efeito ao bus de áudio |
| `set_audio_bus` | Configurar propriedades do bus de áudio |
| `get_audio_bus_layout` | Obter info do layout de bus de áudio |
| `get_audio_info` | Obter info de nós relacionados a áudio |

### Ferramentas de AnimationTree (4)
| Ferramenta | Descrição |
|------|-------------|
| `create_animation_tree` | Criar AnimationTree |
| `get_animation_tree_structure` | Obter estrutura da árvore |
| `set_tree_parameter` | Definir parâmetro do AnimationTree |
| `add_state_machine_state` | Adicionar estado à state machine |

### Ferramentas de State Machine (3)
| Ferramenta | Descrição |
|------|-------------|
| `remove_state_machine_state` | Remover estado da state machine |
| `add_state_machine_transition` | Adicionar transição entre estados |
| `remove_state_machine_transition` | Remover transição de estado |

### Ferramentas de Blend Tree (1)
| Ferramenta | Descrição |
|------|-------------|
| `set_blend_tree_node` | Configurar nós do blend tree |

### Ferramentas de Análise & Busca (4)
| Ferramenta | Descrição |
|------|-------------|
| `analyze_scene_complexity` | Analisar desempenho da cena |
| `analyze_signal_flow` | Mapear conexões de sinais |
| `find_unused_resources` | Encontrar recursos não referenciados |
| `get_project_statistics` | Obter estatísticas do projeto |

### Ferramentas de Teste & QA (6)
| Ferramenta | Descrição |
|------|-------------|
| `run_test_scenario` | Executar cenário de teste automatizado |
| `assert_node_state` | Verificar valores de propriedade de nó |
| `assert_screen_text` | Verificar texto na tela |
| `compare_screenshots` | Comparar dois screenshots |
| `run_stress_test` | Executar teste de estresse de desempenho |
| `get_test_report` | Obter relatório de resultados de teste |

## Principais Recursos

- **Integração UndoRedo**: Todas as operações de nó/propriedade suportam Ctrl+Z
- **Parsing Inteligente de Tipos**: `"Vector2(100, 200)"`, `"#ff0000"`, `"Color(1,0,0)"` convertidos automaticamente
- **Reconexão Automática**: Reconexão com backoff exponencial (1s → 2s → 4s ... → 60s máx)
- **Heartbeat**: Ping/pong a cada 10s mantém a conexão ativa
- **Erros Úteis**: Respostas de erro incluem sugestões para próximos passos

## Comparação com Concorrentes

### Contagem de Ferramentas

| Categoria | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) | ee0pdt (free) | bradypp (free) |
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

| Funcionalidade | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **Conexão** | WebSocket (tempo real) | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | Sim | Sim | Não | Não | Não |
| **JSON-RPC 2.0** | Sim | Customizado | Customizado | Customizado | N/A |
| **Reconexão automática** | Sim (backoff exponencial) | N/A | Não | Não | N/A |
| **Heartbeat** | Sim (ping/pong 10s) | Não | Não | Não | Não |
| **Sugestões de erro** | Sim (dicas contextuais) | Não | Não | Não | Não |
| **Captura de tela** | Sim (editor + jogo) | Sim | Não | Não | Não |
| **Simulação de entrada** | Sim (tecla/mouse/ação/sequência) | Sim (básico) | Não | Não | Não |
| **Inspeção em runtime** | Sim (árvore de cena + propriedades + monitor) | Não | Não | Não | Não |
| **Gerenciamento de sinais** | Sim (conectar/desconectar/inspecionar) | Não | Não | Não | Não |
| **Visualizador no navegador** | Não | Não | Sim | Não | Não |
| **Geração de mesh 3D por IA** | Não | Não | Não | Sim (Meshy API) | Não |

### Categorias Exclusivas (Nenhum Concorrente Possui)

| Categoria | Ferramentas | Por Que Importa |
|----------|-------|----------------|
| **Animation** | 6 ferramentas | Criar animações, adicionar tracks, definir keyframes — tudo programaticamente |
| **TileMap** | 6 ferramentas | Definir células, preencher retângulos, consultar dados de tiles — essencial para level design 2D |
| **Theme/UI** | 6 ferramentas | StyleBox, cores, fontes — construir temas de UI sem trabalho manual no editor |
| **Profiling** | 2 ferramentas | FPS, memória, draw calls, física — monitoramento de desempenho |
| **Batch/Refactor** | 8 ferramentas | Buscar por tipo, alterações de propriedade em lote, atualizações entre cenas, análise de dependências |
| **Shader** | 6 ferramentas | Criar/editar shaders, atribuir materiais, definir parâmetros |
| **Export** | 3 ferramentas | Listar presets, obter comandos de exportação, verificar templates |
| **Physics** | 6 ferramentas | Configurar formas de colisão, corpos, raycasts e gerenciamento de camadas |
| **3D Scene** | 6 ferramentas | Adicionar meshes, câmeras, luzes, ambiente, suporte a GridMap |
| **Particle** | 5 ferramentas | Criar partículas com materiais customizados, presets e gradientes |
| **Navigation** | 6 ferramentas | Configurar regiões de navegação, agentes, pathfinding, baking |
| **Audio** | 6 ferramentas | Sistema completo de bus de áudio, efeitos, players, gerenciamento ao vivo |
| **AnimationTree** | 4 ferramentas | Construir state machines com transições e blend trees |
| **State Machine** | 3 ferramentas | Gerenciamento avançado de state machine para animações complexas |
| **Testing/QA** | 6 ferramentas | Testes automatizados, assertions, stress test, comparação de screenshots |
| **Runtime** | 19 ferramentas | Inspecionar e controlar o jogo em tempo de execução: inspecionar, gravar, reproduzir, navegar |

### Vantagens de Arquitetura

| Aspecto | Godot MCP Pro | Concorrente Típico |
|--------|--------------|-------------------|
| **Protocolo** | JSON-RPC 2.0 (padrão, extensível) | JSON customizado ou baseado em CLI |
| **Conexão** | WebSocket persistente com heartbeat | Subprocesso por comando ou TCP bruto |
| **Confiabilidade** | Reconexão automática com backoff exponencial (1s→60s) | Reconexão manual necessária |
| **Segurança de tipos** | Parsing inteligente de tipos (Vector2, Color, Rect2, cores hex) | Apenas strings ou tipos limitados |
| **Tratamento de erros** | Erros estruturados com códigos + sugestões | Mensagens de erro genéricas |
| **Suporte a Undo** | Todas as mutações passam pelo sistema UndoRedo | Modificações diretas (sem undo) |
| **Gerenciamento de porta** | Auto-scan de portas 6505-6509 | Porta fixa, possíveis conflitos |

## Licença

Proprietário — veja [LICENSE](../LICENSE) para detalhes. A compra inclui atualizações vitalícias para v1.x.
