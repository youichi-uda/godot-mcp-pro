> **Language:** [English](skills.md) | 日本語 | [Português (BR)](skills.pt-br.md) | [Español](skills.es.md) | [Русский](skills.ru.md) | [简体中文](skills.zh.md) | [हिन्दी](skills.hi.md)

# Godot MCP Pro — AIアシスタント向けスキル

> このファイルをGodotプロジェクトルートの `.claude/skills.md` にコピーすると、Claude CodeがGodot MCP Proを効果的に活用するためのコンテキストを得られます。

## Godot MCP Proとは？

Godot 4エディタに直接接続する169のMCPツールを利用できます。シーンの作成、スクリプトの記述、プレイヤー入力のシミュレーション、実行中のゲームの検査など、ユーザーがこの会話から離れることなく、すべての操作が可能です。すべての変更はGodotのUndoRedoシステムを通じて行われるため、いつでもCtrl+Zで元に戻せます。

## 基本ワークフロー

### 1. プロジェクトの調査

変更を加える前に、まずプロジェクトの全体像を把握しましょう：

```
get_project_info          → プロジェクト名、Godotバージョン、レンダラー、ビューポートサイズ
get_filesystem_tree       → ディレクトリ構造（filter: "*.tscn" や "*.gd" が使えます）
get_scene_tree            → 現在開いているシーンのノード階層
read_script               → 任意のGDScriptファイルを読む
get_project_settings      → プロジェクト設定の確認
```

### 2. 2Dシーンの構築

```
create_scene   → .tscnファイルをルートノードタイプ指定で作成
add_node       → プロパティ付きの子ノードを追加
create_script  → ゲームロジック用のGDScriptを作成
attach_script  → ノードにスクリプトをアタッチ
update_property → position、scale、modulateなどを設定
save_scene     → ディスクに保存
```

**例 — プレイヤーの作成：**
1. `create_scene` でroot_type `CharacterBody2D`、path `res://scenes/player.tscn` を指定
2. `add_node` でtextureプロパティ付きの `Sprite2D` を追加
3. `add_node` で `CollisionShape2D` を追加
4. `add_resource` でCollisionShape2Dにシェイプ（例：`RectangleShape2D`）を割り当て
5. `create_script` で移動ロジックを記述
6. `attach_script` でルートノードにアタッチ
7. `save_scene`

### 3. 3Dシーンの構築

```
create_scene         → root_type: Node3D
add_mesh_instance    → プリミティブ（box、sphere、cylinder、plane）の追加、または.glb/.gltfのインポート
setup_lighting       → DirectionalLight3D、OmniLight3D、SpotLight3Dの追加
setup_environment    → スカイ、アンビエントライト、フォグ、トーンマップ
setup_camera_3d      → カメラ（オプションでSpringArm3Dによる三人称視点）
set_material_3d      → PBRマテリアル（albedo、metallic、roughness、emission）
setup_collision      → 物理ボディにコリジョンシェイプを追加
setup_physics_body   → 質量、摩擦、重力の設定
```

### 4. スクリプトの作成と編集

```
create_script  → 新規.gdファイルを作成（完全な内容を提供）
edit_script    → 既存スクリプトを編集
  - `replacements: [{search: "old code", replace: "new code"}]` で部分的な編集
  - `content` でファイル全体を置換
  - `insert_at_line` + `text` でコードを挿入
validate_script → 実行せずに構文エラーをチェック
read_script    → 編集前に現在の内容を確認
```

### 5. プレイテストとデバッグ

```
play_scene             → ゲームを起動（mode: "current"、"main"、またはファイルパス）
get_game_screenshot    → ゲームの現在の見た目を確認
capture_frames         → 複数フレームをキャプチャして動きやアニメーションを観察
get_game_scene_tree    → 実行時のシーンツリーを検査
get_game_node_properties → ランタイムの値を読み取り（position、health、stateなど）
set_game_node_property → 実行中のゲームの値を変更
simulate_key           → キー入力（WASD、SPACEなど）をduration指定で実行
simulate_mouse_click   → ビューポート座標でクリック
simulate_action        → InputMapアクション（move_left、jumpなど）をトリガー
get_editor_errors      → ランタイムエラーの確認
stop_scene             → ゲームを停止
```

**プレイテストループ：**
1. `play_scene` → ゲームを開始
2. `get_game_screenshot` → 現在の状態を確認
3. `simulate_key` / `simulate_action` → ゲームを操作
4. `capture_frames` → 時間経過での挙動を観察
5. `get_game_node_properties` → 特定の値を確認
6. `stop_scene` → 完了したら停止
7. スクリプトの問題を修正 → 繰り返し

### 6. アニメーション

```
# シーンにAnimationPlayerノードが存在することを確認
create_animation       → 長さとループモード付きの新規アニメーション
add_animation_track    → property/transform/methodトラックの追加
set_animation_keyframe → 特定時間にキーフレームを挿入
get_animation_info     → 既存アニメーションの情報を取得
```

**例 — バウンドするスプライト：**
1. `create_animation` でname `bounce`、length `1.0`、loop_mode `1`（リニアループ）
2. `add_animation_track` でtrack_path `Sprite2D:position`、track_type `value`
3. `set_animation_keyframe` でtime `0.0`、value `Vector2(0, 0)`
4. `set_animation_keyframe` でtime `0.5`、value `Vector2(0, -50)`
5. `set_animation_keyframe` でtime `1.0`、value `Vector2(0, 0)`

### 7. UI / HUD

```
add_node          → Control、Label、Button、TextureRectなど
set_anchor_preset → Controlの配置（full_rect、center、bottom_wideなど）
set_theme_color   → font_colorなどの変更
set_theme_font_size → テキストサイズの調整
set_theme_stylebox  → 背景、ボーダー、角丸
connect_signal    → buttonのpressed、value_changedなどを接続
```

### 8. TileMap

```
tilemap_get_info      → タイルセットのソースとアトラスレイアウトを確認
tilemap_set_cell      → 個別タイルの配置
tilemap_fill_rect     → 矩形領域を塗りつぶし
tilemap_get_used_cells → 配置済みセルの確認
tilemap_clear         → 全セルをクリア
```

### 9. オーディオ

```
add_audio_bus        → オーディオバスの作成（SFX、Music、UI）
set_audio_bus        → ボリューム、ソロ、ミュートの調整
add_audio_bus_effect → リバーブ、ディレイ、コンプレッサーなどの追加
add_audio_player     → AudioStreamPlayer(2D/3D)ノードの追加
```

### 10. プロジェクト設定

```
set_project_setting  → ビューポートサイズ、物理設定などの変更
set_input_action     → 入力マッピングの定義（move_left → KEY_Aなど）
add_autoload         → Autoloadシングルトンの登録
set_physics_layers   → コリジョンレイヤーの命名（player、enemy、worldなど）
```

## 重要なルールと注意点

### プロパティ値

プロパティは文字列から自動パースされます。以下のフォーマットを使用してください：
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Color: `"Color(1, 0, 0, 1)"` または `"#ff0000"`
- Bool: `"true"` / `"false"`
- 数値: `"42"`、`"3.14"`
- Enum: 整数値を使用（例：最初のenum値は `0`）

### project.godotを直接編集しないこと

Godotエディタは `project.godot` を常に上書きします。プロジェクト設定の変更には必ず `set_project_setting` を使用してください。

### GDScriptの型アノテーション

型なし配列に対する `for` ループでは、明示的な型アノテーションを使用してください：
```gdscript
# NG — エラーの原因になる
for item in some_untyped_array:
    var x := item.value  # 型推論が失敗

# OK
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

### スクリプト変更にはリロードが必要

スクリプトの作成や大幅な変更の後は、`reload_project` を使用してGodotに変更を反映させましょう。特に `create_script` の後は重要です。

### simulate_keyのコツ
- 精密な移動には**短いduration**（0.3〜0.5秒）を使用
- 長いduration（1秒以上）はオーバーシュートの原因に
- ゲームプレイのテストでは、InputMapアクションが定義されている場合は `simulate_key` より `simulate_action` を推奨

### simulate_mouse_click
- デフォルトの `auto_release: true` はpressとreleaseの両方を送信 — UIボタンに必須
- UIボタンはreleaseで発火するため、両方のイベントが必要

### execute_game_scriptの制限事項
- ネストされた関数（`func` 内の `func`）は不可 — コンパイルエラーになる
- 動的アクセスには `.property` ではなく `.get("property")` を使用
- ランタイムエラーはデバッガーを一時停止させる（自動再開されるが、できれば避けること）

### コリジョンとピックアップエリア
- 収集アイテムにはArea3D/Area2Dで半径1.5以上を使用
- 小さい半径ではシミュレーション入力でのトリガーがほぼ不可能

### こまめに保存する

大きな変更を行った後は `save_scene` を呼んでください。保存していない変更はエディタのリロード時に失われる可能性があります。

## 分析とデバッグツール

問題が発生した場合、以下のツールで調査できます：

```
get_editor_errors          → スクリプトエラーとランタイム例外を確認
get_output_log             → print()出力と警告を読む
analyze_scene_complexity   → パフォーマンスのボトルネックを特定
analyze_signal_flow        → シグナル接続を可視化
detect_circular_dependencies → 循環参照するスクリプト/シーンを検出
find_unused_resources      → 未使用ファイルのクリーンアップ
get_performance_monitors   → FPS、メモリ、ドローコール、物理統計
```

## テストとQA

```
run_test_scenario   → 自動テストシーケンスの定義と実行
assert_node_state   → ノードプロパティが期待値と一致するか検証
assert_screen_text  → 画面にテキストが表示されているか検証
compare_screenshots → ビジュアル回帰テスト（base64ではなくファイルパスを使用）
run_stress_test     → 多数のノードを生成してパフォーマンスをテスト
```

## 高度なパターン

### クロスシーン操作
```
cross_scene_set_property → 現在開いていないシーンのノードを変更
find_node_references     → パターンを参照しているすべてのファイルを検索
batch_set_property       → 特定タイプの全ノードにプロパティを設定
```

### シェーダーワークフロー
```
create_shader        → GLSL風のシェーダーコードを記述
assign_shader_material → ノードに適用
set_shader_param     → 実行時にuniformを調整
get_shader_params    → 現在の値を取得
```

### ナビゲーション（3D）
```
setup_navigation_region → 歩行可能エリアの定義
bake_navigation_mesh   → ナビメッシュの生成
setup_navigation_agent → キャラクターにパスファインディングを追加
```

### AnimationTreeとステートマシン
```
create_animation_tree           → ステートマシンまたはブレンドツリーでAnimationTreeをセットアップ
add_state_machine_state         → ステートを追加（idle、walk、run、jump）
add_state_machine_transition    → ステート間のトランジションを定義
set_tree_parameter              → ブレンドパラメータを制御
```

## 推奨ワークフロー順序

ゲームをゼロから構築する場合の推奨順序：

1. **プロジェクトセットアップ** — `get_project_info`、`set_project_setting`（ビューポート、物理）
2. **入力マッピング** — `set_input_action` で全プレイヤー操作を定義
3. **メインシーン** — `create_scene` でメインシーンとして設定
4. **プレイヤー** — スプライト、コリジョン、スクリプト付きのプレイヤーシーンを作成
5. **レベル/ワールド** — 環境を構築（TileMap、3Dメッシュなど）
6. **ゲームロジック** — 敵、アイテム、UIのスクリプト
7. **オーディオ** — バスのセットアップ、オーディオプレイヤーの追加
8. **プレイテスト** — `play_scene` でシミュレーション入力によるテスト、バグ修正
9. **ポリッシュ** — アニメーション、パーティクル、シェーダー、テーマ
10. **エクスポート** — `list_export_presets`、`export_project`
