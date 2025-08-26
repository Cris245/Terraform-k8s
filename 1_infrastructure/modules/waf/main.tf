# Cloud Armor WAF Module
# Implements Web Application Firewall for the DevOps Challenge

# Enable Cloud Armor API
resource "google_project_service" "cloud_armor" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Cloud Armor Security Policy
resource "google_compute_security_policy" "waf_policy" {
  name    = var.waf_policy_name
  project = var.project_id

  # Rule 1: OWASP Top 10 Protection
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('owasp-crs-v030301-id942420-sqli') || evaluatePreconfiguredExpr('owasp-crs-v030301-id942200-sqli') || evaluatePreconfiguredExpr('owasp-crs-v030301-id942190-sqli') || evaluatePreconfiguredExpr('owasp-crs-v030301-id941160-xss') || evaluatePreconfiguredExpr('owasp-crs-v030301-id941100-xss') || evaluatePreconfiguredExpr('owasp-crs-v030301-id941110-xss')"
      }
    }
    description = "OWASP Top 10 Protection"
  }

  # Rule 2: Block malicious user agents
  rule {
    action   = "deny(403)"
    priority = "2000"
    match {
      expr {
        expression = "request.headers['user-agent'].contains('sqlmap') || request.headers['user-agent'].contains('nikto') || request.headers['user-agent'].contains('nmap') || request.headers['user-agent'].contains('masscan') || request.headers['user-agent'].contains('zap') || request.headers['user-agent'].contains('w3af') || request.headers['user-agent'].contains('dirbuster') || request.headers['user-agent'].contains('gobuster') || request.headers['user-agent'].contains('dirb') || request.headers['user-agent'].contains('burpsuite') || request.headers['user-agent'].contains('acunetix') || request.headers['user-agent'].contains('nessus')"
      }
    }
    description = "Block malicious user agents"
  }

  # Rule 3: Block unsafe HTTP methods
  rule {
    action   = "deny(405)"
    priority = "3000"
    match {
      expr {
        expression = "request.method == 'PUT' || request.method == 'PATCH' || request.method == 'DELETE' || request.method == 'TRACE' || request.method == 'CONNECT'"
      }
    }
    description = "Block unsafe HTTP methods"
  }

  # Rule 4: Rate limiting
  rule {
    action   = "rate_based_ban"
    priority = "4000"
    rate_limit_options {
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = 300
    }
    match {
      expr {
        expression = "true"
      }
    }
    description = "Rate limiting - 100 requests per minute per IP"
  }

  # Rule 5: Geographic blocking (optional)
  dynamic "rule" {
    for_each = var.waf_enable_geo_blocking ? [1] : []
    content {
      action   = "deny(403)"
      priority = "5000"
      match {
        expr {
          expression = "origin.region_code == 'CN' || origin.region_code == 'RU' || origin.region_code == 'KP'"
        }
      }
      description = "Geographic blocking for high-risk countries"
    }
  }

  # Default rule - allow all other traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      expr {
        expression = "true"
      }
    }
    description = "Default rule, higher priority overrides it"
  }
}


