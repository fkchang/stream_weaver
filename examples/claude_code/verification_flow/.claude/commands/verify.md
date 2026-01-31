# Account Verification Flow

This slash command demonstrates a realistic multi-step workflow with forms, status pages, toasts, and page transitions.

## Instructions

Execute the following phases in order. Use session name `verify` throughout. Each phase waits for user interaction before proceeding.

### Phase 1: Initialize

Open the panel with a fresh session. The panel command will output a URL - **show this URL to the user** in case the browser doesn't open automatically:

```bash
streamweaver panel verify --fresh
```

If the browser doesn't open, tell the user: "If the panel didn't open, paste this URL in your browser: [URL from output]"

### Phase 2: Sign-Up Form

Push the sign-up form:

```bash
streamweaver canvas-push verify <<'RUBY'
card do
  header1 "Create Account"
  md "Enter your details to get started."
  text_field :email, placeholder: "your@email.com", label: "Email"
  text_field :name, placeholder: "Your Name", label: "Name"
  button "Sign Up", id: "btn_signup", style: :primary
end
canvas_continue message: "Creating account..."
RUBY
```

Wait for the user to submit:

```bash
streamweaver canvas-wait verify
```

The response will be JSON with `email` and `name` values. Store these for use in subsequent pages.

### Phase 3: Provisioning Status Page with Toast

This phase demonstrates proper toast usage: the canvas shows a **status page** (not a form) while terminal work happens. The toast alerts the user to check the terminal for permission prompts.

Push the provisioning status page (no form, no wait - just status display):

```bash
streamweaver canvas-push verify <<'RUBY'
card do
  header1 "Provisioning Account"
  status_dot status: :yellow, pulse: true, label: "SETTING UP"
  md "Creating your account infrastructure..."
  md "**Step 1 of 3**: Initializing database"
end
RUBY
```

Send a toast to alert the user to check the terminal:

```bash
streamweaver canvas-toast verify "⚠️ Grant permission in terminal to continue"
```

Now run terminal commands (which may require permission). Update the status page as work progresses:

```bash
echo "Initializing database for NAME_VALUE..."
```

Update to step 2:

```bash
streamweaver canvas-push verify <<'RUBY'
card do
  header1 "Provisioning Account"
  status_dot status: :yellow, pulse: true, label: "SETTING UP"
  md "Creating your account infrastructure..."
  md "**Step 2 of 3**: Configuring permissions"
end
RUBY
```

```bash
echo "Setting up permissions..."
```

Update to step 3 complete:

```bash
streamweaver canvas-push verify <<'RUBY'
card do
  header1 "Provisioning Account"
  status_dot status: :green, pulse: false, label: "COMPLETE"
  md "Creating your account infrastructure..."
  md "**Step 3 of 3**: Sending verification email ✓"
end
RUBY
```

(Replace NAME_VALUE with the actual name from Phase 2)

### Phase 4: Verification Code Page

Push the verification code page, substituting the user's email into the message:

```bash
streamweaver canvas-push verify <<'RUBY'
card do
  header1 "Verify Your Email"
  status_dot status: :yellow, pulse: true, label: "AWAITING CODE"
  md "We sent a 6-digit code to **EMAIL_VALUE**"
  text_field :code, placeholder: "Enter 6-digit code", label: "Verification Code"
  button "Verify", id: "btn_verify", style: :primary
end
canvas_continue message: "Verifying code..."
RUBY
```

(Replace EMAIL_VALUE with the actual email from Phase 2)

Wait for the verification:

```bash
streamweaver canvas-wait verify
```

The response will be JSON with the `code` value. After canvas-wait returns, the user sees the "Verifying code..." spinner. **Immediately push the next page** - do NOT wait again.

### Phase 5: Welcome Page

Push the welcome/success page immediately (this replaces the spinner). Substitute the user's name:

```bash
streamweaver canvas-push verify <<'RUBY'
card do
  header1 "Welcome, NAME_VALUE!"
  badge "VERIFIED", variant: :success
  md "Your account has been created and verified successfully."
  md "You can now access all features."
end
RUBY
```

(Replace NAME_VALUE with the actual name from Phase 2)

**Do NOT wait here** - this is an informational page with no form. Pause briefly to let the user see the success message, then close:

```bash
sleep 2
```

### Phase 6: Cleanup

Close the panel:

```bash
streamweaver canvas-close verify
```

## Notes

- All commands use the session name `verify`
- The `--fresh` flag on panel closes any existing session first
- If the browser doesn't auto-open, share the URL from the panel command output with the user
- **Toast usage**: Toasts are for alerting users to check the terminal when their attention is on a status page. Don't use toasts on form pages where the user is already expected to interact with the canvas.
- `canvas-wait` returns JSON with all form field values
- **canvas_continue flow**: When a form uses `canvas_continue`, after `canvas-wait` returns, the user sees the spinner. You must **immediately push the next page** to replace the spinner - do NOT call `canvas-wait` again (there's nothing to wait for).
- **Final pages**: Informational success pages (no form) should NOT use `canvas-wait`. Just display the content briefly with `sleep`, then close.
