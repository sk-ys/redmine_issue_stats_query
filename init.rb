Redmine::Plugin.register :redmine_issue_stats_query do
  name 'Redmine Issue Stats Query'
  author 'sk-ys'
  url 'https://github.com/sk-ys/redmine_issue_stats_query'
  author_url 'https://github.com/sk-ys'
  description 'Adds count-based columns and filters (relations, comments, attachments, children) to the issue query'
  version '0.0.1'
  requires_redmine version_or_higher: '4.2.0'
  settings default: {
    'allow_global_total_relations_count' => '0',
    'allow_global_total_children_count' => '0',
    'allow_global_total_watchers_count' => '0'
  }, partial: 'settings/redmine_issue_stats_query_settings'

  project_module :issue_tracking do
    permission :view_total_relations_count, {}, read: true
    permission :view_total_children_count, {}, read: true
    permission :view_total_watchers_count, {}, read: true
  end
end

RedmineIssueStatsQuery::Hooks::ModelHook
