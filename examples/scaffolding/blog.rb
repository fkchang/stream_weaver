#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

module PostStore
  @posts = [
    { id: '1', title: 'Hello World', body: 'First post',   status: 'published' },
    { id: '2', title: 'Second Post', body: 'Another post', status: 'draft' }
  ]

  def self.all;      @posts; end
  def self.find(id); @posts.find { |p| p[:id] == id }; end

  def self.create(attrs)
    id = ((@posts.map { |p| p[:id].to_i }.max || 0) + 1).to_s
    @posts << { id: id, **attrs }
    id
  end

  def self.update(id, attrs)
    post = find(id) or return false
    post.merge!(attrs)
    true
  end

  def self.destroy(id)
    @posts.reject! { |p| p[:id] == id }
    true
  end
end

app 'Blog' do
  resource :post, store: PostStore do
    field :title,  :string
    field :body,   :text
    field :status, :enum, values: %w[draft published]
  end

  navbar do
    nav_item 'Home',  href: '/',       active: state[:_sw_action] == :home
    nav_item 'Posts', href: '/posts',  active: state[:_sw_resource] == :post
  end

  page :home, '/' do
    header1 'My Blog'
    text 'Welcome! Check out the posts.'
  end
end.run!
