# Android MCP setup

This workstation uses [`minhalvp/android-mcp-server`](https://github.com/minhalvp/android-mcp-server) pinned to commit `451d255a7305e6efef8a1a2b7374a21c512bba45`.

It exposes these Codex tools through ADB:

- installed-package inspection;
- screenshots;
- Android UI hierarchy and clickable-element coordinates;
- package action intents;
- Android shell commands.

The server is installed globally in the local Codex MCP configuration and uses `uv` with Python 3.11. Restart Codex after adding or changing an MCP server.

## Work-computer setup

1. Install Android Platform Tools and `uv`.
2. Enable Developer options and USB debugging on the Android phone.
3. On Xiaomi/HyperOS, also enable **USB debugging (Security settings)** if automated taps are needed.
4. Connect the phone, accept its RSA prompt, and confirm `adb devices` shows `device`.
5. Clone the Android MCP repository and check out the pinned commit above.
6. Run `uv sync --extra test` and `uv run pytest -q`.
7. Add the server to Codex as an STDIO MCP server, with the Platform Tools folder on its `PATH`.
8. Use a prompt approval policy for the server because `execute_adb_shell_command` can perform powerful device actions.

The MCP server cannot bypass Android's lock screen or Xiaomi's ADB security controls. Keep the phone unlocked and awake during automated visual QA.

