require File.expand_path('../../test_helper', __FILE__)

# Integration with IssueQuery: available filters/columns, filtering, sorting,
# column values and permission handling.
class IssueQueryPatchTest < ActiveSupport::TestCase
  include IssueStatsTestHelper
  fixtures(*IssueStatsTestHelper::FIXTURES)

  VISIBLE_KEYS = %w[
    visible_relations_count visible_children_count visible_watchers_count
    comments_count journals_count property_changes_count attachments_count
  ].freeze
  TOTAL_KEYS = %w[
    total_relations_count total_children_count total_watchers_count
  ].freeze

  def setup
    @project = stats_project
    @user = stats_member(@project, [:view_issues])
    User.current = @user
  end

  def teardown
    User.current = nil
    Setting.plugin_redmine_issue_stats_query = {}
    Setting.clear_cache
  end

  def new_query(project = @project)
    IssueQuery.new(name: '_', project: project)
  end

  # Restrict a query to the issues created by the test.
  def limit_to(query, issues)
    query.add_filter('issue_id', '=', [issues.map(&:id).join(',')])
  end

  # --- available filters / columns ---------------------------------------

  def test_global_list_offers_only_stats_without_permission_requirement
    filters = IssueQuery.new(name: '_').available_filters
    VISIBLE_KEYS.each { |key| assert filters.key?(key), "#{key} should be available" }
    TOTAL_KEYS.each { |key| assert_not filters.key?(key), "#{key} should be hidden" }
  end

  def test_total_stat_is_available_in_project_with_permission
    User.current = stats_member(@project, [:view_issues, :view_total_relations_count])
    filters = new_query.available_filters

    assert filters.key?('total_relations_count')
    assert_not filters.key?('total_children_count')
    assert new_query.available_columns.map(&:name).include?(:total_relations_count)
    assert_not new_query.available_columns.map(&:name).include?(:total_children_count)
  end

  def test_global_setting_enables_total_stat_on_global_list
    Setting.plugin_redmine_issue_stats_query = { 'allow_global_total_children_count' => '1' }
    filters = IssueQuery.new(name: '_').available_filters

    assert filters.key?('total_children_count')
    assert_not filters.key?('total_relations_count')
  end

  # --- filter / sort / column ---------------------------------------------

  def children_fixture
    parent, mid, none = Array.new(3) { stats_issue(@project) }
    c1, c2, c3 = Array.new(3) { stats_issue(@project) }
    make_child(c1, parent)
    make_child(c2, parent)
    make_child(c3, mid)
    [parent, mid, none]
  end

  def test_filter
    parent, mid, none = children_fixture
    query = new_query
    limit_to(query, [parent, mid, none])
    query.add_filter('visible_children_count', '>=', ['1'])

    assert_equal [parent.id, mid.id].sort, query.issues.map(&:id).sort
    assert_equal 2, query.issue_count
  end

  def test_filter_with_zero_matches_issues_without_rows
    parent, mid, none = children_fixture
    query = new_query
    limit_to(query, [parent, mid, none])
    query.add_filter('visible_children_count', '!*', [''])

    assert_equal [none.id], query.issues.map(&:id)
  end

  def test_sort
    parent, mid, none = children_fixture
    query = new_query
    limit_to(query, [parent, mid, none])
    query.sort_criteria = [['visible_children_count', 'desc'], ['id', 'asc']]

    assert_equal [parent.id, mid.id, none.id], query.issues.map(&:id)
  end

  def test_column_values_are_preloaded
    parent, mid, none = children_fixture
    query = new_query
    limit_to(query, [parent, mid, none])
    query.column_names = [:subject, :visible_children_count]
    issues = query.issues.index_by(&:id)

    assert_equal 2, issues[parent.id].stats_counts[:visible_children_count]
    assert_equal 1, issues[mid.id].stats_counts[:visible_children_count]
    assert_equal 0, issues[none.id].stats_counts[:visible_children_count]
  end

  def test_filter_and_sort_with_several_stats_do_not_multiply_rows
    issue = stats_issue(@project)
    3.times { Attachment.generate!(container: issue) }
    other = stats_issue(@project)
    relate(issue, other)
    relate(issue, stats_issue(@project))
    add_journal(issue, notes: 'a')
    add_journal(issue, notes: 'b')

    query = new_query
    limit_to(query, [issue, other])
    query.add_filter('attachments_count', '=', ['3'])
    query.add_filter('visible_relations_count', '=', ['2'])
    query.add_filter('comments_count', '=', ['2'])
    query.sort_criteria = [['attachments_count', 'desc'], ['comments_count', 'desc']]

    assert_equal [issue.id], query.issues.map(&:id)
    assert_equal 1, query.issue_count
  end

  # --- saved queries ------------------------------------------------------

  # A shared saved query may hold a stat filter the viewer is not allowed to
  # use. It must not raise (no JOIN exists for it); the filter is ignored.
  def test_unavailable_stat_filter_in_saved_query_is_ignored
    a, b, c = Array.new(3) { stats_issue(@project) }
    relate(a, b)

    query = new_query
    limit_to(query, [a, b, c])
    query.filters['total_relations_count'] = { operator: '>=', values: ['1'] }

    assert_nothing_raised do
      assert_equal [a.id, b.id, c.id].sort, query.issues.map(&:id).sort
      assert_equal 3, query.issue_count
    end
  end
end
