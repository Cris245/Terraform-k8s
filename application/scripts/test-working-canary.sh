#!/bin/bash

# Working Canary Deployment Test
set -e

GATEWAY_IP="${1:-REPLACE_WITH_GATEWAY_IP}"
TOTAL_REQUESTS=${2:-100}

echo "🧪 Testing Working Canary Deployment"
echo "===================================="
echo "Gateway IP: $GATEWAY_IP"
echo "Total Requests: $TOTAL_REQUESTS"
echo "===================================="

# Test 1: Header-based canary routing
echo "📍 Test 1: Header-based Canary Routing"
echo "---------------------------------------"

canary_header_success=0
for i in {1..5}; do
    response=$(curl -s -H "canary: true" http://$GATEWAY_IP/ | grep -o "canary" || echo "")
    if [ "$response" = "canary" ]; then
        ((canary_header_success++))
        echo "✅ Request $i: Canary header routing working"
    else
        echo "❌ Request $i: Canary header routing failed"
    fi
done

echo "Canary header success rate: $canary_header_success/5"
echo ""

# Test 2: Traffic distribution (90% stable, 10% canary)
echo "📊 Test 2: Traffic Distribution Analysis"
echo "----------------------------------------"

stable_count=0
canary_count=0
unknown_count=0

for i in $(seq 1 $TOTAL_REQUESTS); do
    response=$(curl -s http://$GATEWAY_IP/ | grep -o "production\|canary" || echo "unknown")
    
    case $response in
        "production")
            ((stable_count++))
            ;;
        "canary")
            ((canary_count++))
            ;;
        *)
            ((unknown_count++))
            ;;
    esac
    
    if [ $((i % 20)) -eq 0 ]; then
        echo "Progress: $i/$TOTAL_REQUESTS - Stable: $stable_count, Canary: $canary_count, Unknown: $unknown_count"
    fi
done

# Calculate percentages
if [ $TOTAL_REQUESTS -gt 0 ]; then
    stable_percentage=$(( (stable_count * 100) / TOTAL_REQUESTS ))
    canary_percentage=$(( (canary_count * 100) / TOTAL_REQUESTS ))
    unknown_percentage=$(( (unknown_count * 100) / TOTAL_REQUESTS ))
else
    stable_percentage=0
    canary_percentage=0
    unknown_percentage=0
fi

echo ""
echo "📈 Final Traffic Distribution:"
echo "  Stable (production): $stable_count ($stable_percentage%)"
echo "  Canary: $canary_count ($canary_percentage%)"
echo "  Unknown: $unknown_count ($unknown_percentage%)"
echo ""

# Test 3: Health endpoints
echo "🏥 Test 3: Health Endpoint Validation"
echo "-------------------------------------"

# Test stable health
stable_health=$(curl -s http://$GATEWAY_IP/health)
if echo "$stable_health" | grep -q "healthy"; then
    echo "✅ Stable health endpoint: OK"
else
    echo "❌ Stable health endpoint: Failed"
    echo "   Response: $stable_health"
fi

# Test canary health with header
canary_health=$(curl -s -H "canary: true" http://$GATEWAY_IP/health)
if echo "$canary_health" | grep -q "healthy"; then
    echo "✅ Canary health endpoint: OK"
else
    echo "❌ Canary health endpoint: Failed"
    echo "   Response: $canary_health"
fi

# Test HTTPS
https_health=$(curl -s -k https://$GATEWAY_IP/health)
if echo "$https_health" | grep -q "healthy"; then
    echo "✅ HTTPS health endpoint: OK"
else
    echo "❌ HTTPS health endpoint: Failed"
    echo "   Response: $https_health"
fi

echo ""

# Test 4: Performance check
echo "⚡ Test 4: Performance Check"
echo "---------------------------"

# Measure response time
total_time=0
successful_requests=0

for i in {1..10}; do
    start_time=$(date +%s.%3N)
    response=$(curl -s http://$GATEWAY_IP/health)
    end_time=$(date +%s.%3N)
    
    if echo "$response" | grep -q "healthy"; then
        response_time=$(echo "$end_time - $start_time" | bc)
        response_time_ms=$(echo "$response_time * 1000" | bc)
        total_time=$(echo "$total_time + $response_time" | bc)
        ((successful_requests++))
        echo "Request $i: ${response_time_ms}ms"
    else
        echo "Request $i: Failed"
    fi
done

if [ $successful_requests -gt 0 ]; then
    avg_time=$(echo "scale=3; $total_time / $successful_requests" | bc)
    avg_time_ms=$(echo "$avg_time * 1000" | bc)
    echo "Average response time: ${avg_time_ms}ms"
fi

echo ""

# Summary
echo "🎯 Test Summary"
echo "==============="

tests_passed=0
total_tests=4

# Evaluate results
if [ $canary_header_success -eq 5 ]; then
    echo "✅ Header-based routing: PASSED"
    ((tests_passed++))
else
    echo "❌ Header-based routing: FAILED ($canary_header_success/5)"
fi

# Check if traffic distribution is reasonable (15-30% for canary with 20% target)
if [ $canary_percentage -ge 15 ] && [ $canary_percentage -le 30 ]; then
    echo "✅ Traffic distribution: PASSED ($canary_percentage% canary)"
    ((tests_passed++))
else
    echo "❌ Traffic distribution: FAILED ($canary_percentage% canary, expected 15-30%)"
fi

if echo "$stable_health $canary_health $https_health" | grep -q "healthy.*healthy.*healthy"; then
    echo "✅ Health endpoints: PASSED"
    ((tests_passed++))
else
    echo "❌ Health endpoints: FAILED"
fi

if [ $successful_requests -eq 10 ]; then
    echo "✅ Performance: PASSED"
    ((tests_passed++))
else
    echo "❌ Performance: FAILED ($successful_requests/10 successful)"
fi

echo ""
echo "Overall: $tests_passed/$total_tests tests passed"

if [ $tests_passed -eq $total_tests ]; then
    echo "🎉 All canary tests PASSED! Canary deployment is working correctly."
    exit 0
else
    echo "❌ Some tests FAILED. Canary deployment needs attention."
    exit 1
fi
