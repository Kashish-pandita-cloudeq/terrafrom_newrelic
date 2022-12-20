terraform {
  #required_version = "~> 1.2.6"
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 2.49.1"
    }
  }
}

provider "newrelic" {
  account_id = "3087301"
  api_key = "NRAK-N96JFJ8YYZLFHYKMLORYUKN7L3L"    # Usually prefixed with 'NRAK'
  region = "US"                    # Valid regions are US and EU
}

resource "newrelic_alert_policy" "my_alert_policy" {
  name = "NEW_demo_alert_policy"
  #incident_preference = "PER_POLICY" # PER_POLICY is default
}

#Data source
data "newrelic_entity" "app_name" {
  name = "Demo_app_for_new_relic_one"
  type = "APPLICATION"
  domain = "APM"
}

#tags for entity
resource "newrelic_entity_tags" "tags_new" {
    guid = data.newrelic_entity.app_name.guid

    tag {
        key = "my-key"
        values = ["my-value", "my-other-value"]
    }

    tag {
        key = "my-key-2"
        values = ["my-value-2"]
    }
}

#alertcondition
resource "newrelic_alert_policy" "alert_policy_name" {
  name = "My Alert Policy Name"
}

#NRQL alert condition //alerts when the average response duration rises above the threshold of 5.5 for 5 minutes..critical in priority
resource "newrelic_nrql_alert_condition" "foo" {
  policy_id                    = newrelic_alert_policy.alert_policy_name.id
  type                         = "static"
  aggregation_delay            = "120" 
  aggregation_method           = "event_flow"
  name                         = "foo"
  description                  = "Alert when transactions are taking too long"
  runbook_url                  = "https://www.example.com"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query             = "SELECT average(duration) FROM Transaction where appName = '${data.newrelic_entity.app_name.name}'"
    #evaluation_offset = 3       #it was giving aggregated attribute warning
  
  }

  critical {
    operator              = "above"
    threshold             = 5.5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

#Newrelic one raw dashboard
resource "newrelic_one_dashboard_raw" "new_dash" {
  name = "New Relic dashboard demo"

    page {
    name = "Dashboard"
    widget {
      title = "Custom widget"
      row = 5
      column = 5
      width = 7
      height = 8
      visualization_id = "viz.bar"
      configuration = <<EOT
      {
        "legend": {
          "enabled": false
        },
        "nrqlQueries": [
          {
            "accountId":  "3552620" ,
            "query": "SELECT average(loadAverageOneMinute), average(loadAverageFiveMinute), average(loadAverageFifteenMinute) from SystemSample SINCE 60 minutes ago    TIMESERIES"
          }
        ],
        "yAxisLeft": {
          "max": 100,
          "min": 50,
          "zero": false
        }
      }
      EOT
    }
    widget {
      title = "Server CPU"
      row = 5
      column = 5
      width = 7
      height = 8
      visualization_id = "viz.bar"
      configuration = <<EOT
      {
        "nrqlQueries": [
          {
            "accountId":  "3552620" ,
            "query": "SELECT average(cpuPercent) FROM SystemSample since 3 hours ago facet hostname limit 400"
          }
        ]
      }
      EOT
    }
    widget {
      title  = "Docker Server CPU"
      row    = 5
      column = 5
      height = 7
      width  = 8
      visualization_id = "viz.bar"
      configuration = jsonencode(
      {
        "facet": {
          "showOtherSeries": false
        },
        "nrqlQueries": [
          {
            "accountId": "3552620"  #local.accountID,
            "query": "SELECT average(cpuPercent) FROM SystemSample since 3 hours ago facet hostname limit 400"
          }
        ]
      }
      )
      linked_entity_guids = ["MzU1MjYyMHxBUE18QVBQTElDQVRJT058MTAwODA5OTE3Nw"]
    }
  }
}

#dashboard(not raw)
resource "newrelic_one_dashboard" "exampledash" {
  name = "New Relic other dashboard"
  permissions = "public_read_only"

  page {
    name = "Dashboard2"

    widget_billboard {
      title = "Requests per minute"
      row = 1
      column = 1
      width = 6
      height = 3

      nrql_query {
        query       = "FROM Transaction SELECT rate(count(*), 1 minute)"
      }
    }

    widget_bar {
      title = "Average transaction duration, by application"
      row = 1
      column = 7
      width = 6
      height = 3

      nrql_query {
        account_id  = "3552620"
        query       = "FROM Transaction SELECT average(duration) FACET appName"
      }

      # Must be another dashboard GUID
      linked_entity_guids = ["MzU1MjYyMHxBUE18QVBQTElDQVRJT058MTAwODA5OTE3Nw"]
    }

    widget_bar {
      title = "Average transaction duration, by application"
      row = 4
      column = 1
      width = 6
      height = 3

      nrql_query {
        account_id  = "3552620"
        query       = "FROM Transaction SELECT average(duration) FACET appName"
      }

      # Must be another dashboard GUID
      filter_current_dashboard = true
    }

    widget_line {
      title = "Average transaction duration and the request per minute, by application"
      row = 4
      column = 7
      width = 6
      height = 3

      nrql_query {
        account_id  = "3552620"
        query       = "FROM Transaction SELECT average(duration) FACET appName"
      }

      nrql_query {
        query       = "FROM Transaction SELECT rate(count(*), 1 minute)"
      }
    }

    widget_markdown {
      title = "Dashboard Note"
      row    = 7
      column = 1
      width = 12
      height = 3

      text = "### Helpful Links\n\n* [New Relic One](https://one.newrelic.com)\n* [Developer Portal](https://developer.newrelic.com)"
    }
  }
}

#service level
resource "newrelic_service_level" "Service_level_response" {
    guid = "MzU1MjYyMHxBUE18QVBQTElDQVRJT058MTAwODA5OTE3Nw"                     #"MzI5ODAxNnxWSVp8REFTSEJPQVJEfDI2MTcxNDc"
    name = "Latency"
    description = "Proportion of requests that are served faster than a threshold."

    events {
        account_id = 3552620
        valid_events {
            from = "Transaction"
            where = "appName = 'Demo_app_for_new_relic_one' AND (transactionType='Web')"
        }
        good_events {
            from = "Transaction"
            where = "appName = 'Demo_app_for_new_relic_one' AND (transactionType= 'Web') AND duration < 0.1"
        }
    }

    objective {
        target = 99.00
        time_window {
            rolling {
                count = 7
                unit = "DAY"
            }
        }
    }
}



# resource "newrelic_alert_channel" "alert_notification_email" {
#   name = "username@example.com"
#   type = "email"

#   config {
#     recipients              = "username@example.com"
#     include_json_attachment = "true"
#   }
# }


# resource "newrelic_alert_condition" "alert_condition_name" {
#   policy_id = newrelic_alert_policy.my_alert_policy.id

#   name        = "My_alert_condition"
#   type        = "apm_app_metric"
#   entities    = [data.newrelic_application.app_name.id]
#   metric      = "apdex"
#   runbook_url = "https://www.example.com"
#   condition_scope = "application"

#   term {
#     duration      = 5
#     operator      = "below"
#     priority      = "critical"
#     threshold     = "0.75"
#     time_function = "all"
#   }
# }

# #Notification Channel using alert channel for email
# resource "newrelic_alert_channel" "alert_notification_email"{
#   name = "noreply@newrellic.com"
#   type = "email"

#   config {
#     recipients              = "noreply@newrellic.com"
#     include_json_attachment = "1"
#   }
# }

# #linking above notification with alert policy
# resource "newrelic_alert_policy_channel" "alert_policy_email" {
#   policy_id = newrelic_alert_policy.my_alert_policy.id

#   # Add the referenced channels to the policy.
#   channel_ids = [
#     newrelic_alert_channel.alert_notification_email.id
#   ]
# }


