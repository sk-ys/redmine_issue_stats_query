module RedmineIssueStatsQuery
  class StatColumn < QueryColumn
    def initialize(name, options = {})
      super(name, { default_order: 'desc' }.merge(options))
    end

    def value_object(issue)
      issue.stat_count(name)
    end
  end
end
