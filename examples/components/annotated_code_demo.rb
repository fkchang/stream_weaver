# Usage: streamweaver canvas-push <session> < examples/components/annotated_code_demo.rb
# Or:    streamweaver panel annotated-code-demo && streamweaver canvas-push annotated-code-demo < examples/components/annotated_code_demo.rb

header2 "AnnotatedCode — Line-Pinned Annotations"
md "Code block with a side panel of annotation bubbles aligned to specific lines. Annotated lines get a left-border highlight."

annotated_code(language: "ruby", annotations: [
  { line: 2, note: "keyword_init: true means Annotation.new(line:, note:) works" },
  { line: 5, note: "Memoized — built once on first access, reused on every render call" },
  { line: 6, note: "Set membership test is O(1); Array#include? would be O(n) per line" }
]) do
  <<~'RUBY'
    class AnnotatedCode < Base
      Annotation = Struct.new(:line, :note, keyword_init: true)

      def annotated_lines
        @annotated_lines ||= Set.new(annotations.map(&:line))
      end
    end
  RUBY
end

header3 "Multiple annotations close together"
md "Annotations at adjacent lines stack without overlap — each gets its own `min-height` slot."

annotated_code(language: "javascript", annotations: [
  { line: 1, note: "Arrow function — implicit return when body is an expression" },
  { line: 2, note: "Destructuring with default: name falls back to 'World'" },
  { line: 3, note: "Template literal — backtick syntax, \#{} interpolation" }
]) do
  <<~'JS'
    const greet = (opts) => {
      const { name = 'World' } = opts;
      return `Hello, ${name}!`;
    };
  JS
end

header3 "No language specified"
md "Falls back to `language-none` (no Prism highlighting) — useful for plain text or pseudocode."

annotated_code(annotations: [
  { line: 1, note: "Start: O(1) stack push" },
  { line: 3, note: "Each node visited once — O(n) total" },
  { line: 5, note: "Stack empty → all reachable nodes visited" }
]) do
  <<~'TEXT'
    push start node onto stack
    while stack is not empty:
      node = stack.pop
      for each unvisited neighbor:
        push neighbor
  TEXT
end
