# Deployment & Production: Summary

This document provides a high-level overview of deploying StreamWeaver applications. For detailed guides, see the linked documentation.

## 📚 Documentation Structure

### Main Guides

1. **[FROM_PROTOTYPE_TO_PRODUCTION.md](FROM_PROTOTYPE_TO_PRODUCTION.md)** - Start here!
   - Decision matrix for choosing the right approach
   - Use case comparisons
   - Migration paths from simple to complex
   - Quick reference for what you need

2. **[QUICK_START_DEPLOYMENT.md](QUICK_START_DEPLOYMENT.md)** - Get deployed in 5-15 minutes
   - Three deployment paths (simple, database, railway)
   - Step-by-step instructions
   - Troubleshooting guide

3. **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete technical reference
   - All deployment platforms compared
   - Database options (SQLite, PostgreSQL, ActiveRecord, Sequel)
   - Authentication strategies (Basic, Session, OAuth)
   - Production configuration
   - Security best practices

### Templates & Examples

4. **[deployment-templates/](deployment-templates/)** - Ready-to-use configuration files
   - Platform configs: `render.yaml`, `railway.toml`, `fly.toml`
   - App templates: `Gemfile`, `Rakefile`, `app.rb`
   - Environment variables: `.env.example`

5. **[../examples/](../examples/)** - Working code examples
   - `basic_auth_demo.rb` - HTTP Basic Auth
   - `database_todo.rb` - Database persistence
   - `session_auth_demo.rb` - Full authentication system

---

## 🚀 Quick Navigation

### "I want to..."

**...collect data once from a user**
→ Use `run_once!` mode, no deployment needed
→ See README.md examples

**...build a quick tool for my team**
→ Add Basic Auth, deploy to free tier
→ See [basic_auth_demo.rb](../examples/basic_auth_demo.rb)
→ 5 minutes to deploy

**...build a web app with user accounts**
→ Use session auth + database
→ See [QUICK_START_DEPLOYMENT.md](QUICK_START_DEPLOYMENT.md)
→ 15 minutes to deploy

**...build production software**
→ Use production template
→ See [deployment-templates/](deployment-templates/)
→ 1-2 hours to full setup

---

## 🎯 Key Concepts

### State Management

**In-Memory (Default)**:
```ruby
state[:todos] ||= []  # Lost on server restart
```
Good for: Prototypes, temporary UIs, single sessions

**Database Persistence**:
```ruby
Todo.create(text: state[:new_todo])  # Permanent storage
```
Good for: Web apps, multi-user systems, data integrity

### Authentication

**None** - Quick prototypes
```ruby
app "My App" do
  # No auth needed
end
```

**Basic HTTP Auth** - Internal tools
```ruby
use Rack::Auth::Basic do |u, p|
  u == 'admin' && p == ENV['PASS']
end
```

**Session-Based** - Web apps
```ruby
session[:user_id] = user.id
# Full user accounts, login/logout
```

**OAuth** - Production apps
```ruby
provider :github, ENV['KEY'], ENV['SECRET']
# Third-party login (GitHub, Google, etc.)
```

### Deployment Platforms

**Render** - Most Heroku-like, easiest migration
- Best for: Most users, production apps
- Free tier: Yes
- Setup: `render.yaml` + Git push

**Railway** - Fastest setup, great DX
- Best for: Prototyping, quick deploys
- Free tier: $5 trial credit
- Setup: `railway up`

**Fly.io** - Global edge deployment
- Best for: Low latency worldwide
- Free tier: 3 small VMs
- Setup: `fly deploy`

---

## 📊 At-a-Glance Comparison

| Scenario | State | Auth | Database | Deploy | Cost | Time |
|----------|-------|------|----------|--------|------|------|
| **Prototype** | Memory | None | None | Local | $0 | 0 min |
| **Internal Tool** | Memory | Basic | SQLite/None | Free tier | $0 | 5 min |
| **Small App** | Database | Sessions | PostgreSQL | Paid | $7-15 | 15 min |
| **Production** | Database | Sessions+OAuth | PostgreSQL+Redis | Paid | $25-100 | 1-2 hrs |

---

## 🛠️ Common Patterns

### Pattern 1: Quick Prototype
```ruby
require 'stream_weaver'

app "Quick Form" do
  text_field :data
  button "Submit" { |s| puts s[:data] }
end.run_once!  # Run, collect, exit
```

### Pattern 2: Internal Dashboard
```ruby
require 'stream_weaver'

use Rack::Auth::Basic, "Admin" do |u, p|
  u == 'admin' && p == ENV['ADMIN_PASS']
end

app "Dashboard" do
  # Your protected content
end.run!
```

### Pattern 3: Web App with Database
```ruby
require 'stream_weaver'
require 'sinatra/activerecord'

set :database, ENV['DATABASE_URL']

class Post < ActiveRecord::Base
end

app "Blog" do
  Post.all.each do |post|
    card { text post.title }
  end
end.run!
```

### Pattern 4: Authenticated Web App
```ruby
require 'stream_weaver'
require 'sinatra/activerecord'
require 'bcrypt'

# See docs/deployment-templates/app.rb.template
# for complete example with:
# - User registration
# - Login/logout
# - Protected routes
# - Session management
```

---

## ✅ Production Checklist

Before deploying to production:

**Required**:
- [ ] Set `SESSION_SECRET` (64+ characters)
- [ ] Set `RACK_ENV=production`
- [ ] Use PostgreSQL (not SQLite)
- [ ] Enable HTTPS/SSL
- [ ] Hash passwords with BCrypt
- [ ] Validate user input
- [ ] Add `.env` to `.gitignore`

**Recommended**:
- [ ] Set up error tracking (Sentry)
- [ ] Configure logging
- [ ] Enable database backups
- [ ] Set up monitoring/uptime checks
- [ ] Test authentication flow
- [ ] Add rate limiting
- [ ] Configure email service
- [ ] Set up staging environment

**Optional**:
- [ ] Add background jobs (Sidekiq)
- [ ] Configure CDN
- [ ] Set up CI/CD
- [ ] Add performance monitoring
- [ ] Configure Redis for caching
- [ ] Set up file storage (S3)

---

## 🔗 External Resources

### Deployment Platforms
- [Render](https://render.com) - Easiest Heroku alternative
- [Railway](https://railway.app) - Fast prototyping platform
- [Fly.io](https://fly.io) - Global edge deployment

### Authentication
- [BCrypt Ruby](https://github.com/bcrypt-ruby/bcrypt-ruby) - Password hashing
- [OmniAuth](https://github.com/omniauth/omniauth) - OAuth authentication
- [Warden](https://github.com/wardencommunity/warden) - Rack authentication framework

### Database
- [ActiveRecord](https://guides.rubyonrails.org/active_record_basics.html) - Rails ORM
- [Sequel](https://sequel.jeremyevans.net/) - Lightweight database toolkit
- [PostgreSQL](https://www.postgresql.org/) - Production database

### Tools
- [Sinatra ActiveRecord](https://github.com/sinatra-activerecord/sinatra-activerecord) - Database integration
- [Puma](https://puma.io/) - Web server (included with StreamWeaver)
- [Rack](https://github.com/rack/rack) - Web server interface

---

## 🆘 Getting Help

1. Check [FROM_PROTOTYPE_TO_PRODUCTION.md](FROM_PROTOTYPE_TO_PRODUCTION.md) for decision guidance
2. Follow [QUICK_START_DEPLOYMENT.md](QUICK_START_DEPLOYMENT.md) for step-by-step
3. Reference [DEPLOYMENT.md](DEPLOYMENT.md) for technical details
4. Copy templates from [deployment-templates/](deployment-templates/)
5. Study examples in [../examples/](../examples/)
6. Open issue on GitHub for questions

---

## 📈 Growth Path

```
Start Simple → Add Features → Scale

Day 1:    In-memory state, run locally
Week 1:   Add Basic Auth, deploy free tier
Month 1:  Add database, user accounts
Month 3:  Add background jobs, email
Month 6:  Full production with monitoring
```

**The StreamWeaver Philosophy**: 
Start with the simplest solution that works. Add complexity only when needed.

---

## 🎓 Learning Resources

**Beginner**: Start here
1. Read [FROM_PROTOTYPE_TO_PRODUCTION.md](FROM_PROTOTYPE_TO_PRODUCTION.md)
2. Try [basic_auth_demo.rb](../examples/basic_auth_demo.rb)
3. Follow [QUICK_START_DEPLOYMENT.md](QUICK_START_DEPLOYMENT.md)

**Intermediate**: Building real apps
1. Read [DEPLOYMENT.md](DEPLOYMENT.md)
2. Try [database_todo.rb](../examples/database_todo.rb)
3. Use [deployment-templates/](deployment-templates/)

**Advanced**: Production systems
1. Study [session_auth_demo.rb](../examples/session_auth_demo.rb)
2. Customize [app.rb.template](deployment-templates/app.rb.template)
3. Add monitoring, jobs, email, etc.

---

**Remember**: StreamWeaver is designed to grow with you. Start simple, add features as needed, and deploy when ready. The platform supports everything from quick Claude Code interactions to full production web applications.

Happy building! 🚀
