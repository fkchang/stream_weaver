# Usage: streamweaver canvas-push <session> < examples/components/callout_demo.rb
# Or:    streamweaver panel callout-demo && streamweaver canvas-push callout-demo < examples/components/callout_demo.rb

header2 "Callout Variants"
md "All seven tone variants — the last two (`:decision` and `:risk`) are new."

callout(variant: :info, title: "Info") do
  text "General information. Use for context or background knowledge."
end

callout(variant: :warning, title: "Warning") do
  text "Something needs attention but is not a blocker."
end

callout(variant: :success, title: "Success") do
  text "An operation completed successfully."
end

callout(variant: :error, title: "Error") do
  text "Something went wrong. Action required."
end

callout(variant: :tip, title: "Tip") do
  text "A helpful hint or shortcut worth knowing."
end

callout(variant: :decision, title: "Decision — Guest session storage") do
  text "Chosen approach: opaque token stored in DB. Stateless JWT was rejected because we need revocability for account merges. Hard to reverse — commit before implementing."
end

callout(variant: :risk, title: "Risk — Session expiry") do
  text "Guest sessions must expire. Proposed TTL: 24h. Missing this causes unbounded DB growth. Verify the cleanup job runs before shipping."
end
