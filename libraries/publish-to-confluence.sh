#!/bin/bash

set -e

# ============================================================
# Environment Variables
# ============================================================

BASE_URL="$CONFLUENCE_BASE_URL"
EMAIL="$CONFLUENCE_EMAIL"
TOKEN="$CONFLUENCE_API_TOKEN"
SPACE_KEY="$CONFLUENCE_SPACE_KEY"

PARENT_ID="6094858"
INDEX_PAGE_ID="6094858"

AUTH=$(echo -n "$EMAIL:$TOKEN" | base64)

NOW=$(date +"%d/%m/%Y %H:%M:%S")

CONTENT_FILE="confluence-content.html"

# ============================================================
# Validation
# ============================================================

if [ -z "$BASE_URL" ]; then
  echo "CONFLUENCE_BASE_URL is missing"
  exit 1
fi

if [ -z "$EMAIL" ]; then
  echo "CONFLUENCE_EMAIL is missing"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  echo "CONFLUENCE_API_TOKEN is missing"
  exit 1
fi

if [ -z "$SPACE_KEY" ]; then
  echo "CONFLUENCE_SPACE_KEY is missing"
  exit 1
fi

echo "Using Confluence URL: $BASE_URL"

# ============================================================
# Read Files Safely
# ============================================================

AGG_HTML=$(cat agg.html 2>/dev/null || echo "")
ZAP_SUMMARY=$(cat zap-summary.html 2>/dev/null || echo "")

if [ -f "pw_runs_summary.txt" ]; then

  PW_ROWS=$(tail -n +2 pw_runs_summary.txt | awk -F',' '
  {
    printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
    $1,$2,$3,$4,$5,$6
  }')

else

  PW_ROWS=""

fi

AI_SUMMARY=$(echo "${AI_SUMMARY:-}" \
  | sed 's/&/\&amp;/g' \
  | sed 's/</\&lt;/g' \
  | sed 's/>/\&gt;/g')

# ============================================================
# Build HTML Content
# ============================================================

cat > "$CONTENT_FILE" <<EOF
<h1>🚀 Performance & UI Test Report</h1>

<h2>📊 Test Summary</h2>

<table border='1' style='border-collapse: collapse; width: 60%;'>
<tr><th>Test Type</th><td>Automation + Load + Security</td></tr>
<tr><th>Test Date</th><td>${NOW}</td></tr>
<tr><th>Test Duration</th><td>${TEST_DURATION}</td></tr>
<tr><th>Concurrent Users</th><td>${CONCURRENT_USERS}</td></tr>
</table>

<h2>📏 SLA Configuration</h2>

<table border='1'>
<tr><th>Metric</th><th>Threshold</th></tr>
<tr><td>Avg (ms)</td><td>${SLA_AVG}</td></tr>
<tr><td>P90 (ms)</td><td>${SLA_P90}</td></tr>
<tr><td>Error %</td><td>${SLA_ERR}</td></tr>
</table>

<h2>📈 Transaction-Level Aggregate</h2>

${AGG_HTML}

<h2>🎭 Playwright Summary</h2>

<table border='1'>
<tr>
<th>Run</th>
<th>Start</th>
<th>End</th>
<th>Duration</th>
<th>Passed</th>
<th>Failed</th>
</tr>

${PW_ROWS}

</table>

<h2>🔐 Security Summary</h2>

${ZAP_SUMMARY}

<h2>🧠 AI Analysis & Observations</h2>

${AI_SUMMARY}

<h2>📎 Attachments</h2>

<ac:structured-macro ac:name="attachments"/>
EOF

echo "Confluence HTML generated"

# ============================================================
# Create JSON Payload
# ============================================================

TITLE="Performance Report - ${NOW}"

jq -n \
  --arg title "$TITLE" \
  --arg parentId "$PARENT_ID" \
  --arg spaceKey "$SPACE_KEY" \
  --rawfile content "$CONTENT_FILE" \
'
{
  type: "page",
  title: $title,
  ancestors: [{id: $parentId}],
  space: {key: $spaceKey},
  body: {
    storage: {
      value: $content,
      representation: "storage"
    }
  }
}
' > payload.json

# ============================================================
# Validate Payload
# ============================================================

echo "===================================="
echo "Validating payload.json"
echo "===================================="

jq . payload.json

echo "Payload size:"
wc -c payload.json

echo "===================================="

# ============================================================
# Create Confluence Page
# ============================================================

echo "Creating Confluence page..."

curl --http1.1 \
  --fail-with-body \
  -sS \
  -X POST \
  "${BASE_URL}/rest/api/content" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  --data-binary @payload.json \
  -o response.json

echo "===================================="
echo "Confluence API Response"
echo "===================================="

cat response.json

echo "===================================="

PAGE_ID=$(jq -r '.id // empty' response.json)

if [ -z "$PAGE_ID" ]; then
  echo "Failed to create Confluence page"
  exit 1
fi

echo "Confluence page created: ${PAGE_ID}"

# ============================================================
# Upload Attachments
# ============================================================

upload_file() {

  FILE=$1

  if [ -f "$FILE" ]; then

    echo "Uploading $FILE"

    curl --http1.1 \
      --fail-with-body \
      -sS \
      -X POST \
      "${BASE_URL}/rest/api/content/${PAGE_ID}/child/attachment" \
      -H "Authorization: Basic ${AUTH}" \
      -H "X-Atlassian-Token: no-check" \
      -F "file=@${FILE}"

    echo "$FILE uploaded"

  else

    echo "$FILE not found"

  fi
}

upload_file "zap-report.png"
upload_file "playwright-report.png"
upload_file "playwright-report.zip"
upload_file "jmeter-dashboard-full.png"

# ============================================================
# Upload JMeter Graph PNGs
# ============================================================

if [ -d "jm-graphs" ]; then

  for file in jm-graphs/*.png; do
    [ -e "$file" ] || continue
    upload_file "$file"
  done

fi

# ============================================================
# Export PAGE_ID
# ============================================================

if [ -n "$GITHUB_ENV" ]; then
  echo "PAGE_ID=${PAGE_ID}" >> "$GITHUB_ENV"
fi

echo "===================================="
echo "Confluence publish completed"
echo "===================================="
