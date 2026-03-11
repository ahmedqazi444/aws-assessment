#!/bin/bash
#===============================================================================
# Unleash Live - Deployment Test Script
#
# This script validates the multi-region deployment by:
# 1. Authenticating with Cognito (us-east-1) to retrieve a JWT
# 2. Concurrently calling /greet in both regions
# 3. Concurrently calling /dispatch in both regions
# 4. Asserting response regions match expected regions
# 5. Measuring and displaying latency for geographic comparison
#
# Usage:
#   ./test_deployment.sh                    # Auto-detect config from terraform
#   ./test_deployment.sh --config file.json # Use config file
#   
# Generate config: terraform output -json test_config > test_config.json
#===============================================================================

set -uo pipefail

# Set AWS profile if not already set (optional - uses default credential chain if not set)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${AWS_PROFILE:-}" ]; then
    TFVARS="$SCRIPT_DIR/../environments/dev/terraform.tfvars"
    if [ -f "$TFVARS" ]; then
        PROFILE=$(grep 'aws_profile' "$TFVARS" 2>/dev/null | sed 's/.*= *"\([^"]*\)".*/\1/')
        if [ -n "$PROFILE" ]; then
            export AWS_PROFILE="$PROFILE"
        fi
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "\n${CYAN}[$1]${NC} $2"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_failure() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${YELLOW}ℹ${NC} $1"
}

#-------------------------------------------------------------------------------
# Test Function
#-------------------------------------------------------------------------------

call_endpoint() {
    local url="$1"
    local method="$2"
    local expected_region="$3"
    local label="$4"
    local token="$5"
    local result_file="$6"

    local start_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')

    local response
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: Bearer $token" \
            --max-time 30 "$url" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X POST -H "Authorization: Bearer $token" \
            --max-time 30 "$url" 2>/dev/null)
    fi

    local end_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')
    local latency=$((end_ms - start_ms))

    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    local actual_region=$(echo "$body" | jq -r '.region // "unknown"' 2>/dev/null || echo "unknown")

    local status="PASSED"
    local error=""

    if [ "$http_code" != "200" ]; then
        status="FAILED"
        error="HTTP status $http_code"
    elif [ "$actual_region" != "$expected_region" ]; then
        status="FAILED"
        error="Region mismatch: expected '$expected_region', got '$actual_region'"
    fi

    cat > "$result_file" << EOF
{"label":"$label","http_code":"$http_code","latency_ms":$latency,"expected_region":"$expected_region","actual_region":"$actual_region","status":"$status","error":"$error"}
EOF
}

print_result() {
    local result=$(cat "$1")
    local label=$(echo "$result" | jq -r '.label')
    local http_code=$(echo "$result" | jq -r '.http_code')
    local latency=$(echo "$result" | jq -r '.latency_ms')
    local expected=$(echo "$result" | jq -r '.expected_region')
    local actual=$(echo "$result" | jq -r '.actual_region')
    local status=$(echo "$result" | jq -r '.status')
    local error=$(echo "$result" | jq -r '.error')

    echo ""
    echo -e "  ${BOLD}$label${NC}"
    echo "  ├── HTTP Status: $http_code"
    echo "  ├── Latency:     ${latency}ms"
    echo "  ├── Expected:    $expected"
    echo "  ├── Actual:      $actual"

    if [ "$status" = "PASSED" ]; then
        echo -e "  └── Result:     ${GREEN}PASSED ✓${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  └── Result:     ${RED}FAILED ✗${NC} ($error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

print_header "Unleash Live - Multi-Region Deployment Test"

#-------------------------------------------------------------------------------
# Step 1: Load Configuration
#-------------------------------------------------------------------------------

print_step "1/5" "Loading configuration..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE=""

# Check for config file argument
if [ "${1:-}" = "--config" ] && [ -n "${2:-}" ]; then
    CONFIG_FILE="$2"
elif [ -f "$SCRIPT_DIR/test_config.json" ]; then
    CONFIG_FILE="$SCRIPT_DIR/test_config.json"
elif [ -f "$SCRIPT_DIR/../environments/dev/test_config.json" ]; then
    CONFIG_FILE="$SCRIPT_DIR/../environments/dev/test_config.json"
fi

# If no config file, try terraform
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    print_info "No config file found, trying terraform output..."
    TF_DIR="$SCRIPT_DIR/../environments/dev"
    if [ -d "$TF_DIR" ]; then
        cd "$TF_DIR"
        CONFIG=$(terraform output -json test_config 2>/dev/null) || {
            print_failure "Failed to get terraform output. Generate config first:"
            echo "  cd environments/dev"
            echo "  terraform output -json test_config > ../../test/test_config.json"
            exit 1
        }
        cd - > /dev/null
    else
        print_failure "Cannot find terraform directory or config file"
        exit 1
    fi
else
    print_info "Using config file: $CONFIG_FILE"
    CONFIG=$(cat "$CONFIG_FILE")
fi

# Parse config
API_US_EAST_1=$(echo "$CONFIG" | jq -r '.api_urls["us-east-1"]')
API_EU_WEST_1=$(echo "$CONFIG" | jq -r '.api_urls["eu-west-1"]')
CLIENT_ID=$(echo "$CONFIG" | jq -r '.cognito.client_id')
COGNITO_REGION=$(echo "$CONFIG" | jq -r '.cognito.region')
SECRET_NAME=$(echo "$CONFIG" | jq -r '.secret_name')
TEST_USER=$(echo "$CONFIG" | jq -r '.test_user')

echo "  API (us-east-1): $API_US_EAST_1"
echo "  API (eu-west-1): $API_EU_WEST_1"
echo "  Cognito Region:  $COGNITO_REGION"
echo "  Test User:       $TEST_USER"
print_success "Configuration loaded"

#-------------------------------------------------------------------------------
# Step 2: Authenticate with Cognito
#-------------------------------------------------------------------------------

print_step "2/5" "Authenticating with Cognito ($COGNITO_REGION)..."

PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$COGNITO_REGION" \
    --query 'SecretString' \
    --output text 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    print_failure "Failed to retrieve password from Secrets Manager"
    exit 1
fi
print_success "Password retrieved from Secrets Manager"

AUTH_RESULT=$(aws cognito-idp initiate-auth \
    --client-id "$CLIENT_ID" \
    --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters USERNAME="$TEST_USER",PASSWORD="$PASSWORD" \
    --region "$COGNITO_REGION" 2>&1)

TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.IdToken' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    print_failure "Cognito authentication failed"
    exit 1
fi

print_success "JWT token retrieved successfully"
echo "  Token: ${TOKEN:0:50}..."

#-------------------------------------------------------------------------------
# Step 3: Test /greet Endpoints Concurrently
#-------------------------------------------------------------------------------

print_step "3/5" "Testing GET /greet endpoints (concurrent)..."

call_endpoint "${API_US_EAST_1}/greet" "GET" "us-east-1" "us-east-1 GET /greet" "$TOKEN" "$TMPDIR/greet_us.json" &
PID1=$!
call_endpoint "${API_EU_WEST_1}/greet" "GET" "eu-west-1" "eu-west-1 GET /greet" "$TOKEN" "$TMPDIR/greet_eu.json" &
PID2=$!
wait $PID1; wait $PID2

print_result "$TMPDIR/greet_us.json"
print_result "$TMPDIR/greet_eu.json"

#-------------------------------------------------------------------------------
# Step 4: Test /dispatch Endpoints Concurrently
#-------------------------------------------------------------------------------

print_step "4/5" "Testing POST /dispatch endpoints (concurrent)..."

call_endpoint "${API_US_EAST_1}/dispatch" "POST" "us-east-1" "us-east-1 POST /dispatch" "$TOKEN" "$TMPDIR/dispatch_us.json" &
PID3=$!
call_endpoint "${API_EU_WEST_1}/dispatch" "POST" "eu-west-1" "eu-west-1 POST /dispatch" "$TOKEN" "$TMPDIR/dispatch_eu.json" &
PID4=$!
wait $PID3; wait $PID4

print_result "$TMPDIR/dispatch_us.json"
print_result "$TMPDIR/dispatch_eu.json"

#-------------------------------------------------------------------------------
# Step 5: Latency Comparison
#-------------------------------------------------------------------------------

print_step "5/5" "Geographic Performance Analysis..."

LAT_US_GREET=$(jq -r '.latency_ms' "$TMPDIR/greet_us.json")
LAT_EU_GREET=$(jq -r '.latency_ms' "$TMPDIR/greet_eu.json")
LAT_US_DISPATCH=$(jq -r '.latency_ms' "$TMPDIR/dispatch_us.json")
LAT_EU_DISPATCH=$(jq -r '.latency_ms' "$TMPDIR/dispatch_eu.json")

echo ""
echo -e "  ${BOLD}Latency Comparison (milliseconds):${NC}"
echo ""
echo "  ┌──────────────────┬─────────────┬─────────────┐"
echo "  │     Endpoint     │  us-east-1  │  eu-west-1  │"
echo "  ├──────────────────┼─────────────┼─────────────┤"
printf "  │ GET /greet       │  %7s ms │  %7s ms │\n" "$LAT_US_GREET" "$LAT_EU_GREET"
printf "  │ POST /dispatch   │  %7s ms │  %7s ms │\n" "$LAT_US_DISPATCH" "$LAT_EU_DISPATCH"
echo "  └──────────────────┴─────────────┴─────────────┘"
echo ""
print_info "Latency varies based on your geographic location"

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

print_header "Test Summary"

echo ""
echo "  Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}             ✓ ALL TESTS PASSED SUCCESSFULLY                   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                    ✗ SOME TESTS FAILED                         ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
