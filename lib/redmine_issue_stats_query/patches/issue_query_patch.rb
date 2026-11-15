module RedmineIssueStatsQuery
  module Patches
    module IssueQueryPatch
      def self.prepended(base)
        Stats.keys.each do |key|
          base.add_available_column(
            StatColumn.new(key,
                           sortable: Stats.expr(key),
                           caption: "label_#{key}".to_sym))
        end
      end

      def initialize_available_filters
        super
        stat_keys.each do |key|
          add_available_filter key.to_s,
                               type: :integer, name: l("label_#{key}")
        end
      end

      def available_columns
        @stat_available_columns ||=
          super.select {|column| !column_stat?(column) || stat_keys.include?(column.name)}
      end

      # JOIN the aggregates that are used as a filter.
      def base_scope
        scope = super
        stat_keys.each do |key|
          scope = scope.joins(Stats.join_sql(key)) if filters.key?(key.to_s)
        end
        scope
      end

      # JOIN the aggregates that are used for sorting.
      def joins_for_order_statement(order_options)
        joins = [super]
        stat_keys.each do |key|
          if order_options.to_s.include?(Stats.alias_for(key))
            joins << Stats.join_sql(key)
          end
        end
        joins.compact.join(' ').presence
      end

      # Load the counts of displayed columns for the whole page at once.
      def issues(options = {})
        issues = super
        keys = stat_keys.select { |key| has_column?(key) }
        if keys.any? && issues.any?
          ids = issues.map(&:id)
          keys.each do |key|
            counts = Stats.counts(key, ids)
            issues.each { |issue| issue.stats_counts[key] = counts[issue.id] || 0 }
          end
        end
        issues
      end

      Stats.keys.each do |key|
        define_method("sql_for_#{key}_field") do |_field, operator, value|
          "(#{Stats.expr(key)} #{stats_sql_op(operator, value)})"
        end
      end

      private

      def stat_keys
        @stat_keys ||= Stats.keys.select do |key|
          permission = Stats.permission_for(key)

          # Show the stat when no permission is required for it.
          next true if permission.nil?

          # If plugin settings allow global display for this total_* stat,
          # show it regardless of project context and user permissions.
          next true if Stats.global_enabled?(key)

          # Hide permission-controlled stats on global issue lists.
          next false unless project

          User.current.allowed_to?(permission, project)
        end
      end

      def column_stat?(column)
        Stats.keys.include?(column.name)
      end

      def stats_sql_op(operator, value)
        v = value.first.to_i
        case operator
        when '='  then "= #{v}"
        when '>=' then ">= #{v}"
        when '<=' then "<= #{v}"
        when '><' then "BETWEEN #{value[0].to_i} AND #{value[1].to_i}"
        when '!*' then '= 0'
        when '*'  then '> 0'
        else "= #{v}"
        end
      end
    end
  end
end
