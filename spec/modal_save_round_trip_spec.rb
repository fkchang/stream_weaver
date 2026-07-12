# frozen_string_literal: true

require "spec_helper"
require "rack/test"

# stream_weaver-ho5 (reopened): browser-verified root cause -- the Save
# button inside a modal emitted `hx-on::before-request => "open = false"`.
# htmx collects `hx-include` values *after* `before-request` fires, and
# closing removed the modal's fields from the DOM before that collection
# happened, so the POST carried zero fields (silent data loss). The fix
# moves the close to `hx-on::after-request`, reading the modal wrapper's
# fresh `data-sw-open` attribute (set by the server on every re-render)
# instead of unconditionally closing -- so a validation-failure response
# that re-renders the modal still-open leaves it open, and a real close
# only ever happens once the request (and therefore param collection) is
# done.
RSpec.describe "modal save round trip (stream_weaver-ho5)" do
  def build_app
    store = { 1 => { id: 1, name: "Nora Albrecht" } }

    StreamWeaver::App.new("Modal save fixture") do
      action(:edit, updates: :quick_edit_modal) do |state, key|
        person = store[key.to_i]
        state[:editing_id] = person[:id]
        state[:edit_name] = person[:name]
      end

      action(:save_edit, updates: :people) do |state, _key|
        person = store[state[:editing_id]]
        name = state[:edit_name].to_s.strip

        if name.empty?
          flash[:error] = "Name can't be blank."
        else
          person[:name] = name
          state[:editing_id] = nil
          state[:quick_edit_open] = false
          flash[:notice] = "Saved #{name}."
        end
      end

      fragment(:people) do
        store.each_value do |p|
          text p[:name]
          button "Edit", action: :edit, key: p[:id]
        end
      end

      fragment(:quick_edit_modal) do
        if state[:editing_id]
          open_modal(:quick_edit)
          modal(:quick_edit, title: "Quick edit") do
            text_field :edit_name, label: "Name", submit: false

            modal_footer do
              button "Save", action: :save_edit, key: :save, style: :primary
            end
          end
        end
      end
    end
  end

  def session_for(app)
    Rack::Test::Session.new(Rack::MockSession.new(app.generate))
  end

  # Attribute-level parsing exactly as a browser would see it, anchored on
  # visible label text rather than the hashed stable id -- mirrors
  # spec/live_input_fragment_wiring_spec.rb's "no assumptions about what the
  # values *should* be" approach.
  def button_tag(html, label)
    html[/<button[^>]*>#{Regexp.escape(label)}<\/button>/] or
      raise "no <button>#{label}</button> found in:\n#{html}"
  end

  def tag_attrs(tag)
    attrs = {}
    tag.scan(/([\w:-]+)="([^"]*)"/).each { |k, v| attrs[k] = CGI.unescapeHTML(v) }
    attrs
  end

  def action_href(html, label)
    tag_attrs(button_tag(html, label)).fetch("hx-post")
  end

  # The modal wrapper's x-init attribute contains a JS arrow function (a
  # literal ">") which would truncate a naive full-tag regex -- data-sw-open
  # is emitted before that attribute, so a direct scan for it is both
  # simpler and immune to that truncation.
  def modal_open_state(html)
    html[/data-sw-open="([^"]*)"/, 1]
  end

  def open_modal_html(session)
    home = session.get("/").body
    session.post(action_href(home, "Edit")).body
  end

  it "the after-request handler reads data-sw-open off the modal wrapper, never assigns before the request fires" do
    session = session_for(build_app)
    modal_html = open_modal_html(session)
    save_attrs = tag_attrs(button_tag(modal_html, "Save"))
    handler = save_attrs.fetch("hx-on::after-request")

    expect(save_attrs).not_to have_key("hx-on::before-request")
    expect(handler).to include("closest('.sw-modal-wrapper')")
    expect(handler).to include("dataset.swOpen")
  end

  it "reflects the server's open decision in data-sw-open when the modal is opened" do
    session = session_for(build_app)
    modal_html = open_modal_html(session)

    expect(modal_open_state(modal_html)).to eq("true")
  end

  it "round-trips a save: params collected from the modal's own emitted inputs reach the server, the store updates, the response reflects it, and a second open-modal action renders the modal again" do
    session = session_for(build_app)
    modal_html = open_modal_html(session)

    post_url = action_href(modal_html, "Save")
    field_name = tag_attrs(modal_html[/<input[^>]+name="edit_name"[^>]*>/]).fetch("name")

    response = session.post(post_url, field_name => "Nora Fenwick-Vance").body

    expect(response).to include("Saved Nora Fenwick-Vance.")
    expect(response).to include("Nora Fenwick-Vance")

    reopened = open_modal_html(session)
    expect(modal_open_state(reopened)).to eq("true")
    expect(reopened).to include('name="edit_name"')
  end

  it "leaves the modal open when the save fails validation" do
    session = session_for(build_app)
    modal_html = open_modal_html(session)

    post_url = action_href(modal_html, "Save")
    field_name = tag_attrs(modal_html[/<input[^>]+name="edit_name"[^>]*>/]).fetch("name")

    response = session.post(post_url, field_name => "   ").body

    expect(response).to match(/Name can.{1,6}t be blank\./)
    expect(modal_open_state(response)).to eq("true")
  end
end
