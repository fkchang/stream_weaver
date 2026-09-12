# StreamWeaver: From Prototype to Production

This guide helps you choose the right approach based on your use case, from quick Claude Code interactions to full production web applications.

## Decision Matrix

### Use Case 1: Quick Prototype / Claude Code Interaction

**Characteristics**:
- One-time or temporary use
- No user accounts needed
- Data doesn't need to persist beyond session
- Built and used in < 1 hour

**Setup**: ✅ **No changes needed!**

**What to use**:
- In-memory `state()` (default behavior)
- No database
- No authentication
- Local deployment only

**Example**:
```ruby
require 'stream_weaver'

app "Quick Survey" do
  header "Tell us about yourself"
  text_field :name
  text_field :email
  select :interest, ["Ruby", "Python", "JavaScript"]
end.run_once!  # Returns result, then exits
```

**Deploy**: Don't deploy - run locally!

---

### Use Case 2: Internal Tool / Dashboard

**Characteristics**:
- Used by team members (< 10 people)
- Needs basic security
- Data updates during session
- Used regularly but not 24/7

**Setup**: ⚡ **5 minutes**

**What to use**:
- In-memory state (or add SQLite for simple persistence)
- HTTP Basic Auth
- Deploy to Render/Railway free tier

**Example**: See `examples/basic_auth_demo.rb`

**Deploy**:
```ruby
# Add to your app
use Rack::Auth::Basic, "Admin Area" do |user, pass|
  user == ENV['ADMIN_USER'] && pass == ENV['ADMIN_PASS']
end

# Deploy to Render (5 min setup)
# Set ADMIN_USER and ADMIN_PASS in dashboard
```

**Cost**: Free (Render/Railway free tier)

---

### Use Case 3: Small Web App (< 100 users)

**Characteristics**:
- Multiple users with accounts
- Data needs to persist
- Basic CRUD operations
- Low to medium traffic

**Setup**: ⏱️ **15 minutes**

**What to use**:
- SQLite (development) → PostgreSQL (production)
- Session-based authentication
- Deploy to Render/Railway

**Example**: See `examples/database_todo.rb`

**Deploy**:
1. Copy templates from `docs/deployment-templates/`
2. Add PostgreSQL on platform
3. Set `SESSION_SECRET` and `DATABASE_URL`
4. Deploy!

**Cost**: ~$7-15/month (Render Starter or Railway)

---

### Use Case 4: Production Web App (like rivet-crm)

**Characteristics**:
- Many users (100+)
- Complex data models
- Background jobs
- Email notifications
- File uploads
- API integrations

**Setup**: ⏰ **1-2 hours**

**What to use**:
- PostgreSQL with ActiveRecord
- Full authentication system (with password reset, etc.)
- Background jobs (Sidekiq)
- Email (SendGrid/Mailgun)
- File storage (S3/Cloudinary)
- Error tracking (Sentry)
- Deploy to Render/Railway/Fly.io (paid tier)

**Example**: See `docs/deployment-templates/app.rb.template`

**Deploy**:
1. Use production template as starting point
2. Add required services (Redis, Email, etc.)
3. Set up monitoring and error tracking
4. Configure CI/CD
5. Set up staging environment

**Cost**: ~$25-100/month depending on traffic

---

## Feature Comparison Table

| Feature | Prototype | Internal Tool | Small App | Production |
|---------|-----------|---------------|-----------|------------|
| **State** | In-memory | In-memory/SQLite | PostgreSQL | PostgreSQL |
| **Auth** | None | Basic HTTP | Sessions + BCrypt | Sessions + OAuth |
| **Deploy** | Local only | Free tier | Paid starter | Paid production |
| **Setup Time** | 0 min | 5 min | 15 min | 1-2 hours |
| **Cost** | Free | Free | $7-15/mo | $25-100/mo |
| **Users** | 1 | < 10 | < 100 | 100+ |
| **Uptime** | Ad-hoc | Best effort | 99% | 99.9% |
| **Monitoring** | None | Optional | Recommended | Required |
| **Backups** | None | Optional | Daily | Hourly |

---

## Migration Paths

### From Prototype → Internal Tool

**Add**:
- HTTP Basic Auth (5 lines of code)
- Deploy to free tier

**Keep**:
- In-memory state
- Simple deployment

---

### From Internal Tool → Small App

**Add**:
- Database (SQLite → PostgreSQL)
- User accounts and sessions
- Proper authentication

**Upgrade**:
- Move to paid hosting tier
- Add database backups

---

### From Small App → Production

**Add**:
- Background jobs (Sidekiq + Redis)
- Email service
- File storage
- Error tracking
- Monitoring
- CI/CD pipeline
- Staging environment

**Upgrade**:
- Larger database
- Multiple web servers
- CDN for assets

---

## Platform Recommendations by Use Case

### Prototype
**Run locally**: `ruby app.rb`
- No deployment needed
- Perfect for `run_once!` mode

### Internal Tool
**Render Free Tier** or **Railway Free Trial**
- Easy setup
- No credit card required (Render)
- Perfect for team tools

### Small App
**Render Starter** ($7/mo) or **Railway** (~$10/mo)
- PostgreSQL included
- Auto-deploy from Git
- SSL certificates
- Daily backups

### Production App
**Render Professional** or **Fly.io** or **Railway Pro**
- Scaling options
- High availability
- Advanced monitoring
- Priority support

---

## Database Recommendations

### Prototype
**None** (use in-memory state)
```ruby
state[:todos] ||= []
state[:todos] << new_todo
```

### Internal Tool
**SQLite** (if persistence needed)
```ruby
configure :development do
  set :database, {adapter: 'sqlite3', database: 'db/app.db'}
end
```

### Small App
**PostgreSQL** (via platform)
```ruby
configure :production do
  set :database, ENV['DATABASE_URL']
end
```

### Production App
**PostgreSQL** + **Redis** (for caching/jobs)
```ruby
# Database
set :database, ENV['DATABASE_URL']

# Cache
require 'redis'
$redis = Redis.new(url: ENV['REDIS_URL'])
```

---

## Authentication Recommendations

### Prototype
**None** - It's just you!

### Internal Tool
**HTTP Basic Auth**
```ruby
use Rack::Auth::Basic, "Admin" do |u, p|
  u == ENV['ADMIN_USER'] && p == ENV['ADMIN_PASS']
end
```

### Small App
**Session-based with BCrypt**
```ruby
# See examples/session_auth_demo.rb
class User < ActiveRecord::Base
  include BCrypt
  # ... password hashing
end
```

### Production App
**Sessions + OAuth + 2FA**
```ruby
# Multiple providers
use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET']
  provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET']
end

# Two-factor authentication
gem 'rotp'  # Time-based OTP
```

---

## When to Upgrade

### From Prototype → Internal Tool
**Upgrade when**:
- Team wants to access it
- You're running it daily
- Data needs basic persistence

**Don't upgrade if**:
- One-time use
- Only you use it
- No sensitive data

---

### From Internal Tool → Small App
**Upgrade when**:
- More than 10 users
- Users need their own accounts
- Data integrity is important
- Uptime matters

**Don't upgrade if**:
- Just for your team
- Occasional use
- Basic features sufficient

---

### From Small App → Production
**Upgrade when**:
- 100+ active users
- Revenue depends on it
- Need advanced features (background jobs, email, etc.)
- Scaling is required
- Professional SLA needed

**Don't upgrade if**:
- Growing slowly
- Current setup handles load
- Budget is tight

---

## Quick Start by Use Case

### I want to: **Collect data from Claude Code**
```ruby
result = app "Survey" do
  text_field :name
  select :choice, options
end.run_once!

puts result  # Use the data
```
**Deploy**: Don't! Run locally.

---

### I want to: **Build an internal dashboard**
```ruby
use Rack::Auth::Basic, "Dashboard" do |u, p|
  u == 'admin' && p == ENV['ADMIN_PASS']
end

app "Team Dashboard" do
  # Your dashboard content
end.run!
```
**Deploy**: Railway or Render free tier

---

### I want to: **Build a simple web app with users**
Use templates:
```bash
cp docs/deployment-templates/* .
bundle install
bundle exec rake db:migrate
```
**Deploy**: Render Starter ($7/mo)

---

### I want to: **Build production software**
Start with template, then add:
- Error tracking (Sentry)
- Email service (SendGrid)
- Background jobs (Sidekiq)
- File storage (S3)
- Monitoring (New Relic)

**Deploy**: Render Professional or Fly.io

---

## Summary: Choose Your Adventure

```
┌─────────────────────────────────────────────────────────────┐
│                    START HERE                                │
│         What are you building with StreamWeaver?            │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   Quick Form         Internal Tool       Web Application
   (Claude Code)      (Team of 5-10)      (Public users)
        │                   │                   │
        ▼                   ▼                   ▼
   No Database        SQLite/None         PostgreSQL
   No Auth           Basic HTTP Auth      Session Auth
   Local Only        Free Tier Deploy     Paid Deploy
   0 setup time      5 min setup          15-60 min setup
        │                   │                   │
        ▼                   ▼                   ▼
   run_once!         examples/            docs/deployment-
                     basic_auth_demo.rb   templates/
```

---

## Need Help Deciding?

Ask yourself:

1. **Who will use this?**
   - Just me → Prototype
   - My team → Internal Tool
   - Customers → Small App or Production

2. **How often?**
   - Once → Prototype
   - Weekly → Internal Tool
   - Daily → Small App or Production

3. **Does data need to persist?**
   - No → Prototype or Internal Tool
   - Yes → Small App or Production

4. **Do users need accounts?**
   - No → Prototype or Internal Tool
   - Yes → Small App or Production

5. **What's the budget?**
   - $0 → Prototype or Internal Tool
   - < $20/mo → Small App
   - $20+/mo → Production

---

## Resources

- [Deployment Guide](DEPLOYMENT.md) - Full technical details
- [Quick Start](QUICK_START_DEPLOYMENT.md) - Get deployed fast
- [Templates](deployment-templates/) - Ready-to-use configs
- [Examples](../examples/) - Working code samples

Happy building! 🚀
