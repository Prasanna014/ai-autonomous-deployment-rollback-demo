#!/bin/bash

##############################################################################
# AI Autonomous Deployment Rollback Demo - Rollback Script
# 
# Responsibilities:
# - Stop current version
# - Redeploy previous successful version
# - Start application
# - Verify application health
##############################################################################

set -e

# Configuration
APP_DIR="${APP_DIR:-.}"
APP_PORT="${APP_PORT:-8080}"
BACKUP_DIR="${APP_DIR}/backups"
VERSION_FILE="${APP_DIR}/version.txt"
LOG_FILE="${APP_DIR}/application.log"
PYTHON_CMD="python3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

##############################################################################
# Main Rollback Flow
##############################################################################

main() {
    log_info "=========================================="
    log_info "Starting Rollback Process"
    log_info "=========================================="
    
    # Step 1: Find the latest successful backup
    log_info "Step 1: Finding latest backup..."
    find_latest_backup
    
    # Step 2: Stop current application
    log_info "Step 2: Stopping current application..."
    stop_application
    
    # Step 3: Restore from backup
    log_info "Step 3: Restoring from backup..."
    restore_backup
    
    # Step 4: Install dependencies
    log_info "Step 4: Installing dependencies..."
    install_dependencies
    
    # Step 5: Start application
    log_info "Step 5: Starting application..."
    start_application
    
    # Step 6: Verify application is running
    log_info "Step 6: Verifying application health..."
    verify_application
    
    log_info "=========================================="
    log_info "Rollback Completed Successfully"
    log_info "=========================================="
}

find_latest_backup() {
    if [ ! -d "${BACKUP_DIR}" ]; then
        log_error "No backup directory found at ${BACKUP_DIR}"
        exit 1
    fi
    
    # Find the most recent backup
    LATEST_BACKUP=$(ls -td "${BACKUP_DIR}"/backup_* 2>/dev/null | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        log_error "No backups found in ${BACKUP_DIR}"
        exit 1
    fi
    
    log_info "Found latest backup: ${LATEST_BACKUP}"
    
    # Verify backup contains required files
    if [ ! -f "${LATEST_BACKUP}/app.py" ] || [ ! -f "${LATEST_BACKUP}/requirements.txt" ] || [ ! -f "${LATEST_BACKUP}/version.txt" ]; then
        log_error "Backup is incomplete. Missing required files."
        exit 1
    fi
    
    export ROLLBACK_VERSION=$(cat "${LATEST_BACKUP}/version.txt")
    log_info "Rolling back to version: ${ROLLBACK_VERSION}"
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

restore_backup() {
    log_info "Restoring files from backup..."
    
    cp "${LATEST_BACKUP}/app.py" "${APP_DIR}/"
    cp "${LATEST_BACKUP}/requirements.txt" "${APP_DIR}/"
    cp "${LATEST_BACKUP}/version.txt" "${APP_DIR}/"
    
    log_info "Files restored successfully"
    
    # Rename current log as historical
    if [ -f "${LOG_FILE}" ]; then
        mv "${LOG_FILE}" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
    fi
}

install_dependencies() {
    log_info "Installing Python dependencies..."
    
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
                log_info "Rolled back to: ${VERSION_RESPONSE}"
                
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
