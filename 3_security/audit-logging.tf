# Audit Logging Configuration for Production Security
# Implements comprehensive audit logging system

resource "google_logging_project_sink" "security_audit_sink" {
  name = "security-audit-sink"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/security_audit_logs"
  
  filter = <<EOF
protoPayload.serviceName=("iam.googleapis.com" OR "container.googleapis.com" OR "compute.googleapis.com")
AND (
  protoPayload.methodName:("setIamPolicy" OR "createRole" OR "deleteRole" OR "createServiceAccount" OR "deleteServiceAccount")
  OR protoPayload.authenticationInfo.principalEmail!=""
  OR severity>=ERROR
)
EOF

  unique_writer_identity = true
}

resource "google_bigquery_dataset" "security_audit_logs" {
  dataset_id = "security_audit_logs"
  location   = "US"
  
  labels = {
    security = "audit"
    compliance = "required"
  }
}

# Log metrics for security monitoring
resource "google_logging_metric" "failed_authentication" {
  name   = "failed_authentication_attempts"
  filter = <<EOF
protoPayload.serviceName="iam.googleapis.com"
AND protoPayload.authenticationInfo.principalEmail!=""
AND protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"
AND protoPayload.status.code!=0
EOF

  metric_descriptor {
    metric_kind = "COUNTER"
    value_type  = "INT64"
    display_name = "Failed Authentication Attempts"
  }
}

resource "google_logging_metric" "privilege_escalation" {
  name   = "privilege_escalation_attempts"
  filter = <<EOF
protoPayload.serviceName="iam.googleapis.com"
AND protoPayload.methodName:("setIamPolicy" OR "createRole" OR "deleteRole")
AND protoPayload.authenticationInfo.principalEmail!=""
EOF

  metric_descriptor {
    metric_kind = "COUNTER"
    value_type  = "INT64"
    display_name = "Privilege Escalation Attempts"
  }
}

resource "google_logging_metric" "container_security_events" {
  name   = "container_security_events"
  filter = <<EOF
protoPayload.serviceName="container.googleapis.com"
AND (
  protoPayload.methodName:("createCluster" OR "deleteCluster" OR "setNodePoolManagement")
  OR protoPayload.request.cluster.name!=""
)
EOF

  metric_descriptor {
    metric_kind = "COUNTER"
    value_type  = "INT64"
    display_name = "Container Security Events"
  }
}

# Alert policies for security events
resource "google_monitoring_alert_policy" "failed_auth_alert" {
  display_name = "High Failed Authentication Rate"
  combiner     = "OR"
  
  conditions {
    display_name = "Failed authentication threshold"
    
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/failed_authentication_attempts\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.security_alerts.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_notification_channel" "security_alerts" {
  display_name = "Security Alerts"
  type         = "email"
  
  labels = {
    email_address = "security-team@company.com"
  }
}

# IAM audit configuration
resource "google_project_iam_audit_config" "security_audit" {
  project = var.project_id
  service = "allServices"
  
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  
  audit_log_config {
    log_type = "DATA_READ"
  }
  
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Log router for real-time security monitoring
resource "google_logging_project_sink" "realtime_security_sink" {
  name = "realtime-security-sink"
  destination = "pubsub.googleapis.com/projects/${var.project_id}/topics/security-events"
  
  filter = <<EOF
severity>=ERROR
AND (
  protoPayload.serviceName:("iam.googleapis.com" OR "container.googleapis.com")
  OR resource.type="k8s_cluster"
  OR resource.type="gce_instance"
)
EOF

  unique_writer_identity = true
}

resource "google_pubsub_topic" "security_events" {
  name = "security-events"
  
  labels = {
    security = "realtime-monitoring"
  }
}

# Variables
variable "project_id" {
  description = "GCP project ID"
  type        = string
}
