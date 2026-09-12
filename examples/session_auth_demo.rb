#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Session-Based Authentication
#
# This example demonstrates a complete authentication system with:
# - User registration
# - Login/logout
# - Password hashing with BCrypt
# - Protected routes
# - Session management
#
# Setup:
#   gem install stream_weaver sinatra-activerecord sqlite3 bcrypt rake
#   
# Create migration:
#   bundle exec rake db:create_migration NAME=create_users
#   
# Add to migration:
#   create_table :users do |t|
#     t.string :username, null: false
#     t.string :email, null: false
#     t.string :password_hash, null: false
#     t.timestamps
#   end
#   add_index :users, :username, unique: true
#   add_index :users, :email, unique: true
#   
# Run migration:
#   bundle exec rake db:migrate
#
# Run:
#   ruby examples/session_auth_demo.rb

require_relative '../lib/stream_weaver'
require 'sinatra/activerecord'
require 'bcrypt'

# Database configuration
configure :development do
  set :database, {adapter: 'sqlite3', database: 'db/auth_demo_dev.db'}
end

configure :production do
  set :database, ENV['DATABASE_URL'] || {adapter: 'sqlite3', database: 'db/auth_demo_prod.db'}
end

# User model with password hashing
class User < ActiveRecord::Base
  include BCrypt
  
  validates :username, presence: true, uniqueness: true, length: { minimum: 3 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  
  def password
    @password ||= Password.new(password_hash) if password_hash
  end
  
  def password=(new_password)
    @password = new_password
    self.password_hash = Password.create(new_password) if new_password.present?
  end
  
  def authenticate(password)
    self.password == password
  end
  
  def self.authenticate(username_or_email, password)
    user = find_by(username: username_or_email) || find_by(email: username_or_email)
    user if user&.authenticate(password)
  end
  
  private
  
  def password_required?
    password_hash.blank? || @password.present?
  end
end

# Create table if it doesn't exist (for quick demo purposes)
unless ActiveRecord::Base.connection.table_exists?(:users)
  ActiveRecord::Base.connection.create_table :users do |t|
    t.string :username, null: false
    t.string :email, null: false
    t.string :password_hash, null: false
    t.timestamps
  end
  ActiveRecord::Base.connection.add_index :users, :username, unique: true
  ActiveRecord::Base.connection.add_index :users, :email, unique: true
  
  # Create demo user
  User.create!(
    username: 'demo',
    email: 'demo@example.com',
    password: 'password123'
  )
  
  puts "\n✅ Demo user created:"
  puts "   Username: demo"
  puts "   Password: password123\n\n"
end

# Authentication helpers
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

# Routes
get '/login' do
  redirect '/' if logged_in?
  LoginApp.generate.call(env)
end

post '/login' do
  user = User.authenticate(params[:username], params[:password])
  if user
    session[:user_id] = user.id
    session[:flash] = { type: :success, message: "Welcome back, #{user.username}!" }
    redirect '/'
  else
    session[:flash] = { type: :error, message: "Invalid username or password" }
    redirect '/login'
  end
end

get '/register' do
  redirect '/' if logged_in?
  RegisterApp.generate.call(env)
end

post '/register' do
  user = User.new(
    username: params[:username],
    email: params[:email],
    password: params[:password]
  )
  
  if user.save
    session[:user_id] = user.id
    session[:flash] = { type: :success, message: "Account created! Welcome, #{user.username}!" }
    redirect '/'
  else
    session[:flash] = { type: :error, message: user.errors.full_messages.join(', ') }
    redirect '/register'
  end
end

post '/logout' do
  session.clear
  session[:flash] = { type: :info, message: "You've been logged out" }
  redirect '/login'
end

get '/' do
  require_login
  DashboardApp.generate.call(env)
end

# Login App
LoginApp = app "🔐 Login" do
  header1 "Login"
  
  # Show flash messages
  if session[:flash]
    flash = session.delete(:flash)
    alert(variant: flash[:type]) do
      text flash[:message]
    end
  end
  
  card do
    form :login do
      text_field :username, placeholder: "Username or Email"
      text_field :password, placeholder: "Password"
      
      hstack justify: :between do
        submit "Login"
        cancel "Register"
      end
    end
  end
  
  # Handle cancel button to redirect to register
  if state[:login] == false
    redirect '/register'
  end
  
  # Submit form to /login
  if state[:login] && state[:login].is_a?(Hash)
    # This would normally be handled by the POST route
    # but we're demonstrating the pattern
  end
end

# Registration App
RegisterApp = app "📝 Register" do
  header1 "Create Account"
  
  # Show flash messages
  if session[:flash]
    flash = session.delete(:flash)
    alert(variant: flash[:type]) do
      text flash[:message]
    end
  end
  
  card do
    form :register do
      text_field :username, placeholder: "Username (min 3 characters)"
      text_field :email, placeholder: "Email"
      text_field :password, placeholder: "Password (min 6 characters)"
      
      hstack justify: :between do
        submit "Create Account"
        cancel "Back to Login"
      end
    end
  end
  
  # Handle cancel button to redirect to login
  if state[:register] == false
    redirect '/login'
  end
end

# Dashboard App (Protected)
DashboardApp = app "👤 Dashboard", theme: :dashboard do
  # Show flash messages
  if session[:flash]
    flash = session.delete(:flash)
    alert(variant: flash[:type]) do
      text flash[:message]
    end
  end
  
  header1 "Dashboard"
  
  card do
    header3 "👋 Welcome, #{current_user.username}!"
    vstack spacing: :sm do
      text "Email: #{current_user.email}"
      text "Member since: #{current_user.created_at.strftime('%B %d, %Y')}"
      text "User ID: ##{current_user.id}"
    end
  end
  
  card do
    header3 "Sample Protected Content"
    text "This content is only visible to authenticated users."
    
    text_field :note, placeholder: "Write a note..."
    
    button "Save Note" do |state|
      if state[:note] && !state[:note].strip.empty?
        state[:saved_notes] ||= []
        state[:saved_notes] << {
          text: state[:note],
          time: Time.now.strftime('%I:%M %p')
        }
        state[:note] = ""
      end
    end
    
    if state[:saved_notes] && !state[:saved_notes].empty?
      vstack spacing: :sm do
        state[:saved_notes].each do |note|
          text "📝 #{note[:time]}: #{note[:text]}"
        end
      end
    end
  end
  
  card do
    header3 "Account Actions"
    
    form :logout do
      submit "Logout", style: :secondary
    end
    
    if state[:logout]
      redirect '/logout'
    end
  end
  
  alert(variant: :info) do
    text "🔒 Your session is secure. All passwords are hashed with BCrypt."
  end
end

# Start the app
if __FILE__ == $0
  puts "\n" + "="*60
  puts "  Session Authentication Demo"
  puts "="*60
  puts "\n📝 Features:"
  puts "  ✓ User registration with validation"
  puts "  ✓ Secure login/logout"
  puts "  ✓ Password hashing with BCrypt"
  puts "  ✓ Protected routes"
  puts "  ✓ Session management"
  puts "\n🔐 Demo credentials:"
  puts "  Username: demo"
  puts "  Password: password123"
  puts "\n🌐 Starting server..."
  puts ""
  
  DashboardApp.run!
end
