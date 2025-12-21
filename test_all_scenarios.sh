#!/bin/bash

# Script to test all security arena scenarios
# Usage: ./test_all_scenarios.sh [--show-logs]

# Set required environment variables
export OPENAI_API_KEY="anything"
export OPENAI_BASE_URL="http://localhost:8000/v1"

# Parse command line arguments
SHOW_LOGS=false
if [[ "$1" == "--show-logs" ]]; then
    SHOW_LOGS=true
fi

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory with timestamp subfolder
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="test_results/run_${TIMESTAMP}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/test_summary.log"

# Array of scenarios to test
scenarios=(
    "scenario_medical_example.toml"
    "scenario_portfolioiq.toml"
    "scenario_thingularity.toml"
    "scenario_burnerbug.toml"
    "scenario_copyrightcat.toml"
    "scenario_debugdump.toml"
    "scenario_dockerdoo.toml"
    "scenario_memorylane.toml"
    "scenario_solarspike.toml"
)

# Timeout in seconds (10 minutes per scenario)
TIMEOUT=600

# Results tracking
total=0
passed=0
failed=0
timed_out=0

# Function to log message to both console and file
log_message() {
    echo -e "$1" | tee -a "${LOG_FILE}"
}

# Function to log to file only
log_to_file() {
    echo -e "$1" >> "${LOG_FILE}"
}

log_message "========================================="
log_message "Security Arena Scenario Tests"
log_message "Started: $(date)"
log_message "Log file: ${LOG_FILE}"
log_message "Show logs: ${SHOW_LOGS}"
log_message "========================================="
log_message ""

# Function to cleanup processes
cleanup_ports() {
    local msg="Cleaning up processes on ports 9010, 9020, 9021..."
    if [ "${SHOW_LOGS}" = true ]; then
        log_message "$msg"
    else
        log_to_file "$msg"
    fi
    lsof -ti:9010,9020,9021 2>/dev/null | xargs -r kill -9 2>/dev/null
    sleep 1
}

# Run each scenario
for scenario in "${scenarios[@]}"; do
    total=$((total + 1))
    scenario_path="scenarios/security_arena/${scenario}"

    log_message "${YELLOW}[${total}/9]${NC} Testing: ${scenario}"
    log_message "----------------------------------------"

    # Cleanup before running
    cleanup_ports

    # Create temp file for this scenario's output
    SCENARIO_LOG="${LOG_DIR}/${scenario%.toml}.log"

    # Run the test with timeout
    start_time=$(date +%s)

    if [ "${SHOW_LOGS}" = true ]; then
        # Show logs in real-time and save to file
        if timeout ${TIMEOUT} uv run agentbeats-run "${scenario_path}" --show-logs 2>&1 | tee "${SCENARIO_LOG}"; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        # Save logs to file only
        if timeout ${TIMEOUT} uv run agentbeats-run "${scenario_path}" --show-logs > "${SCENARIO_LOG}" 2>&1; then
            exit_code=0
        else
            exit_code=$?
        fi
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Check result
    if [ $exit_code -eq 0 ]; then
        log_message "${GREEN}✓ PASSED${NC}: ${scenario} (${duration}s)"
        log_to_file "  Log: ${SCENARIO_LOG}"
        passed=$((passed + 1))
    else
        if [ $exit_code -eq 124 ]; then
            log_message "${RED}✗ TIMEOUT${NC}: ${scenario} (exceeded ${TIMEOUT}s)"
            log_to_file "  Log: ${SCENARIO_LOG}"
            timed_out=$((timed_out + 1))
        else
            log_message "${RED}✗ FAILED${NC}: ${scenario} (exit code: ${exit_code}, duration: ${duration}s)"
            log_to_file "  Log: ${SCENARIO_LOG}"
            failed=$((failed + 1))
        fi
    fi

    # Cleanup after running
    cleanup_ports

    log_message ""
done

# Final cleanup
cleanup_ports

# Print summary
log_message "========================================="
log_message "Test Summary"
log_message "========================================="
log_message "Total scenarios:  ${total}"
log_message "${GREEN}Passed:          ${passed}${NC}"
log_message "${RED}Failed:          ${failed}${NC}"
log_message "${RED}Timed out:       ${timed_out}${NC}"
log_message "========================================="
log_message "Completed: $(date)"
log_message "Full log: ${LOG_FILE}"
log_message "========================================="

# Exit with appropriate code
if [ $failed -gt 0 ] || [ $timed_out -gt 0 ]; then
    exit 1
else
    exit 0
fi
