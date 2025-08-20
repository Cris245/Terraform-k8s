#!/bin/bash

# Automated Rollback Script with Health Monitoring
set -e

NAMESPACE=${1:-golang-app}
DEPLOYMENT=${2:-golang-app}
GATEWAY_IP=${3:-REPLACE_WITH_GATEWAY_IP}
HEALTH_CHECK_RETRIES=${4:-5}
HEALTH_CHECK_INTERVAL=${5:-30}

echo "🔄 Automated Rollback Script"
echo "============================"
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT"
echo "Gateway IP: $GATEWAY_IP"
echo "Health Check Retries: $HEALTH_CHECK_RETRIES"
echo "Health Check Interval: ${HEALTH_CHECK_INTERVAL}s"
echo "============================"

# Function to check deployment health
check_deployment_health() {
    local retries=0
    
    while [ $retries -lt $HEALTH_CHECK_RETRIES ]; do
        echo "🏥 Health check attempt $((retries + 1))/$HEALTH_CHECK_RETRIES"
        
        # Check if deployment is ready
        if kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q "^[1-9]"; then
            echo "✅ Deployment has ready replicas"
            
            # Check health endpoint
            if curl -f -s http://$GATEWAY_IP/health > /dev/null; then
                echo "✅ Health endpoint responding"
                return 0
            else
                echo "❌ Health endpoint not responding"
            fi
        else
            echo "❌ No ready replicas found"
        fi
        
        ((retries++))
        if [ $retries -lt $HEALTH_CHECK_RETRIES ]; then
            echo "⏳ Waiting ${HEALTH_CHECK_INTERVAL}s before next check..."
            sleep $HEALTH_CHECK_INTERVAL
        fi
    done
    
    echo "❌ Health checks failed after $HEALTH_CHECK_RETRIES attempts"
    return 1
}

# Function to get current deployment revision
get_current_revision() {
    kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
}

# Function to get previous revision
get_previous_revision() {
    current_revision=$(get_current_revision)
    previous_revision=$((current_revision - 1))
    echo $previous_revision
}

# Function to perform rollback
perform_rollback() {
    echo "🔄 Performing rollback..."
    
    current_revision=$(get_current_revision)
    previous_revision=$(get_previous_revision)
    
    echo "Current revision: $current_revision"
    echo "Rolling back to revision: $previous_revision"
    
    # Perform rollback to previous revision
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
    
    # Wait for rollback to complete
    echo "⏳ Waiting for rollback to complete..."
    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=300s
    
    # Check if rollback was successful
    new_revision=$(get_current_revision)
    if [ "$new_revision" != "$current_revision" ]; then
        echo "✅ Rollback completed successfully (revision: $new_revision)"
        return 0
    else
        echo "❌ Rollback failed - revision unchanged"
        return 1
    fi
}

# Function to check error rate from Prometheus
check_error_rate() {
    echo "📊 Checking error rate from Prometheus..."
    
    # Get Prometheus service IP
    PROMETHEUS_IP=$(kubectl get service -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$PROMETHEUS_IP" ]; then
        echo "⚠️  Prometheus not accessible, skipping error rate check"
        return 0
    fi
    
    # Query for 5xx error rate in the last 5 minutes
    query="rate(http_requests_total{code=~\"5..\"}[5m]) / rate(http_requests_total[5m]) * 100"
    response=$(curl -s "http://$PROMETHEUS_IP:9090/api/v1/query?query=$query")
    
    if echo "$response" | grep -q "success"; then
        # Extract error rate (simplified - in production you'd parse JSON properly)
        error_rate=$(echo "$response" | grep -o '"value":\[[^]]*\]' | grep -o '[0-9.]*' | tail -1)
        
        if [ -n "$error_rate" ]; then
            echo "Current 5xx error rate: ${error_rate}%"
            
            # If error rate > 5%, trigger rollback
            if (( $(echo "$error_rate > 5" | bc -l) 2>/dev/null )); then
                echo "❌ High error rate detected (${error_rate}% > 5%)"
                return 1
            else
                echo "✅ Error rate within acceptable limits (${error_rate}% <= 5%)"
                return 0
            fi
        fi
    fi
    
    echo "⚠️  Could not determine error rate"
    return 0
}

# Function to check response time
check_response_time() {
    echo "⏱️  Checking response time..."
    
    total_time=0
    successful_requests=0
    max_response_time=2000  # 2 seconds in milliseconds
    
    for i in {1..10}; do
        response_time=$(curl -w "%{time_total}\n" -o /dev/null -s http://$GATEWAY_IP/health)
        response_time_ms=$(echo "$response_time * 1000" | bc)
        
        if [ $? -eq 0 ]; then
            total_time=$(echo "$total_time + $response_time" | bc)
            ((successful_requests++))
            echo "Request $i: ${response_time_ms}ms"
            
            # Check if individual request is too slow
            if (( $(echo "$response_time_ms > $max_response_time" | bc -l) )); then
                echo "❌ Slow response detected (${response_time_ms}ms > ${max_response_time}ms)"
                return 1
            fi
        else
            echo "❌ Request $i failed"
            return 1
        fi
    done
    
    if [ $successful_requests -gt 0 ]; then
        avg_time=$(echo "scale=3; $total_time / $successful_requests" | bc)
        avg_time_ms=$(echo "$avg_time * 1000" | bc)
        echo "Average response time: ${avg_time_ms}ms"
        
        if (( $(echo "$avg_time_ms <= $max_response_time" | bc -l) )); then
            echo "✅ Response time within acceptable limits"
            return 0
        else
            echo "❌ Average response time too high (${avg_time_ms}ms > ${max_response_time}ms)"
            return 1
        fi
    else
        echo "❌ No successful requests"
        return 1
    fi
}

# Function to send notifications
send_notification() {
    local status=$1
    local message=$2
    
    echo "📢 Notification: $message"
    
    # In production, you would send to Slack, email, PagerDuty, etc.
    # For now, just log to kubectl events
    kubectl create event rollback-$status \
        --namespace=$NAMESPACE \
        --message="$message" \
        --reason="AutomatedRollback" \
        --type="Warning" 2>/dev/null || true
    
    # Log to deployment annotations
    kubectl annotate deployment $DEPLOYMENT -n $NAMESPACE \
        "rollback.timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "rollback.status=$status" \
        "rollback.message=$message" \
        --overwrite=true 2>/dev/null || true
}

# Function to cleanup failed canary
cleanup_canary() {
    echo "🧹 Cleaning up canary deployment..."
    
    # Remove canary deployment and service
    kubectl delete deployment golang-app-canary -n $NAMESPACE --ignore-not-found=true
    kubectl delete service golang-app-canary-service -n $NAMESPACE --ignore-not-found=true
    
    # Reset traffic routing to stable
    kubectl apply -f ../application/istio-config/virtual-service.yaml
    
    echo "✅ Canary cleanup completed"
}

# Main rollback logic
main() {
    echo "🚀 Starting automated health monitoring and rollback check"
    
    # Initial health check
    if ! check_deployment_health; then
        echo "❌ Initial health check failed - triggering rollback"
        
        # Perform rollback
        if perform_rollback; then
            send_notification "success" "Automatic rollback completed successfully due to health check failure"
            
            # Wait and verify rollback health
            sleep 30
            if check_deployment_health; then
                echo "✅ Post-rollback health check passed"
                cleanup_canary
                exit 0
            else
                send_notification "failed" "Post-rollback health check failed"
                exit 1
            fi
        else
            send_notification "failed" "Automatic rollback failed"
            exit 1
        fi
    fi
    
    # Check error rate
    if ! check_error_rate; then
        echo "❌ Error rate check failed - triggering rollback"
        
        if perform_rollback; then
            send_notification "success" "Automatic rollback completed due to high error rate"
            cleanup_canary
            exit 0
        else
            send_notification "failed" "Rollback failed after error rate threshold exceeded"
            exit 1
        fi
    fi
    
    # Check response time
    if ! check_response_time; then
        echo "❌ Response time check failed - triggering rollback"
        
        if perform_rollback; then
            send_notification "success" "Automatic rollback completed due to poor response times"
            cleanup_canary
            exit 0
        else
            send_notification "failed" "Rollback failed after response time threshold exceeded"
            exit 1
        fi
    fi
    
    echo "✅ All checks passed - no rollback needed"
    send_notification "healthy" "Deployment health monitoring completed successfully"
    exit 0
}

# Check if running directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
