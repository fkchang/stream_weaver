# StreamWeaver URL Routing

StreamWeaver supports URL-addressable views — deep links, browser back/forward, and bookmarkable URLs — without adding a router library. Two mechanisms are available depending on complexity.

## How It Works (Internals)

StreamWeaver uses a bidirectional URL ↔ state contract:

- **On GET `/*`**: The path is parsed into a partial state hash and merged into session state before render. This seeds the right view on direct URL load.
- **After POST actions**: The current state is converted to a path and sent as `HX-Push-Url`, updating the browser URL bar without a full page load.

This means **routing is just state**. A URL like `/goals` means `state[:main_nav] = 2`. A URL like `/initiative/init-001` means `state[:main_nav] = 2, state[:initiative_id] = "init-001"`.

---

## `route_by` — Simple Key→Path Mapping

For apps with a single state key driving navigation (tab switchers, simple page routers):

```ruby
app "My App" do
  route_by :page, home: "/", dashboard: "/dashboard", settings: "/settings"

  state[:page] ||= :home

  navbar do
    nav_item "Home",      href: "/",          active: state[:page] == :home
    nav_item "Dashboard", href: "/dashboard",  active: state[:page] == :dashboard
    nav_item "Settings",  href: "/settings",   active: state[:page] == :settings
  end

  case state[:page]
  when :home      then render_home
  when :dashboard then render_dashboard
  when :settings  then render_settings
  end
end.run!
```

**How it works:** `route_by :page, home: "/"` creates a bidirectional map. When `state[:page]` changes (button callback or nav click), StreamWeaver emits `HX-Push-Url: /` automatically. Visiting `/dashboard` directly seeds `state[:page] = :dashboard` before render.

**Limitation:** One state key only. Doesn't handle parameterized paths like `/initiative/:id`.

---

## `route_with` — Bidirectional Parser/Builder

For apps with parameterized routes, multi-key navigation state, or complex URL structures. Requires two lambdas:

- **`parser`**: `path → partial_state_hash | nil` — called on every GET request. Returns a hash to merge into state, or `nil` to pass through.
- **`builder`**: `current_state → path_string | nil` — called after every POST action. Returns the new path to push, or `nil` to leave the URL unchanged.

### Example: UTF Dashboard

```ruby
app "UTF Dashboard", layout: :full do
  route_with(
    parser: lambda do |path|
      case path
      when '/', ''
        { main_nav: 0 }
      when '/tasks'
        { main_nav: 1 }
      when '/goals'
        { main_nav: 2 }
      when '/secretaries'
        { main_nav: 3 }
      when %r{\A/secretary/([^/]+)\z}
        { main_nav: 3, secretary_name: CGI.unescape(Regexp.last_match(1)) }
      when '/sessions'
        { main_nav: 4 }
      when %r{\A/task/([^/]+)\z}
        { main_nav: 0, view_task_id: CGI.unescape(Regexp.last_match(1)) }
      when %r{\A/initiative/([^/]+)/surface/([^/]+)\z}
        { main_nav: 2,
          initiative_id: CGI.unescape(Regexp.last_match(1)),
          surface_id: CGI.unescape(Regexp.last_match(2)) }
      when %r{\A/initiative/([^/]+)\z}
        { main_nav: 2, initiative_id: CGI.unescape(Regexp.last_match(1)) }
      else
        nil
      end
    end,

    builder: lambda do |current_state|
      if current_state[:view_task_id].to_s.strip != ''
        "/task/#{CGI.escape(current_state[:view_task_id].to_s)}"
      elsif current_state[:secretary_name].to_s.strip != ''
        "/secretary/#{CGI.escape(current_state[:secretary_name].to_s)}"
      elsif current_state[:initiative_id].to_s.strip != ''
        "/initiative/#{CGI.escape(current_state[:initiative_id].to_s)}"
      else
        case current_state[:main_nav].to_i
        when 1 then '/tasks'
        when 2 then '/goals'
        when 3 then '/secretaries'
        when 4 then '/sessions'
        else '/'
        end
      end
    end
  )

  # ... app body
end
```

### Parser Rules

- Return a **hash** to merge into state (only the keys you want to set, not the full state)
- Return `nil` to indicate "this path isn't handled by me" — Sinatra will 404
- Always `CGI.unescape` captured path segments before storing in state
- Match most-specific patterns first (`:id/surface/:sid` before `:id`)

### Builder Rules

- Return a **path string** (starting with `/`) to push to the browser history
- Return `nil` to leave the URL unchanged (good for transient state like modal open/close)
- Check priority: specific context (task detail, initiative detail) before generic tabs
- Always `CGI.escape` state values interpolated into paths

---

## URL Parameters vs State

Query params (`?key=value`) are automatically synced to state on every GET request via `sync_params_to_state`. You can use them alongside path-based routing:

```
GET /goals?filter=active
# → state[:main_nav] = 2 (from path parser)
# → state[:filter] = "active" (from query param sync)
```

---

## Navigating Programmatically

To trigger URL updates from button callbacks, just update the state key that the builder watches:

```ruby
button "View Initiative" do |s|
  s[:initiative_id] = "init-042"  # builder will push /initiative/init-042
  s[:main_nav] = 2
end
```

No explicit redirect needed — the `after` hook calls `path_for_state` on every POST response automatically.

---

## Edit Routes (CRUD Pattern)

For edit views (`/initiative/:id/edit`), add an edit flag to the route:

```ruby
# In parser:
when %r{\A/initiative/([^/]+)/edit\z}
  { main_nav: 2, initiative_id: CGI.unescape(Regexp.last_match(1)), editing_initiative: true }

# In builder:
elsif current_state[:initiative_id].to_s.strip != '' && current_state[:editing_initiative]
  "/initiative/#{CGI.escape(current_state[:initiative_id])}/edit"
elsif current_state[:initiative_id].to_s.strip != ''
  "/initiative/#{CGI.escape(current_state[:initiative_id])}"
```

Then in the app body:

```ruby
if state[:editing_initiative] && state[:initiative_id]
  render_initiative_edit_form(state[:initiative_id])
elsif state[:initiative_id]
  render_initiative_detail(state[:initiative_id])
end
```

---

## Comparison

| Scenario | Use |
|---|---|
| Simple tab nav (one active tab) | `route_by` |
| Multi-param routes (`/x/:id`, `/x/:id/edit`) | `route_with` |
| Mixed tab + entity detail | `route_with` |
| No bookmarkability needed | Neither (omit routing entirely) |
