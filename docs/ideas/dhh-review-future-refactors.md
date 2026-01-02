# DHH Review: Future Refactors

Notes from DHH-style code review of service mode implementation (2026-01-02).

## Route Duplication Between Service and SinatraApp

The `/apps/:app_id/update`, `/apps/:app_id/action/:button_id`, `/apps/:app_id/event/:key`, and `/apps/:app_id/form/:form_name` routes in `service.rb` are nearly identical to their counterparts in `server.rb`. Extract shared logic to `RouteHelpers` module.

```ruby
# lib/stream_weaver/route_helpers.rb
module StreamWeaver
  module RouteHelpers
    def coerce_param_value(value, current_value)
      case
      when value.is_a?(Array)               then value
      when %w[on true].include?(value)      then true
      when value == "false"                 then false
      when current_value.is_a?(Array)       then Array(value)
      else                                  value
      end
    end

    def sync_params_to_state(state, excluded_keys: [])
      excluded = %w[splat captures app_id button_id] + excluded_keys.map(&:to_s)
      params.each do |key, value|
        next if excluded.include?(key)
        state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
      end
    end
  end
end
```

## PID File Management Should Be Its Own Class

Extract PID file logic from Service (lines 96-129) to dedicated class:

```ruby
# lib/stream_weaver/pid_file.rb
module StreamWeaver
  class PidFile
    PATH = File.expand_path('~/.streamweaver/server.pid').freeze

    class << self
      def write(port:)
        FileUtils.mkdir_p(File.dirname(PATH))
        File.write(PATH, "port=#{port}\npid=#{Process.pid}\n")
      end

      def delete
        File.delete(PATH) if File.exist?(PATH)
      end

      def read
        return unless File.exist?(PATH)
        content = File.read(PATH)
        { port: content[/port=(\d+)/, 1]&.to_i,
          pid:  content[/pid=(\d+)/, 1]&.to_i }
      end

      def process_alive?
        info = read or return false
        Process.kill(0, info[:pid])
        true
      rescue Errno::ESRCH
        delete
        false
      end
    end
  end
end
```

## Admin Inline Styles Should Use Semantic CSS Classes

The Admin class has inline styles everywhere. Should use semantic classes that reference the theme system:

```ruby
# Before
div style: "display: inline-flex; align-items: center; gap: 0.5rem; ..." do

# After
div class: "admin-status-bar" do
  status_indicator :running, "Port #{Service.settings.port}"
end
```

## CLI Repetitive Error Handling

Every CLI method that contacts the service has identical error handling. Extract to helper:

```ruby
# Before: Repeated 5+ times
rescue Errno::ECONNREFUSED
  puts "Error: Could not connect to StreamWeaver service"
  exit 1
end

# After
def self.with_service_connection
  yield
rescue Errno::ECONNREFUSED
  puts "Error: Could not connect to StreamWeaver service"
  exit 1
end
```

## CLI Case Statement Could Be More Declarative

```ruby
# After: Declarative command mapping
COMMANDS = {
  'serve'   => :serve,
  'run'     => :run_app,
  'list'    => :list_apps,
  'remove'  => ->(args) { remove_app(args.first) },
  # ...
}.freeze

def self.run(args)
  return help if args.empty?
  command = args.shift
  handler = COMMANDS[command]

  case handler
  when Symbol then send(handler, args)
  when Proc   then handler.call(args)
  when nil    then handle_unknown_command(command, args)
  end
end
```

## Remove Comment Banners

The Service class has banner comments like:
```ruby
# =========================================
# Service Management Routes
# =========================================
```

Well-organized code documents itself through structure. If you need a banner to find routes, the class is too large.
