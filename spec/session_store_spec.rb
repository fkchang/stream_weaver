# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe StreamWeaver::SessionStore do
  describe StreamWeaver::SessionStore::FileStore do
    subject(:store) { described_class.new }

    it "strips blank top-level values, as before scopes existed" do
      result = store.filter({ name: "", age: 5, note: nil })
      expect(result).to eq({ age: 5 })
    end

    it "leaves an unregistered nested hash opaque, blanks and all" do
      result = store.filter({ manual: { a: "", b: 1 } })
      expect(result).to eq({ manual: { a: "", b: 1 } })
    end

    it "recurses exactly one level into a registered scope's sub-hash, stripping its blanks" do
      state = { person_form: { name: "Alice", email: "", role: nil } }
      result = store.filter(state, scope_names: [:person_form])
      expect(result[:person_form]).to eq({ name: "Alice" })
    end

    it "does not recurse two levels deep into a registered scope" do
      state = { person_form: { address: { street: "", city: "Reno" } } }
      result = store.filter(state, scope_names: [:person_form])
      # one level only: the nested `address` hash itself is untouched
      expect(result[:person_form][:address]).to eq({ street: "", city: "Reno" })
    end

    it "always excludes _flash -- flash is one-shot, never the value persisted for the next request (FAC-P3.2b)" do
      state = { name: "Alice", _flash: { notice: "Saved!" } }
      result = store.filter(state)
      expect(result).to eq({ name: "Alice" })
    end
  end

  describe StreamWeaver::SessionStore::CookieStore do
    subject(:store) { described_class.new }

    it "recurses one level into a registered scope's sub-hash for cookie-budget stripping" do
      state = { person_form: { name: "Alice", email: "" } }
      result = store.filter(state, scope_names: [:person_form])
      expect(result[:person_form]).to eq({ name: "Alice" })
    end

    it "still applies hard-transient and app-transient filtering at the top level" do
      state = { code_content: "keep me out", visible: "x" }
      result = store.filter(state, app_transient: [:visible], scope_names: [])
      expect(result).to eq({})
    end

    it "always excludes _flash -- flash is one-shot, never the value persisted for the next request (FAC-P3.2b)" do
      state = { name: "Alice", _flash: { notice: "Saved!" } }
      result = store.filter(state)
      expect(result).to eq({ name: "Alice" })
    end
  end
end
