#!/bin/bash
set -e
echo "================================================"
echo " Running tests..."
echo "================================================"

# Create virtual environment
python3 -m venv /tmp/venv

# Use venv binaries directly
PIP=/tmp/venv/bin/pip
FLAKE8=/tmp/venv/bin/flake8
PYTEST=/tmp/venv/bin/pytest

# Install dependencies
echo "[1/3] Installing dependencies..."
$PIP install -r requirements.txt --quiet
$PIP install flake8 pytest pytest-django --quiet

# Linting
echo "[2/3] Running flake8..."
$FLAKE8 mydjanjo/ --max-line-length=120 --exclude=migrations --statistics || true

# Tests
echo "[3/3] Running pytest..."
$PYTEST mydjanjo/tests/ -v --tb=short

echo "================================================"
echo " All tests passed."
echo "================================================"
