# Cleanup and How `panel` Opens the Browser

## Kill orphaned servers

If a previous session launched orphaned processes (canvas or standalone), clean them up:

```bash
# List active canvas sessions
streamweaver canvas-list

# Close a specific canvas session
streamweaver canvas-close brainstorm

# Stop the entire canvas bridge
streamweaver canvas-stop

# List all loaded StreamWeaver apps
streamweaver list

# Remove all apps from the service
streamweaver clear

# Find orphaned StreamWeaver processes by port range
lsof -i :4567-4600 -sTCP:LISTEN

# Kill a specific port (e.g., 4570)
lsof -ti :4570 | xargs kill -9
```

## How `streamweaver panel` opens the browser

**You don't need to detect the terminal or call any helper scripts.** `streamweaver panel <session>` figures out the best experience automatically:

- **In iTerm2:** opens as a vertical split pane next to the terminal so the canvas lives alongside the conversation. This is the ideal UX — the user sees diagrams without leaving the terminal context.
- **Anywhere else (Terminal.app, VSCode terminal, kitty, alacritty, tmux, SSH, Linux):** opens in the default system browser (a new tab/window) and prints the URL.

Either way the URL is printed in stdout so the user has a fallback.

**Anti-patterns to avoid:**
- Don't run `python` scripts to drive iTerm — the `iterm2_ruby` gem (on RubyGems) drives iTerm natively and the CLI handles invocation.
- Don't try to `osascript`/AppleScript the iTerm split yourself — `streamweaver panel` already does this through the iTerm2 Ruby API.
- Don't open the browser with a shell `open` / `xdg-open` after `streamweaver panel` — it already opened one (or split into one). Doing so creates duplicates.

If you specifically need the browser opened externally even when iTerm is available (e.g., for screen sharing on a separate display), that's a feature request — file a bd issue rather than working around it in the skill.
