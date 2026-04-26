#!/bin/bash
set -e
echo "Running tests..."
pip3 install -r requirements.txt --quiet
python3 -m pytest app/tests/ -v --tb=short
echo "All tests passed."
