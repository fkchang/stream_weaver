# frozen_string_literal: true

require 'cgi'

module StreamWeaver
  module Resource
    module DefaultViews
      include StateKeys

      # Proc for rendering a single form field — called via instance_exec so
      # DSL methods (text_field, select, etc.) resolve against the App instance.
      FIELD_INPUT = proc do |field|
        label = field.name.to_s.tr('_', ' ').capitalize
        case field.type
        when :string           then text_field field.name, label: label, submit: false
        when :text             then text_area  field.name, label: label, rows: 4, submit: false
        when :enum             then select     field.name, field.opts[:values] || [], submit: false
        when :boolean          then checkbox   field.name, label, submit: false
        when :integer, :number then text_field field.name, submit: false
        when :date             then text_field field.name, submit: false
        else                        text_field field.name, submit: false
        end
      end
      private_constant :FIELD_INPUT

      def self.index(defn, app, items)
        items ||= []
        app.instance_exec do
          header1 defn.plural.capitalize

          button("New #{defn.singular.capitalize}", style: :primary) do |s|
            s[ACTION]   = :new
            s[RESOURCE] = defn.name
          end

          unless items.empty?
            table(items, markdown: true) do
              defn.fields.each do |f|
                column f.name, header: f.name.to_s.tr('_', ' ').capitalize do |item|
                  CGI.escape_html(item[f.name].to_s)
                end
              end
              column :_sw_actions, header: '' do |item|
                eid = CGI.escape(item[:id].to_s)
                s   = defn.singular
                "[View](/#{s}/#{eid}) [Edit](/#{s}/#{eid}/edit) [Delete](/#{s}/#{eid}/delete)"
              end
            end
          end
        end
      end

      def self.show(defn, app, item)
        return if item.nil?

        app.instance_exec do
          card do
            first_field = defn.fields.first
            first_value = first_field ? item[first_field.name] : item[:id]
            header3 (first_value || item[:id]).to_s

            defn.fields.each do |field|
              label = field.name.to_s.tr('_', ' ').capitalize
              text "#{label}: #{item[field.name]}"
            end

            hstack do
              button("Edit") do |s|
                s[ACTION]   = :edit
                s[RESOURCE] = defn.name
                s[ID]       = item[:id]
              end
              button("Delete", style: :danger) do |s|
                s[ACTION]   = :destroy_confirm
                s[RESOURCE] = defn.name
                # ID already set
              end
            end
          end
        end
      end

      def self.new(defn, app, _data)
        app.instance_exec do
          header1 "New #{defn.singular.capitalize}"

          form :"#{defn.singular}_form" do
            defn.fields.each { |f| instance_exec(f, &FIELD_INPUT) }

            submit("Create") do |form_values|
              id = defn.store.create(form_values.transform_keys(&:to_sym))
              app.state[ACTION]   = :show
              app.state[RESOURCE] = defn.name
              app.state[ID]       = id
            end
          end
        end
      end

      def self.edit(defn, app, item)
        return if item.nil?

        app.instance_exec do
          first_field = defn.fields.first
          title_value = first_field ? item[first_field.name] : item[:id]
          header1 "Edit #{title_value || item[:id]}"

          seeded_key = :"#{defn.singular}_form_seeded_for"
          if state[seeded_key] != item[:id]
            defn.fields.each do |field|
              state[:"#{defn.singular}_form"] ||= {}
              state[:"#{defn.singular}_form"][field.name] = item[field.name]
            end
            state[seeded_key] = item[:id]
          end

          form :"#{defn.singular}_form" do
            defn.fields.each { |f| instance_exec(f, &FIELD_INPUT) }

            submit("Save") do |form_values|
              defn.store.update(app.state[ID], form_values.transform_keys(&:to_sym))
              app.state[ACTION] = :show
            end
          end
        end
      end

      def self.destroy_confirm(defn, app, item)
        return if item.nil?

        app.instance_exec do
          first_field = defn.fields.first
          title_value = first_field ? item[first_field.name] : item[:id]

          alert(variant: :warning) do
            text "Delete \"#{title_value}\"? This cannot be undone."
            hstack do
              button("Confirm Delete", style: :danger) do |s|
                defn.store.destroy(item[:id])
                s[ACTION]   = :index
                s[RESOURCE] = defn.name
                s[ID]       = nil
              end
              button("Cancel") do |s|
                s[ACTION]   = :index
                s[RESOURCE] = defn.name
              end
            end
          end
        end
      end
    end
  end
end
