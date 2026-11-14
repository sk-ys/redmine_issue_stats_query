module RedmineIssueStatsQuery
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
      Stats.keys.each do |key|
        add_available_filter key.to_s,
                             type: :integer, name: l("label_#{key}")
      end
    end

    # JOIN the aggregates that are used as a filter.
    def base_scope
      scope = super
      Stats.keys.each do |key|
        scope = scope.joins(Stats.join_sql(key)) if filters.key?(key.to_s)
      end
      scope
    end

    # JOIN the aggregates that are used for sorting.
    def joins_for_order_statement(order_options)
      joins = [super]
      Stats.keys.each do |key|
        if order_options.to_s.include?(Stats.alias_for(key))
          joins << Stats.join_sql(key)
        end
      end
      joins.compact.join(' ').presence
    end

    # Load the counts of displayed columns for the whole page at once.
    def issues(options = {})
      issues = super
      keys = Stats.keys.select { |key| has_column?(key) }
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
