# Audit Logging Configuration for GCP
# This module sets up comprehensive audit logging for the Golang HA infrastructure

# Enable audit logging for key GCP services
locals {
  audit_services = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com"
  ]
}

resource "google_project_iam_audit_config" "service_audit" {
  for_each = toset(local.audit_services)
  project  = var.project_id
  service  = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
    exempted_members = each.value == "secretmanager.googleapis.com" ? var.secret_exempted_members : null
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Log sink for security events to BigQuery
resource "google_logging_project_sink" "security_audit_sink" {
  name                   = "${var.project_name}-security-audit-sink"
  project                = var.project_id
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.audit_dataset.dataset_id}"
  description            = "Sink for security audit logs"
  unique_writer_identity = true

  # Filter for security-relevant events
  filter = <<-EOT
    (protoPayload.serviceName="container.googleapis.com" OR
     protoPayload.serviceName="compute.googleapis.com" OR
     protoPayload.serviceName="iam.googleapis.com" OR
     protoPayload.serviceName="cloudresourcemanager.googleapis.com" OR
     protoPayload.serviceName="secretmanager.googleapis.com" OR
     protoPayload.serviceName="cloudkms.googleapis.com") AND
    (protoPayload.methodName:"delete" OR
     protoPayload.methodName:"create" OR
     protoPayload.methodName:"update" OR
     protoPayload.methodName:"setIamPolicy" OR
     protoPayload.methodName:"addBinding" OR
     protoPayload.methodName:"removeBinding" OR
     severity>=ERROR)
  EOT
}

# BigQuery dataset for audit logs
resource "google_bigquery_dataset" "audit_dataset" {
  dataset_id                  = replace("${var.project_name}_audit_logs", "-", "_")
  project                     = var.project_id
  friendly_name              = "Security Audit Logs"
  description                = "Dataset for storing security audit logs from GCP services"
  location                   = var.audit_dataset_location
  default_table_expiration_ms = var.audit_log_retention_days * 24 * 60 * 60 * 1000

  labels = {
    environment = var.environment
    component   = "audit-logging"
    managed-by  = "terraform"
  }

  # Default access uses creator's identity; explicit access blocks omitted for simplicity
}

# Grant BigQuery Data Editor role to the sink writer
resource "google_bigquery_dataset_iam_member" "sink_writer" {
  dataset_id = google_bigquery_dataset.audit_dataset.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.security_audit_sink.writer_identity
}

# Log sink for application logs
resource "google_logging_project_sink" "application_logs_sink" {
  name                   = "${var.project_name}-application-logs-sink"
  project                = var.project_id
  destination            = "storage.googleapis.com/${google_storage_bucket.audit_logs_bucket.name}"
  description            = "Sink for application audit logs"
  unique_writer_identity = true

  # Filter for application-specific logs
  filter = <<-EOT
    resource.type="k8s_container" AND
    resource.labels.project_id="${var.project_id}" AND
    (resource.labels.container_name="golang-app" OR
     resource.labels.container_name="golang-app-canary") AND
    (jsonPayload.level="ERROR" OR
     jsonPayload.level="WARN" OR
     httpRequest.status>=400 OR
     labels."k8s-pod/security.istio.io/tlsMode"="istio")
  EOT
}

# Cloud Storage bucket for application audit logs
resource "google_storage_bucket" "audit_logs_bucket" {
  name          = "${var.project_id}-audit-logs-${random_id.bucket_suffix.hex}"
  project       = var.project_id
  location      = var.audit_logs_location
  force_destroy = false

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = var.audit_log_retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    component   = "audit-logging"
    managed-by  = "terraform"
  }
}

# Random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Grant Storage Object Creator role to the application logs sink
resource "google_storage_bucket_iam_member" "application_logs_writer" {
  bucket = google_storage_bucket.audit_logs_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.application_logs_sink.writer_identity
}

# Log-based metrics for security monitoring
resource "google_logging_metric" "failed_authentication" {
  name    = "${var.project_name}-failed-authentication"
  project = var.project_id
  filter  = <<-EOT
    protoPayload.authenticationInfo.principalEmail!="" AND
    protoPayload.authorizationInfo.granted=false AND
    protoPayload.serviceName="container.googleapis.com"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "Failed Authentication Attempts"
  }

  # No label extractors to avoid descriptor mismatch
}

resource "google_logging_metric" "privilege_escalation" {
  name    = "${var.project_name}-privilege-escalation"
  project = var.project_id
  filter  = <<-EOT
    protoPayload.methodName:"setIamPolicy" OR
    protoPayload.methodName:"addBinding" OR
    (protoPayload.serviceName="container.googleapis.com" AND
     protoPayload.methodName:"create" AND
     protoPayload.request.nodePool.config.serviceAccount!="")
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "Privilege Escalation Events"
  }

  # No label extractors to avoid descriptor mismatch
}

resource "google_logging_metric" "data_access_anomaly" {
  name    = "${var.project_name}-data-access-anomaly"
  project = var.project_id
  filter  = <<-EOT
    protoPayload.serviceName="secretmanager.googleapis.com" AND
    protoPayload.methodName:"AccessSecretVersion" AND
    timestamp>="${var.baseline_timestamp}"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "Suspicious Data Access"
  }

  # No label extractors to avoid descriptor mismatch
}

resource "google_logging_metric" "high_privilege_operations" {
  name    = "${var.project_name}-high-privilege-ops"
  project = var.project_id
  filter  = <<-EOT
    (protoPayload.methodName:"delete" AND
     (protoPayload.serviceName="container.googleapis.com" OR
      protoPayload.serviceName="compute.googleapis.com")) OR
    (protoPayload.methodName:"setMetadata" AND
     protoPayload.serviceName="compute.googleapis.com") OR
    (protoPayload.serviceName="cloudkms.googleapis.com" AND
     protoPayload.methodName!:"get")
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "High Privilege Operations"
  }

  # No label extractors to avoid descriptor mismatch
}

# Alerting policies for security events
resource "google_monitoring_alert_policy" "failed_auth_alert" {
  display_name = "${var.project_name} - Failed Authentication Alert"
  project      = var.project_id
  combiner     = "OR"
  enabled      = var.enable_alerting

  conditions {
    display_name = "Failed authentication attempts"
    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.failed_authentication.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.failed_auth_threshold

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  documentation {
    content   = "Multiple failed authentication attempts detected. Investigate potential brute force attack."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "privilege_escalation_alert" {
  display_name = "${var.project_name} - Privilege Escalation Alert"
  project      = var.project_id
  combiner     = "OR"
  enabled      = var.enable_alerting

  conditions {
    display_name = "Privilege escalation detected"
    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.privilege_escalation.name}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  documentation {
    content   = "Privilege escalation event detected. Review IAM policy changes immediately."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_channels
}

# Dashboard for audit logging
resource "google_monitoring_dashboard" "audit_dashboard" {
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "${var.project_name} - Security Audit Dashboard"
    mosaicLayout = {
      columns = 24
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Failed Authentication Attempts"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.failed_authentication.name}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Failed Attempts/min"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Privilege Escalation Events"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.privilege_escalation.name}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Events/min"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 12
          height = 4
          yPos   = 4
          widget = {
            title = "High Privilege Operations"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.high_privilege_operations.name}\""
                    aggregation = {
                      alignmentPeriod  = "300s"
                      perSeriesAligner = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields = ["metric.label.service", "metric.label.operation"]
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Operations/5min"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}
