# Deployment Templates

This directory contains ready-to-use configuration files and templates for deploying StreamWeaver applications to various platforms.

## Files Overview

### Platform Configuration Files

- **`render.yaml`** - Render.com deployment configuration (Infrastructure as Code)
- **`railway.toml`** - Railway deployment configuration
- **`fly.toml`** - Fly.io deployment configuration
- **`Procfile`** - Heroku-style process configuration (works with most platforms)

### Application Templates

- **`Gemfile.template`** - Production-ready Gemfile with all necessary dependencies
- **`Rakefile.template`** - Rake tasks for database migrations and utilities
- **`app.rb.template`** - Complete production app with auth, database, and routing
- **`.env.example`** - Environment variables template

## Quick Usage

### For Render.com

1. Copy `render.yaml` to your repository root
2. Update service names and environment variables as needed
3. Push to GitHub
4. Create a new Blueprint Instance on Render.com
5. Select your repository and `render.yaml`

### For Railway

1. Copy `railway.toml` to your repository root
2. Create account at railway.app
3. Connect your GitHub repository
4. Add PostgreSQL database from Railway dashboard
5. Set environment variables in Railway dashboard

### For Fly.io

1. Install flyctl: `brew install flyctl` (macOS) or download from fly.io
2. Run `fly auth login`
3. Copy `fly.toml` to your repository root (or generate with `fly launch`)
4. Create PostgreSQL: `fly postgres create`
5. Attach database: `fly postgres attach <db-name>`
6. Deploy: `fly deploy`

### Starting a New Production App

1. **Copy templates to your project**:
```bash
cp docs/deployment-templates/Gemfile.template Gemfile
cp docs/deployment-templates/Rakefile.template Rakefile
cp docs/deployment-templates/app.rb.template app.rb
cp docs/deployment-templates/.env.example .env
```

2. **Install dependencies**:
```bash
bundle install
```

3. **Generate session secret**:
```bash
openssl rand -hex 64
# Add to .env file as SESSION_SECRET
```

4. **Create database migration**:
```bash
bundle exec rake db:create_migration NAME=create_users
```

5. **Edit migration** (in db/migrate/):
```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_hash, null: false
      t.timestamps
    end
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
  end
end
```

6. **Run migration**:
```bash
bundle exec rake db:migrate
```

7. **Test locally**:
```bash
ruby app.rb
```

8. **Deploy** (choose one):
   - Copy `render.yaml` and push to GitHub → Create Blueprint on Render
   - Copy `railway.toml` and `railway up`
   - Copy `fly.toml` and `fly deploy`

## Customization

### Adding Custom Environment Variables

Edit `.env.example` and add your variables:
```bash
MY_API_KEY=your_key_here
FEATURE_FLAG=true
```

Then set them on your deployment platform's dashboard.

### Changing Database

**Switch to Sequel instead of ActiveRecord**:

Update `Gemfile.template`:
```ruby
gem 'sequel'
# Remove: gem 'sinatra-activerecord'
```

Update `app.rb.template`:
```ruby
require 'sequel'
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/dev.db')

class User < Sequel::Model
  plugin :validation_helpers
  # ...
end
```

### Adding Background Jobs

Uncomment in `Gemfile.template`:
```ruby
gem 'sidekiq'
gem 'redis'
```

Add worker to `Procfile`:
```
worker: bundle exec sidekiq -r ./app.rb
```

Add worker service to `render.yaml`:
```yaml
- type: worker
  name: my-worker
  env: ruby
  buildCommand: bundle install
  startCommand: bundle exec sidekiq -r ./app.rb
```

### Adding Email Support

Uncomment in `Gemfile.template`:
```ruby
gem 'mail'
```

Configure in `app.rb.template`:
```ruby
require 'mail'

Mail.defaults do
  delivery_method :smtp, {
    address: ENV['SMTP_ADDRESS'],
    port: ENV['SMTP_PORT'],
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD']
  }
end
```

## Platform-Specific Notes

### Render.com

- Auto-generates `DATABASE_URL` when you add PostgreSQL
- Can auto-generate `SESSION_SECRET` with `generateValue: true`
- Supports zero-downtime deploys
- Free tier includes 750 hours/month

### Railway

- Easiest setup with one-click database provisioning
- Auto-sets `DATABASE_URL` and `PORT`
- $5 free trial credit
- Usage-based pricing after trial

### Fly.io

- Requires Docker knowledge for custom builds
- Best for global deployments (edge)
- Free tier: 3 small VMs + 3GB storage
- Excellent CLI tooling

## Security Checklist

Before deploying to production:

- [x] Set strong `SESSION_SECRET` (64+ characters)
- [x] Use PostgreSQL instead of SQLite
- [x] Enable `FORCE_SSL=true` in production
- [x] Set `RACK_ENV=production`
- [x] Add `.env` to `.gitignore`
- [x] Use environment variables for all secrets
- [x] Enable database backups on platform
- [x] Set up error tracking (Sentry, Rollbar)
- [x] Configure logging
- [x] Test authentication flow

## Monitoring

Recommended additions to `Gemfile.template` for production:

```ruby
# Error tracking
gem 'sentry-ruby'
gem 'sentry-sinatra'

# Logging
gem 'lograge'

# Performance monitoring
gem 'newrelic_rpm'  # or
gem 'skylight'
```

## Need Help?

- See [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed deployment guide
- See [QUICK_START_DEPLOYMENT.md](../QUICK_START_DEPLOYMENT.md) for step-by-step walkthrough
- Check [examples/](../../examples/) for working examples
- Open an issue on GitHub for support

## License

These templates are provided as-is under the same MIT license as StreamWeaver.
