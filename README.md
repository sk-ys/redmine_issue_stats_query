# redmine_issue_stats_query

Adds count-based columns, filters and sorting to the issue list:
related issues, comments (public notes only), attachments, watchers,
direct subtasks.

## Install
Copy to `plugins/redmine_issue_stats_query`, then restart Redmine.
No migrations required.

## How it works
- Filter / sort: each stat is aggregated in a derived table that is
  LEFT JOINed only when the filter or sort is used (one row per issue,
  so result rows are never multiplied).
- Columns: counts for the issues on the current page are loaded in one
  query per displayed column.

## Permissions
`total_*_count` stats are controlled by project permissions:
- `view_total_relations_count`
- `view_total_children_count`
- `view_total_watchers_count`

These `total_*_count` stats are disabled on global issue list queries
(no project context). They are available only in project issue lists
when the current user has the corresponding permission on that project.

`visible_*_count` stats are always available and use visibility rules
defined by each stat.

## Add a stat
1. Add an entry to `DEFINITIONS` in `lib/redmine_issue_stats_query/stats.rb`
2. Add `label_<key>` to `config/locales/*.yml`
