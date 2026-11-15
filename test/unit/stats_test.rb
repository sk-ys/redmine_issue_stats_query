require File.expand_path('../../test_helper', __FILE__)

# One group of tests per stat. Each test checks the counts returned by
# Stats.counts, which is also what the filter/sort SQL is built from.
class StatsTest < ActiveSupport::TestCase
  include IssueStatsTestHelper
  fixtures(*IssueStatsTestHelper::FIXTURES)

  def setup
    @project = stats_project
    @hidden_project = stats_project
    User.current = User.find(1) # admin
  end

  def teardown
    User.current = nil
  end

  # --- attachments_count -------------------------------------------------

  def test_attachments_count
    a, b, c = Array.new(3) { stats_issue(@project) }
    2.times { Attachment.generate!(container: a) }
    Attachment.generate!(container: b)

    assert_equal({ a.id => 2, b.id => 1 }, stats_counts(:attachments_count, a, b, c))
  end

  # --- comments_count ----------------------------------------------------

  def test_comments_count_counts_only_journals_with_notes
    a, b = Array.new(2) { stats_issue(@project) }
    add_journal(a, notes: 'one')
    add_journal(a, notes: 'two')
    add_journal(a, details: 1) # property change only
    add_journal(b, details: 2)

    assert_equal({ a.id => 2 }, stats_counts(:comments_count, a, b))
  end

  def test_comments_count_hides_private_notes_without_permission
    user = stats_member(@project, [:view_issues])
    issue = stats_issue(@project)
    add_journal(issue, notes: 'public')
    add_journal(issue, notes: 'private of another user', private_notes: true)
    add_journal(issue, user: user, notes: 'my private note', private_notes: true)

    User.current = user
    assert_equal({ issue.id => 2 }, stats_counts(:comments_count, issue))
  end

  def test_comments_count_shows_private_notes_with_permission
    user = stats_member(@project, [:view_issues, :view_private_notes])
    issue = stats_issue(@project)
    add_journal(issue, notes: 'public')
    add_journal(issue, notes: 'private of another user', private_notes: true)

    User.current = user
    assert_equal({ issue.id => 2 }, stats_counts(:comments_count, issue))
  end

  # Regression: the user's own private notes matched both the "own notes" and
  # the "private notes in permitted projects" relations and were counted twice.
  def test_comments_count_does_not_double_count_own_private_notes
    user = stats_member(@project, [:view_issues, :view_private_notes])
    issue = stats_issue(@project)
    add_journal(issue, notes: 'public')
    add_journal(issue, notes: 'private of another user', private_notes: true)
    add_journal(issue, user: user, notes: 'my private note', private_notes: true)

    User.current = user
    assert_equal({ issue.id => 3 }, stats_counts(:comments_count, issue))
  end

  # --- journals_count ----------------------------------------------------

  def test_journals_count_counts_notes_and_property_changes
    a, b = Array.new(2) { stats_issue(@project) }
    add_journal(a, notes: 'a note')
    add_journal(a, details: 2) # one journal, two details => one entry

    assert_equal({ a.id => 2 }, stats_counts(:journals_count, a, b))
  end

  def test_journals_count_does_not_double_count_own_private_notes
    user = stats_member(@project, [:view_issues, :view_private_notes])
    issue = stats_issue(@project)
    add_journal(issue, user: user, notes: 'my private note', private_notes: true)

    User.current = user
    assert_equal({ issue.id => 1 }, stats_counts(:journals_count, issue))
  end

  # --- property_changes_count --------------------------------------------

  def test_property_changes_count_counts_journals_with_details
    a, b = Array.new(2) { stats_issue(@project) }
    add_journal(a, details: 2) # counted once, not once per detail
    add_journal(a, details: 1)
    add_journal(a, notes: 'comment only') # not a property change

    assert_equal({ a.id => 2 }, stats_counts(:property_changes_count, a, b))
  end

  # --- relations ----------------------------------------------------------

  def test_total_relations_count_counts_both_directions
    a, b, c, d = Array.new(4) { stats_issue(@project) }
    relate(a, b)
    relate(c, a)

    assert_equal({ a.id => 2, b.id => 1, c.id => 1 },
                 stats_counts(:total_relations_count, a, b, c, d))
  end

  def test_visible_relations_count_excludes_invisible_issues
    user = stats_member(@project, [:view_issues])
    a, b = Array.new(2) { stats_issue(@project) }
    hidden = stats_issue(@hidden_project)
    relate(a, b)
    relate(a, hidden)
    relate(hidden, b)

    User.current = user
    assert_equal({ a.id => 1, b.id => 1 }, stats_counts(:visible_relations_count, a, b))
    assert_equal({ a.id => 2, b.id => 2 }, stats_counts(:total_relations_count, a, b))
  end

  def test_visible_relations_count_for_admin_includes_everything
    a, b = Array.new(2) { stats_issue(@project) }
    hidden = stats_issue(@hidden_project)
    relate(a, b)
    relate(a, hidden)

    assert_equal({ a.id => 2, b.id => 1 }, stats_counts(:visible_relations_count, a, b))
  end

  # --- children -----------------------------------------------------------

  def test_total_children_count_counts_direct_children_only
    parent, other = Array.new(2) { stats_issue(@project) }
    c1, c2, c3 = Array.new(3) { stats_issue(@project) }
    make_child(c1, parent)
    make_child(c2, parent)
    make_child(c3, c1) # grandchild of parent

    assert_equal({ parent.id => 2, c1.id => 1 },
                 stats_counts(:total_children_count, parent, c1, c2, c3, other))
  end

  def test_visible_children_count_excludes_invisible_children
    user = stats_member(@project, [:view_issues])
    parent = stats_issue(@project)
    visible_child = stats_issue(@project)
    hidden_child = stats_issue(@hidden_project)
    make_child(visible_child, parent)
    make_child(hidden_child, parent)

    User.current = user
    assert_equal({ parent.id => 1 }, stats_counts(:visible_children_count, parent))
    assert_equal({ parent.id => 2 }, stats_counts(:total_children_count, parent))
  end

  # --- watchers -----------------------------------------------------------

  def test_total_watchers_count_ignores_permissions
    issue = stats_issue(@project)
    3.times { Watcher.create!(watchable: issue, user: User.generate!) }

    User.current = stats_member(@project, [:view_issues])
    assert_equal({ issue.id => 3 }, stats_counts(:total_watchers_count, issue))
  end

  def test_visible_watchers_count_with_permission_counts_everyone
    user = stats_member(@project, [:view_issues, :view_issue_watchers])
    issue = stats_issue(@project)
    2.times { Watcher.create!(watchable: issue, user: User.generate!) }
    Watcher.create!(watchable: issue, user: user)

    User.current = user
    assert_equal({ issue.id => 3 }, stats_counts(:visible_watchers_count, issue))
  end

  def test_visible_watchers_count_without_permission_counts_only_self
    user = stats_member(@project, [:view_issues])
    issue = stats_issue(@project)
    2.times { Watcher.create!(watchable: issue, user: User.generate!) }

    User.current = user
    assert_equal({}, stats_counts(:visible_watchers_count, issue))

    Watcher.create!(watchable: issue, user: user)
    assert_equal({ issue.id => 1 }, stats_counts(:visible_watchers_count, issue))
  end

  # --- generic ------------------------------------------------------------

  def test_counts_returns_empty_hash_without_ids
    assert_equal({}, RedmineIssueStatsQuery::Stats.counts(:attachments_count, []))
  end

  def test_every_definition_runs_and_returns_integers
    issue = stats_issue(@project)
    RedmineIssueStatsQuery::Stats.keys.each do |key|
      counts = RedmineIssueStatsQuery::Stats.counts(key, [issue.id])
      assert counts.values.all? { |v| v.is_a?(Integer) }, "#{key} returned #{counts.inspect}"
    end
  end
end
