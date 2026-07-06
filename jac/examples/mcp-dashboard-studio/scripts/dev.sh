#!/usr/bin/env bash
# scripts/dev.sh — start the MCP server and the Jac full-stack app together.
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ENTRY="main.jac"
MCP_PORT=3001
TRANSPORT="streamable-http"

cd "$PROJECT_ROOT"

echo ""
echo "=========================================="
echo "  Jac MCP Studio — Dev Environment"
echo "=========================================="
echo ""

# ── Virtual environment ─────────────────────────────────────────────────────
if [ -d ".venv" ]; then
    echo "Activating virtual environment (.venv)"
    source .venv/bin/activate
else
    echo "ERROR: .venv not found. Run: uv venv && uv sync"
    exit 1
fi

# ── Check jac ───────────────────────────────────────────────────────────────
if ! command -v jac >/dev/null 2>&1; then
    echo "ERROR: 'jac' not found. Install with: uv sync"
    exit 1
fi

echo "Jac: $(jac --version 2>&1 | head -1)"

# ── Check jac-mcp plugin ────────────────────────────────────────────────────
if ! jac --version 2>&1 | grep -q "jac-mcp"; then
    echo "ERROR: jac-mcp plugin not installed. Run: uv add jac-mcp"
    exit 1
fi

# ── Free MCP port if occupied ───────────────────────────────────────────────
if lsof -ti :"$MCP_PORT" >/dev/null 2>&1; then
    echo "Port $MCP_PORT in use — killing existing process..."
    kill -9 "$(lsof -ti :"$MCP_PORT")"
    sleep 1
fi

# ── Start MCP server ─────────────────────────────────────────────────────────
echo ""
echo "Starting MCP server"
echo "  Transport : $TRANSPORT"
echo "  Port      : $MCP_PORT"
echo "  URL       : http://127.0.0.1:$MCP_PORT/mcp/"
echo ""

jac mcp --transport "$TRANSPORT" --port "$MCP_PORT" &
MCP_PID=$!

# Wait for server to be ready
sleep 2

if ! kill -0 "$MCP_PID" 2>/dev/null; then
    echo "ERROR: MCP server failed to start."
    exit 1
fi

echo "MCP server running (PID: $MCP_PID)"

# ── Cleanup on exit ──────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "Stopping MCP server (PID: $MCP_PID)..."
    kill "$MCP_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Start Jac full-stack app ─────────────────────────────────────────────────
echo ""
echo "Starting Jac app"
echo "  Entry : $APP_ENTRY"
echo ""

jac start "$APP_ENTRY" --dev
