output "audit_dataset_id" {
  description = "BigQuery dataset ID for audit logs"
  value       = google_bigquery_dataset.audit_dataset.dataset_id
}

output "audit_dataset_name" {
  description = "BigQuery dataset name for audit logs"
  value       = google_bigquery_dataset.audit_dataset.friendly_name
}

output "audit_logs_bucket_name" {
  description = "Cloud Storage bucket name for audit logs"
  value       = google_storage_bucket.audit_logs_bucket.name
}

output "audit_logs_bucket_url" {
  description = "Cloud Storage bucket URL for audit logs"
  value       = google_storage_bucket.audit_logs_bucket.url
}

output "security_audit_sink_id" {
  description = "Security audit log sink ID"
  value       = google_logging_project_sink.security_audit_sink.id
}

output "security_audit_sink_writer_identity" {
  description = "Security audit log sink writer identity"
  value       = google_logging_project_sink.security_audit_sink.writer_identity
}

output "application_logs_sink_id" {
  description = "Application logs sink ID"
  value       = google_logging_project_sink.application_logs_sink.id
}

output "application_logs_sink_writer_identity" {
  description = "Application logs sink writer identity"
  value       = google_logging_project_sink.application_logs_sink.writer_identity
}

# Log-based metrics outputs
output "failed_authentication_metric_name" {
  description = "Failed authentication metric name"
  value       = google_logging_metric.failed_authentication.name
}

output "privilege_escalation_metric_name" {
  description = "Privilege escalation metric name"
  value       = google_logging_metric.privilege_escalation.name
}

output "data_access_anomaly_metric_name" {
  description = "Data access anomaly metric name"
  value       = google_logging_metric.data_access_anomaly.name
}

output "high_privilege_operations_metric_name" {
  description = "High privilege operations metric name"
  value       = google_logging_metric.high_privilege_operations.name
}

# Alert policy outputs
output "failed_auth_alert_policy_id" {
  description = "Failed authentication alert policy ID"
  value       = google_monitoring_alert_policy.failed_auth_alert.id
}

output "privilege_escalation_alert_policy_id" {
  description = "Privilege escalation alert policy ID"
  value       = google_monitoring_alert_policy.privilege_escalation_alert.id
}

# Dashboard output
output "audit_dashboard_id" {
  description = "Audit logging dashboard ID"
  value       = google_monitoring_dashboard.audit_dashboard.id
}

output "audit_dashboard_url" {
  description = "Audit logging dashboard URL"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.audit_dashboard.id}?project=${var.project_id}"
}

# Useful queries for manual investigation
output "useful_log_queries" {
  description = "Useful Cloud Logging queries for audit investigation"
  value = {
    failed_logins = "protoPayload.authenticationInfo.principalEmail!=\"\" AND protoPayload.authorizationInfo.granted=false"
    
    iam_changes = "protoPayload.methodName:(\"setIamPolicy\" OR \"addBinding\" OR \"removeBinding\")"
    
    resource_deletions = "protoPayload.methodName:\"delete\" AND (protoPayload.serviceName=\"container.googleapis.com\" OR protoPayload.serviceName=\"compute.googleapis.com\")"
    
    secret_access = "protoPayload.serviceName=\"secretmanager.googleapis.com\" AND protoPayload.methodName:\"AccessSecretVersion\""
    
    high_risk_operations = "protoPayload.methodName:(\"create\" OR \"delete\" OR \"update\") AND severity>=WARNING"
    
    network_changes = "protoPayload.serviceName=\"compute.googleapis.com\" AND protoPayload.methodName:(\"insert\" OR \"delete\" OR \"patch\") AND protoPayload.request.kind:(\"firewall\" OR \"network\" OR \"subnetwork\")"
    
    kubectl_operations = "resource.type=\"k8s_cluster\" AND protoPayload.methodName:(\"create\" OR \"delete\" OR \"update\" OR \"patch\")"
    
    vault_operations = "resource.labels.container_name=\"vault\" AND (jsonPayload.level=\"ERROR\" OR jsonPayload.level=\"WARN\")"
  }
}

# Compliance reporting queries
output "compliance_queries" {
  description = "Pre-built queries for compliance reporting"
  value = {
    # GDPR Article 30 - Records of processing activities
    data_processing_activities = "protoPayload.serviceName:(\"secretmanager.googleapis.com\" OR \"cloudkms.googleapis.com\") AND protoPayload.methodName:(\"AccessSecretVersion\" OR \"Decrypt\" OR \"Encrypt\")"
    
    # SOC 2 Type II - Access controls
    access_control_events = "protoPayload.methodName:(\"setIamPolicy\" OR \"addBinding\" OR \"removeBinding\" OR \"testIamPermissions\")"
    
    # PCI DSS - System access logging
    system_access_logs = "protoPayload.authenticationInfo.principalEmail!=\"\" AND timestamp>=timestamp_sub(timestamp(format_timestamp(\"%Y-%m-%d %H:%M:%S\", current_timestamp())), interval 24 hour)"
    
    # ISO 27001 - Information security incident management
    security_incidents = "severity>=ERROR AND (protoPayload.serviceName=\"container.googleapis.com\" OR protoPayload.serviceName=\"compute.googleapis.com\" OR protoPayload.serviceName=\"iam.googleapis.com\")"
  }
}

# Integration endpoints
output "log_export_configs" {
  description = "Configuration for external log export integrations"
  value = {
    bigquery_table = "${var.project_id}.${google_bigquery_dataset.audit_dataset.dataset_id}"
    storage_bucket = "gs://${google_storage_bucket.audit_logs_bucket.name}"
    pubsub_topic   = ""  # Can be added if needed for real-time processing
  }
}

# Monitoring URLs for easy access
output "monitoring_urls" {
  description = "Direct URLs for monitoring and investigation"
  value = {
    cloud_logging_console = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
    
    bigquery_console = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.audit_dataset.dataset_id}"
    
    storage_console = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.audit_logs_bucket.name}?project=${var.project_id}"
    
    monitoring_console = "https://console.cloud.google.com/monitoring?project=${var.project_id}"
    
    security_command_center = "https://console.cloud.google.com/security/command-center?project=${var.project_id}"
  }
}
