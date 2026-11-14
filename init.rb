Redmine::Plugin.register :redmine_issue_stats_query do
  name 'Redmine Issue Stats Query'
  author 'sk-ys'
  url 'https://github.com/sk-ys/redmine_issue_stats_query'
  author_url 'https://github.com/sk-ys'
  description 'Adds count-based columns and filters (relations, comments, attachments, children) to the issue query'
  version '0.0.1'
  requires_redmine version_or_higher: '4.2.0'
end

RedmineIssueStatsQuery::Hooks::ModelHook
