# Redmine Issue Stats Query

Adds count-based columns, filters and sorting to the issue list:
related issues, comments, issue history, property changes count, attachments, watchers, direct subtasks.

On the issue filter selector, stat filters are grouped under `Issue stats`.

## Install

1. Copy (or clone) this plugin into `plugins/redmine_issue_stats_query` inside your Redmine installation. The directory name must be `redmine_issue_stats_query`.

2. Restart Redmine. (No database migration is required.)

3. Check that the plugin appears under **Administration > Plugins**.

4. Go to **Administration > Plugins > Redmine Issue Stats Query** and configure the plugin global permission settings as needed (see "Permissions").

5. Grant the permission to the roles that should use the global column and filters (see "Permissions").

## How it works

- Filter / sort: each stat is aggregated in a derived table that is
  LEFT JOINed only when the filter or sort is used (one row per issue, so result rows are never multiplied).
- Columns: counts for the issues on the current page are loaded in one query per displayed column.

## Available stats

Each stat is available as a filter, a column and a sort key.

| Stats name                   | Key                       | Description                                                                                                                                 |
|------------------------------|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| Attachments count            | `attachments_count`       | files attached to the issue.                                                                                                                |
| Comments count               | `comments_count`          | history entries that have a note.                                                                                                           |
| Issue history count          | `journals_count`          | history entries that have a note or property changes.                                                                                       |
| Property changes count       | `property_changes_count`  | history entries that have property changes. An entry counts once, however many properties it changes; comment-only entries are not counted. |
| Related issues count         | `visible_relations_count` | relations, in either direction, to issues the current user can see.                                                                         |
| Related issues count (total) | `total_relations_count`   | all relations, in either direction, regardless of visibility.                                                                               |
| Subtasks count               | `visible_children_count`  | direct subtasks the current user can see.                                                                                                   |
| Subtasks count (total)       | `total_children_count`    | all direct subtasks, regardless of visibility.                                                                                              |
| Watchers count               | `visible_watchers_count`  | all watchers if the user may view the watcher list (`view_issue_watchers`), otherwise only the user's own watch.                            |
| Watchers count (total)       | `total_watchers_count`    | all watchers, regardless of permissions.                                                                                                    |

The `total_*_count` stats require extra permissions, see below.

## Permissions

`total_*_count` stats are controlled by project permissions:

- `view_total_relations_count`
- `view_total_children_count`
- `view_total_watchers_count`

By default, these `total_*_count` stats are disabled on global issue
list queries (no project context). You can enable each one in plugin
settings:

- `allow_global_total_relations_count`
- `allow_global_total_children_count`
- `allow_global_total_watchers_count`

When enabled, user permission settings are ignored for that
`total_*_count` stat, regardless of whether the issue list is global
or project-scoped.

`visible_*_count` stats are always available and use visibility rules
defined by each stat.

`comments_count` and `journals_count` are visibility-aware for private
notes, so private notes are counted only when the current user is
allowed to view them (or is the note author).

----

## Development

The following sections are for developers of this plugin. They are not
needed to use it.

### Adding a stat

1. Add an entry to `DEFINITIONS` in `lib/redmine_issue_stats_query/stats.rb`
2. Add `label_<key>` to `config/locales/*.yml`
3. Add tests for it to `test/unit/stats_test.rb`

### Running the tests

From the Redmine root directory:

```
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_issue_stats_query
```

The tests create their own projects, issues, users and roles, so they do
not depend on Redmine's fixture data.

## Compatibility

Tested on Redmine 6.1 (column and filters). Not tested on other versions.

## License

GNU General Public License v2.0 (GPL-2.0). See [LICENSE](LICENSE).