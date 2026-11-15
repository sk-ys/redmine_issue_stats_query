require File.expand_path('../../../../test/test_helper', __FILE__)

# Helpers shared by the plugin tests.
#
# Every test creates its own projects / issues / users and only looks at the
# issues it created, so the results do not depend on Redmine's fixture data.
module IssueStatsTestHelper
  FIXTURES = %i[
    projects enabled_modules users email_addresses user_preferences
    members member_roles roles trackers projects_trackers issue_statuses
    enumerations workflows issues issue_categories versions journals
    journal_details issue_relations watchers attachments queries
    custom_fields custom_values custom_fields_projects custom_fields_trackers
  ].freeze

  # { issue_id => count } for the given issues (zero counts are omitted).
  def stats_counts(key, *issues)
    RedmineIssueStatsQuery::Stats.counts(key, issues.flatten.map(&:id))
  end

  # A project that only its members can see.
  def stats_project(is_public: false)
    Project.generate!(is_public: is_public, tracker_ids: [1])
  end

  def stats_issue(project, attrs = {})
    Issue.generate!({ project: project }.merge(attrs))
  end

  # An active user who is a member of the project with the given permissions.
  def stats_member(project, permissions)
    user = User.generate!
    role = Role.generate!(permissions: permissions)
    User.add_to_project(user, project, role)
    user
  end

  def add_journal(issue, user: User.find(2), notes: '', private_notes: false, details: 0)
    journal = Journal.new(journalized: issue, user: user,
                          notes: notes, private_notes: private_notes)
    details.times do |i|
      journal.details << JournalDetail.new(property: 'attr', prop_key: "field#{i}",
                                           old_value: 'a', value: 'b')
    end
    journal.save!
    journal
  end

  def relate(from, to)
    # skip validations: cross-project relations are disabled by default
    IssueRelation.new(issue_from: from, issue_to: to, relation_type: 'relates')
                 .save!(validate: false)
  end

  # Set the parent directly; the stats only look at issues.parent_id.
  def make_child(child, parent)
    Issue.where(id: child.id).update_all(parent_id: parent.id)
  end
end
