# frozen_string_literal: true

module StreamWeaver
  module Resource
    # Shared field-type-to-widget rendering table (form-for.md §3). Extracted
    # from DefaultViews so both DefaultViews and `form_for` render fields the
    # same way -- one type-to-widget mapping, not two.
    module FieldInput
      # Proc for rendering a single form field -- called via instance_exec so
      # DSL methods (text_field, select, etc.) resolve against the App instance.
      RENDER = proc do |field|
        label = field.name.to_s.tr('_', ' ').capitalize
        case field.type
        when :string           then text_field field.name, label: label, submit: false
        when :text             then text_area  field.name, label: label, rows: 4, submit: false
        when :enum             then select     field.name, field.opts[:values] || [], submit: false
        when :boolean           then checkbox   field.name, label, submit: false
        when :integer, :number then text_field field.name, submit: false
        when :date              then date_field  field.name, label: label, submit: false
        else                         text_field field.name, submit: false
        end
      end
    end
  end
end
