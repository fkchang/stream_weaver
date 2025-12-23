# Quick Start: Deploying Your StreamWeaver App

This guide will get you from zero to deployed in under 15 minutes.

## Choose Your Path

### Path 1: Simple App (No Database) - 5 minutes

**Best for**: Quick prototypes, Claude Code interactions, internal tools

1. **Create your app**:
```ruby
# my_app.rb
require 'stream_weaver'

app "My App" do
  header "Hello World"
  text_field :name
  button "Submit" { |state| puts state[:name] }
end.run!
```

2. **Create Gemfile**:
```ruby
source 'https://rubygems.org'
gem 'stream_weaver'
```

3. **Deploy to Render** (easiest):
   - Push to GitHub
   - Go to [render.com](https://render.com)
   - Click "New" → "Web Service"
   - Connect your repo
   - Build command: `bundle install`
   - Start command: `ruby my_app.rb`
   - Click "Create Web Service"
   - Done! 🎉

---

### Path 2: App with Database - 10 minutes

**Best for**: Apps that need to save data

1. **Copy production template**:
```bash
cp docs/deployment-templates/Gemfile.template Gemfile
cp docs/deployment-templates/app.rb.template app.rb
cp docs/deployment-templates/Rakefile.template Rakefile
cp docs/deployment-templates/.env.example .env
```

2. **Set environment variables** (edit .env):
```bash
SESSION_SECRET=$(openssl rand -hex 64)
```

3. **Create user migration**:
```bash
bundle install
bundle exec rake db:create_migration NAME=create_users
```

Edit the migration file:
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

4. **Run migration**:
```bash
bundle exec rake db:migrate
```

5. **Deploy to Render**:
   - Copy `docs/deployment-templates/render.yaml` to your repo root
   - Push to GitHub
   - Go to [render.com](https://render.com)
   - Click "New" → "Blueprint Instance"
   - Connect your repo
   - Select `render.yaml`
   - Click "Apply"
   - Done! 🎉

---

### Path 3: Quick Deploy to Railway - 3 minutes

**Best for**: Fastest prototyping

1. **Install Railway CLI**:
```bash
npm i -g @railway/cli
railway login
```

2. **Create your app** (simple version):
```ruby
# app.rb
require 'stream_weaver'
app "My App" do
  header "Hello Railway!"
end.run!
```

3. **Deploy**:
```bash
railway init
railway up
railway open
```

Done! Your app is live! 🚀

---

## Platform Comparison

| Platform | Setup Time | Free Tier | Best For |
|----------|-----------|-----------|----------|
| **Render** | 5 min | Yes | Production apps, easiest Heroku replacement |
| **Railway** | 3 min | $5 credit | Prototyping, fastest deployment |
| **Fly.io** | 10 min | Yes | Global apps, advanced users |

---

## Next Steps

### Add Authentication

Already built into the production template! Just uncomment the auth routes and you get:
- User registration
- Login/logout
- Password hashing with BCrypt
- Protected routes

### Add a Database Model

```ruby
# Create migration
bundle exec rake db:create_migration NAME=create_posts

# In the migration file:
class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :content
      t.references :user, foreign_key: true
      t.timestamps
    end
  end
end

# Run migration
bundle exec rake db:migrate

# Add model
class Post < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
end
```

### Use in Your App

```ruby
app "My Blog" do
  # Create post
  text_field :title
  text_area :content
  button "Publish" do |state|
    Post.create(
      title: state[:title],
      content: state[:content],
      user: current_user
    )
  end
  
  # Display posts
  Post.all.each do |post|
    card do
      header3 post.title
      text post.content
    end
  end
end
```

---

## Environment Variables Checklist

Set these on your deployment platform:

### Required
- [x] `SESSION_SECRET` - Generate with `openssl rand -hex 64`
- [x] `RACK_ENV=production`

### Optional
- [ ] `DATABASE_URL` - Auto-set by platform when you add PostgreSQL
- [ ] `FORCE_SSL=true` - Force HTTPS
- [ ] `PORT` - Auto-set by platform

---

## Troubleshooting

**"Bundle install failed"**
- Check that Gemfile is valid Ruby syntax
- Ensure all gems are available on rubygems.org

**"SESSION_SECRET required"**
- Generate: `openssl rand -hex 64`
- Set on platform dashboard or in .env file

**"Database connection failed"**
- Ensure PostgreSQL database is provisioned
- Check that DATABASE_URL is set
- Verify migrations have run: `rake db:migrate`

**"App won't start"**
- Check logs in platform dashboard
- Verify start command: `bundle exec ruby app.rb`
- Ensure app listens on `ENV['PORT']`

---

## Support

- [StreamWeaver Documentation](../DEPLOYMENT.md)
- [Example Apps](../../examples/)
- [Deployment Templates](../deployment-templates/)

Happy deploying! 🚀
