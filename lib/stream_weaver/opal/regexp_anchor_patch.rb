# frozen_string_literal: true
# backtick_javascript: true

# Fixes a real Opal bug: \A and \z anchors are only translated to JS's ^/$
# for a regex LITERAL known at compile time. An INTERPOLATED regex literal
# (`/foo#{bar}baz/`) goes through Opal.regexp, which joins the source parts
# and passes them straight to `new RegExp(...)` with zero anchor
# translation. \A/\z aren't valid JS regex escapes, so they silently match
# nothing instead of anchoring -- no error, just a pattern that quietly
# never matches.
#
# Regexp.new(string) is NOT the same bug and does not need this patch --
# it has its own, separate corelib-level translation
# (`regexp.replace('\A', '^').replace('\z', '$')`, no interpolation
# involved at all). That handling has its own narrower limitations (no /g,
# so only the first \A and first \z in a pattern get translated; \Z isn't
# handled) but is unaffected by, and doesn't fix, the Opal.regexp bug this
# file patches.
#
# Found via StreamWeaver::Org::Reader#callout_marker_match, which builds
# /\A\*(#{Regexp.union(VARIANT_EMOJI.keys)})...\*\z/ at runtime -- every
# emoji-marked callout silently misclassified as a card. Not specific to
# Regexp.union, emoji, or that one call site: reproduced with a plain
# string interpolated into an anchored pattern, no union/escape involved --
# it's specifically about interpolation, not about Regexp.new.
#
# Must load AFTER `opal` (which defines Opal.regexp) and BEFORE anything
# else in the build sequence -- every compiled file captures its OWN
# `$regexp = Opal.regexp` local alias at module-load time (a per-file
# Opal codegen optimization), so patching Opal.regexp from a script loaded
# after the whole bundle has already executed is too late: those aliases
# already point at the original, unpatched function. Compiling this as
# part of the same Opal::Builder sequence (see bin/build_extension),
# positioned right after `opal` and before any other `builder.build` call,
# is what makes every later file's alias capture pick up the fix instead.
#
# \A -> ^ is an exact translation as long as the pattern never reaches JS's
# `m` (multiline) flag -- confirmed by reading Opal.regexp's own source: it
# only ever sets JS's `s` (dotall) for Ruby's /m modifier, never JS's `m`,
# so ^ stays equivalent to \A for every pattern this function is ever
# called with. \z -> $ is the same story for \z specifically; \Z is treated
# the same way here for simplicity, though it isn't exact (\Z also matches
# just before a trailing newline, $ without /m doesn't) -- fine for this
# codebase's actual patterns, worth knowing if a future one relies on that
# distinction.
#
# Not yet filed upstream -- tracked as stream_weaver-mg6b.
if RUBY_ENGINE == "opal"
  %x{
    (function () {
      var original = Opal.regexp;
      Opal.regexp = function (parts, flags) {
        for (var i = 0; i < parts.length; i++) {
          if (typeof parts[i] === "string") {
            parts[i] = parts[i].replace(/\\A/g, "^").replace(/\\[zZ]/g, "$");
          }
        }
        return original(parts, flags);
      };
    })();
  }
end
