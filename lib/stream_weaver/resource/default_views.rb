# frozen_string_literal: true

module StreamWeaver
  module Resource
    module DefaultViews
      def self.index(defn, app, items)
        items ||= []
        app.instance_exec(defn, items) do |d, its|
          header1 d.plural.capitalize

          button("New #{d.singular.capitalize}", style: :primary) do |s|
            s[:_sw_action]   = :new
            s[:_sw_resource] = d.name
          end

          unless d.fields.empty?
            table(its) do
              d.fields.each do |field|
                column field.name, header: field.name.to_s.tr('_', ' ').capitalize
              end
            end
          end

          its.each do |item|
            hstack do
              button("View", id: item[:id]) do |s|
                s[:_sw_action]   = :show
                s[:_sw_resource] = d.name
                s[:_sw_id]       = item[:id]
              end
              button("Edit", id: "edit_#{item[:id]}") do |s|
                s[:_sw_action]   = :edit
                s[:_sw_resource] = d.name
                s[:_sw_id]       = item[:id]
              end
              button("Delete", id: "del_#{item[:id]}", style: :danger) do |s|
                s[:_sw_confirm_delete] = item[:id]
                s[:_sw_resource]       = d.name
              end
            end
          end
        end

        render_destroy_confirm(defn, app)
      end

      def self.show(defn, app, item)
        return if item.nil?

        app.instance_exec(defn, item) do |d, it|
          card do
            first_field = d.fields.first
            first_value = first_field ? it[first_field.name] : it[:id]
            header3 (first_value || it[:id]).to_s

            d.fields.each do |field|
              label = field.name.to_s.tr('_', ' ').capitalize
              text "#{label}: #{it[field.name]}"
            end

            hstack do
              button("Edit") do |s|
                s[:_sw_action]   = :edit
                s[:_sw_resource] = d.name
                s[:_sw_id]       = it[:id]
              end
              button("Delete", style: :danger) do |s|
                s[:_sw_confirm_delete] = it[:id]
                s[:_sw_resource]       = d.name
              end
            end
          end
        end

        render_destroy_confirm(defn, app)
      end

      def self.new(defn, app, _data)
        app.instance_exec(defn) do |d|
          header1 "New #{d.singular.capitalize}"

          form :"#{d.singular}_form" do
            d.fields.each do |field|
              label = field.name.to_s.tr('_', ' ').capitalize
              case field.type
              when :string
                text_field field.name, label: label, submit: false
              when :text
                text_area field.name, label: label, rows: 4, submit: false
              when :enum
                select field.name, field.opts[:values] || [], submit: false
              when :boolean
                checkbox field.name, label, submit: false
              when :integer, :number
                text_field field.name, submit: false
              when :date
                text_field field.name, submit: false
              else
                text_field field.name, submit: false
              end
            end

            submit("Create") do |form_values|
              id = d.store.create(form_values.transform_keys(&:to_sym))
              app.state[:_sw_action]   = :show
              app.state[:_sw_resource] = d.name
              app.state[:_sw_id]       = id
            end
          end
        end
      end

      def self.edit(defn, app, item)
        return if item.nil?

        app.instance_exec(defn, item) do |d, it|
          first_field = d.fields.first
          title_value = first_field ? it[first_field.name] : it[:id]
          header1 "Edit #{title_value || it[:id]}"

          seeded_key = :"#{d.singular}_form_seeded_for"
          if state[seeded_key] != it[:id]
            d.fields.each do |field|
              state[:"#{d.singular}_form"] ||= {}
              state[:"#{d.singular}_form"][field.name] = it[field.name]
            end
            state[seeded_key] = it[:id]
          end

          form :"#{d.singular}_form" do
            d.fields.each do |field|
              label = field.name.to_s.tr('_', ' ').capitalize
              case field.type
              when :string
                text_field field.name, label: label, submit: false
              when :text
                text_area field.name, label: label, rows: 4, submit: false
              when :enum
                select field.name, field.opts[:values] || [], submit: false
              when :boolean
                checkbox field.name, label, submit: false
              when :integer, :number
                text_field field.name, submit: false
              when :date
                text_field field.name, submit: false
              else
                text_field field.name, submit: false
              end
            end

            submit("Save") do |form_values|
              d.store.update(app.state[:_sw_id], form_values.transform_keys(&:to_sym))
              app.state[:_sw_action] = :show
            end
          end
        end
      end

      def self.render_destroy_confirm(defn, app)
        id = app.state[:_sw_confirm_delete]
        return unless id

        app.instance_exec(defn, id) do |d, confirm_id|
          alert(variant: :warning) do
            text "Delete this #{d.singular}? This cannot be undone."
            hstack do
              button("Confirm Delete", style: :danger) do |s|
                d.store.destroy(confirm_id)
                s[:_sw_confirm_delete] = nil
                s[:_sw_action]         = :index
                s[:_sw_resource]       = d.name
                s[:_sw_id]             = nil
              end
              button("Cancel") do |s|
                s[:_sw_confirm_delete] = nil
              end
            end
          end
        end
      end
      private_class_method :render_destroy_confirm
    end
  end
end
