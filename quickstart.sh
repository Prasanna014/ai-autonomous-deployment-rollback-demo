#!/bin/bash

##############################################################################
# Quick Start Script - Set up and run the demo application
##############################################################################

set -e

echo "=========================================="
echo "AI Autonomous Deployment Rollback Demo"
echo "Quick Start Setup"
echo "=========================================="

# Check Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not installed"
    exit 1
fi

echo "✓ Python version: $(python3 --version)"

# Install dependencies
echo ""
echo "Installing dependencies..."
pip3 install -r requirements.txt

echo ""
echo "=========================================="
echo "Setup complete! Starting application..."
echo "=========================================="
echo ""
echo "Application will run on: http://0.0.0.0:8080"
echo "Health endpoint: http://localhost:8080/health"
echo "Root endpoint: http://localhost:8080/"
echo ""
echo "Logs will be written to: application.log"
echo "Press Ctrl+C to stop"
echo "=========================================="
echo ""

# Run application
python3 app.py
