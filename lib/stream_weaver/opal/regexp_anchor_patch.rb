# frozen_string_literal: true
# backtick_javascript: true

# Fixes a real Opal bug: \A and \z anchors are only translated to JS's ^/$
# for a regex LITERAL known at compile time. A regex built at runtime --
# any interpolation (`/foo#{bar}baz/`), or Regexp.new(string) -- goes
# through Opal.regexp, which joins the source parts and passes them
# straight to `new RegExp(...)` with zero anchor translation. \A/\z aren't
# valid JS regex escapes, so they silently match nothing instead of
# anchoring -- no error, just a pattern that quietly never matches.
#
# Found via StreamWeaver::Org::Reader#callout_marker_match, which builds
# /\A\*(#{Regexp.union(VARIANT_EMOJI.keys)})...\*\z/ at runtime -- every
# emoji-marked callout silently misclassified as a card. Not specific to
# Regexp.union, emoji, or that one call site: reproduced with a plain
# string interpolated into an anchored pattern, no union/escape involved.
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
# \A -> ^ and \z/\Z -> $ are the correct translations as long as the
# pattern never reaches JS's `m` (multiline) flag -- confirmed by reading
# Opal.regexp's own source: it only ever sets JS's `s` (dotall) for Ruby's
# /m modifier, never JS's `m`, so ^/$ stay equivalent to \A/\z for every
# pattern this function is ever called with.
#
# Filed upstream: https://github.com/opal/opal (see stream_weaver-<id> for
# the tracking issue and full repro).
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
