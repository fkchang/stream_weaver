# SlimGraphR Diagram Guide

`diagram` is already available after installing StreamWeaver. Start a canvas session as usual, then put a diagram inside `streamweaver canvas-push`; no separate `require 'slim_graph_r'` belongs in the document. Run `streamweaver diagrams` whenever the choice is uncertain: it opens the packaged, executable Diagram Atlas with all 39 examples, use guidance, and limits.

Pick the picture that answers the question. A diagram describes declared information; do not imply live telemetry, provenance, capacity, policy enforcement, or elapsed time that you do not have.

| Question | Family and first choice | Choose another type when | Constraint to keep honest |
|---|---|---|---|
| What systems exist and how do they connect? | **Systems** — `:architecture` | dependencies: `:dependency`; placement: `:deployment`; a platform overview: `:high_level`; transfers with roles/tools: `:data_flow` | Split dense inventories into several views. |
| What data model, storage lifecycle, or access boundary matters? | **Data** — `:er` | physical columns/indexes: `:db_schema`; classes/interfaces: `:uml_class`; permissions: `:dp_security_matrix`; tiered storage: `:medallion` | A selective diagram is not generated schema or enforced policy. |
| What happens, who owns it, or what state is valid? | **Flow** — `:flowchart` | roles and stages: `:swimlane` or `:process`; message order: `:sequence`; customer experience: `:journey`; dates: `:gantt` or `:timeline` | Split exception-heavy procedures; a state machine is not one observed request trace. |
| What contains, reports to, or layers above what? | **Hierarchy** — `:tree` | people/reporting: `:org_chart`; nested scopes: `:nested`; stack: `:layers`; ranked/measured levels: `:pyramid` | Use the declared hierarchy, not a network graph or runtime topology. |
| Where should we invest, diagnose, or find a tradeoff? | **Strategy** — `:quadrant` | overlap: `:venn`; repeating improvement: `:loop`; causes: `:fishbone`; evolution/value chain: `:wardley` | Qualitative placement is an argument, not a measured result. |
| How much, how has it changed, or where does it flow? | **Quantitative** — `:bar` | trend: `:line`; relationship: `:scatter`; composition: `:treemap`; volume transfer: `:sankey`; multi-axis profile: `:radar` | Label units and sources; avoid charts when values are estimates or categories only. |

## Minimal runnable patterns

Use one pattern as the starting point, then add only facts the reader needs. These are the smallest honest forms for the six families, copied from the Diagram Atlas vocabulary.

### Systems — architecture

```ruby
diagram :architecture, title: 'Publishing path' do
  external :reader, 'Reader'
  node :app, 'Web app', emphasis: true
  store :db, 'Database'
  flow :reader, :app
  edge :app, :db, 'Read'
end
```

### Data — entity relationship

```ruby
diagram :er, title: 'Order domain' do
  entity :customer, 'Customer' do
    field :id, 'id', key: :primary, type: 'uuid'
  end
  entity :order, 'Order' do
    field :customer_id, 'customer_id', key: :foreign, type: 'uuid'
  end
  relationship :customer, :order, from: '1', to: '0..*', label: 'places'
end
```

### Flow — flowchart

```ruby
diagram :flowchart, title: 'Publishing decision' do
  step :draft, 'Prepare draft'
  decision :review, 'Ready to publish?'
  step :publish, 'Publish'
  flow :draft, :review
  edge :review, :publish, 'Approved'
end
```

### Hierarchy — tree

```ruby
diagram :tree, title: 'Service ownership' do
  root :platform, 'Platform' do
    child :api, 'API' do
      child :billing, 'Billing'
    end
  end
end
```

### Strategy — quadrant

```ruby
diagram :quadrant, title: 'Portfolio choices' do
  horizontal_axis low: 'EASY', high: 'HARD'
  vertical_axis low: 'LOW VALUE', high: 'HIGH VALUE'
  item :billing, 'Billing refresh', x: 0.72, y: 0.66, focal: true
  item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
end
```

### Quantitative — bar chart

```ruby
diagram :bar, title: 'Weekly signups', unit: 'signups' do
  scale min: 0, max: 60
  category :mon, 'Mon', 42
  category :tue, 'Tue', 57
end
```

## Full type index

This index is an inventory, not a reason to load every example into an agent's context. The Atlas is the source for executable examples and detailed limits.

- **Systems (6):** `:architecture`, `:dependency`, `:deployment`, `:high_level`, `:data_flow`, `:dp_integration`
- **Data (6):** `:db_schema`, `:er`, `:uml_class`, `:dp_security_matrix`, `:medallion`, `:it_state`
- **Flow (10):** `:flowchart`, `:process`, `:swimlane`, `:state`, `:sequence`, `:journey`, `:story_map`, `:gantt`, `:kanban`, `:timeline`
- **Hierarchy (5):** `:org_chart`, `:tree`, `:nested`, `:layers`, `:pyramid`
- **Strategy (5):** `:quadrant`, `:venn`, `:loop`, `:fishbone`, `:wardley`
- **Quantitative (7):** `:bar`, `:line`, `:scatter`, `:treemap`, `:sankey`, `:polar`, `:radar`
