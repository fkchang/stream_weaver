# Canvas IPC Session Summary

**Date:** January 2025
**Branch:** `feature/canvas-ipc`
**Status:** Superseded by template-based approach

## What We Attempted

Implement two-way IPC similar to [claude-canvas](https://github.com/BEARLY-HODLING/claude-canvas):
- Unix socket for Claude CLI ↔ Bridge communication
- WebSocket mode for Bridge ↔ Browser (partially implemented)
- Commands: `canvas`, `canvas-push`, `canvas-wait`, `canvas-close`, `pick`, `confirm`

## Overlap with Template Approach

Both solve the same problem: **Push UI → Wait for response → Get JSON**

| Feature | Canvas (this session) | Templates (other thread) |
|---------|----------------------|-------------------------|
| Push UI | `canvas-push` via Unix socket | `push` via HTTP |
| Wait for response | `canvas-wait` (Unix socket, broken) | `wait` (HTTP polling, working) |
| Confirm dialog | `streamweaver confirm` | `streamweaver template confirm` |
| Pick/choices | `streamweaver pick` | `streamweaver template choices` |

**The template approach won** - simpler architecture, working code.

## Dead Code (if going with templates)

### Files to Delete (~1023 lines)

```
lib/stream_weaver/canvas/
  protocol.rb        # 69 lines - Unix socket message encoding
  session.rb         # 66 lines - Session with websocket tracking
  bridge.rb          # 161 lines - Message routing
  client.rb          # 205 lines - CLI to Unix socket communication
  bridge_server.rb   # 413 lines - Sinatra + Unix socket server
  helpers.rb         # 109 lines - DSL generators (overlaps with templates)
```

### CLI Commands to Remove (cli.rb lines 58-73)

```ruby
when 'canvas'        # line 58
when 'canvas-push'   # line 60
when 'canvas-wait'   # line 62
when 'canvas-close'  # line 64
when 'canvas-list'   # line 66
when 'canvas-stop'   # line 68
when 'pick'          # line 71 (use `template choices` instead)
when 'confirm'       # line 73 (use `template confirm` instead)
```

Plus the method implementations (~300 lines):
- `canvas_session`
- `canvas_push`
- `canvas_wait`
- `canvas_close`
- `canvas_list`
- `canvas_stop`
- `canvas_pick`
- `canvas_confirm`

### Dead Code in alpinejs.rb

WebSocket mode code (~100 lines) only used by canvas:
- Line 25-34: `mode` parameter and `websocket_mode?` method
- Line 317-335: WebSocket mode in `render_radio_group`
- Line 451-458: WebSocket mode in `render_button`
- Line 499-505: WebSocket mode in `container_attributes`
- Line 570-665: `websocket_init_script` method (sendEvent, getFormState, WebSocket connection)

## What's NOT Dead Code

### In alpinejs.rb - Keep These

The HTTP fallback for `sendEvent` and visual feedback are useful but currently embedded in websocket_init_script. If removing websocket mode, these would be lost.

### Templates Already Cover

- `templates/confirm.rb` - Better than `canvas/helpers.rb` confirm
- `templates/choices.rb` - Better than `pick` command
- `templates/wizard.rb` - Multi-step forms (no canvas equivalent)
- `templates/table.rb`, `code.rb`, `diff.rb`, `info.rb` - No canvas equivalents

## Recommendation

### Option A: Full Cleanup (Recommended)

1. Delete entire `lib/stream_weaver/canvas/` directory
2. Remove canvas-* and pick/confirm commands from CLI
3. Remove websocket mode from alpinejs.rb
4. Keep templates as the solution

**Effort:** ~1400 lines to remove

### Option B: Keep Canvas, Fix Later

1. Leave canvas code dormant
2. Document it as "experimental, use templates instead"
3. Maybe fix the socket forwarding someday

**Risk:** Confusion about which approach to use

### Option C: Salvage Pieces

1. Port visual feedback to templates
2. Port helpers.rb parsing fixes to templates
3. Then do Option A

## Files Changed Summary

| File | Change Type | Dead if using templates? |
|------|-------------|-------------------------|
| `lib/stream_weaver/canvas/*` | Created | YES - delete all |
| `lib/stream_weaver/cli.rb` | Modified | Partial - remove canvas commands |
| `lib/stream_weaver/adapter/alpinejs.rb` | Modified | Partial - remove websocket mode |
| `stream_weaver.gemspec` | Modified | Check if sinatra-contrib still needed |
| `docs/plans/2026-01-10-canvas-ipc-design.md` | Created | Archive or delete |

## Testing Note

No spec files were created for canvas (checked `spec/*canvas*` - empty).
Templates have their own tests in the other thread.
