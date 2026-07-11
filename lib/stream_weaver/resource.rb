# frozen_string_literal: true

require 'cgi'
require_relative 'resource/state_keys'
require_relative 'resource/store'
require_relative 'resource/field_input'
require_relative 'resource/default_views'

module StreamWeaver
  RouteRule = Struct.new(:parser, :builder, :source, keyword_init: true)
  Field     = Struct.new(:name, :type, :opts)

  class ResourceDefinition
    include Resource::StateKeys

    attr_reader :name, :singular, :plural, :store, :fields

    def initialize(name, store, plural: nil)
      @name      = name.to_sym
      @singular  = name.to_s
      @plural    = plural&.to_s || "#{@singular}s"
      @store     = store
      @fields    = []
      @edit_view = :modal
      @new_view  = :modal
      @only      = %i[index show new edit destroy destroy_confirm]
      @overrides = {}

      # Memoize member-route regexes — built once, matched on every request
      esc = Regexp.escape(@singular)
      @edit_re    = %r{\A/#{esc}/([^/]+)/edit\z}
      @delete_re  = %r{\A/#{esc}/([^/]+)/delete\z}
      @show_re    = %r{\A/#{esc}/([^/]+)\z}

      Resource::Store.validate!(store, name)
    end

    # DSL methods (dual-purpose: reader when called with no args, setter with args)
    def field(name, type, **opts); @fields << Field.new(name, type, opts); end
    def edit_view(style = nil);    style.nil? ? @edit_view : (@edit_view = style); end
    def new_view(style = nil);     style.nil? ? @new_view  : (@new_view  = style); end
    def only(actions = nil);       actions.nil? ? @only : (@only = Array(actions)); end
    def except(actions);           @only -= Array(actions);                end
    def index(&blk); @overrides[:index] = blk; end
    def show(&blk);  @overrides[:show]  = blk; end
    def new(&blk);   @overrides[:new]   = blk; end
    def edit(&blk);  @overrides[:edit]  = blk; end

    def overrides; @overrides; end

    # Routing
    def parse_path(path)
      case path
      when "/#{@plural}"     then sw_state(:index)
      when "/#{@plural}/new" then sw_state(:new)
      when @edit_re          then sw_state(:edit,           CGI.unescape($1))
      when @delete_re        then sw_state(:destroy_confirm, CGI.unescape($1))
      when @show_re          then sw_state(:show,           CGI.unescape($1))
      end
    end

    def build_path(st)
      return nil unless st[RESOURCE] == @name
      id = st[ID]
      case st[ACTION]
      when :index then "/#{@plural}"
      when :new   then "/#{@plural}/new"
      when :show            then id && "/#{@singular}/#{CGI.escape(id.to_s)}"
      when :edit            then id && "/#{@singular}/#{CGI.escape(id.to_s)}/edit"
      when :destroy_confirm then id && "/#{@singular}/#{CGI.escape(id.to_s)}/delete"
      end
    end

    # Rendering — called every rebuild; dispatches to DefaultViews or override block
    def render_if_active(app)
      st = app.state
      return unless st[RESOURCE] == @name && @only.include?(st[ACTION])
      id = st[ID]
      case st[ACTION]
      when :index           then render_action(:index,           app, @store.all)
      when :show            then render_action(:show,            app, @store.find(id))
      when :new             then render_action(:new,             app, nil)
      when :edit            then render_action(:edit,            app, @store.find(id))
      when :destroy_confirm then render_action(:destroy_confirm, app, @store.find(id))
      end
    end

    def render_action(action, app, data)
      if (override = @overrides[action])
        app.with_clean_form_context { app.instance_exec(data, &override) }
      else
        Resource::DefaultViews.send(action, self, app, data)
      end
    end

    private

    def sw_state(action, id = nil)
      h = { RESOURCE => @name, ACTION => action }
      h[ID] = id if id
      h
    end
  end
end
