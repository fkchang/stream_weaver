# frozen_string_literal: true
# S5: Watch — Side Effect on State Change
# React equivalent: useEffect with [username] dependency array
# StreamWeaver: watch(:key) { |val| } — fires exactly when that key changes

TAKEN = %w[alice bob admin root test ruby opal streamweaver].freeze

app "S5 — Watch: Username Availability" do
  watch(:username) do |name|
    n = name.to_s.strip.downcase
    state[:status] = if n.empty?
      nil
    elsif n.length < 3
      :too_short
    elsif TAKEN.include?(n)
      :taken
    else
      :available
    end
  end

  card do
    header3 "Choose a username"
    text_field :username, placeholder: "e.g. forrest42"

    case state[:status]
    when :too_short  then badge "Too short (min 3 chars)", color: :yellow
    when :taken      then badge "Already taken", color: :red
    when :available  then badge "Available!", color: :green
    end
  end

  div(style: "height:12px")

  card do
    header3 "How it works"
    md "**watch(:username)** fires every time `:username` changes — like `useEffect(() => { check(username) }, [username])` in React. No polling, no diffing. The watch block runs once per distinct value, sets `:status`, and the render reflects it immediately."
  end
end
