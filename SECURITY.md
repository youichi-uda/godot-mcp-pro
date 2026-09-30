# Security

This document describes what Godot MCP Pro does and does not protect against. It
is deliberately specific about the weak points, because a vague assurance is
worse than none.

## Trust model

**The trust boundary is any process running as your user on your machine.**
Inside it there is no further protection. Outside it there is no exposure.

- Both port ranges bind to `127.0.0.1` only — `6505–6509` for MCP servers,
  `6510–6514` for `godot-cli`. Nothing is reachable from the network.
- The MCP server is a local Node process your client launches. Its only runtime
  dependencies are `@modelcontextprotocol/sdk` and `ws`.
- The addon is plain GDScript, shipped in the release and mirrored in the public
  repository, so it can be read without being run.

A local process capable of attacking this could already edit your project files
directly. The addon does not widen that boundary much — but it does make
crossing it more convenient, which is the part worth understanding.

## The editor dials out

This is the least obvious property and the one most worth knowing.

Each MCP server **listens** on a port in its range, and the Godot plugin
**connects out** to every port in that range. The plugin is the client; the
server is not.

The consequence: a process that binds one of those ports before the real server
does will receive the editor's connection, and can then issue any command the
plugin accepts — including `execute_editor_script`, which runs arbitrary
GDScript inside the editor process.

By default there is **no authentication on that connection**. See
[Connection token](#connection-token-optional) for an opt-in mitigation, and note
its limits: a process running as *you* can read the token file, so the token
does not defend against a same-user attacker. It defends against other users on
a shared machine and against cross-project mix-ups.

## `execute_editor_script` is not sandboxed

The tool refuses code whose text contains `ResourceSaver.save(`,
`ProjectSettings.save(`, `ConfigFile.save(`, `DirAccess` mutations, or
`FileAccess.open` in a write mode. `allow_unsafe_editor_io=true` overrides it.

**This is an accident guard, not a security control.** It is a string match on
the submitted source. Code that assembles such a call dynamically walks past it,
and many destructive APIs are not on the list at all. Its purpose is to stop an
agent from clobbering an open resource by mistake.

If you need the editing tools without arbitrary execution, disable
`execute_editor_script` — see below.

## Reducing the surface

- **Per-tool disabling.** The MCP Server status panel in the editor lets you
  switch individual tools off; the router then refuses them with `-32603`. This
  is the lever for running without `execute_editor_script`, or without the
  runtime tools.
- **Smaller modes.** Starting the server with `--minimal` or `--lite` registers
  a reduced tool set, which lowers the surface as a side effect.
- **Write guards.** Tools refuse to overwrite scenes and scripts that are open in
  the editor unless `force=true`, and refuse to write to a path whose extension
  does not match the kind of file they produce. These exist for correctness, but
  they also blunt accidental damage.

## Connection token (optional)

Disabled by default; enabling it changes nothing for clients that do not use it.

When enabled, the plugin generates a random token at startup, writes it to
`user://mcp_auth_token`, and requires a connecting server to prove it knows the
token before any command is accepted. A server presents it via the
`GODOT_MCP_TOKEN` environment variable or by reading the same file.

Enable it in the editor: **Project → Project Settings → Godot MCP Pro →
`require_connection_token`**, or set the environment variable
`GODOT_MCP_REQUIRE_TOKEN=1` before launching the editor.

What it protects against:

- Another user on a shared machine binding the port range first.
- A server belonging to a different project connecting by accident.

What it does **not** protect against:

- A process running as you. It can read `user://mcp_auth_token` exactly as the
  legitimate server does.

## Other processes on the same project

The editor and the played game talk over small JSON files in the project's
`user://` directory (`mcp_game_request`, `mcp_input_commands`,
`mcp_screenshot_request`, …). Every Godot process of that project shares that
directory — a manually started test run, a leftover play session that never
stopped, a second editor — and any of them can read, answer, or inject through
those files. This sits inside the trust boundary above, but it bites by
accident far more often than on purpose.

What the addon does about it:

- **Requests name their editor** (`editor_pid`). A game process started by an
  editor (it receives `--editor-pid` on its command line) ignores requests that
  name a different editor, leaving them for that editor's own processes.
- **Every runtime response names its responder** (`game_pid`). When a stray
  process does answer, the mismatch is visible immediately instead of looking
  like a bug in the tool.
- **Screenshot requests always produce an outcome file** (`mcp_screenshot_result`)
  naming the process that took them and why it could or could not render — a
  headless process can never produce an image, and now says so instead of
  vanishing into a generic timeout.

What you should do about it:

- **Start test processes with `GODOT_MCP_HEADLESS_CHILD=1`** in their
  environment (the addon's own `run_headless_scene` does this). Their MCP
  services then never come up, so they cannot consume or answer anything.
- When runtime tools misbehave — screenshots time out although the game runs,
  scene queries return a scene you did not start — check
  `pgrep -af godot` for a second process of the same project and close it.

## Reporting a vulnerability

Open a GitHub issue for anything already public, or contact the author directly
for something that should be handled quietly first. Please include the version
(`plugin.cfg` and the server's `package.json`), your OS, and the smallest
reproduction you can manage.
