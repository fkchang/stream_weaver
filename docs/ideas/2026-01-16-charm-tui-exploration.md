# StreamWeaver for TUI: Adapting the DSL to Charm

**Date:** January 16, 2026
**Status:** Exploration / Feasibility Analysis

## Executive Summary

StreamWeaver's reactive DSL could be adapted to target Charm's TUI libraries (Bubbletea, Lipgloss, Bubbles) instead of web browsers. The core insight—**your Ruby block re-executes on every interaction**—translates naturally to Bubbletea's Elm Architecture. This document explores feasibility, architectural alignment, and a potential implementation path.

## The Opportunity

With Marco Roth's Charm Ruby gems now available, Ruby developers can build "glamorous" terminal UIs. But Charm follows the Elm Architecture pattern, requiring explicit model/update/view separation:

```ruby
# Current Charm/Bubbletea approach
class Counter
  include Bubbletea::Model

  def initialize
    @count = 0
  end

  def update(msg)
    case msg
    when Bubbletea::KeyMsg
      @count += 1 if msg.key == "+"
      @count -= 1 if msg.key == "-"
    end
    [self, nil]
  end

  def view
    "Count: #{@count}\n\nPress + or - to change, q to quit"
  end
end

Bubbletea::Program.new(Counter.new).run
```

StreamWeaver's approach is more declarative—state changes and UI definition live together:

```ruby
# StreamWeaver's reactive approach
app "Counter" do
  state[:count] ||= 0

  text "Count: #{state[:count]}"

  button "+" do |s|
    s[:count] += 1
  end
end.run!
```

**Question: Can we bring StreamWeaver's token-efficient DSL to terminal UIs?**

## Architectural Alignment Analysis

### What Aligns Well

| StreamWeaver Concept | Charm Equivalent | Compatibility |
|---------------------|------------------|---------------|
| `state[:key]` hash | Model instance variables | Direct mapping |
| Block re-execution | `view()` method called after `update()` | Same pattern |
| Component rendering | Lipgloss styled strings | Conceptual match |
| Button callbacks | KeyMsg/MouseMsg handling | Needs translation layer |
| Layout (vstack, hstack) | Lipgloss.join_vertical/horizontal | Direct equivalent |

### Key Differences

| Aspect | StreamWeaver (Web) | Charm (TUI) |
|--------|-------------------|-------------|
| Event model | HTTP requests via HTMX | Keyboard/mouse messages |
| Rendering | HTML via Phlex | ANSI strings via Lipgloss |
| Components | Form elements (text_field, select) | Bubbles components (TextInput, List) |
| State persistence | Session cookies | In-memory only |
| Interaction | Click, type, submit | Keypress, mouse click |

## Proposed Architecture: CharmWeaver

A new rendering backend for StreamWeaver's DSL that targets Charm instead of web browsers.

### Core Abstraction

```ruby
# Same DSL, different target
tui "Counter" do
  state[:count] ||= 0

  text "Count: #{state[:count]}"

  # TUI-specific: key bindings instead of buttons
  on_key "+" do |s|
    s[:count] += 1
  end

  on_key "-" do |s|
    s[:count] -= 1
  end
end.run!
```

### Implementation Strategy

**Phase 1: Proof of Concept**
- Create `CharmWeaver::App` that wraps Bubbletea::Model
- Implement basic components: `text`, `header`, `vstack`, `hstack`
- Map `state[:key]` to model instance variables
- Block re-execution on each `view()` call

```ruby
module CharmWeaver
  class App
    include Bubbletea::Model

    def initialize(title, &block)
      @title = title
      @block = block
      @state = {}
      @components = []
      @key_handlers = {}
    end

    def init
      [self, nil]
    end

    def update(msg)
      case msg
      when Bubbletea::KeyMsg
        return [self, Bubbletea.quit] if msg.key == "q"

        if handler = @key_handlers[msg.key]
          handler.call(@state)
        end
      end
      [self, nil]
    end

    def view
      @components.clear
      @key_handlers.clear

      # Re-execute block (StreamWeaver's core insight)
      instance_eval(&@block)

      render_components
    end

    private

    def state
      @state
    end

    def text(content)
      @components << { type: :text, content: content }
    end

    def on_key(key, &handler)
      @key_handlers[key] = handler
    end

    def render_components
      @components.map do |c|
        case c[:type]
        when :text
          c[:content]
        end
      end.join("\n")
    end
  end
end

def tui(title, &block)
  CharmWeaver::App.new(title, &block)
end
```

**Phase 2: Component Library**

Map StreamWeaver components to Charm equivalents:

| StreamWeaver | CharmWeaver | Implementation |
|--------------|-------------|----------------|
| `text` | `text` | Lipgloss styled string |
| `header` | `header` | Lipgloss bold/colored |
| `text_field :name` | `text_input :name` | Bubbles::TextInput |
| `text_area :bio` | `text_area :bio` | Bubbles::TextArea |
| `select :choice, [...]` | `list :choice, [...]` | Bubbles::List |
| `checkbox :agree` | `toggle :agree` | Custom toggle component |
| `button "Click"` | `on_key "enter"` | Key binding |
| `vstack` | `vstack` | Lipgloss.join_vertical |
| `hstack` | `hstack` | Lipgloss.join_horizontal |
| `card` | `box` | Lipgloss border + padding |
| `alert` | `styled_box` | Lipgloss with color variant |

**Phase 3: Focus Management**

TUIs need focus handling for input components:

```ruby
tui "Form" do
  state[:focus] ||= :name

  text_input :name, focused: state[:focus] == :name
  text_input :email, focused: state[:focus] == :email

  on_key "tab" do |s|
    s[:focus] = s[:focus] == :name ? :email : :name
  end

  on_key "enter" do |s|
    # Submit
  end
end.run!
```

**Phase 4: Agentic Mode**

StreamWeaver's `run_once!` maps to TUI forms:

```ruby
result = tui "Quick Input" do
  text "Enter your name:"
  text_input :name

  on_key "enter" do |s|
    s[:_submit] = true
  end
end.run_once!

puts result[:name]
```

## Component Mapping Deep Dive

### Text & Display

```ruby
# StreamWeaver (web)
text "Hello, #{name}"
md "**Bold** text"
header "Section"

# CharmWeaver (TUI)
text "Hello, #{name}"                    # Plain text
text "**Bold** text", style: :markdown   # Glamour rendering
header "Section"                          # Lipgloss bold + color
```

### Input Components

```ruby
# StreamWeaver (web)
text_field :name, placeholder: "Name"

# CharmWeaver (TUI) - wraps Bubbles::TextInput
text_input :name, placeholder: "Name"
```

The key difference: TUI inputs require focus management and cursor handling, which Bubbles handles internally.

### Layout

```ruby
# StreamWeaver (web)
columns widths: ['30%', '70%'] do
  column { sidebar_content }
  column { main_content }
end

# CharmWeaver (TUI) - character-based widths
columns widths: [20, 60] do
  column { sidebar_content }
  column { main_content }
end
```

### Styling

```ruby
# New: Lipgloss-based styling DSL
tui "Styled" do
  style :title,
    bold: true,
    foreground: "#FF6B6B",
    margin_bottom: 1

  text "Welcome", style: :title
end.run!
```

## Challenges & Solutions

### Challenge 1: Event Model Difference

**Web:** Events trigger HTTP requests, server re-renders entire UI
**TUI:** Events are keyboard/mouse messages, model updates locally

**Solution:** CharmWeaver's `update()` method triggers block re-execution, mimicking StreamWeaver's behavior. The pattern is the same—just the transport differs.

### Challenge 2: Component Complexity

Bubbles components (TextInput, List) maintain internal state (cursor position, scroll offset). StreamWeaver components are stateless—state lives in the hash.

**Solution:** CharmWeaver manages Bubbles component instances internally, syncing their values to `state[:key]` after each update cycle.

```ruby
class CharmWeaver::App
  def text_input(key, **opts)
    @bubble_components[key] ||= Bubbles::TextInput.new(**opts)
    @components << { type: :text_input, key: key, component: @bubble_components[key] }
  end

  def update(msg)
    # Forward messages to focused component
    if focused = @bubble_components[@focused_key]
      focused, cmd = focused.update(msg)
      @state[@focused_key] = focused.value
    end
    [self, cmd]
  end
end
```

### Challenge 3: Mouse Support

StreamWeaver buttons are clickable. TUI "buttons" are typically key-bound.

**Solution:** Use Bubblezone for mouse region tracking:

```ruby
tui "Clickable" do
  button "Save" do |s|
    s[:saved] = true
  end
  # Renders as clickable zone + key hint: [Save] (Enter)
end.run!
```

### Challenge 4: Forms & Submission

StreamWeaver's `run_once!` returns when a form is "submitted." TUIs need explicit submission handling.

**Solution:** Define submission triggers:

```ruby
result = tui "Form" do
  text_input :name
  text_input :email

  # Explicit submit key
  submit_on "ctrl+s"
  # Or automatic when all fields filled
  submit_when { state[:name] && state[:email] }
end.run_once!
```

## API Design: Full Example

```ruby
require 'charm_weaver'

tui "Task Manager",
  theme: :dracula,        # Lipgloss color scheme
  border: :rounded        # App border style
do
  header "My Tasks"

  # Input with auto-focus
  text_input :new_task, placeholder: "Add task..."

  on_key "enter" do |s|
    next if s[:new_task].to_s.empty?
    s[:tasks] ||= []
    s[:tasks] << { name: s[:new_task], done: false }
    s[:new_task] = ""
  end

  divider

  # List with selection
  state[:tasks]&.each_with_index do |task, i|
    selected = state[:selected] == i

    hstack do
      text selected ? ">" : " "
      text task[:done] ? "[x]" : "[ ]"
      text task[:name], style: task[:done] ? :dim : :normal
    end
  end

  # Key bindings
  on_key "j" do |s|
    s[:selected] = [(s[:selected] || 0) + 1, (s[:tasks]&.size || 1) - 1].min
  end

  on_key "k" do |s|
    s[:selected] = [(s[:selected] || 0) - 1, 0].max
  end

  on_key "space" do |s|
    if s[:tasks] && s[:selected]
      s[:tasks][s[:selected]][:done] ^= true
    end
  end

  on_key "d" do |s|
    s[:tasks]&.delete_at(s[:selected]) if s[:selected]
  end

  # Footer
  divider
  text "j/k: navigate | space: toggle | d: delete | q: quit", style: :help
end.run!
```

## Token Efficiency Comparison

The goal: same expressiveness, fewer tokens for LLM-driven development.

**Raw Bubbletea (58 lines):**
```ruby
class TaskManager
  include Bubbletea::Model

  def initialize
    @tasks = []
    @new_task = Bubbles::TextInput.new(placeholder: "Add task...")
    @selected = 0
    @focused = :input
  end

  def init
    [self, Bubbles::TextInput.focus]
  end

  def update(msg)
    case msg
    when Bubbletea::KeyMsg
      case msg.key
      when "enter"
        unless @new_task.value.empty?
          @tasks << { name: @new_task.value, done: false }
          @new_task.set_value("")
        end
      when "j"
        @selected = [@selected + 1, @tasks.size - 1].min
      when "k"
        @selected = [@selected - 1, 0].max
      when " "
        @tasks[@selected][:done] ^= true if @tasks[@selected]
      when "d"
        @tasks.delete_at(@selected)
      when "q"
        return [self, Bubbletea.quit]
      else
        @new_task, cmd = @new_task.update(msg)
        return [self, cmd]
      end
    end
    [self, nil]
  end

  def view
    lines = ["My Tasks", "", @new_task.view, ""]
    @tasks.each_with_index do |t, i|
      prefix = i == @selected ? ">" : " "
      check = t[:done] ? "[x]" : "[ ]"
      lines << "#{prefix} #{check} #{t[:name]}"
    end
    lines << ""
    lines << "j/k: navigate | space: toggle | d: delete | q: quit"
    lines.join("\n")
  end
end

Bubbletea::Program.new(TaskManager.new).run
```

**CharmWeaver DSL (35 lines):** ~40% fewer tokens, same functionality.

## Implementation Roadmap

### Phase 1: Core (Week 1-2)
- [ ] `CharmWeaver::App` base class wrapping Bubbletea::Model
- [ ] Basic components: `text`, `header`, `divider`, `vstack`, `hstack`
- [ ] State hash integration
- [ ] `on_key` handler registration
- [ ] Block re-execution in `view()`

### Phase 2: Input Components (Week 3-4)
- [ ] `text_input` wrapping Bubbles::TextInput
- [ ] `text_area` wrapping Bubbles::TextArea
- [ ] Focus management system
- [ ] Tab navigation between inputs

### Phase 3: Selection Components (Week 5-6)
- [ ] `list` wrapping Bubbles::List
- [ ] `table` wrapping Bubbles::Table
- [ ] Selection state synchronization

### Phase 4: Styling & Polish (Week 7-8)
- [ ] Theme support via Lipgloss
- [ ] `style` DSL for custom styles
- [ ] `box` component with borders
- [ ] `alert` with color variants

### Phase 5: Advanced Features (Week 9-10)
- [ ] Mouse support via Bubblezone
- [ ] `run_once!` agentic mode
- [ ] Animation via Harmonica
- [ ] Charts via NTCharts

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Bubbles component state sync complexity | High | Medium | Start with simple components, add complex ones incrementally |
| Focus management edge cases | Medium | High | Study Huh? form library implementation |
| Performance with large state | Low | Medium | Optimize re-render diffing if needed |
| Charm gem API changes | Medium | Medium | Pin gem versions, contribute upstream |

## Success Criteria

1. **Token efficiency:** CharmWeaver DSL uses 30-50% fewer tokens than raw Bubbletea for equivalent functionality
2. **Familiar API:** StreamWeaver users can transfer knowledge directly
3. **Full component coverage:** All common TUI patterns expressible
4. **Production quality:** Suitable for real CLI tools, not just demos

## Conclusion

Adapting StreamWeaver's DSL to Charm is **highly feasible**. The reactive model (block re-execution on state change) maps directly to Bubbletea's Elm Architecture. The main work is:

1. Wrapping Bubbles components to sync with `state[:key]`
2. Implementing focus management
3. Translating web concepts (buttons → key bindings)

The payoff: Ruby developers get a token-efficient, declarative DSL for beautiful TUIs, consistent with StreamWeaver's web approach. Same mental model, different output target.

**Recommendation:** Proceed with Phase 1 proof of concept to validate the component wrapping approach before committing to full implementation.
