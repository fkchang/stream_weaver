# Account Verification Flow Example

A realistic multi-step workflow demonstrating StreamWeaver's canvas capabilities: forms, status pages, toasts, and page transitions.

## The Flow

1. **Sign-Up Form** → User enters email and name
2. **Provisioning Status** → Canvas shows progress while terminal work runs (toast alerts user to check terminal)
3. **Verification Code** → User enters verification code from email
4. **Welcome Page** → Confirms verification, displays personalized greeting

## Key Concepts Demonstrated

### Canvas + Terminal Interplay
Phase 2 shows how to use canvas as a status display while Claude runs terminal commands. The toast alerts the user to check the terminal for permission prompts.

### Proper Toast Usage
Toasts are for alerting users to check the terminal when their attention is on a **status page**. Don't use toasts on form pages where the user is already interacting with the canvas.

### canvas_continue
Use `canvas_continue message: "..."` on form pages to show a spinner after submit (instead of "You can close this window").

## Usage

```bash
cd examples/claude_code/verification_flow
# In Claude Code, run:
/verify
```

## Features Demonstrated

| Feature | Command | Purpose |
|---------|---------|---------|
| Fresh start | `panel --fresh` | Open panel, close existing session first |
| Form pages | `canvas-push` | Display forms with text fields and buttons |
| Status pages | `canvas-push` | Display progress while work happens |
| Notifications | `canvas-toast` | Alert user to check terminal |
| User input | `canvas-wait` | Block until button click, capture field values |
| Spinner feedback | `canvas_continue` | Show spinner after form submit |
| Cleanup | `canvas-close` | Close panel and browser pane |

## DSL Components Used

- `card` - Container for content
- `header1` - Page titles
- `md` - Markdown text with dynamic substitution
- `text_field` - Form inputs with labels and placeholders
- `button` - Actions with primary styling
- `status_dot` - Visual status indicator (yellow pulsing, green complete)
- `badge` - Success/status badges
- `canvas_continue` - Spinner feedback for multi-step flows
