#!/usr/bin/env python3
"""
AI Autonomous Deployment Rollback Demo Application
A lightweight Flask application for demonstrating deployment and rollback scenarios.
"""

import os
import sys
import logging
from datetime import datetime
from pathlib import Path
from flask import Flask, jsonify, request

# Configuration
APP_PORT = int(os.getenv("PORT", "8090"))
APP_HOST = "0.0.0.0"
LOG_DIR = os.getenv("LOG_DIR", ".")
os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, "application.log")

VERSION_FILE = "version.txt"

# Initialize Flask application
app = Flask(__name__)

# Configure logging
def setup_logging():
    """Configure application logging to file and console."""
    log_format = "%(asctime)s - %(levelname)s - %(message)s"
    
    # Create logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # File handler
    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(logging.Formatter(log_format))
    logger.addHandler(file_handler)
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter(log_format))
    logger.addHandler(console_handler)
    
    return logger

def read_version():
    """Read version from version.txt file."""
    try:
        if Path(VERSION_FILE).exists():
            with open(VERSION_FILE, 'r') as f:
                version = f.read().strip()
                return version
        return "unknown"
    except Exception as e:
        logger.error(f"Failed to read version file: {e}")
        return "unknown"

# Setup logging before any log calls
logger = setup_logging()

# Read version
APP_VERSION = read_version()

@app.route("/", methods=["GET"])
def index():
    """Root endpoint returning deployment demo status."""
    logger.info("GET / - Root endpoint accessed")
    return "Deployment Demo Running\n", 200

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    logger.info("GET /health - Health check requested")
    
    # Example: Intentional failure scenarios for testing rollback
    # Uncomment any of these to simulate different failure modes:
    
    # 1. INVALID IMPORT FAILURE (uncomment to break):
    # from non_existent_module import something  # This will cause startup failure
    
    # 2. STARTUP EXCEPTION (uncomment to break):
    # raise RuntimeError("Intentional startup failure for rollback testing")
    
    # 3. HEALTH CHECK FAILURE (uncomment to break):
    # return jsonify({"status": "DOWN", "error": "Intentional health check failure"}), 503
    
    # 4. MISSING REQUIRED FILE (uncomment to break):
    # required_file = Path("/required/config/missing.conf")
    # if not required_file.exists():
    #     logger.error("Required configuration file missing")
    #     return jsonify({"status": "DOWN", "error": "Missing configuration"}), 500
    
    response = {
        "status": "UP",
        "version": APP_VERSION,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    logger.info(f"Health check successful - Version: {APP_VERSION}")
    return jsonify(response), 200

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    logger.warning(f"404 Not Found - Path: {request.path if 'request' in dir() else 'unknown'}")
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    logger.error(f"500 Internal Server Error: {str(error)}")
    return jsonify({"error": "Internal server error"}), 500

def startup_checks():
    """Perform startup validation checks."""
    logger.info("=" * 60)
    logger.info("Starting AI Autonomous Deployment Rollback Demo Application")
    logger.info("=" * 60)
    logger.info(f"Application Version: {APP_VERSION}")
    logger.info(f"Listening on: {APP_HOST}:{APP_PORT}")
    logger.info(f"Process ID: {os.getpid()}")
    logger.info(f"Timestamp: {datetime.utcnow().isoformat()}")
    
    # Example: Add custom startup validation
    # Uncomment to simulate startup failure:
    # if some_condition:
    #     logger.critical("Startup validation failed!")
    #     raise RuntimeError("Application startup validation failed")
    
    logger.info("Startup checks completed successfully")
    logger.info("=" * 60)

if __name__ == "__main__":
    try:
        startup_checks()
        logger.info(f"Starting Flask application on {APP_HOST}:{APP_PORT}")
        app.run(host=APP_HOST, port=APP_PORT, debug=False)
    except Exception as e:
        logger.critical(f"Application startup failed: {str(e)}", exc_info=True)
        sys.exit(1)
