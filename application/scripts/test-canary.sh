#!/bin/bash

# Canary Deployment Test Script
# This script tests the canary deployment to ensure it's working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to test canary deployment
test_canary() {
    print_status "Testing canary deployment..."
    
    # Get canary service IP
    local canary_ip=$(kubectl get service golang-app-canary-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$canary_ip" ]; then
        print_error "Canary service IP not available"
        return 1
    fi
    
    print_status "Canary service IP: $canary_ip"
    
    # Test health endpoint
    print_status "Testing health endpoint..."
    local health_response=$(curl -s -o /dev/null -w "%{http_code}" http://$canary_ip/health)
    
    if [ "$health_response" = "200" ]; then
        print_success "Health endpoint is working"
    else
        print_error "Health endpoint returned $health_response"
        return 1
    fi
    
    # Test main endpoint
    print_status "Testing main endpoint..."
    local main_response=$(curl -s -o /dev/null -w "%{http_code}" http://$canary_ip/)
    
    if [ "$main_response" = "200" ]; then
        print_success "Main endpoint is working"
    else
        print_error "Main endpoint returned $main_response"
        return 1
    fi
    
    # Test metrics endpoint
    print_status "Testing metrics endpoint..."
    local metrics_response=$(curl -s -o /dev/null -w "%{http_code}" http://$canary_ip/metrics)
    
    if [ "$metrics_response" = "200" ]; then
        print_success "Metrics endpoint is working"
    else
        print_error "Metrics endpoint returned $metrics_response"
        return 1
    fi
    
    # Load test
    print_status "Running load test..."
    for i in {1..10}; do
        curl -s http://$canary_ip/ > /dev/null &
    done
    wait
    
    print_success "Load test completed"
    
    # Check pod logs
    print_status "Checking canary pod logs..."
    kubectl logs -l app=golang-app-canary --tail=10
    
    print_success "Canary deployment test completed successfully"
}

# Function to test production deployment
test_production() {
    print_status "Testing production deployment..."
    
    # Get production service IP
    local prod_ip=$(kubectl get service golang-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$prod_ip" ]; then
        print_error "Production service IP not available"
        return 1
    fi
    
    print_status "Production service IP: $prod_ip"
    
    # Test health endpoint
    print_status "Testing health endpoint..."
    local health_response=$(curl -s -o /dev/null -w "%{http_code}" http://$prod_ip/health)
    
    if [ "$health_response" = "200" ]; then
        print_success "Health endpoint is working"
    else
        print_error "Health endpoint returned $health_response"
        return 1
    fi
    
    # Test main endpoint
    print_status "Testing main endpoint..."
    local main_response=$(curl -s -o /dev/null -w "%{http_code}" http://$prod_ip/)
    
    if [ "$main_response" = "200" ]; then
        print_success "Main endpoint is working"
    else
        print_error "Main endpoint returned $main_response"
        return 1
    fi
    
    # Test metrics endpoint
    print_status "Testing metrics endpoint..."
    local metrics_response=$(curl -s -o /dev/null -w "%{http_code}" http://$prod_ip/metrics)
    
    if [ "$metrics_response" = "200" ]; then
        print_success "Metrics endpoint is working"
    else
        print_error "Metrics endpoint returned $metrics_response"
        return 1
    fi
    
    # Load test
    print_status "Running load test..."
    for i in {1..20}; do
        curl -s http://$prod_ip/ > /dev/null &
    done
    wait
    
    print_success "Load test completed"
    
    # Check pod logs
    print_status "Checking production pod logs..."
    kubectl logs -l app=golang-app --tail=10
    
    print_success "Production deployment test completed successfully"
}

# Main function
main() {
    echo "🧪 Deployment Test Script"
    echo "========================"
    echo
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    # Test based on argument
    case "${1:-canary}" in
        "canary")
            test_canary
            ;;
        "production")
            test_production
            ;;
        "both")
            test_canary
            echo
            test_production
            ;;
        *)
            print_error "Invalid argument. Use: canary, production, or both"
            exit 1
            ;;
    esac
    
    print_success "All tests completed successfully!"
}

# Run main function
main "$@"
