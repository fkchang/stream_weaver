# frozen_string_literal: true

require 'cgi'

module StreamWeaver
  RouteRule = Struct.new(:parser, :builder, :source, keyword_init: true)
  Field     = Struct.new(:name, :type, :opts)

  class ResourceDefinition
    attr_reader :name, :singular, :plural, :store, :fields

    def initialize(name, store, plural: nil)
      @name      = name.to_sym
      @singular  = name.to_s
      @plural    = plural&.to_s || "#{@singular}s"
      @store     = store
      @fields    = []
      @edit_view = :modal
      @new_view  = :modal
      @only      = %i[index show new edit destroy]
      @overrides = {}

      Resource::Store.validate!(store, name) if defined?(Resource::Store)
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
      when "/#{@plural}"                                          then sw_state(:index)
      when "/#{@plural}/new"                                      then sw_state(:new)
      when %r{\A/#{Regexp.escape(@singular)}/([^/]+)/edit\z}
        sw_state(:edit, CGI.unescape($1))
      when %r{\A/#{Regexp.escape(@singular)}/([^/]+)\z}
        sw_state(:show, CGI.unescape($1))
      end
    end

    def build_path(st)
      return nil unless st[:_sw_resource] == @name
      id = st[:_sw_id]
      case st[:_sw_action]
      when :index then "/#{@plural}"
      when :new   then "/#{@plural}/new"
      when :show  then id && "/#{@singular}/#{CGI.escape(id.to_s)}"
      when :edit  then id && "/#{@singular}/#{CGI.escape(id.to_s)}/edit"
      end
    end

    # Rendering — called every rebuild; dispatches to DefaultViews or override block
    def render_if_active(app)
      st = app.state
      return unless st[:_sw_resource] == @name && @only.include?(st[:_sw_action])
      id = st[:_sw_id]
      case st[:_sw_action]
      when :index then render_action(:index, app, @store.all)
      when :show  then render_action(:show,  app, @store.find(id))
      when :new   then render_action(:new,   app, nil)
      when :edit  then render_action(:edit,  app, @store.find(id))
      end
    end

    def render_action(action, app, data)
      if (override = @overrides[action])
        app.instance_exec(data, &override)
      elsif defined?(Resource::DefaultViews)
        Resource::DefaultViews.send(action, self, app, data)
      # else: no-op until T3 ships DefaultViews
      end
    end

    private

    def sw_state(action, id = nil)
      h = { _sw_resource: @name, _sw_action: action }
      h[:_sw_id] = id if id
      h
    end
  end
end
