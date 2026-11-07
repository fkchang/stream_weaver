# frozen_string_literal: true

require 'uri'

module StreamWeaver
  # The URL a POST response pushes into the address bar (HX-Push-Url) when route state decides the path.
  #
  # The route builder returns a bare path ("/"), so pushing it as-is DROPS the query string the browser is
  # on. A `tabs ..., url: true` group keeps its active tab in that query (?view=2), so every click snapped
  # the page back to the first tab. When the push would land on the page the browser is already on, that
  # page's own URL (path, query, fragment) is kept instead. The path still comes from route state: a push to
  # a different page is unchanged and carries no old query.
  #
  # "Same page" is an exact match on the decoded-as-sent path, ignoring one trailing slash. Any mismatch
  # (an escaped path, a different page) keeps the old bare-path push.
  module PushUrl
    module_function

    # @param pushed_path [String] the path the app wants in the address bar
    # @param current_url [String, nil] the HX-Current-URL header: the requesting tab's own on-screen URL
    # @return [String] the URL to push
    def keep_query(pushed_path, current_url)
      current = parse(current_url)
      return pushed_path unless current && same_page?(pushed_path, current) && carries_state?(current)

      [current.path, ("?#{current.query}" unless current.query.to_s.empty?), ("##{current.fragment}" unless current.fragment.to_s.empty?)].join
    end

    # The mount prefix the browser is on ("/apps/my-slug"), so a push keeps the slug or hex id the user typed.
    # @return [String, nil]
    def mount_prefix(current_url)
      parse(current_url)&.path.to_s[%r{\A/apps/[^/]+}]
    end

    def parse(url)
      return nil if url.to_s.empty?

      URI.parse(url)
    rescue URI::Error
      nil
    end

    def same_page?(pushed_path, current)
      return false if pushed_path.to_s.include?('?')

      current.path.chomp('/') == pushed_path.to_s.chomp('/')
    end

    def carries_state?(current) = !(current.query.to_s.empty? && current.fragment.to_s.empty?)

    private_class_method :parse, :same_page?, :carries_state?
  end
end
