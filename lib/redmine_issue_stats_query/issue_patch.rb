module RedmineIssueStatsQuery
  module IssuePatch
    def stats_counts
      @stats_counts ||= {}
    end

    # Preloaded by IssueQuery#issues; falls back to one query per issue.
    def stat_count(key)
      return 0 if new_record?
      stats_counts.fetch(key) do
        stats_counts[key] = Stats.counts(key, [id])[id] || 0
      end
    end
  end
end
