# StreamWeaver Goes Static

You've always been able to write reactive, server-rendered UIs without touching JavaScript. Now the same Ruby DSL runs entirely in the browser — no server, no round-trips, no ops.

Here's a complete interactive app:

```ruby
app "Hello World" do
  header1 "Welcome to StreamWeaver!"

  text_field :name, placeholder: "Enter your name"

  if state[:name] && state[:name].strip != ""
    text "Hello, #{state[:name]}!"

    checkbox :subscribe, "Subscribe to newsletter"

    if state[:subscribe]
      text "You're subscribed!"
    end
  end
end
```

That's not a server app stripped of its `require` lines. That is the whole thing — identical DSL, running in-browser via Opal. State lives in the page. Interactions re-execute the block and patch the DOM with morphdom. No server involved.

## One command to deploy

```bash
streamweaver opal-build app.rb
```

That produces a `dist/` folder: `index.html`, `app.js`, `morphdom.min.js`. Drag it to GitHub Pages, Netlify, S3 — anywhere that serves files. Done.

## What this is not

It's not React. It's not Next.js. There's no webpack config, no `package.json`, no `node_modules`, no TypeScript compilation step, no context switch between your "frontend language" and your "backend language" because there is only one language. You write Ruby. You ship Ruby. The toolchain is one gem.

The mental model stays the same whether you're building a server-rendered dashboard or a static page: declare what the UI looks like given the current state, let StreamWeaver figure out the rest.

## Phase 1 — honest about scope

The core components are covered: `app`, `header`, `text_field`, `checkbox`, `button`, `md`, `div`. State is fully reactive in-browser.

What's not there yet: `feed`, `streamer`, and `service_client` (they require a server by definition), plus `mermaid`, `chartjs`, `tabs`, and `table` (coming in Phase 2). If your app uses those, keep running it server-side — that path isn't going anywhere.

Full component parity is the goal. Phase 1 gets you surprisingly far.
