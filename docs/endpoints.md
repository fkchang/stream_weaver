# Custom HTTP Endpoints — `endpoint`

The "never rewrite in Sinatra" escape hatch: register a real HTTP route (webhook
receiver, JSON API, file download, health check) directly from the app DSL,
without leaving StreamWeaver or hand-rolling a separate Sinatra/Rails service.

**This is not URL routing.** [`docs/routing.md`](routing.md) (`route_by` /
`route_with` / `page`) maps URL paths to *state* so the same StreamWeaver view
renders differently per path — it's still an HTML page render. `endpoint` is
the opposite: a genuine Rack route that bypasses StreamWeaver's state
machinery, component tree, and view rendering entirely. Use `route_by`/`page`
for "different tab/view depending on the URL." Use `endpoint` for "something
that isn't a StreamWeaver page at all" — a webhook, a JSON API, a file
download.

## Basic usage

```ruby
app "My App" do
  endpoint :get, "/api/status" do |req|
    { ok: true, uptime: 42 }          # Hash -> 200 application/json
  end

  endpoint :post, "/webhook/github" do |req|
    payload = req.body.read           # req is a Rack::Request
    handle_github_event(payload)
    [202, {}, "queued"]                # Rack triplet passes through verbatim
  end

  # ... normal StreamWeaver UI DSL below, in the same app
  header1 "My App"
end.run!
```

Supported verbs: `:get`, `:post`, `:put`, `:patch`, `:delete`.

## Return value conventions

The block's return value is converted into the HTTP response:

| Return type | Response |
|---|---|
| `Hash` | `200`, `Content-Type: application/json`, body is `JSON.generate`d |
| `String` | `200`, `Content-Type: text/html`, body is the string as-is |
| `[status, headers, body]` (Array) | Passed through to Rack verbatim — full control (custom status, headers, streaming, file downloads, etc.) |
| anything else | `200`, `Content-Type: text/plain`, body is `#to_s` |

Use the Rack-triplet form for anything that doesn't fit the Hash/String
shortcuts — custom status codes, redirects, non-JSON/HTML content types, or
file downloads:

```ruby
endpoint :get, "/export/report.csv" do |req|
  csv = generate_report_csv
  [200, { 'Content-Type' => 'text/csv', 'Content-Disposition' => 'attachment; filename="report.csv"' }, csv]
end
```

## The block argument

The block receives the raw [`Rack::Request`](https://www.rubydoc.info/gems/rack/Rack/Request)
for the current request — not StreamWeaver state, not a component. Use it like
you would in any Rack app:

```ruby
endpoint :get, "/api/echo" do |req|
  { query: req.params }                     # query string / route params
end

endpoint :post, "/webhook/github" do |req|
  req.body.read                             # raw request body
end
```

**Gotcha:** if the incoming request's `Content-Type` is
`application/x-www-form-urlencoded` or `multipart/form-data`, Sinatra will
already have consumed the body to build `params` *before* your block runs —
`req.body.read` comes back empty in that case. Use `req.params` for form
submissions instead, or make sure the sender uses a different `Content-Type`
(e.g. `application/json`, `text/plain`) for endpoints that need the raw body.

## No CSRF, no session, no state

`endpoint` is a raw Rack route. It does **not** go through StreamWeaver's
session/state machinery, CSRF protection, or component rendering — the block
you write is the entire request handler. If you need auth, verify a webhook
signature, parse JSON, etc., do it yourself inside the block just as you would
in a plain Sinatra route.

## Precedence: internal routes always win

StreamWeaver's own framework routes (`/update`, `/action/*`, `/submit`,
`/event/*`, `/form/*`, `/theme/*`, `/sw/*`, plus a handful of others like `/`,
`/stream`, `/deck/*`) are defined before any `endpoint` you register. Sinatra
dispatches to the *first* route that matches a request, so if an `endpoint`
path collides with one of these, the internal route always wins — your block
is simply never reached.

`endpoint` warns at registration time when it detects a collision with a
known-reserved path/prefix, so the mistake is loud instead of silently eaten:

```
StreamWeaver: endpoint POST /update collides with a StreamWeaver-internal route
and will never be reached — the internal route always wins.
```

Pick paths outside StreamWeaver's reserved prefixes (`/action/`, `/event/`,
`/form/`, `/theme/`, `/sw/`) and outside `/update` and `/submit` to avoid this
entirely.

## Service mode (`streamweaver run`)

In standalone mode (`App#run!`), endpoints are served at the path exactly as
registered (e.g. `GET /api/status`).

In multi-app service mode, each app is mounted under `/apps/:app_id`, so its
endpoints are scoped under that prefix too: an app registered as `svc123`
serves `endpoint :get, "/api/status"` at `GET /apps/svc123/api/status` — and
equally via the app's human-readable slug, e.g. `GET /apps/my-dashboard/api/status`. The
same precedence rule applies — StreamWeaver's fixed `/apps/:app_id/...` routes
(update, action, event, form, theme) are defined first and always win on
collision.
