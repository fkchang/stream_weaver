# frozen_string_literal: true

# Consulting Deck Components — reusable composition patterns for the
# consulting-deck genre (kickoff/proposal/status presentations).
# ------------------------------------------------------------------
# Extracted (Batch B) from the 20-slide kickoff deck after measuring which
# inline shapes repeated >= 3 times with fragile style duplication. Every
# helper expands to existing low-level StreamWeaver DSL primitives
# (div, text, card, header4, md) — no framework changes are involved or
# required.
#
# Usage from a deck DSL fragment that gets instance_eval'd against an App:
#
#   unless respond_to?(:labeled_card) # idempotent under canvas-push concatenation
#     require_relative 'consulting_deck_components'
#     extend ConsultingDeckComponents
#   end
#
# Helpers are deck-genre generic: they contain layout/typography only and
# take all wording as arguments, so they carry no engagement-specific
# content.
module ConsultingDeckComponents
  # Accent palette token shared by the helpers below. Reads the active
  # theme's --sw-accent with a fixed fallback so exported HTML still renders
  # sensibly without the stylesheet variables.
  ACCENT = "var(--sw-accent, #0f9d58)".freeze
  MUTED_TEXT = "var(--sw-text-dim, #666)".freeze
  ELEVATED_SURFACE = "var(--sw-surface-elevated, #f4f7f6)".freeze
  BORDER = "var(--sw-border, #e0e0e0)".freeze

  # Agenda row: big accent number + heading + one-line description.
  def agenda_item(number, heading, description)
    div style: "display: flex; gap: 1.25rem; align-items: baseline; padding: 0.5rem 0; border-bottom: 1px solid #{BORDER};" do
      text number, style: "font-size: 1.4rem; font-weight: 800; color: #{ACCENT}; min-width: 2.75rem; margin: 0;"
      div do
        text heading, style: "font-weight: 700; margin: 0 0 0.15rem 0; font-size: 1.05rem;"
        text description, tone: :muted, style: "margin: 0; font-size: 0.85rem;"
      end
    end
  end

  # Key/value row inside an "at a glance" sidebar card.
  def glance_row(label, value)
    div style: "margin-bottom: 0.35rem;" do
      text label, style: "font-size: 0.62rem; font-weight: 700; letter-spacing: 0.07em; text-transform: uppercase; color: #{ACCENT}; margin: 0;"
      text value, style: "font-size: 0.76rem; line-height: 1.3; margin: 0.05rem 0 0 0;"
    end
  end

  # Compact card for a criterion/requirement: heading + one-or-two-line body.
  def criterion_card(heading, body)
    card style: "padding: 0.4rem 0.7rem; font-size: 0.72rem; line-height: 1.26;" do
      header4 heading, style: "margin: 0 0 0.15rem 0; font-size: 0.88rem;"
      text body, style: "margin: 0;"
    end
  end

  # Card carrying a status label, in two placements:
  #
  #   label_style: :corner (default) — the tag rides the card's built-in
  #     corner label slot and a heading + body sit inside. Used for
  #     open-item/decision cards ("Decision today", "Phase-1 exit", ...).
  #
  #     labeled_card "Decision today", "Body copy...", heading: "The decision"
  #
  #   label_style: :inline — a small-caps accent label line inside the card
  #     above the body, with no heading. Used for scenario/option cards.
  #
  #     labeled_card "Original plan", "Body copy...", label_style: :inline
  def labeled_card(tag, body, heading: nil, label_style: :corner)
    case label_style
    when :inline
      card style: "padding: 0.5rem 0.85rem; margin-bottom: 0.4rem; font-size: 0.78rem; line-height: 1.3;" do
        text tag, style: "font-size: 0.64rem; font-weight: 700; letter-spacing: 0.07em; text-transform: uppercase; color: #{ACCENT}; margin: 0 0 0.15rem 0;"
        text body, style: "margin: 0;"
      end
    else
      card label: tag, style: "padding: 0.5rem 0.8rem; font-size: 0.78rem; line-height: 1.32;" do
        header4 heading, style: "margin: 0 0 0.15rem 0; font-size: 0.9rem;"
        text body, style: "margin: 0;"
      end
    end
  end

  # One column of a detailed phase timeline: a compact accent-left block
  # (label + title + meta line) plus a small markdown bullet list.
  def phase_detail(label, title, meta, bullets_md)
    div style: "background: #{ELEVATED_SURFACE}; border-left: 4px solid #{ACCENT}; border-radius: 0 6px 6px 0; padding: 0.5rem 0.75rem;" do
      text label, style: "font-size: 0.62rem; font-weight: 700; letter-spacing: 0.07em; text-transform: uppercase; color: #{ACCENT}; margin: 0;"
      text title, style: "font-weight: 700; font-size: 0.9rem; margin: 0.1rem 0;"
      text meta, style: "font-size: 0.66rem; color: #{MUTED_TEXT}; margin: 0 0 0.2rem 0;"
      md bullets_md, style: "font-size: 0.68rem; line-height: 1.25;"
    end
  end
end
