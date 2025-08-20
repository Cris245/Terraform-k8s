# Cloud Armor Security Policy for WAF
resource "google_compute_security_policy" "golang_app_policy" {
  name        = "${var.project_name}-security-policy"
  project     = var.project_id
  description = "Cloud Armor security policy for Golang HA application"

  # Rate limiting rule - Prevent DDoS attacks
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      rate_limit_threshold {
        count        = var.rate_limit_requests
        interval_sec = var.rate_limit_interval
      }
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      ban_duration_sec = var.ban_duration_sec
    }
    description = "Rate limiting to prevent DDoS attacks"
  }

  # Geo-based blocking (optional)
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = "1500"
      match {
        expr {
          expression = join(" || ", [for country in var.blocked_countries : "origin.region_code == '${country}'"])
        }
      }
      description = "Block traffic from specific countries"
    }
  }

  # SQL injection protection
  rule {
    action   = "deny(403)"
    priority = "2000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Protection against SQL injection attacks"
  }

  # Cross-site scripting (XSS) protection
  rule {
    action   = "deny(403)"
    priority = "2001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Protection against XSS attacks"
  }

  # Local file inclusion (LFI) protection
  rule {
    action   = "deny(403)"
    priority = "2002"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Protection against local file inclusion attacks"
  }

  # Remote code execution (RCE) protection
  rule {
    action   = "deny(403)"
    priority = "2003"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Protection against remote code execution attacks"
  }

  # Remote file inclusion (RFI) protection
  rule {
    action   = "deny(403)"
    priority = "2004"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
    description = "Protection against remote file inclusion attacks"
  }

  # Scanner detection
  rule {
    action   = "deny(403)"
    priority = "2005"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      }
    }
    description = "Protection against security scanners"
  }

  # Protocol attack protection
  rule {
    action   = "deny(403)"
    priority = "2006"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      }
    }
    description = "Protection against protocol attacks"
  }

  # Session fixation protection
  rule {
    action   = "deny(403)"
    priority = "2007"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sessionfixation-v33-stable')"
      }
    }
    description = "Protection against session fixation attacks"
  }

  # Method enforcement - Only allow specific HTTP methods
  rule {
    action   = "deny(405)"
    priority = "3000"
    match {
      expr {
        expression = join(" && ", [
          "request.method != 'GET'",
          "request.method != 'POST'", 
          "request.method != 'HEAD'",
          "request.method != 'OPTIONS'"
        ])
      }
    }
    description = "Allow only GET, POST, HEAD, and OPTIONS methods"
  }

  # Block known bad User-Agents
  dynamic "rule" {
    for_each = length(var.blocked_user_agents) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = "4000"
      match {
        expr {
          expression = join(" || ", [for ua in var.blocked_user_agents : "has(request.headers['user-agent']) && request.headers['user-agent'].lower().contains('${lower(ua)}')"])
        }
      }
      description = "Block malicious user agents"
    }
  }

  # Throttle requests to health endpoint (optional)
  dynamic "rule" {
    for_each = var.enable_health_check_throttling ? [1] : []
    content {
      action   = "throttle"
      priority = "5000"
      match {
        expr {
          expression = "request.path.startsWith('/health')"
        }
      }
      rate_limit_options {
        rate_limit_threshold {
          count        = 30
          interval_sec = 60
        }
        conform_action = "allow"
        exceed_action  = "deny(429)"
        enforce_on_key = "IP"
      }
      description = "Throttle health check requests"
    }
  }

  # Allow trusted IP ranges with higher priority
  dynamic "rule" {
    for_each = var.trusted_ip_ranges
    content {
      action   = "allow"
      priority = 500 + rule.key
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = [rule.value]
        }
      }
      description = "Allow trusted IP range: ${rule.value}"
    }
  }

  # Default allow rule (lowest priority)
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule - allow all traffic not caught by higher priority rules"
  }

  # Enable adaptive protection (ML-based DDoS protection)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = var.enable_adaptive_protection
      rule_visibility = "STANDARD"
    }
  }

  # Advanced DDoS protection settings
  advanced_options_config {
    json_parsing = "STANDARD"
    log_level    = "VERBOSE"
    user_ip_request_headers = [
      "X-Forwarded-For",
      "X-Real-IP",
      "X-Client-IP"
    ]
  }
}

# SSL Policy for enhanced security
resource "google_compute_ssl_policy" "golang_app_ssl_policy" {
  name            = "${var.project_name}-ssl-policy"
  project         = var.project_id
  description     = "SSL policy for Golang HA application"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
  
  custom_features = [
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
  ]
}

# Backend service configuration for WAF integration
resource "google_compute_backend_service" "golang_app_backend" {
  count                           = var.create_backend_service ? 1 : 0
  name                           = "${var.project_name}-backend-service"
  project                        = var.project_id
  description                    = "Backend service for Golang HA application with WAF"
  protocol                       = "HTTP"
  port_name                      = "http"
  timeout_sec                    = var.backend_timeout_sec
  connection_draining_timeout_sec = 300
  load_balancing_scheme          = "EXTERNAL"
  
  # Attach security policy
  security_policy = google_compute_security_policy.golang_app_policy.id

  backend {
    group                 = var.backend_neg_id
    balancing_mode        = "UTILIZATION"
    max_utilization       = 0.8
    capacity_scaler       = 1.0
  }

  health_checks = var.health_check_ids

  # Logging configuration
  log_config {
    enable      = true
    sample_rate = var.waf_log_sampling_rate
  }

  # Connection draining
  connection_draining_timeout_sec = 300

  # Circuit breaker settings
  circuit_breakers {
    max_requests_per_connection = 10
    max_connections             = 100
    max_pending_requests        = 10
    max_requests                = 100
    max_retries                 = 3
  }

  # Outlier detection
  outlier_detection {
    consecutive_errors                    = 5
    consecutive_gateway_failure_threshold = 3
    interval {
      seconds = 30
    }
    base_ejection_time {
      seconds = 30
    }
    max_ejection_percent = 50
    min_health_percent   = 50
  }
}

# URL map for routing (if needed)
resource "google_compute_url_map" "golang_app_url_map" {
  count           = var.create_url_map ? 1 : 0
  name            = "${var.project_name}-url-map"
  project         = var.project_id
  description     = "URL map for Golang HA application"
  default_service = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].id : var.default_backend_service

  # Health check path
  path_matcher {
    name            = "health-check-matcher"
    default_service = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].id : var.default_backend_service

    path_rule {
      paths   = ["/health", "/healthz"]
      service = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].id : var.default_backend_service
    }

    path_rule {
      paths   = ["/metrics"]
      service = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].id : var.default_backend_service
    }
  }

  host_rule {
    hosts        = var.allowed_hosts
    path_matcher = "health-check-matcher"
  }
}
