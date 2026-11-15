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

## Add a stat
1. Add an entry to `DEFINITIONS` in `lib/redmine_issue_stats_query/stats.rb`
2. Add `label_<key>` to `config/locales/*.yml`
