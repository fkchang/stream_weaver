# Running StreamWeaver with Puma-dev

This example demonstrates how to run StreamWeaver apps with [Puma-dev](https://github.com/puma/puma-dev), which provides memorable URLs like `http://myapp.test` for your local development.

## Why Use Puma-dev?

- **Memorable URLs**: Access your app at `http://[directory-name].test` instead of remembering port numbers
- **Always Available**: No need to start the app manually - Puma-dev starts it on first request
- **Multiple Apps**: Run multiple StreamWeaver apps side-by-side with their own URLs
- **No Browser Auto-open**: Apps run on-demand without opening the browser automatically

## Setup

### 1. Install Puma-dev

```bash
# macOS
brew install puma/puma/puma-dev
sudo puma-dev -setup
puma-dev -install

# Linux
gem install puma-dev
puma-dev -setup
puma-dev -install
```

### 2. Create Your App

Create a directory for your app with a `config.ru` file:

```ruby
# config.ru
require 'bundler/setup'
require 'stream_weaver'

App = app "My StreamWeaver App" do
  header1 "Hello from Puma-dev!"
  text_field :message, placeholder: "Enter a message"
  
  if state[:message] && !state[:message].empty?
    text "You said: #{state[:message]}"
  end
end

run App
```

### 3. Link to Puma-dev

```bash
cd /path/to/your/app
puma-dev link
```

This creates a symlink in `~/.puma-dev/` pointing to your app directory.

### 4. Access Your App

Open your browser and navigate to:
```
http://[directory-name].test
```

For example, if your directory is named `myapp`, visit `http://myapp.test`.

## How It Works

When running under Puma-dev:

1. **Port Detection**: StreamWeaver detects the `PORT` environment variable set by Puma-dev
2. **No Auto-browser**: The browser won't auto-open (since `PORT` is set)
3. **Same Behavior**: All other StreamWeaver features work exactly the same

When running normally (`ruby app.rb`):

1. **Auto Port**: StreamWeaver finds an available port starting from 4567
2. **Auto Browser**: Opens your browser automatically
3. **Self-contained**: No external dependencies

## Environment Variable Priority

StreamWeaver checks for port in this order:
1. `options[:port]` - Explicitly passed to `run!`
2. `STREAMWEAVER_PORT` - Custom StreamWeaver port
3. `PORT` - Standard port (used by Puma-dev, Heroku, etc.)
4. Auto-detect - Find available port starting from 4567

## Converting Existing Apps

To run an existing StreamWeaver app with Puma-dev:

1. Create a `config.ru` in your app's directory
2. Replace `App.run!` with `run App` in `config.ru`
3. Link to Puma-dev: `puma-dev link`
4. Access at `http://[directory-name].test`

## Troubleshooting

**App not accessible?**
- Check Puma-dev is running: `puma-dev -status`
- Verify symlink exists: `ls -la ~/.puma-dev/`
- Check logs: `tail -f ~/Library/Logs/puma-dev.log` (macOS)

**Want both modes?**
Keep your original `app.rb` with `App.run!` for standalone mode, and create a separate `config.ru` with `run App` for Puma-dev mode.
