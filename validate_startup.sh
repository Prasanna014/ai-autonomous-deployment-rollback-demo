#!/bin/bash

##############################################################################
# AI Autonomous Deployment Rollback Demo - Startup Validation Script
#
# Build Validation Step: Validate Application Startup
#
# Purpose:
# - Test if the application starts successfully
# - Allow application to run for 20 seconds
# - Exit code 124 from timeout = SUCCESS (app stayed running)
# - Generate startup logs for AI analysis
# - Create failure markers for rollback analysis
#
# Fix Applied:
# - Removed global set -e to allow timeout exit code 124 processing
# - Explicit exit code capture and evaluation
# - Proper handling of success (124) vs failure (other non-zero)
##############################################################################

# DO NOT USE: set -e
# Reason: Would prevent processing of timeout exit code 124 (success)

# Configuration
APP_DIR="${APP_DIR:-.}"
LOG_DIR="${LOG_DIR:-.}"
STARTUP_LOG="${LOG_DIR}/startup.log"
DEPLOYMENT_LOG="${LOG_DIR}/deployment.log"
FAILURE_MARKER="${LOG_DIR}/startup_failed"
APP_PORT="${APP_PORT:-8090}"
PYTHON_CMD="python3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${NC} [${timestamp}] $1"
}

log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${NC} [${timestamp}] $1"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} [${timestamp}] $1"
}

##############################################################################
# Function: Validate Application Startup
# 
# Expected Behavior:
# - timeout 20: Runs the command for up to 20 seconds
# - If app exits before 20s: timeout returns the app's exit code
# - If app runs full 20s: timeout returns exit code 124 (SIGTERM)
#
# Success Condition:
# - Exit code 124 = Application ran healthy for 20 seconds
#
# Failure Conditions:
# - Exit code 0 = App exited unexpectedly (too early)
# - Exit code 1+ (non-124) = App crashed with error
##############################################################################

validate_application_startup() {
    log_info "=========================================="
    log_info "Validating Application Startup"
    log_info "=========================================="
    
    # Ensure log directory exists
    mkdir -p "${LOG_DIR}"
    
    # Clear previous startup log
    > "${STARTUP_LOG}"
    
    log_info "Environment:"
    log_info "  APP_DIR: ${APP_DIR}"
    log_info "  LOG_DIR: ${LOG_DIR}"
    log_info "  APP_PORT: ${APP_PORT}"
    log_info "  Python: ${PYTHON_CMD}"
    
    # Step 1: Validate prerequisites
    log_info "Step 1: Validating prerequisites..."
    if [ ! -f "${APP_DIR}/app.py" ]; then
        log_error "app.py not found in ${APP_DIR}"
        generate_failure_context "MISSING_APP_FILE" "app.py not found"
        return 1
    fi
    
    if [ ! -f "${APP_DIR}/requirements.txt" ]; then
        log_error "requirements.txt not found in ${APP_DIR}"
        generate_failure_context "MISSING_REQUIREMENTS" "requirements.txt not found"
        return 1
    fi
    
    if ! command -v ${PYTHON_CMD} &> /dev/null; then
        log_error "Python not available"
        generate_failure_context "PYTHON_NOT_FOUND" "Python interpreter not available"
        return 1
    fi
    
    log_info "Prerequisites validation passed"
    
    # Step 2: Install dependencies
    log_info "Step 2: Installing dependencies..."
    if ! pip3 install -r "${APP_DIR}/requirements.txt" >> "${STARTUP_LOG}" 2>&1; then
        log_error "Failed to install dependencies"
        generate_failure_context "DEPENDENCY_INSTALL_FAILED" "pip install failed"
        return 1
    fi
    log_info "Dependencies installed successfully"
    
    # Step 3: Validate Application Startup with timeout
    log_info "Step 3: Starting application and validating startup for 20 seconds..."
    log_info "  Timeout: 20 seconds"
    log_info "  Port: ${APP_PORT}"
    
    # CRITICAL FIX: Do NOT use set -e here
    # Instead, explicitly capture exit code and handle it
    cd "${APP_DIR}"
    
    # Run application with 20-second timeout
    # Capture exit code in APP_EXIT
    timeout 20 ${PYTHON_CMD} app.py >> "${STARTUP_LOG}" 2>&1
    APP_EXIT=$?
    
    # Step 4: Evaluate application exit code
    log_info "Step 4: Evaluating startup result..."
    log_info "  Application exit code: ${APP_EXIT}"
    
    if [ "$APP_EXIT" = "124" ]; then
        # Exit code 124 = timeout SIGTERM after 20s
        # This means the application stayed running for full 20 seconds
        # = SUCCESS
        log_info "✅ Application started successfully and stayed up for 20 seconds."
        log_info "Exit code 124 (timeout SIGTERM) = EXPECTED SUCCESS"
        
        # Append to deployment log
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Application startup validation PASSED" >> "${DEPLOYMENT_LOG}"
        
        # Clean up any previous failure marker
        rm -f "${FAILURE_MARKER}"
        
        return 0
        
    elif [ "$APP_EXIT" = "0" ]; then
        # Exit code 0 = application exited normally/unexpectedly before timeout
        # = FAILURE (app should stay running)
        log_error "❌ Application exited unexpectedly before 20-second validation period."
        log_error "Exit code 0 = App crashed or shutdown early"
        
        generate_failure_context "APP_PREMATURE_EXIT" "Application exited with code 0 before validation timeout"
        return 1
        
    else
        # Exit code 1-123, 125+ = application crashed with error
        # = FAILURE
        log_error "❌ Application startup validation FAILED."
        log_error "Exit code ${APP_EXIT} = Application error or crash"
        
        case "$APP_EXIT" in
            1)
                generate_failure_context "APP_CRASH" "Application crashed (exit code 1)"
                ;;
            127)
                generate_failure_context "COMMAND_NOT_FOUND" "Python command not found"
                ;;
            *)
                generate_failure_context "APP_ERROR" "Application exited with code ${APP_EXIT}"
                ;;
        esac
        
        return 1
    fi
}

##############################################################################
# Function: Generate Failure Context for AI Analysis
#
# Creates failure markers and context for:
# - Rollback Decision Engine
# - AI-based failure analysis
# - Deployment health tracking
##############################################################################

generate_failure_context() {
    local failure_type="$1"
    local failure_reason="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_error "Generating failure context for AI analysis..."
    
    # Create failure marker
    touch "${FAILURE_MARKER}"
    
    # Record BUILD_FAILURE_TYPE for Harness
    export BUILD_FAILURE_TYPE="${failure_type}"
    log_error "BUILD_FAILURE_TYPE: ${BUILD_FAILURE_TYPE}"
    
    # Append to deployment log
    {
        echo ""
        echo "=========================================="
        echo "❌ STARTUP VALIDATION FAILURE"
        echo "=========================================="
        echo "Timestamp: ${timestamp}"
        echo "Failure Type: ${failure_type}"
        echo "Reason: ${failure_reason}"
        echo ""
        echo "Startup Log Location: ${STARTUP_LOG}"
        echo "Full Deployment Log: ${DEPLOYMENT_LOG}"
        echo ""
        echo "Recent Log Output:"
        tail -20 "${STARTUP_LOG}" 2>/dev/null || echo "(Log file not available)"
        echo "=========================================="
        echo ""
    } >> "${DEPLOYMENT_LOG}"
    
    # Log full startup output for AI analysis
    log_error "Full application startup log:"
    cat "${STARTUP_LOG}" | head -50
    
    return 1
}

##############################################################################
# Function: Cleanup on exit
##############################################################################

cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "Script exited with code: ${exit_code}"
    fi
    
    # Ensure logs are written
    sync
    
    return $exit_code
}

##############################################################################
# Main Execution
##############################################################################

trap cleanup EXIT

log_info "Startup Validation Script Started"
log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

# Initialize deployment log
{
    echo ""
    echo "=========================================="
    echo "APPLICATION STARTUP VALIDATION"
    echo "=========================================="
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Directory: ${APP_DIR}"
    echo "Port: ${APP_PORT}"
    echo "Log Dir: ${LOG_DIR}"
    echo ""
} >> "${DEPLOYMENT_LOG}"

# Run validation
if validate_application_startup; then
    log_info "=========================================="
    log_info "✅ Startup Validation PASSED"
    log_info "=========================================="
    exit 0
else
    log_error "=========================================="
    log_error "❌ Startup Validation FAILED"
    log_error "=========================================="
    exit 1
fi
