# frozen_string_literal: true

require_relative "jira_worklog_import/config/loader"
require_relative "jira_worklog_import/config/root"
require_relative "jira_worklog_import/config/jira"
require_relative "jira_worklog_import/config/csv"
require_relative "jira_worklog_import/config/mapping"
require_relative "jira_worklog_import/config/time"
require_relative "jira_worklog_import/config/validation"
require_relative "jira_worklog_import/config/deduplication"
require_relative "jira_worklog_import/config/rate_limit"

require_relative "jira_worklog_import/csv/reader"
require_relative "jira_worklog_import/mapping/worklog_entry"
require_relative "jira_worklog_import/mapping/worklog_mapper"
require_relative "jira_worklog_import/validation/error"
require_relative "jira_worklog_import/validation/base"
require_relative "jira_worklog_import/validation/issue_key_validator"
require_relative "jira_worklog_import/validation/time_spent_validator"
require_relative "jira_worklog_import/validation/date_validator"
require_relative "jira_worklog_import/validation/chain"
require_relative "jira_worklog_import/jira/error"
require_relative "jira_worklog_import/jira/client"
require_relative "jira_worklog_import/jira/worklogs"
require_relative "jira_worklog_import/pipeline"

# Optional: remove the following require to disable deduplication (tag-based in Jira worklog comments)
require_relative "jira_worklog_import/deduplication/hasher"

# Optional: remove the following require to disable rate limiting / retries
require_relative "jira_worklog_import/http/rate_limiter"
require_relative "jira_worklog_import/http/retry_policy"

# Optional: remove the following require to disable reporting
require_relative "jira_worklog_import/reporting/report"

# Optional: remove the following require to disable rollback
require_relative "jira_worklog_import/rollback/store"
require_relative "jira_worklog_import/rollback/executor"

require_relative "jira_worklog_import/cli/main"
