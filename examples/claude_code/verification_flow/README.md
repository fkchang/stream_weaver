# Account Verification Flow Example

A realistic multi-step workflow demonstrating StreamWeaver's canvas capabilities: forms, status pages, toasts, and page transitions.

## The Flow

1. **Sign Up Form** → User enters email and name
2. **Verification Page** → Shows status with pulsing indicator, sends toast "Check your email!", asks for code
3. **Welcome Page** → Confirms verification, displays personalized greeting

## Why This Scenario?

- **Realistic**: Mirrors common 2FA/email verification flows
- **Demonstrates all features**: Forms → status with toast → final confirmation
- **Clear transitions**: Each page has a distinct purpose
- **Natural toast usage**: "Check your email for the code" is a sensible notification

## Usage

```bash
cd examples/claude_code/verification_flow
# In Claude Code, run:
/verify
```

## Features Demonstrated

| Feature | Command | Purpose |
|---------|---------|---------|
| Fresh start | `canvas-reset` | Clear any existing canvas state |
| Panel setup | `panel` | Open side panel at specific width |
| Form pages | `canvas-push` | Display forms with text fields and buttons |
| Notifications | `canvas-toast` | Show overlay messages |
| User input | `canvas-wait` | Block until button click, capture field values |
| Cleanup | `canvas-close` | Close panel when done |

## DSL Components Used

- `card` - Container for content
- `header1` - Page titles
- `md` - Markdown text with dynamic substitution
- `text_field` - Form inputs with labels and placeholders
- `button` - Actions with primary styling
- `status_dot` - Visual status indicator with pulse animation
- `badge` - Success/status badges
