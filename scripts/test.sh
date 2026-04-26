#!/bin/bash
set -e
echo "Running tests..."
python3 -m pytest app/tests/ -v --tb=short
echo "All tests passed."
