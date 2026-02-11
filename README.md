# mudd

**mudd** is a production-quality Ruby CLI that imports worklogs into Jira from a CSV (e.g. exported from Google Sheets). Invoke it as `bin/mudd`. The project is modular and feature-flag friendly: non-core features can be disabled by removing a single require or directory.

## Requirements

- Ruby 3.3.x (managed via [rbenv](https://github.com/rbenv/rbenv))
- Bundler

## Setup

### 1. Install Ruby with rbenv

```bash
rbenv install 3.3.6   # or your preferred 3.3.x
rbenv local 3.3.6
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Configure environment and Jira URL

- **`.env`** – credentials only (never commit). Copy `.env.example` to `.env` and set `JIRA_EMAIL` and `JIRA_PASSWORD`. Authentication uses **Basic Auth** (`<email>:<password>` as Base64), supported by older Jira Server APIs.
- **`config.yml`** – Jira base URL and other options. Set `jira.base_url` to your Jira base URL (e.g. `https://jira.example.com`). See [Example config.yml](#example-configyml) below.

You don’t need the base URL in both: use **config.yml for the URL**, **.env only for credentials**. Optionally, you can set `JIRA_BASE_URL` in `.env` to override or to run without a config file.

## Usage

Run from the project root. The script uses the shebang and `Bundler.setup`, so you can invoke it directly (no `bundle exec ruby` needed):

```bash
bin/mudd import worklogs.csv
# or
./bin/mudd import worklogs.csv
```

### Import worklogs

```bash
# From a local CSV file
bin/mudd import worklogs.csv

# From a Google Sheets URL (edit or export URL; sheet ID is auto-detected)
bin/mudd import "https://docs.google.com/spreadsheets/d/ID/edit"

# Without SOURCE: use the URL from config (set csv.source_url in config.yml)
bin/mudd import

# With options
bin/mudd import worklogs.csv --config config.yml --verbose
```

### Dry-run (recommended first)

Performs full validation and prints what would be sent to Jira **without making any HTTP writes**:

```bash
bin/mudd import worklogs.csv --dry-run
```

### Rollback last import

Deletes all worklogs created in the last import run:

```bash
bin/mudd rollback
```

### Purge rollback data

Clears the last-run rollback file. Deduplication is stored in Jira (worklog tags), so there is no local dedup file to clear.

```bash
bin/mudd purge
```

### Global flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Validate and print only; do not call Jira API |
| `--verbose` | Verbose output |
| `--config PATH` | Path to `config.yml` |
| `--report-json PATH` | Write JSON report to file (import command) |
| `--start-date YYYY-mm-dd` | Import only logs with date >= this (midnight) |
| `--end-date YYYY-mm-dd` | Import only logs with date <= this (midnight) |

## Example CSV

The default mapping expects CSV columns: **Issue Key**, **Date**, **Time Spent**, **Comment**. Example:

```csv
Issue Key,Date,Time Spent,Comment
PROJ-123,2025-02-01,60,Implemented login flow
PROJ-123,2025-02-02,30,Code review
PROJ-456,2025-02-01,120,Design session
```

- **Date**: format configurable via `time.date_format` (default `%Y-%m-%d`).
- **Time Spent**: depends on `time.time_spent_format` in config: `minutes`, `hours`, or `excel_duration` (`hh:mm:ss`) are converted and sent as `timeSpentSeconds`; `jira` is passed through as-is and sent as `timeSpent` (e.g. `"1h 30m"`).

## Example config.yml

```yaml
jira:
  base_url: https://your-domain.atlassian.net

csv:
  delimiter: ","
  encoding: UTF-8

mapping:
  issue_key: "Issue Key"
  date: "Date"
  time_spent: "Time Spent"
  comment: "Comment"

time:
  date_format: "%Y-%m-%d"
  time_spent_format: "minutes"
  timezone: "Europe/Warsaw"   # IANA TZ identifier (default) for "started" sent to Jira

validation:
  enabled: true
  allow_future_dates: false
  # issue_key_pattern: '\A[A-Z][A-Z0-9]+-\d+\z'

# Optional: deduplication (skip worklogs already in Jira via [mudd-import-id:...] tag in comment)
deduplication:
  enabled: false

# Optional: rate limiting and retries
rate_limit:
  requests_per_second: 10
  max_retries: 3
  backoff_base: 2
```

Put only credentials in `.env` (`JIRA_EMAIL`, `JIRA_PASSWORD`). Put the Jira base URL and other options in `config.yml`.

## Troubleshooting

### SSL / certificate verify failed when fetching Google Sheets (e.g. behind VPN)

If you see `certificate verify failed (unable to get certificate CRL)` or similar when importing from a Google Sheets URL (often on a machine using VPN or corporate proxy), you can skip SSL verification **only for CSV URL fetches**:

- **Config:** In `config.yml` under `csv:`, set `skip_ssl_verify: true`.
- **Env:** Or set `CSV_SKIP_SSL_VERIFY=1` (or `true` / `yes`) in `.env`.

This is insecure (no certificate check for the CSV host). Use only when necessary and only on the affected machine.

## Disabling optional features

Non-core behaviour is isolated so it can be removed by deleting a single require or directory.

| Feature | Location | How to disable |
|--------|----------|-----------------|
| **Deduplication** | `lib/jira_worklog_import/deduplication/` | Remove the `require_relative "jira_worklog_import/deduplication/hasher"` line in `lib/jira_worklog_import.rb`. |
| **Rate limiting & retries** | `lib/jira_worklog_import/http/` | Remove the two `require_relative "jira_worklog_import/http/..."` lines in `lib/jira_worklog_import.rb`. |
| **Reporting** | `lib/jira_worklog_import/reporting/` | Remove the `require_relative "jira_worklog_import/reporting/report"` line in `lib/jira_worklog_import.rb`. |
| **Rollback** | `lib/jira_worklog_import/rollback/` | Remove the two `require_relative "jira_worklog_import/rollback/..."` lines in `lib/jira_worklog_import.rb`. |

Validation is optional but **enabled by default**; set `validation.enabled: false` in `config.yml` to turn it off. Config sections (e.g. `deduplication`, `rate_limit`) are independent: you can remove a section from `config/loader.rb` and the corresponding config class if you want to drop that feature from the app.

## Pipeline

Execution flow:

```
CSV Reader → Mapper → Validators → Deduplication → Jira Client
```

Each step is isolated and can be replaced or removed without breaking the rest.

## Project structure

```
.
├── bin/mudd
├── lib/
│   ├── jira_worklog_import/
│   │   ├── cli/
│   │   ├── config/
│   │   ├── csv/
│   │   ├── mapping/
│   │   ├── validation/
│   │   ├── jira/
│   │   ├── deduplication/   # optional
│   │   ├── http/            # optional
│   │   ├── reporting/       # optional
│   │   └── rollback/        # optional
│   └── jira_worklog_import.rb
├── spec/
├── .env.example
├── .ruby-version
├── Gemfile
├── Gemfile.lock
└── README.md
```

## License

MIT.
