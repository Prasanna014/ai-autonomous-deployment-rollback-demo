# Startup Validation Script - Fix Documentation

## Problem Statement

The original `Validate Application Startup` step had a critical shell scripting issue:

### Original Code Issue
```bash
set -e

timeout 20 python app.py > logs/startup.log 2>&1

APP_EXIT=$?

if [ "$APP_EXIT" = "124" ]; then
    echo "Application started successfully and stayed up for 20s."
    exit 0
fi
```

### The Issue
1. **`set -e` enabled** - Shell terminates immediately on any non-zero exit
2. **timeout returns 124** when the command runs for the full duration without exiting
3. Exit code 124 from timeout = **APPLICATION SUCCESS** (it stayed running for 20s)
4. But `set -e` terminates the script **before** `APP_EXIT=$?` captures the code
5. Result: The if statement never executes, script exits with error

### Why Exit Code 124 Means Success

The `timeout` command behavior:
- **exit 0**: Command exited normally/successfully
- **exit 124**: timeout expired - sent SIGTERM to process (command kept running)
- **exit 125+**: timeout command error
- **exit 1-123**: Command exited with that code

For a Flask application:
- We want it to **stay running** for the full 20 seconds
- If it stays running → timeout sends SIGTERM → exit code 124 → **SUCCESS**
- If it crashes early → exit code 0, 1, etc. → **FAILURE**

---

## Solution: validate_startup.sh

### Key Changes

#### 1. Removed Global `set -e`
```bash
# BEFORE (BROKEN):
set -e
timeout 20 python app.py > logs/startup.log 2>&1
APP_EXIT=$?

# AFTER (FIXED):
# Do NOT use set -e
cd "${APP_DIR}"
timeout 20 ${PYTHON_CMD} app.py >> "${STARTUP_LOG}" 2>&1
APP_EXIT=$?
```

**Why**: Allows the exit code to be captured and processed correctly.

#### 2. Explicit Exit Code Evaluation
```bash
if [ "$APP_EXIT" = "124" ]; then
    # Application ran for full 20s = SUCCESS
    log_info "✅ Application started successfully and stayed up for 20 seconds."
    return 0
    
elif [ "$APP_EXIT" = "0" ]; then
    # App exited early = FAILURE
    log_error "❌ Application exited unexpectedly before timeout."
    generate_failure_context "APP_PREMATURE_EXIT" "..."
    return 1
    
else
    # Any other exit code = FAILURE
    log_error "❌ Application startup validation FAILED."
    log_error "Exit code ${APP_EXIT} = Application error"
    generate_failure_context "APP_ERROR" "Application exited with code ${APP_EXIT}"
    return 1
fi
```

**Benefits**:
- Clear, explicit handling of each exit code
- Proper differentiation between success and failure
- Detailed failure context for AI analysis

#### 3. Enhanced Failure Context Generation
```bash
generate_failure_context() {
    local failure_type="$1"
    local failure_reason="$2"
    
    # Create failure marker for rollback
    touch "${FAILURE_MARKER}"
    
    # Set BUILD_FAILURE_TYPE for Harness
    export BUILD_FAILURE_TYPE="${failure_type}"
    
    # Append detailed context to deployment log
    # Include: timestamp, reason, log snippets, file locations
}
```

**Preserved Features**:
- ✅ `startup.log` created in LOG_DIR
- ✅ `deployment.log` appended with results
- ✅ `startup_failed` marker created on failure
- ✅ `BUILD_FAILURE_TYPE` set for Harness integration

#### 4. Environment Variable Support
```bash
LOG_DIR="${LOG_DIR:-.}"      # Default: current directory
APP_PORT="${APP_PORT:-8090}"  # Default: 8090
PYTHON_CMD="python3"          # Configurable
```

**Benefits**:
- Works with Harness environment variables
- `LOG_DIR=/harness/logs` → logs to `/harness/logs/startup.log`
- `APP_PORT=8090` → validates on configured port

---

## Exit Code Semantics

### Success
| Exit Code | Condition | Handling |
|-----------|-----------|----------|
| **124** | Timeout expired (app ran full 20s) | ✅ **SUCCESS** |

### Failures
| Exit Code | Condition | BUILD_FAILURE_TYPE |
|-----------|-----------|-------------------|
| 0 | App exited before timeout | APP_PREMATURE_EXIT |
| 1 | Generic error | APP_CRASH |
| 127 | Command not found | COMMAND_NOT_FOUND |
| Other | Various errors | APP_ERROR |

---

## Log Output Structure

### Success Case
```
[INFO] Validating Application Startup
[INFO] Step 1: Validating prerequisites...
[INFO] Prerequisites validation passed
[INFO] Step 2: Installing dependencies...
[INFO] Dependencies installed successfully
[INFO] Step 3: Starting application and validating startup for 20 seconds...
[INFO] Application exit code: 124
[INFO] ✅ Application started successfully and stayed up for 20 seconds.
[INFO] ✅ Startup Validation PASSED
```

### Failure Case
```
[INFO] Validating Application Startup
[INFO] Step 1: Validating prerequisites...
[INFO] Prerequisites validation passed
[INFO] Step 2: Installing dependencies...
[INFO] Dependencies installed successfully
[INFO] Step 3: Starting application and validating startup for 20 seconds...
[INFO] Application exit code: 1
[ERROR] ❌ Application startup validation FAILED.
[ERROR] Exit code 1 = Application error or crash
[ERROR] Generating failure context for AI analysis...
[ERROR] BUILD_FAILURE_TYPE: APP_CRASH
[ERROR] ❌ Startup Validation FAILED
```

---

## Integration with Harness Pipeline

### Stage Variables
```yaml
Environment=LOG_DIR=/harness/logs
Environment=APP_PORT=8090
Environment=PORT=8090
```

### Build Validation Step
```yaml
name: Validate Application Startup
type: Script
spec:
  script: |-
    export LOG_DIR=/harness/logs
    export APP_PORT=8090
    bash validate_startup.sh
  onFailure: CONTINUE  # Fails to rollback
```

### Decision Engine Input
- Exit code 0 → Startup successful, continue to Deploy
- Exit code 1 → Startup failed, trigger rollback
- `BUILD_FAILURE_TYPE` env var → AI knows failure category

---

## Preserved Components

### Not Modified
- ✅ AI stages (analysis, decision engine)
- ✅ Deploy_To_VM stage
- ✅ FAILURE_CONTEXT generation
- ✅ Approval stage
- ✅ Autofix stage

### Integration Points
- Script can run before Deploy_To_VM as validation
- Exports BUILD_FAILURE_TYPE for Harness
- Creates startup_failed marker for downstream decision logic
- Appends to deployment.log for audit trail

---

## Usage

### Direct Execution
```bash
# With defaults
bash validate_startup.sh

# With custom environment
export LOG_DIR=/harness/logs
export APP_PORT=8090
bash validate_startup.sh
```

### In Harness Pipeline
```yaml
- step:
    type: ShellScript
    name: Validate Application Startup
    spec:
      shell: Bash
      command: |-
        export LOG_DIR=/harness/logs
        export APP_PORT=8090
        bash validate_startup.sh
      outputVariables:
        - name: BUILD_FAILURE_TYPE
```

---

## Testing Scenarios

### Test 1: Successful Startup (Exit 124)
```bash
# Application stays running for 20s
bash validate_startup.sh
# Expected: Exit code 0, BUILD_FAILURE_TYPE unset
```

### Test 2: Early Exit (Exit 0)
```bash
# Modify app.py to exit immediately
bash validate_startup.sh
# Expected: Exit code 1, BUILD_FAILURE_TYPE=APP_PREMATURE_EXIT
```

### Test 3: Startup Crash (Exit 1+)
```bash
# Inject error in requirements or app.py
bash validate_startup.sh
# Expected: Exit code 1, BUILD_FAILURE_TYPE=APP_ERROR
```

### Test 4: Missing Dependency
```bash
# Remove requirements.txt
bash validate_startup.sh
# Expected: Exit code 1, BUILD_FAILURE_TYPE=MISSING_REQUIREMENTS
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **`set -e` issue** | ❌ Prevents exit code capture | ✅ Explicitly handled |
| **Exit 124 handling** | ❌ Treated as failure | ✅ Treated as success |
| **Failure context** | ❌ Minimal | ✅ Rich (type, reason, logs) |
| **AI integration** | ❌ Limited | ✅ Full (BUILD_FAILURE_TYPE) |
| **Harness compatibility** | ⚠️ Partial | ✅ Complete |

---

## File Location
- **Script**: `validate_startup.sh`
- **Documentation**: This file (STARTUP_VALIDATION_FIX.md)
- **Related**: `app.py`, `deploy.sh`, `rollback.sh`
