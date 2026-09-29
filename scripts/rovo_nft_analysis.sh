#!/usr/bin/env bash

set -euo pipefail

ROVO_URL="https://mcp.atlassian.com/v2/mcp"
JTL_FILE="config/Rovo_Test1.jtl"

OUTPUT_DIR="rovo-output"
NFR_FILE="${OUTPUT_DIR}/nfr_context.txt"
METRICS_FILE="${OUTPUT_DIR}/jmeter_metrics.txt"
ANALYSIS_FILE="${OUTPUT_DIR}/nft_analysis.md"

mkdir -p "$OUTPUT_DIR"

echo "======================================"
echo " Rovo NFT Analysis"
echo "======================================"

# ---------------------------------------------------------
# 1. Validate JTL
# ---------------------------------------------------------

if [ ! -f "$JTL_FILE" ]; then
    echo "ERROR: JTL file not found: $JTL_FILE"
    exit 1
fi

echo "JTL found: $JTL_FILE"


# ---------------------------------------------------------
# 2. Extract useful JMeter statistics
# ---------------------------------------------------------

echo ""
echo "Extracting JMeter metrics..."

python3 <<'PY' > "$METRICS_FILE"
import csv
import statistics
from pathlib import Path

file = Path("config/Rovo_Test1.jtl")

with file.open(newline="", encoding="utf-8", errors="ignore") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

if not rows:
    print("No JMeter samples found.")
    raise SystemExit(0)

def number(row, key):
    try:
        return float(row.get(key, "") or 0)
    except:
        return 0

elapsed = [number(r, "elapsed") for r in rows]
success = [
    str(r.get("success", "")).lower() == "true"
    for r in rows
]

timestamps = [
    number(r, "timeStamp")
    for r in rows
    if number(r, "timeStamp") > 0
]

print("JMeter NFT Test Summary")
print("========================")
print(f"Total samples: {len(rows)}")
print(f"Successful samples: {sum(success)}")
print(f"Failed samples: {len(rows) - sum(success)}")
print(f"Error rate: {(len(rows) - sum(success)) / len(rows) * 100:.2f}%")

if elapsed:
    elapsed_sorted = sorted(elapsed)

    def percentile(values, p):
        index = int(len(values) * p)
        index = min(index, len(values) - 1)
        return sorted(values)[index]

    print(f"Average response time: {statistics.mean(elapsed):.2f} ms")
    print(f"Minimum response time: {min(elapsed):.2f} ms")
    print(f"Maximum response time: {max(elapsed):.2f} ms")
    print(f"P50 response time: {percentile(elapsed, 0.50):.2f} ms")
    print(f"P90 response time: {percentile(elapsed, 0.90):.2f} ms")
    print(f"P95 response time: {percentile(elapsed, 0.95):.2f} ms")
    print(f"P99 response time: {percentile(elapsed, 0.99):.2f} ms")

if len(timestamps) >= 2:
    duration_seconds = (max(timestamps) - min(timestamps)) / 1000

    if duration_seconds > 0:
        throughput = len(rows) / duration_seconds

        print(f"Test duration: {duration_seconds:.2f} seconds")
        print(f"Approx throughput: {throughput:.2f} samples/sec")

print("")
print("Note: Metrics are calculated from the JTL samples available in this file.")
PY

cat "$METRICS_FILE"


# ---------------------------------------------------------
# 3. Build MCP authentication
# ---------------------------------------------------------

echo ""
echo "Creating MCP authentication..."

AUTH=$(printf '%s:%s' \
  "$ATLASSIAN_EMAIL" \
  "$ATLASSIAN_API_TOKEN" | base64 -w 0)


# ---------------------------------------------------------
# 4. MCP INITIALIZE
# ---------------------------------------------------------

echo ""
echo "Initialising Rovo MCP session..."

INIT_RESPONSE=$(curl -sS \
  -D "$OUTPUT_DIR/init_headers.txt" \
  -X POST "$ROVO_URL" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-06-18",
      "capabilities": {},
      "clientInfo": {
        "name": "github-actions-nft-analysis",
        "version": "1.0.0"
      }
    }
  }')

echo "$INIT_RESPONSE"

SESSION_ID=$(grep -i '^mcp-session-id:' "$OUTPUT_DIR/init_headers.txt" \
  | sed 's/^[^:]*:[[:space:]]*//' \
  | tr -d '\r')

if [ -z "$SESSION_ID" ]; then
    echo "WARNING: No MCP session ID returned."
else
    echo "MCP session established."
fi


# ---------------------------------------------------------
# 5. Send initialized notification
# ---------------------------------------------------------

curl -sS \
  -X POST "$ROVO_URL" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  ${SESSION_ID:+-H "Mcp-Session-Id: ${SESSION_ID}"} \
  -d '{
    "jsonrpc": "2.0",
    "method": "notifications/initialized"
  }' > /dev/null


# ---------------------------------------------------------
# 6. Get Atlassian resources / cloudId
# ---------------------------------------------------------

echo ""
echo "Getting Atlassian resources..."

RESOURCES=$(curl -sS \
  -X POST "$ROVO_URL" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  ${SESSION_ID:+-H "Mcp-Session-Id: ${SESSION_ID}"} \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "getAccessibleAtlassianResources",
      "arguments": {}
    }
  }')

echo "$RESOURCES" > "$OUTPUT_DIR/resources.json"

CLOUD_ID=$(echo "$RESOURCES" | jq -r '
  .. |
  objects |
  .cloudId? // empty
' | head -1)

if [ -z "$CLOUD_ID" ]; then
    echo "ERROR: Could not determine Atlassian cloudId."
    cat "$OUTPUT_DIR/resources.json"
    exit 1
fi

echo "Cloud ID detected."


# ---------------------------------------------------------
# 7. Search Confluence for NFRs
# ---------------------------------------------------------

echo ""
echo "Searching Confluence for NFR information..."

NFR_SEARCH=$(curl -sS \
  -X POST "$ROVO_URL" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  ${SESSION_ID:+-H "Mcp-Session-Id: ${SESSION_ID}"} \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"id\": 3,
    \"method\": \"tools/call\",
    \"params\": {
      \"name\": \"searchConfluence\",
      \"arguments\": {
        \"cloudId\": \"${CLOUD_ID}\",
        \"cql\": \"type=page AND (text ~ 'NFR' OR text ~ 'non-functional requirements' OR text ~ 'performance requirements')\"
      }
    }
  }")

echo "$NFR_SEARCH" > "$OUTPUT_DIR/nfr_search.json"

echo "$NFR_SEARCH" > "$NFR_FILE"

echo ""
echo "NFR search completed."


# ---------------------------------------------------------
# 8. Create analysis input
# ---------------------------------------------------------

echo ""
echo "Preparing NFT analysis context..."

cat > "$OUTPUT_DIR/analysis_context.txt" <<EOF
========================================================
NFT PERFORMANCE TEST RESULTS
========================================================

$(cat "$METRICS_FILE")


========================================================
EXISTING CONFLUENCE NFR INFORMATION
========================================================

$(cat "$NFR_FILE")


========================================================
ANALYSIS INSTRUCTIONS
========================================================

Analyse the NFT performance test results against the
documented NFR information.

Identify:

1. NFRs that are met.
2. NFRs that are not met.
3. NFRs where there is insufficient information.
4. Response-time observations.
5. P95 and P99 performance observations.
6. Throughput observations.
7. Error-rate observations.
8. Potential performance bottlenecks.
9. Risks.
10. Recommended next steps.

Rules:

- Do not invent NFR values.
- Do not invent performance targets.
- Clearly distinguish measured results from documented NFRs.
- If an NFR cannot be found, state that it was not found in
  the available Confluence information.
- Recommendations must be based on the available evidence.

Produce a stakeholder-friendly NFT performance analysis.
EOF

echo ""
echo "Analysis context created:"
echo "$OUTPUT_DIR/analysis_context.txt"


# ---------------------------------------------------------
# 9. Save pipeline output
# ---------------------------------------------------------

cp "$OUTPUT_DIR/analysis_context.txt" "$ANALYSIS_FILE"

echo ""
echo "======================================"
echo " Analysis context ready"
echo "======================================"
echo ""
echo "Output:"
echo "$ANALYSIS_FILE"
