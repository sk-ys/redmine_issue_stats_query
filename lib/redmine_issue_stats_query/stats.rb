module RedmineIssueStatsQuery
  # To add a new stat:
  #   1. add an entry to DEFINITIONS
  #   2. add label_<key> to config/locales/*.yml
  #
  # Each definition is a lambda that receives `ids` (an Array of issue ids,
  # or nil for "all issues") and returns an Array of ActiveRecord relations.
  # Every relation must select the issue id as `issue_id`; one row = one count.
  # The relations are combined with UNION ALL and counted per issue_id.
  module Stats
    DEFINITIONS = {
      # Relations in either direction (an issue cannot relate to itself).
      relations_count: lambda { |ids|
        [:issue_from_id, :issue_to_id].map do |col|
          by_ids(IssueRelation.select("#{col} AS issue_id"), col, ids)
        end
      },
      # Comments with a note. Private notes are excluded so counts never
      # reveal their existence.
      comments_count: lambda { |ids|
        rel = Journal.where(journalized_type: 'Issue', private_notes: false)
                     .where.not(notes: [nil, ''])
                     .select('journalized_id AS issue_id')
        [by_ids(rel, :journalized_id, ids)]
      },
      attachments_count: lambda { |ids|
        rel = Attachment.where(container_type: 'Issue')
                        .select('container_id AS issue_id')
        [by_ids(rel, :container_id, ids)]
      },
      # Direct children only.
      children_count: lambda { |ids|
        rel = Issue.where.not(parent_id: nil).select('parent_id AS issue_id')
        [by_ids(rel, :parent_id, ids)]
      }
    }.freeze

    KEYS = DEFINITIONS.keys.freeze

    def self.keys; KEYS; end

    def self.by_ids(relation, column, ids)
      ids ? relation.where(column => ids) : relation
    end

    # SELECT issue_id, cnt for one stat (optionally limited to some issues).
    def self.aggregate_sql(key, ids = nil)
      union = DEFINITIONS.fetch(key).call(ids).map(&:to_sql).join(' UNION ALL ')
      "SELECT u.issue_id AS issue_id, COUNT(*) AS cnt FROM (#{union}) u GROUP BY u.issue_id"
    end

    def self.alias_for(key); "stat_#{key}"; end

    # JOIN clause for filtering / sorting. One row per issue, so it never
    # multiplies result rows.
    def self.join_sql(key)
      a = alias_for(key)
      "LEFT JOIN (#{aggregate_sql(key)}) #{a} ON #{a}.issue_id = #{Issue.table_name}.id"
    end

    # SQL expression of the count (0 when the issue has no rows).
    def self.expr(key)
      "COALESCE(#{alias_for(key)}.cnt, 0)"
    end

    # { issue_id => count } for the given issues (used to display columns).
    def self.counts(key, ids)
      return {} if ids.blank?
      sql = "SELECT s.issue_id, s.cnt FROM (#{aggregate_sql(key, ids)}) s"
      Issue.connection.select_rows(sql).each_with_object({}) do |(id, cnt), h|
        h[id.to_i] = cnt.to_i
      end
    end
  end
end
