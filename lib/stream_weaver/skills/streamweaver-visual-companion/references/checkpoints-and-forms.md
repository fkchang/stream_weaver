# Checkpoints and Forms

## Single choice

Add a `radio_group` + `button`, then use `canvas-wait <session>` to block until they click. Returns JSON with the selection.

## Multiple questions — prefer a form

When a push ends with several questions — a mix of choices and open-ended asks — bundle them into one blocking form instead of making the user read the canvas and type each answer back in the terminal. Combine `radio_group` per choice question and `text_field` per open question, one `button` to submit, and a single `canvas-wait` call to collect everything at once:

```ruby
streamweaver canvas-push brainstorm <<'RUBY'
  header1 "A few quick questions"
  radio_group :layout, ["Sidebar nav", "Top nav", "Tabs"]
  radio_group :theme, ["Light", "Dark", "Match system"]
  text_field :notes, label: "Anything else to flag?"
  button "Submit"
RUBY
```

```bash
streamweaver canvas-wait brainstorm
# {"button":"Submit","state":{"layout":"Top nav","theme":"Dark","notes":"keep it minimal"}}
```

One click, one `canvas-wait`, every answer back at once in `.state` — no round-tripping to the terminal per question.

**Boundary case:** only bundle questions that are independent of each other. If a later question depends on an earlier answer (e.g. "which of these three do you like?" then, based on that pick, "what should we change about it?"), keep those sequential — push the first, wait for the answer, then push the second.
