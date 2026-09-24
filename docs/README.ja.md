> **Language:** [English](../README.md) | 日本語 | [Português (BR)](README.pt-br.md) | [Español](README.es.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | [हिन्दी](README.hi.md)

# Godot MCP Pro

AI駆動のGodotゲーム開発のためのプレミアムMCP（Model Context Protocol）サーバー。ClaudeなどのAIアシスタントをGodotエディタに直接接続し、**187の強力なツール**を提供します。

## アーキテクチャ

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **リアルタイム**: WebSocket接続により即座にフィードバック。ファイルポーリング不要
- **エディタ統合**: GodotのエディタAPI、UndoRedoシステム、シーンツリーにフルアクセス
- **JSON-RPC 2.0**: 適切なエラーコードと提案を備えた標準プロトコル

## このリポジトリの内容

> ⚠️ **この公開リポジトリには無料のGodotアドオン/プラグインのみが含まれています。** MCPサーバー（Node.js、AIアシスタントの接続に必要）は有料パッケージの一部として配布されています — **買い切り**、生涯アップデート付き:
>
> - **Buy Me a Coffee**: <https://buymeacoffee.com/y1uda/extras>
> - **itch.io**: <https://y1uda.itch.io/godot-mcp-pro>
>
> 有料zipには、アドオン、ビルド済みJavaScriptを含む`server/`ディレクトリ、`INSTALL.md`、AIクライアント向けの手順書が含まれています。このリポジトリをクローンして`server/`フォルダが見当たらなくても、**それは想定どおりです** — 上記いずれかのリンクからフルパッケージを入手してください。

## クイックスタート

### 1. Godotプラグインのインストール

`addons/godot_mcp/`フォルダをGodotプロジェクトの`addons/`ディレクトリにコピーします。

プラグインを有効化: **プロジェクト → プロジェクト設定 → プラグイン → Godot MCP Pro → 有効**

### 2. MCPサーバーのインストール

> `server/`ディレクトリは**有料フルパッケージ**にのみ含まれています（上記参照）。zipをダウンロードして展開した後、以下を実行します:

```bash
cd server
npm install
npm run build
```

### 3. Claude Codeの設定

`.mcp.json`に追加:

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

### 4. モードの選択

Godot MCP Proは、各クライアントのツール数上限に合わせて4つのモードを提供します:

| モード | ツール数 | 最適な用途 |
|------|-------|----------|
| **Full**（デフォルト） | 187 | Claude Code, Cline, VS Code Copilot, Cursor |
| **3D** (`--3d`) | 100 | 3Dが必要なAntigravityなど、ツール上限100のクライアント |
| **Lite** (`--lite`) | 88 | Windsurf, JetBrains Junie, Gemini CLI |
| **Minimal** (`--minimal`) | 35 | OpenCode、コンテキストの小さいローカルLLM |

`--3d`はコアツールに加えて物理、AnimationTree、ナビゲーションを含みますが、100ツールの上限に収めるため`uid_to_project_path`、`project_path_to_uid`、`compare_screenshots`、`clear_output`、`close_script`、`reload_open_scripts`、`set_anchor_preset`、`click_button_by_text`を除外しています。

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

最小構成にするには`--lite`を`--minimal`に置き換えてください。

- **Lite**に含まれるもの: project、scene、node、script、editor、input、runtime、input_mapツール。
- **Minimal**に含まれるもの: 35の必須ツール — プロジェクト情報、シーン管理、ノードCRUD、スクリプト編集、エディタエラー、入力シミュレーション、ランタイム検査。

### 5. CLIモード（MCPの代替）

MCP非対応のクライアントや、コンテキストのオーバーヘッドをゼロにしたい場合は、ターミナル/bashツールからCLIを直接使用します。CLIを使うには、先にサーバーをビルドしておく必要があります（ステップ2）。

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

`/path/to/`はファイルを展開した実際のパスに置き換えてください。

CLIはWebSocket経由でGodotエディタプラグインに直接接続します。必要なもの:
- MCPプラグインを有効にした状態でGodotエディタが起動していること
- サーバーがビルド済みであること（`node build/setup.js install`）
- 6510〜6514の範囲に空きポートがあること

**利点**: LLMはすべてのツール定義を最初に読み込む代わりに、`--help`を通じて段階的に機能を把握できます。ツール数の上限に関係なく、ターミナルにアクセスできるあらゆるLLMクライアントで動作します。

### 6. クライアント互換性

| クライアント | 推奨モード | 備考 |
|--------|-----------------|-------|
| Claude Code | Full（デフォルト） | ツールの遅延読み込み — コンテキストコストは最小 |
| VS Code Copilot | Full | Virtual Toolsがツールを自動グループ化 |
| OpenAI Codex CLI | Full | MCPSearchが超過分を遅延読み込み |
| Cline | Full | 厳密な上限なし。`enabledTools`でホワイトリスト指定可 |
| Roo Code | Full | 厳密な上限なし |
| Windsurf | Lite | ツール上限100 |
| JetBrains Junie | Lite | ツール上限100 |
| Gemini CLI | Lite | クライアント上限約100。細かい制御には`excludeTools`を使用 |
| Cursor | Full | ツール上限は撤廃（Dynamic Context Discovery） |
| OpenCode | MinimalまたはCLI | ツールが約40を超えるとモデルの性能が低下 |
| ローカルLLM（LM Studioなど） | MinimalまたはCLI | コンテキストウィンドウがボトルネック |

### 7. 使い方

プラグインを有効にした状態でGodotプロジェクトを開き、Claude Codeを使ってエディタを操作します。

## 全187ツール

### プロジェクトツール (10)
| ツール | 説明 |
|------|-------------|
| `get_project_info` | プロジェクトのメタデータ、バージョン、ビューポート、オートロード |
| `get_filesystem_tree` | フィルタリング付き再帰的ファイルツリー |
| `search_files` | ファジー/globファイル検索 |
| `search_in_files` | プロジェクトファイル内のコンテンツ検索 |
| `get_project_settings` | project.godotの設定を読み取り |
| `set_project_setting` | エディタAPI経由でプロジェクト設定を変更 |
| `uid_to_project_path` | UID → res:// 変換 |
| `project_path_to_uid` | res:// → UID 変換 |
| `add_autoload` | オートロードシングルトンを登録 |
| `remove_autoload` | オートロードシングルトンを削除 |

### シーンツール (10)
| ツール | 説明 |
|------|-------------|
| `get_scene_tree` | 階層付きライブシーンツリー |
| `get_scene_file_content` | .tscnファイルの生コンテンツ |
| `create_scene` | 新規シーンファイルを作成 |
| `open_scene` | エディタでシーンを開く |
| `delete_scene` | シーンファイルを削除 |
| `add_scene_instance` | シーンを子ノードとしてインスタンス化 |
| `play_scene` | シーンを実行（main/current/custom） |
| `stop_scene` | 実行中のシーンを停止 |
| `save_scene` | 現在のシーンをディスクに保存 |
| `get_scene_exports` | シーンファイル内のスクリプト付き全ノードの@export変数を一覧表示 |

### ノードツール (17)
| ツール | 説明 |
|------|-------------|
| `add_node` | 型とプロパティを指定してノードを追加 |
| `delete_node` | ノードを削除（Undo対応） |
| `duplicate_node` | ノードと子ノードを複製 |
| `move_node` | ノードの移動/親の変更 |
| `update_property` | 任意のプロパティを設定（型の自動解析） |
| `get_node_properties` | ノードの全プロパティを取得 |
| `add_resource` | Shape/Materialなどをノードに追加 |
| `set_anchor_preset` | Controlのアンカープリセットを設定 |
| `rename_node` | シーン内のノード名を変更 |
| `connect_signal` | ノード間のシグナルを接続 |
| `disconnect_signal` | シグナル接続を切断 |
| `get_node_groups` | ノードが所属するグループを取得 |
| `set_node_groups` | ノードのグループ所属を設定 |
| `find_nodes_in_group` | グループ内の全ノードを検索 |
| `get_editor_selection` | シーンドックで選択中のノードを取得 |
| `select_nodes` | シーンドックでノードを選択（任意でフォーカス/インスペクト） |
| `clear_editor_selection` | シーンドックの選択を解除 |

### スクリプトツール (9)
| ツール | 説明 |
|------|-------------|
| `list_scripts` | クラス情報付きで全スクリプトを一覧表示 |
| `read_script` | スクリプトの内容を読み取り |
| `create_script` | テンプレートから新規スクリプトを作成 |
| `edit_script` | 検索/置換または全体編集 |
| `attach_script` | スクリプトをノードにアタッチ |
| `validate_script` | GDScriptの構文を検証 |
| `close_script` | スクリプトエディタのタブを閉じる。破棄を指示しない限り未保存の編集があると拒否（Godot 4.7+） |
| `reload_open_scripts` | 開いているスクリプトをディスクから再読み込み。未保存のバッファは保持（Godot 4.7+） |
| `get_open_scripts` | エディタで開いているスクリプトを一覧表示 |

### エディタツール (15)
| ツール | 説明 |
|------|-------------|
| `get_editor_errors` | エラーとスタックトレースを取得 |
| `get_output_log` | 出力パネルの内容を取得 |
| `get_editor_screenshot` | エディタのビューポートをキャプチャ |
| `get_game_screenshot` | 実行中のゲームをキャプチャ |
| `execute_editor_script` | エディタで任意のGDScriptを実行 |
| `clear_output` | 出力パネルをクリア |
| `get_signals` | ノードの全シグナルを接続情報付きで取得 |
| `reload_plugin` | MCPプラグインを再読み込み（自動再接続） |
| `reload_project` | ファイルシステムを再スキャンしスクリプトを再読み込み |
| `compare_screenshots` | 2つのスクリーンショットを比較 |
| `set_auto_dismiss` | エディタのブロッキングダイアログ（「ディスクから再読み込みしますか？」など）を自動で閉じる |
| `get_editor_camera` | 3Dエディタカメラの位置/回転/FOVを取得（4.6+ではスナップ設定も） |
| `set_editor_camera` | 3Dエディタカメラを移動してビューを構図決め |
| `get_unsaved_state` | 未保存の変更があるシーン/スクリプトを報告（未保存リストはGodot 4.7+が必要） |
| `save_all` | 開いている全シーンと変更済みスクリプトバッファを保存し、保存内容を報告（スクリプトはGodot 4.7+が必要） |

### 入力ツール (5)
| ツール | 説明 |
|------|-------------|
| `simulate_key` | キーボードのキー押下/解放をシミュレート |
| `simulate_mouse_click` | 指定位置でのマウスクリックをシミュレート |
| `simulate_mouse_move` | マウス移動をシミュレート |
| `simulate_action` | GodotのInput Actionをシミュレート |
| `simulate_sequence` | フレーム遅延付きの入力イベントシーケンス |

### 入力マップツール (2)
| ツール | 説明 |
|------|-------------|
| `get_input_actions` | 全入力アクションを一覧表示 |
| `set_input_action` | 入力アクションを作成/変更 |

### ランタイムツール (20)
| ツール | 説明 |
|------|-------------|
| `get_game_scene_tree` | 実行中ゲームのシーンツリー |
| `get_game_node_properties` | 実行中ゲームのノードプロパティ |
| `set_game_node_property` | 実行中ゲームのノードプロパティを設定 |
| `execute_game_script` | ゲームコンテキストでGDScriptを実行 |
| `capture_frames` | 複数フレームのスクリーンショットキャプチャ |
| `record_frames` | 多数のフレームをディスク上のPNGファイルに記録 |
| `monitor_properties` | プロパティ値を時系列で記録 |
| `watch_signals` | 一定時間、ノードのシグナル発火をログ記録 |
| `start_recording` | 入力の記録を開始 |
| `stop_recording` | 入力の記録を停止 |
| `replay_recording` | 記録した入力を再生 |
| `find_nodes_by_script` | スクリプトでゲームノードを検索 |
| `get_autoload` | オートロードノードのプロパティを取得 |
| `find_ui_elements` | ゲーム内のUI要素を検索 |
| `click_button_by_text` | テキスト内容でボタンをクリック |
| `wait_for_node` | ノードの出現を待機 |
| `find_nearby_nodes` | 指定位置付近のノードを検索 |
| `navigate_to` | 目標位置へナビゲート |
| `move_to` | キャラクターを目標まで歩かせる |
| `batch_get_properties` | 複数ノードのプロパティを一括取得 |

### アニメーションツール (6)
| ツール | 説明 |
|------|-------------|
| `list_animations` | AnimationPlayer内の全アニメーションを一覧表示 |
| `create_animation` | 新規アニメーションを作成 |
| `add_animation_track` | トラックを追加（value/position/rotation/method/bezier） |
| `set_animation_keyframe` | トラックにキーフレームを挿入 |
| `get_animation_info` | 全トラック/キーを含むアニメーションの詳細情報 |
| `remove_animation` | アニメーションを削除 |

### TileMapツール (6)
| ツール | 説明 |
|------|-------------|
| `tilemap_set_cell` | 単一のタイルセルを設定 |
| `tilemap_fill_rect` | 矩形領域をタイルで塗りつぶし |
| `tilemap_get_cell` | セルのタイルデータを取得 |
| `tilemap_clear` | 全セルをクリア |
| `tilemap_get_info` | TileMapLayerの情報とタイルセットのソース |
| `tilemap_get_used_cells` | 使用中セルの一覧 |

### テーマ & UIツール (8)
| ツール | 説明 |
|------|-------------|
| `create_theme` | Themeリソースファイルを作成 |
| `set_theme_color` | テーマカラーのオーバーライドを設定 |
| `set_theme_constant` | テーマ定数のオーバーライドを設定 |
| `set_theme_font_size` | テーマのフォントサイズのオーバーライドを設定 |
| `set_theme_stylebox` | StyleBoxFlatのオーバーライドを設定 |
| `setup_control` | Control/Containerのレイアウトを1回の呼び出しで設定 |
| `add_virtual_joystick` | 入力アクションに紐づくオンスクリーンVirtualJoystickを追加（Godot 4.7+） |
| `get_theme_info` | テーマのオーバーライド情報を取得 |

### プロファイリングツール (2)
| ツール | 説明 |
|------|-------------|
| `get_performance_monitors` | 全パフォーマンスモニター（FPS、メモリ、物理など） |
| `get_editor_performance` | パフォーマンスの簡易サマリー |

### バッチ & リファクタリングツール (7)
| ツール | 説明 |
|------|-------------|
| `find_nodes_by_type` | 指定型の全ノードを検索 |
| `find_signal_connections` | シーン内の全シグナル接続を検索 |
| `batch_set_property` | 指定型の全ノードにプロパティを設定 |
| `batch_add_nodes` | ノードツリー全体を1回の呼び出しで追加 |
| `find_node_references` | プロジェクトファイル内をパターン検索 |
| `get_scene_dependencies` | リソースの依存関係を取得 |
| `cross_scene_set_property` | 全シーンにまたがってプロパティを設定 |

### シェーダーツール (6)
| ツール | 説明 |
|------|-------------|
| `create_shader` | テンプレートからシェーダーを作成 |
| `read_shader` | シェーダーファイルを読み取り |
| `edit_shader` | シェーダーを編集（置換/検索置換） |
| `assign_shader_material` | ShaderMaterialをノードに割り当て |
| `set_shader_param` | シェーダーパラメータを設定 |
| `get_shader_params` | 全シェーダーパラメータを取得 |

### エクスポートツール (4)
| ツール | 説明 |
|------|-------------|
| `list_export_presets` | エクスポートプリセットを一覧表示 |
| `export_project` | プリセットのエクスポートコマンドを取得 |
| `export_patch_pck` | 指定したベースパック以降に変更されたファイルのみを含むパッチPCKをエクスポート |
| `get_export_info` | エクスポート関連のプロジェクト情報 |

### リソースツール (4)
| ツール | 説明 |
|------|-------------|
| `read_resource` | .tresリソースのプロパティを読み取り |
| `edit_resource` | リソースのプロパティを編集 |
| `create_resource` | 新規.tresリソースを作成 |
| `get_resource_preview` | リソースのサムネイルを取得 |

### 物理ツール (6)
| ツール | 説明 |
|------|-------------|
| `setup_collision` | ノードにコリジョンシェイプを追加 |
| `set_physics_layers` | コリジョンレイヤー/マスクを設定 |
| `get_physics_layers` | コリジョンレイヤー/マスク情報を取得 |
| `add_raycast` | RayCast2D/3Dノードを追加 |
| `setup_physics_body` | 物理ボディのプロパティを設定 |
| `get_collision_info` | コリジョンシェイプの詳細を取得 |

### 3Dシーンツール (7)
| ツール | 説明 |
|------|-------------|
| `add_mesh_instance` | プリミティブメッシュ付きMeshInstance3Dを追加 |
| `setup_lighting` | ライトノードを追加/設定 |
| `set_material_3d` | StandardMaterial3Dのプロパティを設定 |
| `setup_environment` | WorldEnvironmentを設定 |
| `setup_camera_3d` | Camera3Dのプロパティを設定 |
| `add_gridmap` | GridMapノードをセットアップ |
| `get_gridmap_info` | GridMapを検査: MeshLibrary、範囲、アイテムごとの数、フィルタ済みセル（4.7+ではオクタントのサマリーも） |

### パーティクルツール (5)
| ツール | 説明 |
|------|-------------|
| `create_particles` | GPUParticles2D/3Dを作成 |
| `set_particle_material` | ParticleProcessMaterialを設定 |
| `set_particle_color_gradient` | パーティクルのカラーグラデーションを設定 |
| `apply_particle_preset` | プリセットを適用（fire、smoke、sparksなど） |
| `get_particle_info` | パーティクルシステムの詳細を取得 |

### ナビゲーションツール (5)
| ツール | 説明 |
|------|-------------|
| `setup_navigation_region` | NavigationRegionを設定 |
| `bake_navigation_mesh` | ナビゲーションメッシュをベイク |
| `setup_navigation_agent` | NavigationAgentを設定 |
| `set_navigation_layers` | ナビゲーションレイヤーを設定 |
| `get_navigation_info` | ナビゲーション設定の情報を取得 |

### オーディオツール (6)
| ツール | 説明 |
|------|-------------|
| `get_audio_bus_layout` | オーディオバスレイアウト情報を取得 |
| `add_audio_bus` | オーディオバスを追加 |
| `set_audio_bus` | オーディオバスのプロパティを設定 |
| `add_audio_bus_effect` | オーディオバスにエフェクトを追加 |
| `add_audio_player` | AudioStreamPlayerノードを追加 |
| `get_audio_info` | オーディオ関連ノードの情報を取得 |

### AnimationTreeツール (9)
| ツール | 説明 |
|------|-------------|
| `create_animation_tree` | AnimationTreeを作成 |
| `get_animation_tree_structure` | ツリー構造を取得 |
| `add_state_machine_state` | ステートマシンにステートを追加 |
| `remove_state_machine_state` | ステートマシンからステートを削除 |
| `add_state_machine_transition` | ステート間のトランジションを追加 |
| `remove_state_machine_transition` | ステートのトランジションを削除 |
| `set_blend_tree_node` | ブレンドツリーのノードを設定 |
| `set_tree_parameter` | AnimationTreeのパラメータを設定 |
| `setup_ik_modifier` | Skeleton3DにIK SkeletonModifier3D（TwoBoneIK3D、CCDIK3D、FABRIK3Dなど）を追加・設定（Godot 4.6+） |

### 分析 & 検索ツール (6)
| ツール | 説明 |
|------|-------------|
| `find_unused_resources` | 参照されていないリソースを検索 |
| `analyze_signal_flow` | シグナル接続をマッピング |
| `analyze_scene_complexity` | シーンのパフォーマンスを分析 |
| `find_script_references` | スクリプト/リソースの使用箇所を検索 |
| `detect_circular_dependencies` | シーンの循環依存を検出 |
| `get_project_statistics` | プロジェクト全体の統計を取得 |

### テスト & QAツール (6)
| ツール | 説明 |
|------|-------------|
| `run_test_scenario` | 自動テストシナリオを実行 |
| `assert_node_state` | ノードのプロパティ値をアサート |
| `assert_screen_text` | 画面上のテキストを確認 |
| `run_stress_test` | パフォーマンスのストレステストを実行 |
| `set_game_speed` | 実行中ゲームのEngine.time_scaleを読み取り/設定（スローモーション/早送り） |
| `get_test_report` | テスト結果レポートを取得 |

### ヘッドレスツール (3)
| ツール | 説明 |
|------|-------------|
| `run_headless_scene` | 別のヘッドレスGodotプロセスでシーンを実行（例: プロジェクトのテストスイート） |
| `run_headless_script` | `extends SceneTree`スクリプトを`godot --headless --script`で実行 |
| `get_godot_executable` | エディタのGodotバイナリのパス、プロジェクトパス、プラットフォーム |

### Androidツール (3)
| ツール | 説明 |
|------|-------------|
| `list_android_devices` | adbから見えるAndroidデバイスを一覧表示 |
| `get_android_preset_info` | Androidエクスポートプリセットのパッケージ名/エクスポートパスを読み取り |
| `deploy_to_android` | APKをエクスポートし、adbでインストールして起動（リモートデプロイと同様） |

## 主な特徴

- **UndoRedo統合**: すべてのノード/プロパティ操作がCtrl+Zに対応
- **スマート型解析**: `"Vector2(100, 200)"`、`"#ff0000"`、`"Color(1,0,0)"`を自動変換
- **自動再接続**: 指数バックオフによる再接続（1s → 2s → 4s ... → 最大60s）
- **ハートビート**: 10秒ごとのping/pongで接続を維持
- **わかりやすいエラー**: エラーレスポンスに次のステップの提案を含む

## 競合比較

### ツール数

| カテゴリ | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (無料) | Dokujaa (無料) | Coding-Solo (無料) | ee0pdt (無料) | bradypp (無料) |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| プロジェクト | 10 | 5 | 4 | 0 | 2 | 2 | 2 |
| シーン | 10 | 8 | 11 | 9 | 3 | 4 | 5 |
| ノード | **17** | 8 | 0 | 8 | 2 | 3 | 0 |
| スクリプト | **9** | 5 | 6 | 4 | 0 | 5 | 0 |
| エディタ | **15** | 5 | 1 | 5 | 1 | 3 | 2 |
| 入力 | **7** | 2 | 0 | 0 | 0 | 0 | 0 |
| ランタイム | **20** | 0 | 0 | 0 | 0 | 0 | 0 |
| アニメーション | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| TileMap | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| テーマ/UI | **8** | 0 | 0 | 0 | 0 | 0 | 0 |
| プロファイリング | **2** | 0 | 0 | 0 | 0 | 0 | 0 |
| バッチ/リファクタ | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| シェーダー | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| エクスポート | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| リソース | **4** | 0 | 0 | 0 | 0 | 0 | 0 |
| 物理 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| 3Dシーン | **7** | 0 | 0 | 0 | 0 | 0 | 0 |
| パーティクル | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| ナビゲーション | **5** | 0 | 0 | 0 | 0 | 0 | 0 |
| オーディオ | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| AnimationTree | **9** | 0 | 0 | 0 | 0 | 0 | 0 |
| 分析 | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| テスト/QA | **6** | 0 | 0 | 0 | 0 | 0 | 0 |
| アセット/AI | 0 | 0 | 1 | 6 | 0 | 0 | 0 |
| マテリアル | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| その他 | 0 | 0 | 9 | 5 | 5 | 2 | 1 |
| ヘッドレス | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| Androidデプロイ | **3** | 0 | 0 | 0 | 0 | 0 | 0 |
| **合計** | **187** | ~30 | **32** | **39** | **13** | **19** | **10** |

### 機能マトリクス

| 機能 | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (無料) | Dokujaa (無料) | Coding-Solo (無料) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **接続方式** | WebSocket（リアルタイム） | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | あり | あり | なし | なし | なし |
| **JSON-RPC 2.0** | あり | 独自 | 独自 | 独自 | N/A |
| **自動再接続** | あり（指数バックオフ） | N/A | なし | なし | N/A |
| **ハートビート** | あり（10秒 ping/pong） | なし | なし | なし | なし |
| **エラー時の提案** | あり（文脈に応じたヒント） | なし | なし | なし | なし |
| **スクリーンショット** | あり（エディタ + ゲーム） | あり | なし | なし | なし |
| **ゲーム入力シミュレーション** | あり（key/mouse/action/sequence） | あり（基本） | なし | なし | なし |
| **ランタイム検査** | あり（シーンツリー + プロパティ + モニター） | なし | なし | なし | なし |
| **シグナル管理** | あり（接続/切断/検査） | なし | なし | なし | なし |
| **ブラウザビジュアライザー** | なし | なし | あり | なし | なし |
| **AI 3Dメッシュ生成** | なし | なし | なし | あり（Meshy API） | なし |

### 独占カテゴリ（競合にはないもの）

| カテゴリ | ツール | 重要な理由 |
|----------|-------|----------------|
| **アニメーション** | 6ツール | アニメーション作成、トラック追加、キーフレーム設定 — すべてプログラムで |
| **TileMap** | 6ツール | セル設定、矩形塗りつぶし、タイルデータ取得 — 2Dレベルデザインに必須 |
| **テーマ/UI** | 8ツール | StyleBox、カラー、フォント — 手作業のエディタ操作なしでUIテーマを構築 |
| **プロファイリング** | 2ツール | FPS、メモリ、ドローコール、物理 — パフォーマンス監視 |
| **バッチ/リファクタ** | 7ツール | 型による検索、プロパティの一括変更、シーン横断の更新、依存関係分析 |
| **シェーダー** | 6ツール | シェーダーの作成/編集、マテリアル割り当て、パラメータ設定 |
| **エクスポート** | 4ツール | プリセット一覧、エクスポートコマンド取得、テンプレート確認 |
| **物理** | 6ツール | コリジョンシェイプ、ボディ、レイキャストのセットアップとレイヤー管理 |
| **3Dシーン** | 7ツール | メッシュ、カメラ、ライト、環境の追加、GridMap対応 |
| **パーティクル** | 5ツール | カスタムマテリアル、プリセット、グラデーションでパーティクルを作成 |
| **ナビゲーション** | 5ツール | ナビゲーションリージョン、エージェント、経路探索、ベイクを設定 |
| **オーディオ** | 6ツール | 完全なオーディオバスシステム、エフェクト、プレイヤー、ライブ管理 |
| **AnimationTree** | 9ツール | ステートマシン、トランジション、ブレンドツリー、IKモディファイア |
| **テスト/QA** | 6ツール | 自動テスト、アサーション、ストレステスト、スクリーンショット比較 |
| **ランタイム** | 20ツール | 実行時のゲームを検査・制御: 検査、記録、再生、ナビゲーション |

### アーキテクチャの優位性

| 観点 | Godot MCP Pro | 一般的な競合 |
|--------|--------------|-------------------|
| **プロトコル** | JSON-RPC 2.0（標準、拡張可能） | 独自JSONまたはCLIベース |
| **接続** | ハートビート付きの永続WebSocket | コマンドごとのサブプロセスまたは生TCP |
| **信頼性** | 指数バックオフによる自動再接続（1s→60s） | 手動での再接続が必要 |
| **型安全性** | スマート型解析（Vector2、Color、Rect2、16進カラー） | 文字列のみ、または限定的な型 |
| **エラー処理** | コード + 提案付きの構造化エラー | 汎用的なエラーメッセージ |
| **Undo対応** | すべての変更がUndoRedoシステムを経由 | 直接変更（Undo不可） |
| **ポート管理** | ポート6505-6509を自動スキャン | 固定ポート、競合の可能性あり |

## ライセンス

プロプライエタリ — 詳細は[LICENSE](../LICENSE)を参照してください。購入には生涯アップデートが含まれます。
