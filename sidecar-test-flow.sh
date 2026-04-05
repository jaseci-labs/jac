#!/bin/bash
# Sidecar API Test Flow
# Usage: bash sidecar-test-flow.sh [PORT]
# Default port: 8000

PORT=${1:-8000}
BASE="http://127.0.0.1:$PORT"
USER="sidecartest@test.comd"
PASS="test123"

echo "=== Testing sidecar at $BASE ==="
echo ""

# 1. Register
echo "=== 1. REGISTER ==="
curl -s -X POST "$BASE/user/register" \
  -H 'Content-Type: application/json' \
  --data-raw "{\"username\":\"$USER\",\"password\":\"$PASS\"}" 2>&1 | head -1
echo ""

# 2. Login
echo "=== 2. LOGIN ==="
LOGIN_RES=$(curl -s -X POST "$BASE/user/login" \
  -H 'Content-Type: application/json' \
  --data-raw "{\"username\":\"$USER\",\"password\":\"$PASS\"}" 2>&1)
TOKEN=$(echo "$LOGIN_RES" | python -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "FAILED to get token"
  echo "$LOGIN_RES"
  exit 1
fi
echo "Token: ${TOKEN:0:30}..."
echo ""

# 3. Me (create profile)
echo "=== 3. ME ==="
curl -s -X POST "$BASE/walker/me" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"display_name_hint\":\"$USER\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK' if r and r[0].get('success') else 'FAIL:', r[0] if r else d)" 2>/dev/null
echo ""

# 4. Template list
echo "=== 4. TEMPLATE LIST ==="
curl -s -X POST "$BASE/walker/template_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw '{"action":"list"}' 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); templates=r[0].get('templates',[]) if r else []; print(f'OK: {len(templates)} templates') if templates else print('FAIL:', r)" 2>/dev/null
echo ""

# 5. Community list
echo "=== 5. COMMUNITY LIST ==="
curl -s -X POST "$BASE/walker/community_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw '{"action":"list","search":"","tag":""}' 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK' if r else 'FAIL:', r[0] if r else d)" 2>/dev/null
echo ""

# 6. Project list (should be empty)
echo "=== 6. PROJECT LIST ==="
curl -s -X POST "$BASE/walker/project_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw '{"action":"list"}' 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK: projects=', len(r[0].get('projects',[]))) if r else print('FAIL:', d)" 2>/dev/null
echo ""

# 7. Create project
echo "=== 7. CREATE PROJECT ==="
CREATE_RES=$(curl -s -X POST "$BASE/walker/project_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw '{"action":"create","name":"test-sidecar","template_id":"client"}' 2>&1)
PID=$(echo "$CREATE_RES" | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print(r[0].get('project',{}).get('id','')) if r and r[0].get('success') else print('')" 2>/dev/null)
if [ -z "$PID" ]; then
  echo "FAIL: $CREATE_RES" | head -1
else
  echo "OK: project_id=$PID"
fi
echo ""

# 8. Git status
echo "=== 8. GIT STATUS ==="
curl -s -X POST "$BASE/walker/git_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"action\":\"status\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK: branch=', r[0].get('branch','?'), 'dirty=', r[0].get('dirty','?')) if r and r[0].get('success') else print('FAIL:', r)" 2>/dev/null
echo ""

# 9. Git branches
echo "=== 9. GIT BRANCHES ==="
curl -s -X POST "$BASE/walker/git_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"action\":\"branches\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); branches=r[0].get('branches',[]) if r else []; print(f'OK: {len(branches)} branches') if r and r[0].get('success') else print('FAIL:', r)" 2>/dev/null
echo ""

# 10. GitHub status
echo "=== 10. GITHUB STATUS ==="
curl -s -X POST "$BASE/walker/github_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw '{"action":"status"}' 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK: connected=', r[0].get('github_connected','?')) if r else print('FAIL:', d)" 2>/dev/null
echo ""

# 11. File setup
echo "=== 11. FILE SETUP ==="
curl -s -X POST "$BASE/walker/ide_file_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"action\":\"setup\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK: status=', r[0].get('status','?')) if r and r[0].get('success') else print('FAIL:', r)" 2>/dev/null
echo ""

# 12. File list
echo "=== 12. FILE LIST ==="
curl -s -X POST "$BASE/walker/ide_file_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"action\":\"list\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); files=r[0].get('files',[]) if r else []; print(f'OK: {len(files)} files') if r and r[0].get('success') else print('FAIL:', r)" 2>/dev/null
echo ""

# 13. Version list
echo "=== 13. VERSION LIST ==="
curl -s -X POST "$BASE/walker/version_ops" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"action\":\"list\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); versions=r[0].get('versions',[]) if r else []; print(f'OK: {len(versions)} versions') if r and r[0].get('success') else print('FAIL:', r)" 2>/dev/null
echo ""

# 14. AI chat load history
echo "=== 14. AI CHAT HISTORY ==="
curl -s -X POST "$BASE/walker/ai_chat" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"action\":\"load_history\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK: messages=', len(r[0].get('messages',[]))) if r and r[0].get('success') else print('FAIL:', r)" 2>/dev/null
echo ""

# 15. AI chat start
echo "=== 15. AI CHAT START ==="
curl -s -X POST "$BASE/walker/ai_chat" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\",\"message\":\"hello\",\"current_file_path\":\"\",\"action\":\"start\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK: status=', r[1].get('status','?') if len(r)>1 else '?') if r else print('FAIL:', d)" 2>/dev/null
echo ""

# 16. Preview screenshot
echo "=== 16. PREVIEW SCREENSHOT ==="
curl -s -X POST "$BASE/walker/preview_screenshot" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data-raw "{\"project_id\":\"$PID\"}" 2>&1 | python -c "import sys,json; d=json.load(sys.stdin); r=d.get('data',{}).get('reports',[]); print('OK:', r[0].get('error','success') if r else 'no response')" 2>/dev/null
echo ""

echo "=== DONE ==="
