# frozen_string_literal: true

require 'json'
require 'open3'

# getFormState is the only channel a canvas control has for reporting page state
# to a waiting agent, and it reads the DOM rather than Alpine's own store. Two
# checkbox spellings share the "one x-model key" convention and must harvest
# differently: checkbox_group binds N inputs to one array-valued key, a lone
# checkbox binds one input to a boolean key.
RSpec.describe 'canvas form state harvest' do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/test', mode: :websocket) }

  # CI declares node (.github/workflows/ci.yml), so the harvest examples always
  # run where regressions have to be caught. A contributor without node gets a
  # named skip rather than a failure about something they didn't break.
  def self.node?
    return @node unless @node.nil?

    @node = !!system('node', '--version', out: File::NULL, err: File::NULL)
  end

  def group_app(fruits, items: %w[apple banana cherry])
    StreamWeaver::App.new('form state harvest spec') do
      checkbox_group(:fruits) do
        items.each { |value| item(value) { text value.capitalize } }
      end
    end.tap { |app| app.rebuild_with_state({ fruits: fruits }) }
  end

  # disc-105: a multi chip_group is the checkbox_group shape under a different
  # container class -- N checkboxes on one array-valued x-model. A single-select
  # chip group renders radios instead, so it never reaches the checkbox branch.
  def chip_app(langs, multi: true)
    StreamWeaver::App.new('form state harvest spec') do
      chip_group(:langs, %w[ruby js opal], multi: multi)
    end.tap { |app| app.rebuild_with_state({ langs: langs }) }
  end

  def checkbox_app(subscribe)
    StreamWeaver::App.new('form state harvest spec') do
      checkbox(:subscribe, 'Subscribe')
    end.tap { |app| app.rebuild_with_state({ subscribe: subscribe }) }
  end

  # Renders the components on their own, so assertions see exactly the markup the
  # adapter emits (same harness as spec/adapter/route_tabs_spec.rb).
  def render_components(*apps)
    components = apps.flat_map(&:components)
    state = apps.map(&:state).inject({}, :merge)
    canvas_adapter = adapter

    Class.new(Phlex::HTML) do
      define_method(:adapter) { canvas_adapter }
      define_method(:view_template) { components.each { |component| component.render(self, state) } }
    end.new.call
  end

  # Walks emitted markup into the minimal element view getFormState consumes: the
  # attributes it reads, plus the classes of the ancestors still open at that
  # point -- which is what tells a group item apart from a lone checkbox.
  def x_model_elements(html)
    void_tags = %w[input img br hr meta link source]
    open_scopes = []

    html.scan(%r{<(/?)(\w+)([^>]*)>}).filter_map do |closing, tag, attr_text|
      attrs = attr_text.scan(/([\w:@.-]+)(?:="([^"]*)")?/).to_h

      if closing == '/'
        open_scopes.pop
        next
      end

      unless void_tags.include?(tag)
        open_scopes.push(attrs['class'].to_s.split)
        next
      end

      next unless attrs.key?('x-model')

      {
        'attrs' => attrs,
        'type' => attrs['type'],
        'value' => attrs['value'],
        'checked' => attrs.key?('checked'),
        'ancestorClasses' => open_scopes.flatten.uniq
      }
    end
  end

  # Runs the real emitted getFormState against a DOM shim built from the real
  # emitted markup, so the payloads below are harvested rather than restated
  # from the source. The shim models a server-rendered snapshot: `checked` comes
  # from the attribute, not the live property Alpine mutates on click, so the
  # after-the-user-clicks path stays a browser check (see the story's handoff).
  def harvest(html)
    script = adapter.cdn_scripts.find { |candidate| candidate.include?('window.getFormState') }
    raise 'no cdn script defines getFormState' unless script

    source = script[/window\.getFormState = function\(\) \{.*?\n\s*\};/m]
    raise 'could not slice getFormState out of the emitted script' unless source

    program = <<~JS
      const descriptors = #{JSON.generate(x_model_elements(html))};
      const elements = descriptors.map(d => ({
        type: d.type,
        value: d.value,
        checked: d.checked,
        getAttribute: name => (name in d.attrs ? d.attrs[name] : null),
        closest: selector => selector.split(',')
          .some(one => d.ancestorClasses.includes(one.trim().replace(/^\\./, ''))) ? {} : null
      }));
      const window = {};
      const document = {
        querySelectorAll(selector) {
          if (selector !== '[x-model]') throw new Error('unexpected selector: ' + selector);
          return elements;
        }
      };
      #{source}
      console.log(JSON.stringify(window.getFormState()));
    JS

    output, status = Open3.capture2e('node', '-e', program)
    raise "node could not run the harvest: #{output}" unless status.success?

    JSON.parse(output)
  end

  # spec/adapter/alpinejs_spec.rb already pins the group's own attributes (shared
  # x-model, per-item values, checked-from-array). What it does not state is the
  # containment the harvest rule keys off, which is all this describe adds.
  describe 'the markup the harvest reads' do
    let(:html) { render_components(group_app(%w[apple cherry]), checkbox_app(true)) }

    it 'nests the group items inside a container that marks them as a group' do
      group = html[%r{<div class="checkbox-group">.*?</div>}m]

      expect(group).not_to be_nil
      expect(group.scan(/<input/).length).to eq(3)
      expect(html.sub(group, '')).to include('x-model="subscribe"')
    end

    it 'gives a lone checkbox its own key and a constant value' do
      expect(html).to include('class="checkbox-wrapper"')
      expect(html).to include('name="subscribe" value="true" checked x-model="subscribe"')
    end

    it 'nests multi chips inside the container the harvest rule also keys off' do
      group = render_components(chip_app(%w[ruby]))[%r{<div class="sw-chip-group">.*?</div>}m]

      expect(group).not_to be_nil
      expect(group.scan(/type="checkbox"/).length).to eq(3)
    end

    it 'renders a single-select chip group as radios, outside the checkbox branch' do
      html = render_components(chip_app('ruby', multi: false))

      expect(html).to include('<div class="sw-chip-group">')
      expect(html).not_to include('type="checkbox"')
    end
  end

  describe 'the harvested payload' do
    before { skip 'node is not installed, so the emitted JS cannot be run' unless self.class.node? }

    it 'carries the selected group items as an array, in rendered order' do
      expect(harvest(render_components(group_app(%w[cherry apple])))).to eq('fruits' => %w[apple cherry])
    end

    it 'carries an empty array when nothing in the group is selected' do
      expect(harvest(render_components(group_app([])))).to eq('fruits' => [])
    end

    it 'carries an array even when the group holds a single item' do
      expect(harvest(render_components(group_app(%w[apple], items: %w[apple])))).to eq('fruits' => %w[apple])
    end

    it 'carries a lone checkbox as a boolean' do
      expect(harvest(render_components(checkbox_app(true)))).to eq('subscribe' => true)
      expect(harvest(render_components(checkbox_app(false)))).to eq('subscribe' => false)
    end

    it 'keeps both shapes in one payload' do
      html = render_components(group_app(%w[apple cherry]), checkbox_app(true))

      expect(harvest(html)).to eq('fruits' => %w[apple cherry], 'subscribe' => true)
    end

    it 'carries a multi chip_group as an array, in rendered order (disc-105)' do
      expect(harvest(render_components(chip_app(%w[opal ruby])))).to eq('langs' => %w[ruby opal])
    end

    it 'carries an empty array when no chip is selected' do
      expect(harvest(render_components(chip_app([])))).to eq('langs' => [])
    end

    it 'carries a single-select chip group as the selected value' do
      expect(harvest(render_components(chip_app('js', multi: false)))).to eq('langs' => 'js')
    end

    it 'keeps a chip group and a lone checkbox apart in one payload' do
      html = render_components(chip_app(%w[ruby]), checkbox_app(false))

      expect(harvest(html)).to eq('langs' => %w[ruby], 'subscribe' => false)
    end
  end
end
