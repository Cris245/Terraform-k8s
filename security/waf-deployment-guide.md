# WAF (Cloud Armor) Deployment Guide

## Overview

This guide explains how to deploy and configure the Web Application Firewall (WAF) using Google Cloud Armor for the Golang HA server infrastructure.

## Architecture

The WAF implementation uses:
- **Google Cloud Armor** for security policies and attack protection
- **GCP Load Balancer** for traffic routing and SSL termination
- **Istio Gateway** for service mesh traffic management
- **Network Policies** for additional cluster-level security

## Deployment Steps

### 1. Deploy Infrastructure with WAF

The WAF module is integrated into the main Terraform configuration:

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

This creates:
- Cloud Armor security policy with comprehensive rules
- SSL policy with modern TLS configuration
- Required GCP APIs and IAM permissions

### 2. Apply Kubernetes WAF Configuration

```bash
# Apply WAF-specific Kubernetes resources
kubectl apply -f application/k8s-manifests/waf-config.yaml

# Verify deployment
kubectl get backendconfig -n istio-system
kubectl get ingress -n istio-system
kubectl get managedcertificate -n istio-system
```

### 3. Configure Istio Gateway for WAF Integration

The Istio Gateway needs to be configured to work with the GCP Load Balancer:

```bash
# Apply updated gateway configuration
kubectl apply -f application/istio-config/gateway.yaml

# Verify Istio configuration
kubectl get gateway -n golang-app
kubectl get virtualservice -n golang-app
```

## WAF Rules and Protection

### Enabled Protections

1. **Rate Limiting**
   - 100 requests per minute per IP
   - 10-minute ban for violations
   - Configurable thresholds

2. **OWASP Top 10 Protection**
   - SQL Injection (SQLi)
   - Cross-Site Scripting (XSS)
   - Local File Inclusion (LFI)
   - Remote Code Execution (RCE)
   - Remote File Inclusion (RFI)

3. **Attack Detection**
   - Security scanner detection
   - Protocol attack protection
   - Session fixation protection

4. **Method Enforcement**
   - Only allows GET, POST, HEAD, OPTIONS
   - Blocks dangerous HTTP methods

5. **User Agent Filtering**
   - Blocks known malicious tools
   - Customizable blocked agent list

6. **Adaptive Protection**
   - ML-based DDoS protection
   - Automatic threat detection

### Geographic Restrictions (Optional)

Configure country-level blocking:

```hcl
# In terraform.tfvars
waf_blocked_countries = ["CN", "RU", "KP"]  # Example
```

### Trusted IP Ranges

Whitelist trusted IP ranges:

```hcl
# In terraform.tfvars
waf_trusted_ip_ranges = ["10.0.0.0/8", "172.16.0.0/12"]
```

## Monitoring and Logging

### View WAF Logs

```bash
# View Cloud Armor logs
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.name="golang-ha-security-policy"'

# View WAF metrics in Cloud Monitoring
gcloud monitoring metrics list --filter="metric.type:loadbalancing.googleapis.com/https/backend_request_count"
```

### Key Metrics to Monitor

1. **Request Count by Rule**
   - `loadbalancing.googleapis.com/https/backend_request_count`
   - Filter by `security_policy_rule_name`

2. **Blocked Requests**
   - `loadbalancing.googleapis.com/https/request_count`
   - Filter by `response_code` 403, 429

3. **Rate Limiting Events**
   - Monitor for status codes 429
   - Track ban duration effectiveness

## Testing WAF Rules

### Test Rate Limiting

```bash
# Generate rapid requests to trigger rate limiting
for i in {1..150}; do
  curl -w "%{http_code}\n" -o /dev/null -s http://YOUR_LB_IP/
  sleep 0.1
done
```

### Test Security Rules

```bash
# Test SQL injection protection
curl "http://YOUR_LB_IP/?id=1' OR '1'='1"

# Test XSS protection  
curl "http://YOUR_LB_IP/?search=<script>alert('xss')</script>"

# Test blocked user agent
curl -H "User-Agent: sqlmap/1.0" http://YOUR_LB_IP/
```

### Expected Responses

- **Rate limiting**: HTTP 429 (Too Many Requests)
- **Security rules**: HTTP 403 (Forbidden)
- **Valid requests**: HTTP 200 (OK)

## Troubleshooting

### Common Issues

1. **Ingress Not Getting External IP**
   ```bash
   # Check ingress status
   kubectl describe ingress waf-ingress -n istio-system
   
   # Check global IP allocation
   gcloud compute addresses list --global
   ```

2. **BackendConfig Not Applied**
   ```bash
   # Check backend config
   kubectl describe backendconfig waf-backend-config -n istio-system
   
   # Check service annotations
   kubectl describe service istio-ingressgateway -n istio-system
   ```

3. **SSL Certificate Issues**
   ```bash
   # Check managed certificate status
   kubectl describe managedcertificate golang-ha-ssl-cert -n istio-system
   
   # Verify domain DNS pointing to load balancer IP
   nslookup golang-ha.example.com
   ```

### Verification Commands

```bash
# Check WAF policy status
gcloud compute security-policies describe golang-ha-security-policy

# Verify SSL policy
gcloud compute ssl-policies describe golang-ha-ssl-policy

# Test end-to-end connectivity
curl -v https://YOUR_DOMAIN/health
```

## Performance Considerations

### Latency Impact

- Cloud Armor adds ~1-5ms latency
- SSL termination adds ~2-10ms
- Total overhead: typically <15ms

### Throughput

- Rate limiting: 100 req/min per IP by default
- Adjust based on legitimate traffic patterns
- Monitor and tune thresholds

### Cost Optimization

```hcl
# Reduce logging costs
waf_log_sampling_rate = 0.01  # 1% sampling

# Optimize rule evaluation
# More specific rules have higher priority
```

## Advanced Configuration

### Custom WAF Rules

Add custom rules via Terraform:

```hcl
# In terraform.tfvars
waf_custom_rules = [
  {
    action      = "deny(403)"
    priority    = 1500
    expression  = "origin.region_code == 'CN'"
    description = "Block traffic from China"
  }
]
```

### Integration with Monitoring

```yaml
# Add to prometheus monitoring
- alert: WAFHighBlockedRequests
  expr: rate(blocked_requests_total[5m]) > 10
  labels:
    severity: warning
  annotations:
    summary: "High number of blocked requests"
```

## Security Best Practices

1. **Regular Rule Updates**
   - Monitor OWASP threat reports
   - Update rules based on attack patterns
   - Test changes in staging first

2. **Logging and Monitoring**
   - Enable comprehensive logging
   - Set up alerting for attack patterns
   - Regular security audits

3. **Performance Tuning**
   - Monitor latency impact
   - Adjust rate limiting based on traffic
   - Optimize rule ordering

4. **Backup Plans**
   - Document rule changes
   - Have rollback procedures
   - Test disaster recovery

This WAF implementation provides enterprise-grade protection while maintaining high performance and availability for the Golang HA server.
