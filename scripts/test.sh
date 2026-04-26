#!/bin/bash
set -e
echo "Running tests..."
python -m pytest app/tests/ -v --tb=short
echo "All tests passed."
