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
    PERMISSIONS = {
      total_relations_count: :view_total_relations_count,
      total_children_count: :view_total_children_count,
      total_watchers_count: :view_total_watchers_count
    }.freeze

    DEFINITIONS = {
      attachments_count: lambda { |ids|
        rel = Attachment.where(container_type: 'Issue')
                        .select('container_id AS issue_id')
        [by_ids(rel, :container_id, ids)]
      },
      # Journal entries (roughly issue update count), visibility-aware.
      journals_count: lambda { |ids|
        rel = Journal.visible.where(journalized_type: 'Issue', private_notes: false)
                     .select("#{Journal.table_name}.journalized_id AS issue_id")
        [by_ids(rel, :journalized_id, ids)]
      },
      # Journal entries excluding comment-only updates (must have details).
      property_changes_count: lambda { |ids|
        rel = Journal.visible.where(journalized_type: 'Issue')
                     .joins(:details)
                     .group("#{JournalDetail.table_name}.journal_id", "#{Journal.table_name}.journalized_id")
                     .select("#{Journal.table_name}.journalized_id AS issue_id")
        [by_ids(rel, :journalized_id, ids)]
      },
      # Comments with a note. Private notes are excluded so counts never
      # reveal their existence.
      comments_count: lambda { |ids|
        rel = Journal.where(journalized_type: 'Issue', private_notes: false)
                     .where.not(notes: [nil, ''])
                     .select('journalized_id AS issue_id')
        [by_ids(rel, :journalized_id, ids)]
      },
      # Relations in either direction (an issue cannot relate to itself).
      total_relations_count: lambda { |ids|
        [:issue_from_id, :issue_to_id].map do |col|
          by_ids(IssueRelation.select("#{col} AS issue_id"), col, ids)
        end
      },
      # Relations in either direction, but only visible issues.
      visible_relations_count: lambda { |ids|
        visible = Issue.visible.select("#{Issue.table_name}.id")
        [[:issue_from_id, :issue_to_id], [:issue_to_id, :issue_from_id]].map do |col, other|
          rel = IssueRelation.where(other => visible)
                             .select("#{IssueRelation.table_name}.#{col} AS issue_id")
          by_ids(rel, col, ids)
        end
      },
      # Direct children only.
      total_children_count: lambda { |ids|
        rel = Issue.where.not(parent_id: nil).select('parent_id AS issue_id')
        [by_ids(rel, :parent_id, ids)]
      },
      # Direct visible children only.
      visible_children_count: lambda { |ids|
        rel = Issue.visible.where.not(parent_id: nil)
                   .select("#{Issue.table_name}.parent_id AS issue_id")
        [by_ids(rel, :parent_id, ids)]
      },
      # Watchers (users/groups) regardless of current user's permissions.
      total_watchers_count: lambda { |ids|
        rel = Watcher.where(watchable_type: 'Issue')
                     .select("#{Watcher.table_name}.watchable_id AS issue_id")
        [by_ids(rel, :watchable_id, ids)]
      },
      # Watchers visible to current user. Without permission, users can only
      # see themselves as watchers.
      visible_watchers_count: lambda { |ids|
        permission = Project.allowed_to_condition(User.current, :view_issue_watchers)
        base = Issue.joins(:project, :watchers).select("#{Issue.table_name}.id AS issue_id")

        [by_ids(base.where(permission), :id, ids),
         by_ids(base.where("NOT (#{permission})")
                    .where(watchers: { user_id: User.current.id }), :id, ids)]
      }
    }.freeze

    KEYS = DEFINITIONS.keys.freeze

    def self.keys; KEYS; end

    def self.permission_for(key)
      PERMISSIONS[key]
    end

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
