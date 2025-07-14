#!/bin/bash

# Removed: set -e  (so script continues even if some commands fail)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_BASE_URL="http://localhost:8443/api"
VAULT_URL="http://localhost:8200"
TRAEFIK_URL="http://localhost:8080"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

test_service() {
    local service_name="$1"
    local url="$2"
    local expected_status="$3"
    
    log_info "Testing $service_name..."
    ((TOTAL_TESTS++))
    
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status" = "$expected_status" ]; then
        log_success "$service_name is responding (HTTP $status)"
    else
        log_error "$service_name failed (Expected: $expected_status, Got: $status)"
    fi
}

test_json_response() {
    local service_name="$1"
    local url="$2"
    local expected_field="$3"
    
    log_info "Testing $service_name JSON response..."
    ((TOTAL_TESTS++))
    
    local response=$(curl -s "$url" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e ".$expected_field" >/dev/null 2>&1; then
        log_success "$service_name returned valid JSON with field '$expected_field'"
    else
        log_error "$service_name JSON response invalid or missing field '$expected_field'"
        echo "Response: $response"
    fi
}

test_database_connection() {
    log_info "Testing PostgreSQL connection..."
    ((TOTAL_TESTS++))
    
    if docker exec postgres pg_isready -U postgres -d devops_assesment >/dev/null 2>&1; then
        log_success "PostgreSQL is accepting connections"
    else
        log_error "PostgreSQL connection failed"
    fi
}

test_vault_functionality() {
    log_info "Testing Vault secret retrieval..."
    ((TOTAL_TESTS++))
    
    local secret=$(curl -s -H "X-Vault-Token: myroot" \
        "$VAULT_URL/v1/secret/data/database" 2>/dev/null | \
        jq -r '.data.data.username' 2>/dev/null || echo "failed")
    
    if [ "$secret" = "postgres" ]; then
        log_success "Vault secret retrieval working"
    else
        log_error "Vault secret retrieval failed (got: $secret)"
    fi
}

test_api_endpoints() {
    log_info "Testing API endpoints..."
    
    # Test health endpoint
    test_service "Health Endpoint" "$API_BASE_URL/health" "200"
    test_json_response "Health Endpoint" "$API_BASE_URL/health" "status"
    
    # Test users endpoint
    test_service "Users Endpoint" "$API_BASE_URL/users" "200"
    
    # Test user creation
    log_info "Testing user creation..."
    ((TOTAL_TESTS++))
    
    local timestamp=$(date +%s)
    local test_user="testuser_$timestamp"
    local test_email="test_$timestamp@example.com"
    
    local create_response=$(curl -s -X POST "$API_BASE_URL/users" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$test_user\",\"email\":\"$test_email\"}" \
        -w "%{http_code}" 2>/dev/null || echo "000")
    
    local status_code="${create_response: -3}"
    local response_body="${create_response%???}"
    
    if [ "$status_code" = "201" ]; then
        log_success "User creation successful"
        
        # Verify user was created
        log_info "Verifying created user..."
        ((TOTAL_TESTS++))
        
        local user_list=$(curl -s "$API_BASE_URL/users" 2>/dev/null || echo "[]")
        if echo "$user_list" | jq -e ".[] | select(.username==\"$test_user\")" >/dev/null 2>&1; then
            log_success "Created user found in user list"
        else
            log_error "Created user not found in user list"
        fi
    else
        log_error "User creation failed (HTTP $status_code)"
        echo "Response: $response_body"
    fi
}

test_docker_services() {
    log_info "Testing Docker services..."
    
    local services=("traefik" "postgres" "vault" "backend")
    
    for service in "${services[@]}"; do
        log_info "Checking Docker service: $service"
        ((TOTAL_TESTS++))
        
        local container_check=$(docker ps --filter "name=$service" --filter "status=running" --format "{{.Names}}" 2>/dev/null || echo "")
        
        if echo "$container_check" | grep -q "$service"; then
            log_success "Docker service '$service' is running"
        else
            log_error "Docker service '$service' is not running"
            echo "Debug: container_check result: '$container_check'"
        fi
    done
}

test_traefik_routing() {
    log_info "Testing Traefik routing..."
    
    # Test Traefik dashboard
    test_service "Traefik Dashboard" "$TRAEFIK_URL/api/overview" "200"
    
    # Test if backend is registered in Traefik
    ((TOTAL_TESTS++))
    local traefik_services=$(curl -s "$TRAEFIK_URL/api/http/services" 2>/dev/null || echo "[]")
    
    if echo "$traefik_services" | jq -e '.[] | select(.name | contains("backend"))' >/dev/null 2>&1; then
        log_success "Backend service registered in Traefik"
    else
        log_error "Backend service not found in Traefik"
    fi
}

test_security() {
    log_info "Testing security measures..."
    
    # Test SQL injection protection
    ((TOTAL_TESTS++))
    local malicious_payload="'; DROP TABLE users; --"
    local injection_response=$(curl -s -X POST "$API_BASE_URL/users" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$malicious_payload\",\"email\":\"test@example.com\"}" \
        -w "%{http_code}" 2>/dev/null || echo "000")
    
    local injection_status="${injection_response: -3}"
    
    if [ "$injection_status" != "500" ]; then
        log_success "SQL injection protection working"
    else
        log_error "Potential SQL injection vulnerability"
    fi
    
    # Test invalid input handling
    ((TOTAL_TESTS++))
    local invalid_response=$(curl -s -X POST "$API_BASE_URL/users" \
        -H "Content-Type: application/json" \
        -d "{\"invalid\":\"data\"}" \
        -w "%{http_code}" 2>/dev/null || echo "000")
    
    local invalid_status="${invalid_response: -3}"
    
    if [ "$invalid_status" = "400" ]; then
        log_success "Input validation working"
    else
        log_error "Input validation not working properly (got HTTP $invalid_status)"
    fi
}

cleanup_test_data() {
    log_info "Cleaning up test data..."
    
    # Remove test users created during testing
    local users=$(curl -s "$API_BASE_URL/users" 2>/dev/null || echo "[]")
    local test_user_count=$(echo "$users" | jq '[.[] | select(.username | startswith("testuser_"))] | length' 2>/dev/null || echo "0")
    
    if [ "$test_user_count" -gt 0 ]; then
        log_info "Found $test_user_count test users (cleanup would require DELETE endpoint)"
    fi
}

run_performance_test() {
    log_info "Running basic performance test..."
    ((TOTAL_TESTS++))
    
    local start_time=$(date +%s%N)
    for i in {1..10}; do
        curl -s "$API_BASE_URL/health" >/dev/null 2>&1 || true
    done
    local end_time=$(date +%s%N)
    
    local duration=$(((end_time - start_time) / 1000000)) # Convert to milliseconds
    local avg_response=$((duration / 10))
    
    if [ "$avg_response" -lt 500 ]; then
        log_success "Performance test passed (avg: ${avg_response}ms per request)"
    else
        log_warning "Performance test slower than expected (avg: ${avg_response}ms per request)"
    fi
}

generate_report() {
    echo ""
    echo "=================================================="
    echo "             TEST RESULTS SUMMARY"
    echo "=================================================="
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [ "$TOTAL_TESTS" -gt 0 ]; then
        local success_rate=$((TESTS_PASSED * 100 / TOTAL_TESTS))
        echo "Success Rate: $success_rate%"
    else
        echo "Success Rate: 0% (No tests completed)"
    fi
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_PASSED -gt 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Infrastructure is healthy.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed or incomplete. Please check the output above.${NC}"
        exit 1
    fi
}

# Main test execution
main() {
    echo "=================================================="
    echo "        DevOps assesment Infrastructure Test"
    echo "=================================================="
    echo ""
    
    log_info "Starting comprehensive infrastructure tests..."
    echo ""
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 5
    
    # Run tests
    test_docker_services
    echo ""
    
    test_database_connection
    echo ""
    
    test_vault_functionality
    echo ""
    
    test_traefik_routing
    echo ""
    
    test_api_endpoints
    echo ""
    
    test_security
    echo ""
    
    run_performance_test
    echo ""
    
    cleanup_test_data
    echo ""
    
    generate_report
}

# Check dependencies
check_dependencies() {
    local deps=("curl" "jq" "docker")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Run dependency check and main function
check_dependencies
main