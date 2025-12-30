#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo of GitHub Flavored Markdown support
# Shows the full power of the md component using Kramdown

require_relative '../lib/stream_weaver'

app "GitHub Flavored Markdown Demo" do
  header1 "GitHub Flavored Markdown in StreamWeaver"

  text "The md component supports full GFM via Kramdown. The text component renders literally."

  header "1. Text Formatting"
  md <<~MD
    **Bold text** and *italic text* and ***bold italic***

    ~~Strikethrough~~ text

    `Inline code` for short snippets
  MD

  header "2. Links and Images"
  md <<~MD
    [Visit GitHub](https://github.com) - regular link

    [Link with title](https://example.com "Example Site") - hover for title

    ![Ruby Logo](https://www.ruby-lang.org/images/header-ruby-logo.png)
  MD

  header "3. Lists"
  md <<~MD
    **Unordered list:**
    - First item
    - Second item
      - Nested item
      - Another nested
    - Third item

    **Ordered list:**
    1. Step one
    2. Step two
    3. Step three

    **Task list:**
    - [x] Completed task
    - [ ] Incomplete task
    - [ ] Another todo
  MD

  header "4. Blockquotes"
  md <<~MD
    > This is a blockquote.
    > It can span multiple lines.
    >
    > > Nested blockquotes work too!
  MD

  header "5. Code Blocks"
  md <<~MD
    ```ruby
    def hello(name)
      puts "Hello, \#{name}!"
    end

    hello("World")
    ```

    ```javascript
    const greet = (name) => {
      console.log(`Hello, ${name}!`);
    };
    ```
  MD

  header "6. Tables"
  md <<~MD
    | Feature | Supported | Notes |
    |---------|:---------:|-------|
    | Bold | ✅ | `**text**` |
    | Italic | ✅ | `*text*` |
    | Links | ✅ | `[text](url)` |
    | Tables | ✅ | GFM style |
    | Lists | ✅ | Ordered & unordered |
  MD

  header "7. Horizontal Rules"
  md <<~MD
    Content above the rule.

    ---

    Content below the rule.
  MD

  header "8. Headers in Markdown"
  md <<~MD
    ## H2 Header
    ### H3 Header
    #### H4 Header
  MD

  header "9. Dynamic Content"
  text_field :name, placeholder: "Enter your name"

  if state[:name] && !state[:name].empty?
    md "Welcome, **#{state[:name]}**! You can use *markdown* in dynamic content too."
  end
end.run!
