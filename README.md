# AI Autonomous Deployment Rollback Demo

A lightweight, production-style Python Flask application designed for demonstrating autonomous deployment and automatic rollback scenarios. This repository serves as a reference implementation for Harness Deployment + Auto Rollback pipelines.

## Features

- **Lightweight**: Minimal dependencies, fast startup
- **Logging**: Comprehensive application logging to file and console
- **Health Checks**: RESTful health endpoint for monitoring
- **Deployment Ready**: Includes deployment and rollback automation scripts
- **Failure Injection**: Pre-configured hooks for intentional failure testing
- **Version Tracking**: Built-in version management for deployment verification
- **Linux Compatible**: Optimized for Linux server deployment
- **AI-Ready**: Structured logs and endpoints suitable for AI-based analysis pipelines

## Project Structure

```
ai-autonomous-deployment-rollback-demo/
├── app.py                 # Flask application with health and root endpoints
├── requirements.txt       # Python dependencies (Flask, Werkzeug)
├── version.txt           # Current application version
├── deploy.sh             # Automated deployment script
├── rollback.sh           # Automated rollback script
├── README.md             # This file
├── application.log       # Application logs (generated at runtime)
└── backups/              # Backup directory (created during deployment)
    └── backup_*.../      # Timestamped backups for rollback
```

## Application Endpoints

### GET /
Returns deployment status message.

```bash
curl http://localhost:8080/
# Response: Deployment Demo Running
```

### GET /health
Returns application health status and version information.

```bash
curl http://localhost:8080/health
# Response:
# {
#   "status": "UP",
#   "version": "1.0.0",
#   "timestamp": "2024-01-15T10:30:45.123456"
# }
```

## Build Instructions

### Prerequisites

- Python 3.7 or higher
- pip3 package manager
- curl (for health checks)
- lsof (for process management)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ai-autonomous-deployment-rollback-demo.git
cd ai-autonomous-deployment-rollback-demo
```

2. Install dependencies:
```bash
pip3 install -r requirements.txt
```

3. Verify installation:
```bash
python3 -c "import flask; print(f'Flask {flask.__version__} installed')"
```

## Deployment Instructions

### Quick Start

Run the application directly:

```bash
python3 app.py
```

The application will:
- Log startup information to `application.log`
- Listen on `0.0.0.0:8080`
- Display logs in both console and file

### Automated Deployment

Use the deployment script for production-style deployment:

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

**Deployment Script Does:**
1. Validates environment and dependencies
2. Creates timestamped backup of current version
3. Stops existing application
4. Installs/updates dependencies
5. Starts new version
6. Verifies application health with retries
7. Logs all operations

**Environment Variables:**
```bash
APP_DIR=.                    # Application directory (default: current)
APP_PORT=8080               # Application port (default: 8080)
```

**Example:**
```bash
# Deploy to specific directory
APP_DIR=/opt/demo APP_PORT=8080 ./deploy.sh
```

## Rollback Instructions

### Automated Rollback

Restore the previous version:

```bash
# Make script executable
chmod +x rollback.sh

# Run rollback
./rollback.sh
```

**Rollback Script Does:**
1. Finds the latest successful backup
2. Stops current application
3. Restores files from backup
4. Installs dependencies from backed up requirements
5. Starts previous version
6. Verifies application health with retries
7. Logs rollback operations

**Rollback Verification:**
After rollback, verify the version changed:

```bash
curl http://localhost:8080/health
```

The `version` field should match the rolled-back version.

## Health Check Examples

### Basic Health Check

```bash
curl http://localhost:8080/health
```

### Health Check with Status Code

```bash
curl -i http://localhost:8080/health
```

### Continuous Health Monitoring

```bash
while true; do
  curl -s http://localhost:8080/health | jq .
  sleep 5
done
```

### Health Check in Deployment Pipeline

```bash
# Check health and extract version
curl -s http://localhost:8080/health | grep -o '"version":"[^"]*"'

# Health check with timeout
curl -m 5 --fail http://localhost:8080/health
```

## Log Locations and Analysis

### Application Log File

- **Location**: `./application.log` (relative to application directory)
- **Format**: `TIMESTAMP - LEVEL - MESSAGE`
- **Rotation**: Currently unlimited (implement logrotate for production)

### Log Viewing

```bash
# View recent logs
tail -f application.log

# View last 50 lines
tail -50 application.log

# Search for errors
grep ERROR application.log

# Watch logs in real-time
tail -f application.log | grep -E "ERROR|CRITICAL"

# View logs by time range
grep "2024-01-15 10:3" application.log
```

### Log Examples

**Startup Log:**
```
2024-01-15 10:30:45,123 - INFO - ============================================================
2024-01-15 10:30:45,124 - INFO - Starting AI Autonomous Deployment Rollback Demo Application
2024-01-15 10:30:45,125 - INFO - ============================================================
2024-01-15 10:30:45,126 - INFO - Application Version: 1.0.0
2024-01-15 10:30:45,127 - INFO - Listening on: 0.0.0.0:8080
2024-01-15 10:30:45,128 - INFO - Process ID: 12345
2024-01-15 10:30:45,129 - INFO - Timestamp: 2024-01-15T10:30:45.123456
2024-01-15 10:30:45,130 - INFO - Startup checks completed successfully
```

**Request Log:**
```
2024-01-15 10:30:50,234 - INFO - GET / - Root endpoint accessed
2024-01-15 10:30:52,456 - INFO - GET /health - Health check requested
2024-01-15 10:30:52,457 - INFO - Health check successful - Version: 1.0.0
```

**Error Log:**
```
2024-01-15 10:31:00,789 - ERROR - 500 Internal Server Error: [error details]
```

## Failure Testing and Rollback Scenarios

The application includes pre-configured failure injection points for testing rollback automation.

### Scenario 1: Invalid Import Failure

**File**: `app.py` (line ~67)

**To Activate:**
Uncomment the invalid import to simulate dependency issues:

```python
# 1. INVALID IMPORT FAILURE (uncomment to break):
from non_existent_module import something  # This will cause startup failure
```

**Expected Behavior:**
- Application fails to start with ImportError
- Deployment health check fails after retries
- Rollback script restores previous working version

**Testing Command:**
```bash
./deploy.sh              # Fails with import error
./rollback.sh            # Restores previous version
curl http://localhost:8080/health  # Succeeds
```

### Scenario 2: Startup Exception

**File**: `app.py` (line ~73)

**To Activate:**
Uncomment the intentional exception:

```python
# 2. STARTUP EXCEPTION (uncomment to break):
raise RuntimeError("Intentional startup failure for rollback testing")
```

**Expected Behavior:**
- Application crashes during startup
- No process listening on port 8080
- Deployment/health checks detect failure
- Rollback restores previous working version

**Testing Command:**
```bash
./deploy.sh              # Fails with RuntimeError
./rollback.sh            # Restores previous version
curl http://localhost:8080/health  # Succeeds
```

### Scenario 3: Health Check Failure

**File**: `app.py` (line ~79)

**To Activate:**
Uncomment to force 503 Service Unavailable:

```python
# 3. HEALTH CHECK FAILURE (uncomment to break):
return jsonify({"status": "DOWN", "error": "Intentional health check failure"}), 503
```

**Expected Behavior:**
- Application starts but health endpoint returns 503
- Deployment script detects failure in verification step
- Automatic rollback occurs
- Previous version restored and verified

**Testing Command:**
```bash
./deploy.sh              # Succeeds but health check fails
./rollback.sh            # Restores previous version
curl http://localhost:8080/health  # Returns 200
```

### Scenario 4: Missing Configuration

**File**: `app.py` (line ~86)

**To Activate:**
Uncomment to check for required configuration:

```python
# 4. MISSING REQUIRED FILE (uncomment to break):
required_file = Path("/required/config/missing.conf")
if not required_file.exists():
    logger.error("Required configuration file missing")
    return jsonify({"status": "DOWN", "error": "Missing configuration"}), 500
```

**Expected Behavior:**
- Application starts but health check returns 500
- Deployment verification fails
- Rollback triggered automatically
- Previous version with valid config restored

**Testing Command:**
```bash
./deploy.sh              # Fails due to missing config
./rollback.sh            # Restores previous version
curl http://localhost:8080/health  # Returns 200
```

### Custom Failure Injection

Add your own failure scenarios in the health endpoint:

```python
# Custom validation logic
if some_condition:
    logger.error("Custom validation failed")
    return jsonify({"status": "DOWN", "error": "Custom error"}), 500
```

## Version Management

### Update Application Version

Edit `version.txt`:

```bash
# Change version for deployment
echo "2.0.0" > version.txt

# Deploy new version
./deploy.sh

# Verify version
curl http://localhost:8080/health | grep version
```

### Version Tracking in Backups

Each backup directory includes the version:
```
backups/backup_1.0.0_20240115_103045/
├── app.py
├── requirements.txt
├── version.txt          # Contains: 1.0.0
└── application.log.bak
```

## Production Deployment

### System Integration

For production deployment on Linux servers:

1. **Create system service** (systemd):

```ini
[Unit]
Description=AI Autonomous Deployment Demo
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/demo
ExecStart=/usr/bin/python3 /opt/demo/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

2. **Configure log rotation**:

```
/opt/demo/application.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

3. **Harness CI/CD Integration**:

```yaml
# Example Harness Workflow
deployment:
  type: SSH
  scripts:
    - name: Deploy
      script: ./deploy.sh
    - name: Health Check
      script: curl http://localhost:8080/health
  
  rollback:
    - name: Automatic Rollback
      script: ./rollback.sh
      onFailure: true
```

## Architecture for AI Analysis

This application is designed to support AI-based rollback analysis:

### Log Structure
- **Timestamp**: Precise ISO 8601 format for temporal analysis
- **Log Level**: ERROR/INFO for error detection
- **Context**: Endpoint and version information
- **Metrics**: Response codes, timing information

### Health Endpoint
- **Structured JSON**: Easy parsing for ML models
- **Version Field**: Track deployment changes
- **Status Codes**: Clear success/failure indication

### Failure Scenarios
- Recoverable errors (health checks fail but process runs)
- Unrecoverable errors (process crashes)
- Configuration errors (missing dependencies)
- All designed to trigger rollback scenarios

### Analysis Use Cases
- **Anomaly Detection**: Identify unusual patterns in logs
- **Failure Classification**: Categorize failure types
- **Rollback Prediction**: Predict when rollback is needed
- **Root Cause Analysis**: Trace failure origins
- **Deployment Success Rate**: Measure deployment reliability

## Troubleshooting

### Application Won't Start

```bash
# Check Python installation
python3 --version

# Check for port conflicts
lsof -i :8080

# Install dependencies
pip3 install -r requirements.txt

# Run directly to see errors
python3 app.py
```

### Health Check Fails

```bash
# Check if application is running
ps aux | grep "python3 app.py"

# Check logs for errors
tail -50 application.log

# Manually test endpoint
curl -v http://localhost:8080/health
```

### Deployment Script Issues

```bash
# Verify script permissions
chmod +x deploy.sh rollback.sh

# Run with debug output
bash -x deploy.sh

# Check backups exist
ls -la backups/
```

### Rollback Fails

```bash
# List available backups
ls -la backups/

# Check latest backup is complete
ls -la backups/backup_*/ | head -20

# Verify permissions
ls -la app.py requirements.txt version.txt
```

## Contributing

Suggestions for improvements:
- Add database integration examples
- Implement graceful shutdown handlers
- Add metrics collection (Prometheus)
- Add request tracing (OpenTelemetry)
- Implement Blue-Green deployment patterns
- Add canary deployment hooks

## License

MIT License - Free for educational and demonstration purposes.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review application logs
3. Verify environment setup
4. Test individual components

## Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Python Logging Guide](https://docs.python.org/3/library/logging.html)
- [Harness Deployment Guides](https://docs.harness.io/)
- [Rolling Deployments vs Rollbacks](https://en.wikipedia.org/wiki/Deployment_automation)

---

**Last Updated**: 2024-01-15  
**Version**: 1.0.0  
**Status**: Production Ready
