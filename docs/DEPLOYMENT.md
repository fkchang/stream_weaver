# StreamWeaver Deployment Guide

## Overview

StreamWeaver has evolved from a token-efficient tool for quick Claude Code interactions into a framework capable of building full-blown web applications. This guide covers everything you need to deploy StreamWeaver apps from simple prototypes to production-ready applications.

## Table of Contents

1. [Understanding Your Deployment Needs](#understanding-your-deployment-needs)
2. [Deployment Platforms](#deployment-platforms)
3. [Database & Persistence](#database--persistence)
4. [Authentication](#authentication)
5. [Configuration for Production](#configuration-for-production)
6. [Quick Start Templates](#quick-start-templates)

---

## Understanding Your Deployment Needs

StreamWeaver can serve different use cases:

### 1. **Quick Prototypes / Claude Code Interactions**
- **Current Solution**: In-memory `state()` persistence
- **Good for**: One-off scripts, quick data collection, temporary UIs
- **No changes needed**: Works out of the box

### 2. **Small Web Apps** (like dashboards, admin tools)
- **Needs**: Session persistence, maybe SQLite
- **Users**: 1-50 concurrent
- **Deploy to**: Render, Railway (free tier)

### 3. **Production Web Apps** (like rivet-crm)
- **Needs**: Database (PostgreSQL), authentication, sessions
- **Users**: 50+ concurrent
- **Deploy to**: Render, Railway, Fly.io (paid tier)

---

## Deployment Platforms

### Recommended: Heroku Alternatives in 2025

#### 🥇 **Render** (Most Heroku-like)
**Best for**: Easiest migration, great for beginners

```yaml
# render.yaml
services:
  - type: web
    name: streamweaver-app
    env: ruby
    buildCommand: bundle install
    startCommand: ruby app.rb
    envVars:
      - key: RACK_ENV
        value: production
      - key: SESSION_SECRET
        generateValue: true
```

**Pros**:
- Git push to deploy
- Free SSL, auto-scaling
- PostgreSQL addon available
- Great dashboard

**Cons**:
- Can get expensive with many services

**Pricing**: Free tier available, paid starts at $7/mo

---

#### 🥈 **Railway** (Fastest Setup)
**Best for**: Rapid prototyping, team collaboration

```toml
# railway.toml
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "bundle exec ruby app.rb"
healthcheckPath = "/"
restartPolicyType = "ON_FAILURE"
```

**Pros**:
- One-click templates
- Extremely fast deployments
- Generous free tier with trial credits
- Built-in database provisioning

**Cons**:
- Smaller community than Render

**Pricing**: $5 trial credit, then usage-based (~$5-10/mo for small apps)

---

#### 🥉 **Fly.io** (Global Edge)
**Best for**: Apps needing low latency worldwide

```toml
# fly.toml
app = "streamweaver-app"

[build]
  builder = "paketobuildpacks/builder:base"

[env]
  PORT = "8080"

[[services]]
  http_checks = []
  internal_port = 8080
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

**Pros**:
- Deploy close to users globally
- Good free tier
- Excellent for microservices

**Cons**:
- Requires Docker knowledge
- CLI-focused (less GUI)

**Pricing**: Free tier for 3 small VMs

---

#### **Other Options**

**DigitalOcean App Platform**
- Good for traditional developers
- Transparent pricing
- Ruby buildpack support

**Self-Hosted (Advanced)**
- **Dokku** - Heroku on your VPS
- **CapRover** - GUI for Docker deployments  
- **Coolify** - Modern self-hosted PaaS

---

## Database & Persistence

### Option 1: SQLite (Simplest)

**Good for**: Development, small apps (< 100 concurrent users)

```ruby
# Gemfile
gem 'sqlite3'
gem 'sinatra-activerecord'

# app.rb
require 'sinatra/activerecord'

set :database_file, './config/database.yml'

class User < ActiveRecord::Base
end
```

```yaml
# config/database.yml
development:
  adapter: sqlite3
  database: db/development.sqlite3

production:
  adapter: sqlite3
  database: db/production.sqlite3
```

**Note**: Most platforms require persistent volumes for SQLite in production.

---

### Option 2: PostgreSQL (Recommended for Production)

**Good for**: Production apps, multiple users, data integrity

```ruby
# Gemfile
gem 'pg'
gem 'sinatra-activerecord'

# app.rb
require 'sinatra/activerecord'

set :database_file, './config/database.yml'

# Or use DATABASE_URL from environment
set :database, ENV['DATABASE_URL'] if ENV['DATABASE_URL']
```

```yaml
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: 5
  url: <%= ENV['DATABASE_URL'] %>
```

**Setup on platforms**:
- **Render**: Add PostgreSQL service, auto-sets `DATABASE_URL`
- **Railway**: Click "Add Database" → PostgreSQL
- **Fly.io**: `fly postgres create`

---

### ActiveRecord vs Sequel

#### **ActiveRecord** (Recommended for most apps)

```ruby
# Pros: Convention over configuration, Rails-compatible
gem 'sinatra-activerecord'

class User < ActiveRecord::Base
  validates :email, presence: true, uniqueness: true
  has_many :posts
end

# Migrations with Rake
rake db:create_migration NAME=create_users
```

#### **Sequel** (For advanced use cases)

```ruby
# Pros: Lightweight, flexible, powerful SQL
gem 'sequel'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db.sqlite3')

class User < Sequel::Model
  plugin :validation_helpers
  
  def validate
    super
    validates_presence :email
    validates_unique :email
  end
end
```

**Decision**: Use ActiveRecord unless you need advanced SQL features.

---

### Integration Example

```ruby
# example: todo_list_with_db.rb
require 'stream_weaver'
require 'sinatra/activerecord'

# Database setup
set :database, {adapter: "sqlite3", database: "todos.db"}

class Todo < ActiveRecord::Base
end

# Migration (run once): rake db:create_migration NAME=create_todos
# class CreateTodos < ActiveRecord::Migration[7.0]
#   def change
#     create_table :todos do |t|
#       t.string :text
#       t.boolean :completed, default: false
#       t.timestamps
#     end
#   end
# end

app "Todo Manager with Database" do
  header "📝 Persistent Todo List"
  
  text_field :new_todo, placeholder: "Enter a new todo"
  
  button "Add Todo" do |state|
    if state[:new_todo] && !state[:new_todo].strip.empty?
      Todo.create(text: state[:new_todo], completed: false)
      state[:new_todo] = ""
    end
  end
  
  # Display todos from database
  todos = Todo.where(completed: false).order(created_at: :desc)
  
  if todos.empty?
    text "No todos yet. Add one above!"
  else
    header3 "Your Todos (#{todos.count})"
    
    todos.each do |todo|
      div class: "todo-item" do
        text todo.text
        button "✓", style: :secondary do |state|
          todo.update(completed: true)
        end
      end
    end
  end
end.run!
```

---

## Authentication

### Option 1: Session-Based Authentication (Recommended)

**Best for**: Most web apps, user-facing applications

```ruby
require 'stream_weaver'
require 'bcrypt'

# Enable sessions (already enabled in StreamWeaver)
# StreamWeaver uses sessions by default for state management

# User model (using ActiveRecord)
class User < ActiveRecord::Base
  include BCrypt
  
  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }
  
  def password
    @password ||= Password.new(password_hash)
  end
  
  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end
  
  def self.authenticate(username, password)
    user = find_by(username: username)
    user if user && user.password == password
  end
end

# Helper methods
helpers do
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !!current_user
  end
  
  def require_login
    redirect '/login' unless logged_in?
  end
end

# Login app
LoginApp = app "Login" do
  header "Login"
  
  text_field :username, placeholder: "Username"
  text_field :password, placeholder: "Password"
  
  button "Login" do |state|
    user = User.authenticate(state[:username], state[:password])
    if user
      session[:user_id] = user.id
      # Redirect or show success
      state[:error] = nil
    else
      state[:error] = "Invalid username or password"
    end
  end
  
  if state[:error]
    text state[:error]
  end
end

# Protected app
DashboardApp = app "Dashboard" do
  # Check authentication
  unless logged_in?
    redirect '/login'
  end
  
  header "Welcome, #{current_user.username}!"
  
  button "Logout" do |state|
    session.clear
    redirect '/login'
  end
end
```

**Security Notes**:
- Always use HTTPS in production
- Use strong session secrets (64+ characters)
- Set secure session cookies: `set :session_secret, ENV['SESSION_SECRET']`

---

### Option 2: HTTP Basic Auth (Quick & Simple)

**Best for**: Internal tools, admin panels, quick prototypes

```ruby
require 'stream_weaver'

# Method 1: Rack middleware
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == ENV['ADMIN_USER'] && password == ENV['ADMIN_PASS']
end

app "Admin Dashboard" do
  header "Admin Dashboard"
  text "You're authenticated!"
end.run!
```

```ruby
# Method 2: Helper-based approach
helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && 
      @auth.credentials == [ENV['ADMIN_USER'], ENV['ADMIN_PASS']]
  end
end

get '/admin' do
  protected!
  # Your StreamWeaver app here
end
```

---

### Option 3: Third-Party OAuth (GitHub, Google)

**Best for**: User-facing apps, social login

```ruby
# Gemfile
gem 'omniauth'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'

# config.ru or app.rb
require 'omniauth'
require 'omniauth-github'

use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET']
end

# Callback route
get '/auth/:provider/callback' do
  auth = request.env['omniauth.auth']
  session[:user_id] = auth['uid']
  session[:user_name] = auth['info']['name']
  redirect '/'
end

# Login link in your StreamWeaver app
app "My App" do
  unless session[:user_id]
    text "Please login to continue"
    # Link to /auth/github
  else
    header "Welcome, #{session[:user_name]}!"
  end
end
```

---

### Option 4: Simple Extension (sinatra-simple-auth)

**Best for**: Classic/modular Sinatra apps, minimal setup

```ruby
# Gemfile
gem 'sinatra-simple-auth'

require 'sinatra/simple_auth'

enable :sessions
set :password, ENV['APP_PASSWORD']

get '/secure' do
  protected!
  # Your StreamWeaver app
end
```

---

## Configuration for Production

### Environment Variables

```ruby
# app.rb
configure :production do
  # Session secret (REQUIRED)
  set :session_secret, ENV.fetch('SESSION_SECRET') {
    raise "SESSION_SECRET required in production"
  }
  
  # Database
  set :database, ENV['DATABASE_URL']
  
  # Logging
  set :logging, true
  set :dump_errors, false
  set :show_exceptions, false
  
  # Force HTTPS
  use Rack::SslEnforcer if ENV['FORCE_SSL'] == 'true'
end

configure :development do
  set :session_secret, 'development-secret-key-at-least-64-chars-long-for-security'
end
```

### Procfile (for Heroku-style platforms)

```
# Procfile
web: bundle exec ruby app.rb -p $PORT
```

### Environment Setup

```bash
# .env (use with 'gem dotenv' in development)
RACK_ENV=development
SESSION_SECRET=your-super-secret-session-key-minimum-64-characters-for-security
DATABASE_URL=sqlite://db/development.sqlite3

# Production (set on platform)
RACK_ENV=production
SESSION_SECRET=<generated-secure-key>
DATABASE_URL=postgresql://user:pass@host:5432/dbname
```

---

## Quick Start Templates

### Template 1: Simple App (No Database)

```ruby
# my_app.rb
require 'stream_weaver'

app "My App" do
  header "Hello World"
  text_field :name
  
  button "Submit" do |state|
    puts "Hello, #{state[:name]}!"
  end
end.run! if __FILE__ == $0
```

**Deploy to Render**:
1. Push to GitHub
2. Connect repo to Render
3. Set build command: `bundle install`
4. Set start command: `ruby my_app.rb`
5. Deploy!

---

### Template 2: App with Database

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'stream_weaver'
gem 'sinatra-activerecord'
gem 'sqlite3', group: :development
gem 'pg', group: :production
gem 'rake'

# Rakefile
require 'sinatra/activerecord/rake'
require './app'

# app.rb
require 'stream_weaver'
require 'sinatra/activerecord'

# Database config
configure :development do
  set :database, {adapter: 'sqlite3', database: 'db/dev.db'}
end

configure :production do
  set :database, ENV['DATABASE_URL']
end

# Model
class Task < ActiveRecord::Base
end

# App
App = app "Task Manager" do
  text_field :new_task
  
  button "Add" do |state|
    Task.create(name: state[:new_task]) if state[:new_task]
    state[:new_task] = ""
  end
  
  Task.all.each do |task|
    div do
      text task.name
      button "Delete" do |state|
        task.destroy
      end
    end
  end
end

App.run! if __FILE__ == $0
```

**Setup**:
```bash
bundle install
bundle exec rake db:create_migration NAME=create_tasks
# Edit migration file, then:
bundle exec rake db:migrate
ruby app.rb
```

---

### Template 3: Authenticated App

```ruby
# app.rb
require 'stream_weaver'
require 'sinatra/activerecord'
require 'bcrypt'

# Database setup
set :database_file, './config/database.yml'

# Models
class User < ActiveRecord::Base
  include BCrypt
  
  def password
    @password ||= Password.new(password_hash)
  end
  
  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end
  
  def self.authenticate(email, password)
    user = find_by(email: email)
    user if user && user.password == password
  end
end

# Auth helpers
helpers do
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !!current_user
  end
end

# Routes
get '/login' do
  # Show login StreamWeaver app
  LoginApp.generate.call(env)
end

post '/login' do
  user = User.authenticate(params[:email], params[:password])
  if user
    session[:user_id] = user.id
    redirect '/'
  else
    # Show error
  end
end

get '/' do
  if logged_in?
    DashboardApp.generate.call(env)
  else
    redirect '/login'
  end
end

# Apps
LoginApp = app "Login" do
  header "Login"
  # ... login form
end

DashboardApp = app "Dashboard" do
  header "Welcome!"
  # ... main app
end
```

---

## Platform-Specific Deployment Guides

### Render Deployment

1. **Create render.yaml**:
```yaml
databases:
  - name: myapp-db
    databaseName: myapp
    user: myapp

services:
  - type: web
    name: myapp
    env: ruby
    buildCommand: bundle install; bundle exec rake db:migrate
    startCommand: bundle exec ruby app.rb
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: myapp-db
          property: connectionString
      - key: RACK_ENV
        value: production
      - key: SESSION_SECRET
        generateValue: true
```

2. Push to GitHub
3. Connect to Render
4. Deploy!

### Railway Deployment

1. Connect GitHub repo
2. Add PostgreSQL database
3. Set start command: `bundle exec ruby app.rb`
4. Add environment variables
5. Deploy!

### Fly.io Deployment

```bash
# Install flyctl
fly auth login

# Launch app
fly launch

# Add PostgreSQL
fly postgres create

# Attach to app
fly postgres attach --app myapp myapp-db

# Deploy
fly deploy
```

---

## Best Practices

### Security
- ✅ Always use HTTPS in production
- ✅ Set strong SESSION_SECRET (64+ chars)
- ✅ Use environment variables for secrets
- ✅ Hash passwords with BCrypt
- ✅ Validate user input
- ✅ Use CSRF protection for forms

### Performance
- ✅ Use connection pooling for databases
- ✅ Add database indices on frequently queried columns
- ✅ Cache expensive operations
- ✅ Use CDN for static assets

### Monitoring
- ✅ Add error tracking (Sentry, Rollbar)
- ✅ Monitor application logs
- ✅ Set up uptime monitoring
- ✅ Track database performance

---

## Troubleshooting

### "SESSION_SECRET required in production"
**Solution**: Set environment variable `SESSION_SECRET` on your platform

### Database connection errors
**Solution**: Verify `DATABASE_URL` is set correctly and database is provisioned

### App crashes on startup
**Solution**: Check logs, ensure all gems are in Gemfile, run migrations

### Slow database queries
**Solution**: Add indices, optimize queries, check connection pooling

---

## Summary

**For Quick Prototypes**: Use in-memory state, deploy to Railway/Render free tier

**For Small Apps**: Add SQLite, deploy to Railway/Render with persistent volume

**For Production Apps**: Use PostgreSQL, add authentication, deploy to Render/Railway/Fly.io with monitoring

The beauty of StreamWeaver is that you can start simple and add complexity only when needed. Begin with `state()`, add a database when persistence matters, implement auth when you have users, and scale your deployment as your app grows.

Choose the right tool for the job:
- **Render**: Best Heroku replacement, easiest migration
- **Railway**: Fastest for prototyping, great developer experience
- **Fly.io**: Best for global apps, edge deployments
- **Self-hosted**: Maximum control, requires more setup

All platforms support Ruby/Sinatra, offer databases, and can run StreamWeaver apps with minimal configuration.
