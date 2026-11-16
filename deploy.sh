#!/bin/bash

##############################################################################
# AI Autonomous Deployment Rollback Demo - Deployment Script
# 
# Responsibilities:
# - Stop existing application
# - Backup current version
# - Deploy new version
# - Start application
# - Verify process is running
##############################################################################

set -e

# Configuration
APP_DIR="${APP_DIR:-.}"
APP_PORT="${APP_PORT:-8080}"
APP_PROCESS_NAME="python"
BACKUP_DIR="${APP_DIR}/backups"
VERSION_FILE="${APP_DIR}/version.txt"
LOG_FILE="${APP_DIR}/application.log"
PYTHON_CMD="python3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

##############################################################################
# Main Deployment Flow
##############################################################################

main() {
    log_info "=========================================="
    log_info "Starting Deployment Process"
    log_info "=========================================="
    
    # Step 1: Validate environment
    log_info "Step 1: Validating environment..."
    validate_environment
    
    # Step 2: Get new version
    NEW_VERSION=$(cat "${VERSION_FILE}")
    log_info "Deploying version: ${NEW_VERSION}"
    
    # Step 3: Create backup of current version
    log_info "Step 2: Creating backup of current version..."
    create_backup
    
    # Step 4: Stop existing application
    log_info "Step 3: Stopping existing application..."
    stop_application
    
    # Step 5: Install dependencies
    log_info "Step 4: Installing dependencies..."
    install_dependencies
    
    # Step 6: Start application
    log_info "Step 5: Starting application..."
    start_application
    
    # Step 7: Verify application is running
    log_info "Step 6: Verifying application health..."
    verify_application
    
    log_info "=========================================="
    log_info "Deployment Completed Successfully"
    log_info "=========================================="
}

validate_environment() {
    if [ ! -f "${VERSION_FILE}" ]; then
        log_error "version.txt not found in ${APP_DIR}"
        exit 1
    fi
    
    if [ ! -f "${APP_DIR}/app.py" ]; then
        log_error "app.py not found in ${APP_DIR}"
        exit 1
    fi
    
    if [ ! -f "${APP_DIR}/requirements.txt" ]; then
        log_error "requirements.txt not found in ${APP_DIR}"
        exit 1
    fi
    
    # Check if Python is available
    if ! command -v ${PYTHON_CMD} &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    
    log_info "Environment validation passed"
}

create_backup() {
    mkdir -p "${BACKUP_DIR}"
    
    CURRENT_VERSION=$(cat "${VERSION_FILE}" 2>/dev/null || echo "unknown")
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="${BACKUP_DIR}/backup_${CURRENT_VERSION}_${TIMESTAMP}"
    
    if [ -f "${APP_DIR}/app.py" ] && [ -f "${LOG_FILE}" ]; then
        mkdir -p "${BACKUP_PATH}"
        cp "${APP_DIR}/app.py" "${BACKUP_PATH}/"
        cp "${APP_DIR}/requirements.txt" "${BACKUP_PATH}/"
        cp "${APP_DIR}/version.txt" "${BACKUP_PATH}/"
        cp "${LOG_FILE}" "${BACKUP_PATH}/application.log.bak" 2>/dev/null || true
        
        log_info "Backup created at: ${BACKUP_PATH}"
    else
        log_warn "No previous version to backup"
    fi
}

stop_application() {
    # Try to find and kill the Flask application
    PID=$(lsof -i :${APP_PORT} -t 2>/dev/null || echo "")
    
    if [ -n "$PID" ]; then
        log_info "Stopping application with PID: ${PID}"
        kill -SIGTERM ${PID} 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if kill -0 ${PID} 2>/dev/null; then
            log_warn "Process still running, sending SIGKILL"
            kill -SIGKILL ${PID} 2>/dev/null || true
        fi
        
        log_info "Application stopped"
    else
        log_warn "No application running on port ${APP_PORT}"
    fi
}

install_dependencies() {
    log_info "Installing Python dependencies from requirements.txt..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install -r "${APP_DIR}/requirements.txt" 2>&1 | grep -E "Successfully|already|ERROR" || true
    else
        log_error "pip3 not found. Please install pip3."
        exit 1
    fi
    
    log_info "Dependencies installed successfully"
}

start_application() {
    log_info "Starting application..."
    
    cd "${APP_DIR}"
    nohup ${PYTHON_CMD} app.py > ${LOG_FILE} 2>&1 &
    APP_PID=$!
    
    log_info "Application started with PID: ${APP_PID}"
    sleep 2
}

verify_application() {
    log_info "Verifying application health..."
    
    RETRY_COUNT=0
    MAX_RETRIES=10
    RETRY_INTERVAL=2
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if command -v curl &> /dev/null; then
            HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${APP_PORT}/health 2>/dev/null || echo "000")
            
            if [ "$HEALTH_CHECK" == "200" ]; then
                log_info "Health check passed (HTTP ${HEALTH_CHECK})"
                
                # Get version from health endpoint
                VERSION_RESPONSE=$(curl -s http://localhost:${APP_PORT}/health 2>/dev/null | grep -o '"version":"[^"]*"' || echo "")
                log_info "Current deployment info: ${VERSION_RESPONSE}"
                
                return 0
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_warn "Health check attempt ${RETRY_COUNT}/${MAX_RETRIES} failed. Retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
    done
    
    log_error "Application health check failed after ${MAX_RETRIES} attempts"
    log_error "Check logs at: ${LOG_FILE}"
    exit 1
}

# Run main function
main "$@"
