# Build Validation Fix - Corrected Code Blocks

## Overview
This document shows the exact corrected code blocks for the **Validate Application Startup** Build Validation step.

---

## Problem: Original Code (BROKEN)

### Issue
The original script used `set -e` globally, which terminates the shell on ANY non-zero exit code. When `timeout` returns exit code 124 (success case - app ran for full duration), the script exits before the exit code can be captured and evaluated.

### Original Broken Code
```bash
set -e

timeout 20 python app.py > logs/startup.log 2>&1

APP_EXIT=$?

if [ "$APP_EXIT" = "124" ]; then
    echo "Application started successfully and stayed up for 20s."
    exit 0
fi
```

### Why It Fails
1. Line 1: `set -e` enables exit-on-error mode
2. Line 3: `timeout` returns exit code 124 (app ran for full 20s = SUCCESS)
3. **PROBLEM**: `set -e` terminates immediately, script never reaches line 5
4. Line 5: `APP_EXIT=$?` NEVER EXECUTES
5. Line 7-10: if statement NEVER EXECUTES
6. Result: Successful startup marked as failure

---

## Solution: Corrected Code (FIXED)

### Key Changes
1. ✅ **Remove global `set -e`** - Allow exit codes to be captured
2. ✅ **Explicit exit code evaluation** - Handle each case properly
3. ✅ **Rich failure context** - For AI analysis and rollback decisions

### Corrected Code - Full Validation Function

```bash
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
    # THIS IS THE CRITICAL FIX
    log_info "Step 3: Starting application and validating startup for 20 seconds..."
    log_info "  Timeout: 20 seconds"
    log_info "  Port: ${APP_PORT}"
    
    # ✅ KEY FIX: Do NOT use set -e here
    # Instead, explicitly capture exit code and handle it
    cd "${APP_DIR}"
    
    # Run application with 20-second timeout
    # Capture exit code in APP_EXIT
    timeout 20 ${PYTHON_CMD} app.py >> "${STARTUP_LOG}" 2>&1
    APP_EXIT=$?
    
    # Step 4: Evaluate application exit code
    log_info "Step 4: Evaluating startup result..."
    log_info "  Application exit code: ${APP_EXIT}"
    
    # ✅ CORRECTED EXIT CODE HANDLING
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
```

---

## Critical Fix: The Three-Way Exit Code Handling

### Before (Broken)
```bash
# ❌ BROKEN: set -e prevents any exit code handling
set -e
timeout 20 python app.py > logs/startup.log 2>&1
APP_EXIT=$?    # Never executes
# Script terminates here with error
```

### After (Fixed)
```bash
# ✅ FIXED: No set -e, explicit handling
cd "${APP_DIR}"
timeout 20 ${PYTHON_CMD} app.py >> "${STARTUP_LOG}" 2>&1
APP_EXIT=$?    # Always captures exit code

# Now evaluate properly
if [ "$APP_EXIT" = "124" ]; then
    # SUCCESS: App ran for full 20 seconds
    return 0
elif [ "$APP_EXIT" = "0" ]; then
    # FAILURE: App exited early
    return 1
else
    # FAILURE: App crashed
    return 1
fi
```

---

## Exit Code Semantics Table

| Exit Code | Source | Meaning | Action | Why |
|-----------|--------|---------|--------|-----|
| **124** | `timeout` | Command ran for full duration without exiting | ✅ **SUCCESS** | App stayed healthy for 20s = deployment good |
| **0** | Application | App exited normally/unexpectedly | ❌ **FAILURE** | App should stay running; early exit = problem |
| **1** | Application | Generic error/crash | ❌ **FAILURE** | Application encountered an error |
| **127** | Shell | Command not found | ❌ **FAILURE** | Python/command not available |
| **125+** | `timeout` | timeout command error | ❌ **FAILURE** | timeout itself failed |

---

## Failure Context Generation

### Function for AI Analysis

```bash
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
```

---

## Environment Variables

### Configuration
```bash
# Configuration
APP_DIR="${APP_DIR:-.}"                    # Default: current directory
LOG_DIR="${LOG_DIR:-.}"                    # Default: current directory
STARTUP_LOG="${LOG_DIR}/startup.log"       # Startup output
DEPLOYMENT_LOG="${LOG_DIR}/deployment.log" # Deployment status
FAILURE_MARKER="${LOG_DIR}/startup_failed" # Failure marker
APP_PORT="${APP_PORT:-8090}"               # Default: 8090
PYTHON_CMD="python3"                       # Python interpreter
```

### For Harness Pipeline
```bash
# When called from Harness
export LOG_DIR=/harness/logs
export APP_PORT=8090
export PORT=8090
bash validate_startup.sh
```

---

## Expected Output: Success Case

```
[INFO] [2026-11-16 16:00:57] Validating Application Startup
[INFO] [2026-11-16 16:00:57] ==========================================
[INFO] [2026-11-16 16:00:57] Environment:
[INFO] [2026-11-16 16:00:57]   APP_DIR: .
[INFO] [2026-11-16 16:00:57]   LOG_DIR: .
[INFO] [2026-11-16 16:00:57]   APP_PORT: 8090
[INFO] [2026-11-16 16:00:57]   Python: python3
[INFO] [2026-11-16 16:00:57] Step 1: Validating prerequisites...
[INFO] [2026-11-16 16:00:57] Prerequisites validation passed
[INFO] [2026-11-16 16:00:57] Step 2: Installing dependencies...
[INFO] [2026-11-16 16:00:57] Dependencies installed successfully
[INFO] [2026-11-16 16:00:57] Step 3: Starting application and validating startup for 20 seconds...
[INFO] [2026-11-16 16:00:57]   Timeout: 20 seconds
[INFO] [2026-11-16 16:00:57]   Port: 8090
[INFO] [2026-11-16 16:01:17] Step 4: Evaluating startup result...
[INFO] [2026-11-16 16:01:17]   Application exit code: 124
[INFO] [2026-11-16 16:01:17] ✅ Application started successfully and stayed up for 20 seconds.
[INFO] [2026-11-16 16:01:17] Exit code 124 (timeout SIGTERM) = EXPECTED SUCCESS
[INFO] [2026-11-16 16:01:17] ==========================================
[INFO] [2026-11-16 16:01:17] ✅ Startup Validation PASSED
[INFO] [2026-11-16 16:01:17] ==========================================
```

**Exit Code: 0** ✅

---

## Expected Output: Failure Case

```
[INFO] [2026-11-16 16:00:57] Validating Application Startup
[INFO] [2026-11-16 16:00:57] ==========================================
[INFO] [2026-11-16 16:00:57] Environment:
[INFO] [2026-11-16 16:00:57]   APP_DIR: .
[INFO] [2026-11-16 16:00:57]   LOG_DIR: .
[INFO] [2026-11-16 16:00:57]   APP_PORT: 8090
[INFO] [2026-11-16 16:00:57]   Python: python3
[INFO] [2026-11-16 16:00:57] Step 1: Validating prerequisites...
[INFO] [2026-11-16 16:00:57] Prerequisites validation passed
[INFO] [2026-11-16 16:00:57] Step 2: Installing dependencies...
[INFO] [2026-11-16 16:00:57] Dependencies installed successfully
[INFO] [2026-11-16 16:00:57] Step 3: Starting application and validating startup for 20 seconds...
[INFO] [2026-11-16 16:00:57]   Timeout: 20 seconds
[INFO] [2026-11-16 16:00:57]   Port: 8090
[ERROR] [2026-11-16 16:00:58] Step 4: Evaluating startup result...
[ERROR] [2026-11-16 16:00:58]   Application exit code: 1
[ERROR] [2026-11-16 16:00:58] ❌ Application startup validation FAILED.
[ERROR] [2026-11-16 16:00:58] Exit code 1 = Application error or crash
[ERROR] [2026-11-16 16:00:58] Generating failure context for AI analysis...
[ERROR] [2026-11-16 16:00:58] BUILD_FAILURE_TYPE: APP_CRASH
[ERROR] [2026-11-16 16:00:58] Full application startup log:
  Traceback (most recent call last):
    File "app.py", line 1, in <module>
      from nonexistent_module import something
  ModuleNotFoundError: No module named 'nonexistent_module'
[ERROR] [2026-11-16 16:00:58] ==========================================
[ERROR] [2026-11-16 16:00:58] ❌ Startup Validation FAILED
[ERROR] [2026-11-16 16:00:58] ==========================================
```

**Exit Code: 1** ❌  
**BUILD_FAILURE_TYPE: APP_CRASH**

---

## Summary of Changes

| Aspect | Before | After |
|--------|--------|-------|
| **Global set -e** | ❌ Enabled (breaks exit code capture) | ✅ Removed (allows capture) |
| **Exit 124 handling** | ❌ Not executed (script exits first) | ✅ Treated as SUCCESS |
| **Exit 0 handling** | ❌ Not executed | ✅ Treated as FAILURE |
| **Exit 1+ handling** | ❌ Not executed | ✅ Treated as FAILURE |
| **Failure context** | ❌ Minimal | ✅ Rich (type, reason, logs) |
| **BUILD_FAILURE_TYPE** | ❌ Not set | ✅ Exported for Harness |
| **AI integration** | ❌ Limited | ✅ Full context generation |

---

## Files Provided

1. **validate_startup.sh** (369 lines)
   - Complete, production-ready validation script
   - Proper exit code handling
   - Rich failure context for AI
   - Ready to integrate with Harness

2. **STARTUP_VALIDATION_FIX.md** (300+ lines)
   - Detailed technical documentation
   - Problem/solution explanation
   - Testing scenarios (4 test cases)
   - Harness integration guide

3. **BUILD_VALIDATION_SUMMARY.md** (470+ lines)
   - Comprehensive summary
   - Before/after comparison
   - Deployment instructions
   - Troubleshooting guide

4. **CORRECTED_CODE_BLOCKS.md** (this file)
   - Exact corrected code blocks
   - Exit code semantics table
   - Expected output examples

---

## Testing

### Quick Test: Success Case
```bash
# Run the validation script
export LOG_DIR=./logs
export APP_PORT=8090
bash validate_startup.sh

# Check exit code
echo $?
# Expected: 0
```

### Quick Test: Failure Case
```bash
# Break the app (remove import or corrupt)
echo "BROKEN" > app.py

# Run validation
bash validate_startup.sh

# Check exit code
echo $?
# Expected: 1

# Check failure type
echo $BUILD_FAILURE_TYPE
# Expected: APP_CRASH (or other failure type)
```

---

## Conclusion

The corrected `validate_startup.sh` script properly handles the timeout command's exit code 124 (success) and treats it as a successful deployment. All other exit codes are treated as failures with rich context generation for AI analysis and automatic rollback decisions.

✅ **Ready for Production Use**
