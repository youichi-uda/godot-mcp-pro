> **Language:** [English](../README.md) | 日本語 | [Português (BR)](README.pt-br.md) | [Español](README.es.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | [हिन्दी](README.hi.md)

# Godot MCP Pro

AI駆動のGodotゲーム開発のためのプレミアムMCP（Model Context Protocol）サーバー。ClaudeなどのAIアシスタントをGodotエディタに直接接続し、**163の強力なツール**を提供します。

## アーキテクチャ

```
AI Assistant ←—stdio/MCP—→ Node.js Server ←—WebSocket:6505—→ Godot Editor Plugin
```

- **リアルタイム**: WebSocket接続により即座にフィードバック、ファイルポーリング不要
- **エディタ統合**: GodotのエディタAPI、UndoRedoシステム、シーンツリーへのフルアクセス
- **JSON-RPC 2.0**: 適切なエラーコードとサジェスション付きの標準プロトコル

## クイックスタート

### 1. Godotプラグインのインストール

`addons/godot_mcp/` フォルダをGodotプロジェクトの `addons/` ディレクトリにコピーします。

プラグインを有効化: **プロジェクト → プロジェクト設定 → プラグイン → Godot MCP Pro → 有効化**

### 2. MCPサーバーのインストール

> **注意**: `server/` ディレクトリは**フルパッケージ**（有料版）にのみ含まれています。
> このGitHubリポジトリには**アドオン（プラグイン）のみ**が含まれています。
> サーバーを入手するには [godot-mcp.abyo.net](https://godot-mcp.abyo.net/) でフルパッケージをご購入ください。

```bash
cd server
npm install
npm run build
```

### 3. Claude Codeの設定

`.mcp.json` に以下を追加:

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

### 4. ツール権限の自動承認（推奨）

Claude Codeはツール呼び出しのたびに許可を求めます。これらのプロンプトをスキップするには、同梱の権限プリセットをClaude Codeの設定にコピーしてください:

**オプションA: 保守的**（デフォルト — 破壊的なツールをブロック）

```bash
cp settings.local.json ~/.claude/settings.local.json
```

163ツール中152ツールを自動で許可します。以下の11ツールは毎回手動承認が必要です:

| ブロックされるツール | 理由 |
|---|---|
| `delete_node` | シーンからノードを削除 |
| `delete_scene` | ディスクからシーンファイルを削除 |
| `remove_animation` | アニメーションを削除 |
| `remove_autoload` | Autoloadシングルトンを削除 |
| `remove_state_machine_state` | ステートマシンのステートを削除 |
| `remove_state_machine_transition` | ステートマシンのトランジションを削除 |
| `execute_editor_script` | エディタで任意のコードを実行 |
| `execute_game_script` | 実行中のゲームで任意のコードを実行 |
| `export_project` | プロジェクトのエクスポートを実行 |
| `tilemap_clear` | TileMapLayerの全セルをクリア |

**オプションB: 許容的**（すべて許可、危険なコマンドを拒否）

```bash
cp settings.local.permissive.json ~/.claude/settings.local.json
```

163ツールすべてとすべてのBashコマンドを許可します。破壊的なシェルコマンド（`rm -rf`、`git push --force`、`git reset --hard` など）と上記の破壊的MCPツールは明示的に拒否されます。

> **注意**: すでに `settings.local.json` がある場合は、上書きせずに `permissions` セクションを手動でマージしてください。

### 5. Liteモード（オプション）

MCPクライアントにツール数の制限がある場合（例: Windsurf: 100、Cursor: ~40）、162ツールの代わりに76のコアツールを登録するLiteモードを使用してください:

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

Liteモードに含まれるツール: project、scene、node、script、editor、input、runtime、input_map。

### 6. 使い方

プラグインを有効にした状態でGodotプロジェクトを開き、Claude Codeを使ってエディタと対話します。

## 全162ツール

### プロジェクトツール (7)
| ツール | 説明 |
|------|-------------|
| `get_project_info` | プロジェクトのメタデータ、バージョン、ビューポート、Autoload |
| `get_filesystem_tree` | フィルタリング付き再帰的ファイルツリー |
| `search_files` | ファジー/globファイル検索 |
| `get_project_settings` | project.godotの設定を読み取り |
| `set_project_setting` | エディタAPI経由でプロジェクト設定を変更 |
| `uid_to_project_path` | UID → res:// 変換 |
| `project_path_to_uid` | res:// → UID 変換 |

### シーンツール (9)
| ツール | 説明 |
|------|-------------|
| `get_scene_tree` | 階層付きライブシーンツリー |
| `get_scene_file_content` | .tscnファイルの生コンテンツ |
| `create_scene` | 新しいシーンファイルを作成 |
| `open_scene` | エディタでシーンを開く |
| `delete_scene` | シーンファイルを削除 |
| `add_scene_instance` | シーンを子ノードとしてインスタンス化 |
| `play_scene` | シーンを実行（メイン/現在/カスタム） |
| `stop_scene` | 実行中のシーンを停止 |
| `save_scene` | 現在のシーンをディスクに保存 |

### ノードツール (14)
| ツール | 説明 |
|------|-------------|
| `add_node` | タイプとプロパティを指定してノードを追加 |
| `delete_node` | ノードを削除（Undo対応） |
| `duplicate_node` | ノードと子ノードを複製 |
| `move_node` | ノードの移動/再親 |
| `update_property` | 任意のプロパティを設定（自動型変換） |
| `get_node_properties` | ノードの全プロパティを取得 |
| `add_resource` | Shape/Material等をノードに追加 |
| `set_anchor_preset` | Controlのアンカープリセットを設定 |
| `rename_node` | シーン内のノードをリネーム |
| `connect_signal` | ノード間のシグナルを接続 |
| `disconnect_signal` | シグナル接続を切断 |
| `get_node_groups` | ノードが属するグループを取得 |
| `set_node_groups` | ノードのグループメンバーシップを設定 |
| `find_nodes_in_group` | グループ内の全ノードを検索 |

### スクリプトツール (8)
| ツール | 説明 |
|------|-------------|
| `list_scripts` | クラス情報付きスクリプト一覧 |
| `read_script` | スクリプトの内容を読み取り |
| `create_script` | テンプレート付き新規スクリプト作成 |
| `edit_script` | 検索/置換またはフル編集 |
| `attach_script` | ノードにスクリプトをアタッチ |
| `get_open_scripts` | エディタで開いているスクリプト一覧 |
| `validate_script` | GDScriptの構文を検証 |
| `search_in_files` | プロジェクトファイル内のコンテンツを検索 |

### エディタツール (9)
| ツール | 説明 |
|------|-------------|
| `get_editor_errors` | エラーとスタックトレースを取得 |
| `get_editor_screenshot` | エディタビューポートをキャプチャ |
| `get_game_screenshot` | 実行中のゲームをキャプチャ |
| `execute_editor_script` | エディタで任意のGDScriptを実行 |
| `clear_output` | 出力パネルをクリア |
| `get_signals` | ノードの全シグナルと接続を取得 |
| `reload_plugin` | MCPプラグインを再読み込み（自動再接続） |
| `reload_project` | ファイルシステムを再スキャンしスクリプトを再読み込み |
| `get_output_log` | 出力パネルの内容を取得 |

### 入力ツール (7)
| ツール | 説明 |
|------|-------------|
| `simulate_key` | キーボードキーの押下/解放をシミュレート |
| `simulate_mouse_click` | 指定位置でのマウスクリックをシミュレート |
| `simulate_mouse_move` | マウス移動をシミュレート |
| `simulate_action` | Godot Input Actionをシミュレート |
| `simulate_sequence` | フレーム遅延付き入力イベントシーケンス |
| `get_input_actions` | 全入力アクション一覧 |
| `set_input_action` | 入力アクションの作成/変更 |

### ランタイムツール (19)
| ツール | 説明 |
|------|-------------|
| `get_game_scene_tree` | 実行中ゲームのシーンツリー |
| `get_game_node_properties` | 実行中ゲームのノードプロパティ |
| `set_game_node_property` | 実行中ゲームのノードプロパティを設定 |
| `execute_game_script` | ゲームコンテキストでGDScriptを実行 |
| `capture_frames` | マルチフレームスクリーンショットキャプチャ |
| `monitor_properties` | プロパティ値の時系列記録 |
| `start_recording` | 入力録画を開始 |
| `stop_recording` | 入力録画を停止 |
| `replay_recording` | 録画した入力を再生 |
| `find_nodes_by_script` | スクリプトでゲームノードを検索 |
| `get_autoload` | Autoloadノードのプロパティを取得 |
| `batch_get_properties` | 複数ノードのプロパティを一括取得 |
| `find_ui_elements` | ゲーム内のUI要素を検索 |
| `click_button_by_text` | テキストでボタンをクリック |
| `wait_for_node` | ノードの出現を待機 |
| `find_nearby_nodes` | 位置近傍のノードを検索 |
| `navigate_to` | ターゲット位置へナビゲート |
| `move_to` | キャラクターをターゲットまで歩かせる |

### アニメーションツール (6)
| ツール | 説明 |
|------|-------------|
| `list_animations` | AnimationPlayerの全アニメーション一覧 |
| `create_animation` | 新規アニメーション作成 |
| `add_animation_track` | トラック追加（value/position/rotation/method/bezier） |
| `set_animation_keyframe` | トラックにキーフレームを挿入 |
| `get_animation_info` | 全トラック/キー付き詳細アニメーション情報 |
| `remove_animation` | アニメーションを削除 |

### TileMapツール (6)
| ツール | 説明 |
|------|-------------|
| `tilemap_set_cell` | 単一タイルセルを設定 |
| `tilemap_fill_rect` | 矩形領域をタイルで塗りつぶし |
| `tilemap_get_cell` | セルのタイルデータを取得 |
| `tilemap_clear` | 全セルをクリア |
| `tilemap_get_info` | TileMapLayerの情報とタイルセットソース |
| `tilemap_get_used_cells` | 使用中セルの一覧 |

### テーマ & UIツール (6)
| ツール | 説明 |
|------|-------------|
| `create_theme` | Themeリソースファイルを作成 |
| `set_theme_color` | テーマカラーオーバーライドを設定 |
| `set_theme_constant` | テーマ定数オーバーライドを設定 |
| `set_theme_font_size` | テーマフォントサイズオーバーライドを設定 |
| `set_theme_stylebox` | StyleBoxFlatオーバーライドを設定 |
| `get_theme_info` | テーマオーバーライド情報を取得 |

### プロファイリングツール (2)
| ツール | 説明 |
|------|-------------|
| `get_performance_monitors` | 全パフォーマンスモニター（FPS、メモリ、物理等） |
| `get_editor_performance` | パフォーマンス概要 |

### バッチ & リファクタリングツール (8)
| ツール | 説明 |
|------|-------------|
| `find_nodes_by_type` | タイプで全ノードを検索 |
| `find_signal_connections` | シーン内の全シグナル接続を検索 |
| `batch_set_property` | タイプの全ノードにプロパティを設定 |
| `find_node_references` | プロジェクトファイル内のパターン検索 |
| `get_scene_dependencies` | リソース依存関係を取得 |
| `cross_scene_set_property` | 全シーン横断でプロパティを設定 |
| `find_script_references` | スクリプト/リソースの使用箇所を検索 |
| `detect_circular_dependencies` | シーンの循環依存を検出 |

### シェーダーツール (6)
| ツール | 説明 |
|------|-------------|
| `create_shader` | テンプレート付きシェーダー作成 |
| `read_shader` | シェーダーファイルを読み取り |
| `edit_shader` | シェーダーを編集（置換/検索置換） |
| `assign_shader_material` | ShaderMaterialをノードに割り当て |
| `set_shader_param` | シェーダーパラメータを設定 |
| `get_shader_params` | 全シェーダーパラメータを取得 |

### エクスポートツール (3)
| ツール | 説明 |
|------|-------------|
| `list_export_presets` | エクスポートプリセット一覧 |
| `export_project` | プリセットのエクスポートコマンドを取得 |
| `get_export_info` | エクスポート関連のプロジェクト情報 |

### リソースツール (6)
| ツール | 説明 |
|------|-------------|
| `read_resource` | .tresリソースのプロパティを読み取り |
| `edit_resource` | リソースプロパティを編集 |
| `create_resource` | 新規.tresリソースを作成 |
| `get_resource_preview` | リソースのサムネイルを取得 |
| `add_autoload` | Autoloadシングルトンを登録 |
| `remove_autoload` | Autoloadシングルトンを削除 |

### 物理ツール (6)
| ツール | 説明 |
|------|-------------|
| `setup_physics_body` | 物理ボディのプロパティを設定 |
| `setup_collision` | ノードにコリジョンシェイプを追加 |
| `set_physics_layers` | コリジョンレイヤー/マスクを設定 |
| `get_physics_layers` | コリジョンレイヤー/マスク情報を取得 |
| `get_collision_info` | コリジョンシェイプの詳細を取得 |
| `add_raycast` | RayCast2D/3Dノードを追加 |

### 3Dシーンツール (6)
| ツール | 説明 |
|------|-------------|
| `add_mesh_instance` | プリミティブメッシュ付きMeshInstance3Dを追加 |
| `setup_camera_3d` | Camera3Dのプロパティを設定 |
| `setup_lighting` | ライトノードの追加/設定 |
| `setup_environment` | WorldEnvironmentを設定 |
| `add_gridmap` | GridMapノードをセットアップ |
| `set_material_3d` | StandardMaterial3Dのプロパティを設定 |

### パーティクルツール (5)
| ツール | 説明 |
|------|-------------|
| `create_particles` | GPUParticles2D/3Dを作成 |
| `set_particle_material` | ParticleProcessMaterialを設定 |
| `set_particle_color_gradient` | パーティクルのカラーグラデーションを設定 |
| `apply_particle_preset` | プリセットを適用（fire、smoke、sparks等） |
| `get_particle_info` | パーティクルシステムの詳細を取得 |

### ナビゲーションツール (6)
| ツール | 説明 |
|------|-------------|
| `setup_navigation_region` | NavigationRegionを設定 |
| `setup_navigation_agent` | NavigationAgentを設定 |
| `bake_navigation_mesh` | ナビゲーションメッシュをベイク |
| `set_navigation_layers` | ナビゲーションレイヤーを設定 |
| `get_navigation_info` | ナビゲーション設定情報を取得 |

### オーディオツール (6)
| ツール | 説明 |
|------|-------------|
| `add_audio_player` | AudioStreamPlayerノードを追加 |
| `add_audio_bus` | オーディオバスを追加 |
| `add_audio_bus_effect` | オーディオバスにエフェクトを追加 |
| `set_audio_bus` | オーディオバスのプロパティを設定 |
| `get_audio_bus_layout` | オーディオバスレイアウト情報を取得 |
| `get_audio_info` | オーディオ関連ノード情報を取得 |

### AnimationTreeツール (4)
| ツール | 説明 |
|------|-------------|
| `create_animation_tree` | AnimationTreeを作成 |
| `get_animation_tree_structure` | ツリー構造を取得 |
| `set_tree_parameter` | AnimationTreeパラメータを設定 |
| `add_state_machine_state` | ステートマシンにステートを追加 |

### ステートマシンツール (3)
| ツール | 説明 |
|------|-------------|
| `remove_state_machine_state` | ステートマシンからステートを削除 |
| `add_state_machine_transition` | ステート間のトランジションを追加 |
| `remove_state_machine_transition` | ステートのトランジションを削除 |

### ブレンドツリーツール (1)
| ツール | 説明 |
|------|-------------|
| `set_blend_tree_node` | ブレンドツリーノードを設定 |

### 分析 & 検索ツール (4)
| ツール | 説明 |
|------|-------------|
| `analyze_scene_complexity` | シーンのパフォーマンスを分析 |
| `analyze_signal_flow` | シグナル接続をマッピング |
| `find_unused_resources` | 未参照リソースを検索 |
| `get_project_statistics` | プロジェクト全体の統計を取得 |

### テスト & QAツール (6)
| ツール | 説明 |
|------|-------------|
| `run_test_scenario` | 自動テストシナリオを実行 |
| `assert_node_state` | ノードプロパティ値をアサート |
| `assert_screen_text` | 画面上のテキストを確認 |
| `compare_screenshots` | 2つのスクリーンショットを比較 |
| `run_stress_test` | パフォーマンスストレステストを実行 |
| `get_test_report` | テスト結果レポートを取得 |

## 主な特徴

- **UndoRedo統合**: すべてのノード/プロパティ操作がCtrl+Zに対応
- **スマート型変換**: `"Vector2(100, 200)"`、`"#ff0000"`、`"Color(1,0,0)"` を自動変換
- **自動再接続**: 指数バックオフによる再接続（1秒 → 2秒 → 4秒 ... → 最大60秒）
- **ハートビート**: 10秒間隔のping/pongで接続を維持
- **親切なエラー**: エラーレスポンスに次のステップのサジェスションを含む

## 競合比較

### ツール数

| カテゴリ | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) | ee0pdt (free) | bradypp (free) |
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
| **合計** | **162** | ~30 | **32** | **39** | **13** | **19** | **10** |

### 機能マトリクス

| 機能 | Godot MCP Pro | GDAI MCP ($19) | tomyud1 (free) | Dokujaa (free) | Coding-Solo (free) |
|---------|:---:|:---:|:---:|:---:|:---:|
| **接続方式** | WebSocket (リアルタイム) | stdio (Python) | WebSocket | TCP Socket | Headless CLI |
| **Undo/Redo** | 対応 | 対応 | 非対応 | 非対応 | 非対応 |
| **JSON-RPC 2.0** | 対応 | カスタム | カスタム | カスタム | N/A |
| **自動再接続** | 対応（指数バックオフ） | N/A | 非対応 | 非対応 | N/A |
| **ハートビート** | 対応（10秒ping/pong） | 非対応 | 非対応 | 非対応 | 非対応 |
| **エラーサジェスション** | 対応（コンテキスト依存ヒント） | 非対応 | 非対応 | 非対応 | 非対応 |
| **スクリーンショット** | 対応（エディタ + ゲーム） | 対応 | 非対応 | 非対応 | 非対応 |
| **ゲーム入力シミュレーション** | 対応（キー/マウス/アクション/シーケンス） | 対応（基本） | 非対応 | 非対応 | 非対応 |
| **ランタイムインスペクション** | 対応（シーンツリー + プロパティ + モニター） | 非対応 | 非対応 | 非対応 | 非対応 |
| **シグナル管理** | 対応（接続/切断/検査） | 非対応 | 非対応 | 非対応 | 非対応 |
| **ブラウザビジュアライザー** | 非対応 | 非対応 | 対応 | 非対応 | 非対応 |
| **AI 3Dメッシュ生成** | 非対応 | 非対応 | 非対応 | 対応（Meshy API） | 非対応 |

### 独占カテゴリ（競合にはないもの）

| カテゴリ | ツール数 | 重要な理由 |
|----------|-------|----------------|
| **Animation** | 6ツール | アニメーション作成、トラック追加、キーフレーム設定 — すべてプログラム的に |
| **TileMap** | 6ツール | セル設定、矩形塗りつぶし、タイルデータ取得 — 2Dレベルデザインに必須 |
| **Theme/UI** | 6ツール | StyleBox、カラー、フォント — 手動エディタ作業なしでUIテーマを構築 |
| **Profiling** | 2ツール | FPS、メモリ、描画コール、物理 — パフォーマンス監視 |
| **Batch/Refactor** | 8ツール | タイプ検索、一括プロパティ変更、シーン横断更新、依存関係分析 |
| **Shader** | 6ツール | シェーダーの作成/編集、マテリアル割り当て、パラメータ設定 |
| **Export** | 3ツール | プリセット一覧、エクスポートコマンド取得、テンプレート確認 |
| **Physics** | 6ツール | コリジョンシェイプ、ボディ、レイキャスト、レイヤー管理のセットアップ |
| **3D Scene** | 6ツール | メッシュ、カメラ、ライト、環境、GridMapサポートの追加 |
| **Particle** | 5ツール | カスタムマテリアル、プリセット、グラデーション付きパーティクル作成 |
| **Navigation** | 6ツール | ナビゲーションリージョン、エージェント、パスファインディング、ベイクの設定 |
| **Audio** | 6ツール | 完全なオーディオバスシステム、エフェクト、プレイヤー、ライブ管理 |
| **AnimationTree** | 4ツール | トランジションとブレンドツリー付きステートマシンを構築 |
| **State Machine** | 3ツール | 複雑なアニメーション向け高度なステートマシン管理 |
| **Testing/QA** | 6ツール | 自動テスト、アサーション、ストレステスト、スクリーンショット比較 |
| **Runtime** | 19ツール | 実行時のゲームを検査・制御: インスペクト、録画、再生、ナビゲート |

### アーキテクチャの優位性

| 観点 | Godot MCP Pro | 一般的な競合 |
|--------|--------------|-------------------|
| **プロトコル** | JSON-RPC 2.0（標準、拡張可能） | カスタムJSONまたはCLIベース |
| **接続** | ハートビート付き永続WebSocket | コマンドごとのサブプロセスまたは生TCP |
| **信頼性** | 指数バックオフ付き自動再接続（1秒→60秒） | 手動再接続が必要 |
| **型安全性** | スマート型変換（Vector2、Color、Rect2、16進カラー） | 文字列のみまたは限定的な型 |
| **エラーハンドリング** | コード + サジェスション付き構造化エラー | 汎用エラーメッセージ |
| **Undoサポート** | すべての変更がUndoRedoシステムを経由 | 直接変更（Undo不可） |
| **ポート管理** | ポート6505-6509の自動スキャン | 固定ポート、競合の可能性 |

## ライセンス

プロプライエタリ — 詳細は[LICENSE](../LICENSE)を参照。購入にはv1.xの生涯アップデートが含まれます。
