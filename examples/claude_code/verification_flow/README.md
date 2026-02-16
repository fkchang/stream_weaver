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

## Core Patterns

### Session Naming

All commands use the same session name to route to the same canvas instance:

```bash
streamweaver panel verify --fresh      # Opens canvas for session "verify"
streamweaver canvas-push verify <<...  # Pushes content to "verify"
streamweaver canvas-toast verify "..." # Shows toast on "verify"
streamweaver canvas-wait verify        # Waits for input on "verify"
streamweaver canvas-close verify       # Closes "verify"
```

### Heredoc Syntax for DSL

Pass Ruby DSL to canvas-push using heredocs:

```bash
streamweaver canvas-push SESSION_NAME <<'RUBY'
card do
  header1 "Title"
  text_field :email, label: "Email"
  button "Submit", id: "btn_submit", style: :primary
end
RUBY
```

Use `<<'RUBY'` (quoted) to prevent shell variable expansion, or `<<RUBY` (unquoted) if you need shell substitution.

### Capturing Form Values

`canvas-wait` blocks until a button is clicked, then returns JSON with all field values:

```bash
$ streamweaver canvas-wait verify
{"type":"action","button":"btn_sign_up_1","state":{"email":"user@example.com","name":"Jane Doe"}}
```

The `state` object contains all text field values keyed by their symbol names (`:email` → `"email"`).

### Variable Substitution Between Pages

Capture values from one page and substitute into the next:

```bash
# Page 1: Capture user input
RESULT=$(streamweaver canvas-wait verify)
EMAIL=$(echo $RESULT | jq -r '.state.email')
NAME=$(echo $RESULT | jq -r '.state.name')

# Page 2: Use captured values
streamweaver canvas-push verify <<RUBY
card do
  header1 "Welcome, $NAME!"
  md "We sent a code to **$EMAIL**"
end
RUBY
```

### URL Fallback

The panel command outputs a URL in case the browser doesn't auto-open:

```bash
$ streamweaver panel verify --fresh
Canvas 'verify' ready
Browser opened in split pane

URL (if browser didn't open): http://localhost:4570/canvas/verify
```

Share this URL with users if the browser pane doesn't appear.

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
