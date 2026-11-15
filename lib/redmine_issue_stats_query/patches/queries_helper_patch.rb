# frozen_string_literal: true

module RedmineIssueStatsQuery
  module Patches
    module QueriesHelperPatch
      def filters_options_for_select(query)
        html = super
        return html unless query.is_a?(IssueQuery)

        wrap_stats_options_group(html)
      end

      private

      def wrap_stats_options_group(html)
        fragment = Nokogiri::HTML::DocumentFragment.parse("<select>#{html}</select>")
        select = fragment.at_css('select')
        return html unless select

        stats_keys = RedmineIssueStatsQuery::Stats.keys.map(&:to_s)
        options = select.css('option').select { |opt| stats_keys.include?(opt['value']) }
        return html if options.empty?

        group = Nokogiri::XML::Node.new('optgroup', fragment)
        group['label'] = l(:label_issue_stats)
        options.each do |opt|
          opt.remove
          group.add_child(opt)
        end
        select.add_child(group)
        select.inner_html.html_safe
      end
    end
  end
end
