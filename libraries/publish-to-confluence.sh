#!/bin/bash

set -e

BASE_URL="$CONFLUENCE_BASE_URL"
EMAIL="$CONFLUENCE_EMAIL"
TOKEN="$CONFLUENCE_API_TOKEN"
SPACE_KEY="$CONFLUENCE_SPACE_KEY"

PARENT_ID="6094858"
INDEX_PAGE_ID="6094858"

AUTH=$(printf "%s:%s" "$EMAIL" "$TOKEN" | base64)

NOW=$(date +"%d/%m/%Y %H:%M:%S")

CONTENT_FILE="confluence-content.html"

# ============================================================
# Read files
# ============================================================

AGG_HTML=$(cat agg.html)
ZAP_SUMMARY=$(cat zap-summary.html)

PW_ROWS=$(tail -n +2 pw_runs_summary.txt | awk -F',' '
{
  printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
  $1,$2,$3,$4,$5,$6
}')

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
# Create JSON payload
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
# Create Confluence page
# ============================================================

curl -s -X POST \
  "${BASE_URL}/rest/api/content" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  --data @payload.json \
  -o response.json

PAGE_ID=$(jq -r '.id' response.json)

echo "Confluence page created: ${PAGE_ID}"

# ============================================================
# Upload attachments
# ============================================================

upload_file() {

  FILE=$1

  if [ -f "$FILE" ]; then

    echo "Uploading $FILE"

    curl -s -X POST \
      "${BASE_URL}/rest/api/content/${PAGE_ID}/child/attachment" \
      -H "Authorization: Basic ${AUTH}" \
      -H "X-Atlassian-Token: no-check" \
      -F "file=@${FILE}"

    echo "$FILE uploaded"
  fi
}

upload_file "zap-report.png"
upload_file "playwright-report.png"
upload_file "playwright-report.zip"
upload_file "jmeter-dashboard-full.png"

# ============================================================
# Upload all JMeter graph PNGs
# ============================================================

if [ -d "jm-graphs" ]; then

  for file in jm-graphs/*.png; do
    [ -e "$file" ] || continue
    upload_file "$file"
  done

fi

# ============================================================
# Export Page ID
# ============================================================

echo "PAGE_ID=${PAGE_ID}" >> "$GITHUB_ENV"

echo "Confluence publish completed"
