#!/usr/bin/env ruby
# frozen_string_literal: true

# Teachables Browser - Visual triage for teachable moments
#
# Run: ruby teachables_browser.rb
# Opens: http://localhost:8080

require_relative '../lib/stream_weaver'
require 'json'
require 'yaml'
require 'fileutils'

# Configuration
CULTIV_OS = File.expand_path('~/cultiv-os')
PENDING_DIR = File.join(CULTIV_OS, 'captures', 'pending')
APPROVED_DIR = File.join(CULTIV_OS, 'captures', 'approved')
REJECTED_DIR = File.join(CULTIV_OS, 'captures', 'rejected')
DEFERRED_DIR = File.join(CULTIV_OS, 'captures', 'deferred')

# Ensure directories exist
[APPROVED_DIR, REJECTED_DIR, DEFERRED_DIR].each { |d| FileUtils.mkdir_p(d) }

# Helper to load all pending teachables
def load_pending_teachables
  candidates = []
  Dir.glob(File.join(PENDING_DIR, '*.json')).each do |f|
    data = JSON.parse(File.read(f)) rescue {}
    (data['candidates'] || []).each do |c|
      c['_source_file'] = f
      candidates << c
    end
  end
  candidates
end

# Helper to move teachable to a directory
def move_teachable(candidate, to_dir, status, extra = {})
  source_file = candidate['_source_file']
  return unless source_file && File.exist?(source_file)

  # Remove from pending JSON
  data = JSON.parse(File.read(source_file))
  data['candidates'].reject! { |c| c['id'] == candidate['id'] }
  File.write(source_file, JSON.pretty_generate(data))

  # Save to target directory
  candidate.delete('_source_file')
  candidate['status'] = status
  candidate['#{status}_at'] = Time.now.iso8601
  candidate.merge!(extra)

  slug = candidate['id'].gsub(/[^a-zA-Z0-9-]/, '-')[0..50]
  filepath = File.join(to_dir, "#{Date.today}-#{slug}.yaml")
  File.write(filepath, candidate.to_yaml)
  filepath
end

# Count items in directory
def count_items(dir)
  Dir.glob(File.join(dir, '*.yaml')).length
end

# Audience badge colors
def audience_style(aud)
  case aud
  when 'blog' then :strong
  when 'team' then :maybe
  else :skip
  end
end

App = app "Teachables Browser" do
  header "Teachables Browser"

  # Load data
  all_teachables = load_pending_teachables

  # Stats row
  columns widths: ['25%', '25%', '25%', '25%'] do
    column do
      card do
        header4 "Pending"
        text "#{all_teachables.length}"
      end
    end
    column do
      card do
        header4 "Approved"
        text "#{count_items(APPROVED_DIR)}"
      end
    end
    column do
      card do
        header4 "Rejected"
        text "#{count_items(REJECTED_DIR)}"
      end
    end
    column do
      card do
        header4 "Deferred"
        text "#{count_items(DEFERRED_DIR)}"
      end
    end
  end

  # Filters
  header3 "Filters"

  columns widths: ['33%', '33%', '33%'] do
    column do
      text "Audience:"
      tag_buttons :audience_filter, ["all", "blog", "team", "self"]
    end
    column do
      text "Min External Interest:"
      select :min_external, ["0", "5", "6", "7", "8", "9"], default: "0"
    end
    column do
      text "Sort by:"
      select :sort_by, ["external_interest", "novelty", "reusability"], default: "external_interest"
    end
  end

  # Apply filters
  state[:audience_filter] ||= "all"
  state[:min_external] ||= "0"
  state[:sort_by] ||= "external_interest"

  filtered = all_teachables.dup

  unless state[:audience_filter] == "all"
    filtered = filtered.select { |t| t['audience'] == state[:audience_filter] }
  end

  min_ext = state[:min_external].to_i
  if min_ext > 0
    filtered = filtered.select { |t| (t.dig('scores', 'external_interest') || 0) >= min_ext }
  end

  # Sort
  sort_field = state[:sort_by]
  filtered = filtered.sort_by { |t| -(t.dig('scores', sort_field) || 0) }

  # Results header
  header3 "#{filtered.length} Teachables"

  if filtered.empty?
    text "No teachables match your filters."
  else
    # Display each teachable
    filtered.each_with_index do |t, idx|
      card do
        # Header row with scores and audience
        columns widths: ['70%', '30%'] do
          column do
            header4 t['summary'][0..80] + (t['summary'].length > 80 ? '...' : '')
          end
          column do
            status_badge audience_style(t['audience']), t['audience']
          end
        end

        # Metadata row
        text "Project: #{t['project']} | Session: #{t['session_id'][0..20]}..."

        # Scores
        scores = t['scores'] || {}
        md "**Scores:** Novelty: #{scores['novelty']} | Struggle: #{scores['struggle_to_solution']} | Reuse: #{scores['reusability']} | External: #{scores['external_interest']}"

        # Themes
        themes = (t['themes'] || [])[0..5].join(', ')
        text "Themes: #{themes}" unless themes.empty?

        # Patterns
        known = (t.dig('patterns_detected', 'known') || []).join(', ')
        coined = (t.dig('patterns_detected', 'new_coined') || []).join(', ')
        text "Known patterns: #{known}" unless known.empty?
        text "New coined: #{coined}" unless coined.empty?

        # Context (collapsible)
        collapsible "Context" do
          md t['context'] || "(no context)"
        end

        # Action buttons
        columns widths: ['25%', '25%', '25%', '25%'] do
          column do
            button "Approve", style: :primary do |state|
              filepath = move_teachable(t, APPROVED_DIR, 'approved')
              state[:last_action] = "Approved: #{t['id']} -> #{filepath}"
            end
          end
          column do
            button "Reject", style: :secondary do |state|
              filepath = move_teachable(t, REJECTED_DIR, 'rejected')
              state[:last_action] = "Rejected: #{t['id']}"
            end
          end
          column do
            button "Defer", style: :secondary do |state|
              filepath = move_teachable(t, DEFERRED_DIR, 'deferred')
              state[:last_action] = "Deferred: #{t['id']}"
            end
          end
          column do
            button "Promote to Blog" do |state|
              # Create blog draft
              title = t['summary'].split(/[.!?]/)[0].strip
              slug = title.downcase.gsub(/[^a-z0-9]+/, '-')[0..50]

              content = <<~MD
                ---
                title: "#{title}"
                date: #{Date.today}
                status: draft
                source_session: #{t['session_id']}
                themes: #{(t['themes'] || []).join(', ')}
                ---

                # #{title}

                ## Summary

                #{t['summary']}

                ## Context

                #{t['context']}

                ## Key Insights

                TODO: Extract key insights and expand

                ---
                *Generated from teachable: #{t['id']}*
              MD

              blog_dir = File.join(CULTIV_OS, 'blog-drafts')
              FileUtils.mkdir_p(blog_dir)
              filepath = File.join(blog_dir, "#{Date.today}-#{slug}.md")
              File.write(filepath, content)

              # Also approve it
              move_teachable(t, APPROVED_DIR, 'approved', { promoted_to: 'blog', blog_draft: filepath })
              state[:last_action] = "Promoted to blog: #{filepath}"
            end
          end
        end
      end
    end
  end

  # Show last action
  if state[:last_action]
    header3 "Last Action"
    text state[:last_action]
  end
end

App.run! if __FILE__ == $0
