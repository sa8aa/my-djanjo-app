#!/bin/bash
set -e
echo "================================================"
echo " Running tests..."
echo "================================================"

# Create virtual environment if it doesn't exist
python3 -m venv /tmp/venv

# Activate it
source /tmp/venv/bin/activate

# Install dependencies inside the venv
echo "[1/3] Installing dependencies..."
pip install -r requirements.txt --quiet

# Linting
echo "[2/3] Running flake8..."
flake8 . --max-line-length=120 --exclude=migrations --statistics || true

# Tests
echo "[3/3] Running pytest..."
pytest app/tests/ -v --tb=short

echo "================================================"
echo " All tests passed."
echo "================================================"
