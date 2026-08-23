# frozen_string_literal: true

require 'spec_helper'

# disc-097: button and radio_group were ported to the canvas bridge's sendEvent,
# but five other controls kept emitting hx-post at routes the bridge does not
# serve (/canvas/<name>/{update,action/*,form/*} all 404). A canvas doc whose
# primary control is a clickable card, a menu item, a form Save button, a tag
# button or a chip was silently dead beside a plain button that worked.
#
# Every context below is asserted three ways, because "works on canvas" and
# "honest in the reader" and "http untouched" are three different promises:
#   - live canvas  (mode: :websocket)              -> dispatches via sendEvent
#   - reader       (mode: :websocket, inert: true) -> disabled + explanatory title
#   - standalone   (mode: :http)                   -> pinned golden markup
RSpec.describe 'canvas action parity' do
  # The nested-interactive guard, as the Alpine handlers spell it.
  def guard = "!$event.target.closest('a,button,input,select,textarea,label,[data-sw-stop]')"

  def render(app, adapter)
    StreamWeaver::Views::AppContentView.new(app, app.state, adapter, false).call
  end

  def canvas(app) = render(app, StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', mode: :websocket))
  def reader(app) = render(app, StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', mode: :websocket, inert: true))
  def http(app) = render(app, StreamWeaver::Adapter::AlpineJS.new)

  # Each app is built fresh per call: components carry render-time ids and
  # action tokens, so a memoized app would leak counters between examples.
  # App.new only stores its block -- rebuild_with_state is what evaluates it.
  def built(&dsl) = StreamWeaver::App.new('t', &dsl).tap { |app| app.rebuild_with_state({}) }

  def clickable_app
    built do
      action(:open_row) { nil }
      clickable(action: :open_row, key: 'r1') { text 'Row' }
    end
  end

  def menu_app
    built do
      dropdown do
        menu do
          menu_item('Archive') { nil }
          menu_item('Plain')
        end
      end
    end
  end

  def form_app
    built do
      form(:contact) do
        text_field :city
        submit 'Send'
        cancel 'Cancel'
      end
    end
  end

  def tag_buttons_app
    built { tag_buttons :reason, ['Too dark', 'Wrong genre'] }
  end

  def chip_group_app
    built do
      chip_group :langs, %w[ruby js]
      chip_group :one, %w[a b], multi: false
    end
  end

  describe 'clickable(action:)' do
    # The action token embeds an HMAC over the app's action definitions, so it
    # is pinned by shape rather than by value; every other attribute -- and
    # their order -- is golden.
    def token(html) = html[%r{hx-post="[^"]*/action/([^"]+)"}, 1]

    it 'dispatches through sendEvent on click and Enter, on live canvas' do
      html = canvas(clickable_app)
      target = html[/sendEvent\('action', \{button: &quot;([^&]+)&quot;/, 1]
      dispatch = "if (#{guard}) sendEvent('action', {button: &quot;#{target}&quot;, state: getFormState()})"

      expect(html).to include(
        %(<div class="sw-clickable" @click="#{dispatch}" @keydown.enter="#{dispatch}" ) +
        %(id="#{html[/id="(clickable_open_row_\w+)"/, 1]}" role="button" tabindex="0">)
      )
    end

    it 'never posts to a route the bridge does not serve' do
      expect(canvas(clickable_app)).not_to include('hx-post')
    end

    it 'carries the same action target the http build would have posted' do
      canvas_target = canvas(clickable_app)[/sendEvent\('action', \{button: &quot;([^&]+)&quot;/, 1]

      expect(StreamWeaver::ActionToken.decode(canvas_target)).to include(a: 'open_row', k: 'r1')
    end

    it 'renders inert in the reader: no dispatch, not focusable, and says why' do
      html = reader(clickable_app)

      expect(html).not_to include('sendEvent')
      expect(html).not_to include('hx-post')
      wrapper = html[/<div class="sw-clickable"[^>]*>/]

      expect(wrapper).to include('aria-disabled="true"')
      expect(wrapper).to include('title="Interactive on live canvas only"')
      expect(wrapper).not_to include('tabindex')
      # aria-disabled, not disabled: the latter is not a valid div attribute
      # and no CSS or AT would act on it.
      expect(wrapper).not_to match(/[^-]disabled/)
    end

    it 'pins the http attribute set and order' do
      html = http(clickable_app)

      expect(html).to include(
        %(<div class="sw-clickable" hx-post="/action/#{token(html)}" hx-include="[x-model]" ) +
        %(hx-target="#app-container" hx-swap="morph:innerHTML" ) +
        %(hx-indicator="##{html[/id="(clickable_open_row_\w+)"/, 1]}, #app-container" hx-disabled-elt="this" ) +
        %(hx-trigger="click[!event.target.closest('a,button,input,select,textarea,label,[data-sw-stop]')], ) +
        %(keydown[event.key=='Enter'&&!event.target.closest('a,button,input,select,textarea,label,[data-sw-stop]')]" ) +
        %(id="#{html[/id="(clickable_open_row_\w+)"/, 1]}" role="button" tabindex="0">)
      )
    end

    it 'leaves the href form alone in every mode' do
      href_app = built { clickable(href: '/elsewhere') { text 'Go' } }
      link = '<a class="sw-clickable sw-clickable--link" href="/elsewhere">'

      expect(canvas(href_app)).to include(link)
      expect(reader(href_app)).to include(link)
      expect(http(href_app)).to include(link)
    end
  end

  describe 'menu_item with an action block' do
    it 'closes the menu and dispatches through sendEvent, on live canvas' do
      expect(canvas(menu_app)).to include(
        '<button type="button" class="sw-menu-item " ' \
        "@click=\"open = false; sendEvent('action', {button: &quot;menu_item_1&quot;, " \
        'state: getFormState()})">Archive</button>'
      )
    end

    it 'never posts to a route the bridge does not serve' do
      expect(canvas(menu_app)).not_to include('hx-post')
    end

    it 'renders inert in the reader with an explanatory title' do
      html = reader(menu_app)

      expect(html).not_to include('sendEvent')
      expect(html).to include(
        '<button type="button" class="sw-menu-item " disabled title="Interactive on live canvas only">Archive</button>'
      )
    end

    it 'leaves an actionless menu item untouched in every mode' do
      plain = '<button type="button" class="sw-menu-item " @click="open = false">Plain</button>'

      expect(canvas(menu_app)).to include(plain)
      expect(reader(menu_app)).to include(plain)
      expect(http(menu_app)).to include(plain)
    end

    it 'leaves http-mode markup byte-for-byte unchanged' do
      expect(http(menu_app)).to include(
        '<button type="button" class="sw-menu-item " hx-post="/action/menu_item_1" hx-include="[x-model]" ' \
        'hx-target="#app-container" hx-swap="morph:innerHTML" hx-indicator="#app-container" ' \
        '@click="open = false">Archive</button>'
      )
    end
  end

  describe 'form submit' do
    it 'dispatches the form scope through sendEvent, on live canvas' do
      expect(canvas(form_app)).to include(
        '<button type="button" id="form-contact-submit" class="btn btn-primary" ' \
        '@click="$el.disabled=true; ' \
        "sendEvent('action', {button: &quot;form-contact-submit&quot;, form: &quot;contact&quot;, " \
        'values: _form, state: getFormState()})">Send</button>'
      )
    end

    it 'never posts to a route the bridge does not serve' do
      expect(canvas(form_app)).not_to include('hx-post')
    end

    it 'renders inert in the reader with an explanatory title' do
      html = reader(form_app)

      expect(html).not_to include('sendEvent')
      expect(html).to include(
        '<button type="button" id="form-contact-submit" class="btn btn-primary" ' \
        'disabled title="Interactive on live canvas only">Send</button>'
      )
    end

    it 'leaves the cancel button alone in every mode -- it is pure Alpine' do
      cancel = '<button type="button" class="btn btn-secondary" ' \
               '@click="_form = JSON.parse(JSON.stringify(_original))">Cancel</button>'

      expect(canvas(form_app)).to include(cancel)
      expect(reader(form_app)).to include(cancel)
      expect(http(form_app)).to include(cancel)
    end

    it 'leaves http-mode markup byte-for-byte unchanged' do
      expect(http(form_app)).to include(
        '<button type="button" id="form-contact-submit" class="btn btn-primary" hx-post="/form/contact" ' +
        %(hx-include="[name^='contact[']" hx-target="#app-container" hx-swap="morph:innerHTML" ) +
        'hx-indicator="#form-contact-submit, #app-container">Send</button>'
      )
    end
  end

  describe 'tag_buttons' do
    it 'sets the key and dispatches a change event, on live canvas' do
      expect(canvas(tag_buttons_app)).to include(
        '<button type="button" class="tag-btn " ' \
        '@click="$data[&quot;reason&quot;] = &quot;too_dark&quot;; ' \
        "sendEvent('change', {field: &quot;reason&quot;, value: &quot;too_dark&quot;, state: getFormState()})\" " +
        %(:class="{ 'tag-btn-selected': $data[&quot;reason&quot;] === &quot;too_dark&quot; }">Too dark</button>)
      )
    end

    it 'never posts to a route the bridge does not serve' do
      expect(canvas(tag_buttons_app)).not_to include('hx-post')
    end

    it 'renders inert in the reader with an explanatory title' do
      html = reader(tag_buttons_app)

      expect(html).not_to include('sendEvent')
      expect(html).to include(
        '<button type="button" class="tag-btn " disabled title="Interactive on live canvas only">Too dark</button>'
      )
    end

    # An apostrophe in a tag label survived http mode because hx-vals goes
    # through JSON.generate. Interpolating it raw into a JS string literal
    # instead would emit $data.reason = 'don't_like_it' -- a syntax error that
    # renders a live-looking button which does nothing, i.e. this story's own
    # bug reintroduced and keyed on the author's choice of words.
    it 'quotes author-supplied labels so a stray apostrophe cannot break the handler' do
      app = built { tag_buttons :reason, ["Don't like it"] }

      expect(canvas(app)).to include(
        '<button type="button" class="tag-btn " ' +
        %(@click="$data[&quot;reason&quot;] = &quot;don't_like_it&quot;; ) +
        %(sendEvent('change', {field: &quot;reason&quot;, value: &quot;don't_like_it&quot;, state: getFormState()})" ) +
        %(:class="{ 'tag-btn-selected': $data[&quot;reason&quot;] === &quot;don't_like_it&quot; }">Don&#39;t like it</button>)
      )
    end

    it 'leaves http-mode markup byte-for-byte unchanged' do
      expect(http(tag_buttons_app)).to include(
        '<button type="button" class="tag-btn " hx-post="/update" hx-include="[x-model]" ' \
        'hx-target="#app-container" hx-swap="morph:innerHTML" hx-indicator="#app-container" ' \
        'hx-vals="{&quot;reason&quot;:&quot;too_dark&quot;}">Too dark</button>'
      )
    end
  end

  # Not one of the five this story ports -- radio_group was already dispatching
  # through sendEvent. But the sweep spec now vouches for it, and its choices go
  # into the handler unslugged (unlike tag_buttons), so it is the one remaining
  # place an author's apostrophe could still break a canvas control.
  describe 'radio_group (already ported, now covered by the same quoting rule)' do
    it 'quotes author-supplied choices' do
      app = built { radio_group :mood, ["Don't know", 'Fine'] }

      expect(canvas(app)).to include(
        '<input type="radio" name="mood" value="Don\'t know" x-model="mood" ' \
        '@change="sendEvent(\'change\', {field: &quot;mood&quot;, value: &quot;Don\'t know&quot;, ' \
        'state: getFormState()})">'
      )
    end
  end

  describe 'chip_group' do
    it 'dispatches a change event per chip, on live canvas' do
      expect(canvas(chip_group_app)).to include(
        '<input type="checkbox" name="langs[]" value="ruby" x-model="langs" class="sw-chip__input" ' \
        "@change=\"sendEvent('change', {field: &quot;langs&quot;, value: $event.target.value, " \
        'state: getFormState()})">'
      )
    end

    it 'dispatches for single-select chips too' do
      expect(canvas(chip_group_app)).to include(
        '<input type="radio" name="one" value="a" x-model="one" class="sw-chip__input" ' \
        "@change=\"sendEvent('change', {field: &quot;one&quot;, value: $event.target.value, " \
        'state: getFormState()})">'
      )
    end

    it 'never posts to a route the bridge does not serve' do
      expect(canvas(chip_group_app)).not_to include('hx-post')
    end

    it 'renders inert in the reader with an explanatory title' do
      html = reader(chip_group_app)

      expect(html).not_to include('sendEvent')
      expect(html).to include(
        '<input type="checkbox" name="langs[]" value="ruby" x-model="langs" class="sw-chip__input" ' \
        'disabled title="Interactive on live canvas only">'
      )
    end

    it 'emits nothing extra for chips inside a form -- the form submit carries them' do
      in_form = built { form(:prefs) { chip_group :langs, %w[ruby js] } }
      chip = '<input type="checkbox" name="prefs[langs][]" value="ruby" x-model="_form.langs" class="sw-chip__input">'

      expect(canvas(in_form)).to include(chip)
      expect(reader(in_form)).to include(chip)
      expect(http(in_form)).to include(chip)
    end

    it 'leaves http-mode markup byte-for-byte unchanged' do
      expect(http(chip_group_app)).to include(
        '<input type="checkbox" name="langs[]" value="ruby" x-model="langs" class="sw-chip__input" ' \
        'hx-post="/update" hx-include="[x-model]" hx-target="#app-container" hx-swap="morph:innerHTML" ' \
        'hx-indicator="#app-container" hx-trigger="change">'
      )
    end
  end
end
