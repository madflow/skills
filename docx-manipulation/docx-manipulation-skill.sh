#!/bin/bash
# Wrapper script to run Python with the uv-managed virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$SCRIPT_DIR/venv/bin/python"

# Check if venv exists
if [ ! -f "$VENV_PYTHON" ]; then
    echo "Error: Virtual environment not found. Please run:" >&2
    echo "  cd $SCRIPT_DIR && uv venv venv && uv pip install --python venv/bin/python -r requirements.txt" >&2
    exit 1
fi

# Run Python with the venv
exec "$VENV_PYTHON" "$@"
