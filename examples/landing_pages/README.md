# StreamWeaver landing-page suite

Run all six pages from one local preview server:

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 SW_NO_OPEN=1 STREAMWEAVER_PORT=4579 \
  bundle exec ruby examples/landing_pages/app.rb
```

Open <http://127.0.0.1:4579/>. The navigation exposes `/`, `/agents`, `/visuals`,
`/documents`, `/applications`, and `/review`. Each page ends with an expandable
source inspector showing the actual Ruby DSL that composes that page.
