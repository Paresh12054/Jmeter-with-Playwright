#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

JTL_FILE="config/Rovo_Test1.jtl"
OUTPUT_DIR="rovo-output"
ANALYSIS_FILE="${OUTPUT_DIR}/jmeter_analysis.html"

CONFLUENCE_BASE_URL="${CONFLUENCE_BASE_URL}"
CONFLUENCE_EMAIL="${CONFLUENCE_EMAIL}"
CONFLUENCE_API_TOKEN="${CONFLUENCE_API_TOKEN}"

PARENT_PAGE_ID="6094858"
SPACE_KEY="${CONFLUENCE_SPACE_KEY}"

mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo " JMeter Results Analysis"
echo "=========================================="

# ============================================================
# Validate JTL
# ============================================================

if [ ! -f "$JTL_FILE" ]; then
    echo "ERROR: JTL file not found: $JTL_FILE"
    exit 1
fi

echo "JTL file: $JTL_FILE"


# ============================================================
# Generate JMeter Analysis
# ============================================================

python3 <<'PY' > "$ANALYSIS_FILE"

import csv
import statistics
from datetime import datetime
from html import escape

file = "config/Rovo_Test1.jtl"

with open(file, newline="", encoding="utf-8", errors="ignore") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

if not rows:
    print("<p><strong>No JMeter samples were found.</strong></p>")
    raise SystemExit(0)


def get_float(row, column):
    try:
        return float(row.get(column, "") or 0)
    except:
        return 0


def percentile(values, percentage):

    values = sorted(values)

    if not values:
        return 0

    index = (len(values) - 1) * percentage

    lower = int(index)
    upper = min(lower + 1, len(values) - 1)

    if lower == upper:
        return values[lower]

    return values[lower] + (
        values[upper] - values[lower]
    ) * (index - lower)


# ------------------------------------------------------------
# Basic metrics
# ------------------------------------------------------------

total = len(rows)

successful = sum(
    1 for row in rows
    if str(row.get("success", "")).lower() == "true"
)

failed = total - successful

error_rate = (
    failed / total * 100
    if total > 0
    else 0
)


# ------------------------------------------------------------
# Response times
# ------------------------------------------------------------

response_times = [
    get_float(row, "elapsed")
    for row in rows
]

response_times = [
    value for value in response_times
    if value >= 0
]

average = statistics.mean(response_times)
minimum = min(response_times)
maximum = max(response_times)

p50 = percentile(response_times, 0.50)
p90 = percentile(response_times, 0.90)
p95 = percentile(response_times, 0.95)
p99 = percentile(response_times, 0.99)


# ------------------------------------------------------------
# Duration / throughput
# ------------------------------------------------------------

timestamps = [
    get_float(row, "timeStamp")
    for row in rows
    if get_float(row, "timeStamp") > 0
]

duration_seconds = 0
throughput_per_second = 0
throughput_per_minute = 0

if len(timestamps) >= 2:

    duration_seconds = (
        max(timestamps) - min(timestamps)
    ) / 1000

    if duration_seconds > 0:

        throughput_per_second = (
            total / duration_seconds
        )

        throughput_per_minute = (
            throughput_per_second * 60
        )


# ------------------------------------------------------------
# Start HTML
# ------------------------------------------------------------

print("""
<h1>JMeter NFT Performance Analysis</h1>
""")

print(f"""
<p>
<strong>Test Results File:</strong> {escape(file)}
</p>
""")

print(f"""
<h2>Executive Summary</h2>

<p>
The JMeter test executed <strong>{total:,}</strong> samples.
The test recorded an error rate of
<strong>{error_rate:.2f}%</strong>.
The average response time was
<strong>{average:.2f} ms</strong>,
with a P95 response time of
<strong>{p95:.2f} ms</strong>
and a P99 response time of
<strong>{p99:.2f} ms</strong>.
</p>
""")


# ------------------------------------------------------------
# Results table
# ------------------------------------------------------------

print("""
<h2>Performance Results</h2>

<table>
<tr>
<th>Metric</th>
<th>Result</th>
</tr>
""")

metrics = [
    ("Total Samples", f"{total:,}"),
    ("Successful Samples", f"{successful:,}"),
    ("Failed Samples", f"{failed:,}"),
    ("Error Rate", f"{error_rate:.2f}%"),
    ("Average Response Time", f"{average:.2f} ms"),
    ("Minimum Response Time", f"{minimum:.2f} ms"),
    ("Maximum Response Time", f"{maximum:.2f} ms"),
    ("P50 Response Time", f"{p50:.2f} ms"),
    ("P90 Response Time", f"{p90:.2f} ms"),
    ("P95 Response Time", f"{p95:.2f} ms"),
    ("P99 Response Time", f"{p99:.2f} ms"),
    ("Test Duration", f"{duration_seconds:.2f} seconds"),
    ("Throughput", f"{throughput_per_minute:.2f} samples/min"),
]

for name, value in metrics:

    print(f"""
<tr>
<td>{escape(name)}</td>
<td><strong>{escape(value)}</strong></td>
</tr>
""")

print("</table>")


# ------------------------------------------------------------
# Analysis
# ------------------------------------------------------------

print("<h2>Analysis</h2>")

print("<ul>")

if error_rate == 0:

    print("""
<li>
No failed samples were recorded during the test.
</li>
""")

elif error_rate < 1:

    print(f"""
<li>
The test recorded a low error rate of
<strong>{error_rate:.2f}%</strong>.
</li>
""")

else:

    print(f"""
<li>
<strong>Attention:</strong> The test recorded an error rate of
<strong>{error_rate:.2f}%</strong>.
Further investigation of failed transactions is recommended.
</li>
""")


print(f"""
<li>
Average response time was
<strong>{average:.2f} ms</strong>.
</li>
""")

print(f"""
<li>
P95 response time was
<strong>{p95:.2f} ms</strong>,
meaning approximately 95% of recorded requests completed
within this response time.
</li>
""")

print(f"""
<li>
P99 response time was
<strong>{p99:.2f} ms</strong>.
This should be reviewed for potential long-running
transactions or performance outliers.
</li>
""")

if throughput_per_minute > 0:

    print(f"""
<li>
Observed throughput was approximately
<strong>{throughput_per_minute:.2f} samples/minute</strong>.
</li>
""")

if maximum > p95 * 3:

    print(f"""
<li>
The maximum response time of
<strong>{maximum:.2f} ms</strong>
is significantly higher than the P95 response time,
indicating potential response-time outliers.
</li>
""")

print("</ul>")


# ------------------------------------------------------------
# Recommendations
# ------------------------------------------------------------

print("""
<h2>Recommendations</h2>

<ul>

<li>
Review failed transactions and associated error messages,
where applicable.
</li>

<li>
Review P95 and P99 response times for the slowest
transactions and identify potential performance bottlenecks.
</li>

<li>
Correlate response-time behaviour with application,
database and infrastructure monitoring data where available.
</li>

<li>
Compare the observed throughput and response times against
the agreed performance objectives before determining final
test status.
</li>

</ul>
""")


# ------------------------------------------------------------
# Footer
# ------------------------------------------------------------

print(f"""
<hr>

<p>
<strong>Generated automatically by the NFT/JMeter pipeline.</strong>
<br>
Generated on: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
</p>
""")

PY


echo ""
echo "Analysis generated:"
echo "$ANALYSIS_FILE"


# ============================================================
# Publish to Confluence
# ============================================================

echo ""
echo "=========================================="
echo " Publishing results to Confluence"
echo "=========================================="


AUTH=$(printf '%s:%s' \
    "$CONFLUENCE_EMAIL" \
    "$CONFLUENCE_API_TOKEN" | base64 -w 0)


# ------------------------------------------------------------
# Convert HTML to JSON safely
# ------------------------------------------------------------

PAGE_BODY=$(python3 - <<'PY'
import json

with open("rovo-output/jmeter_analysis.html", "r", encoding="utf-8") as f:
    content = f.read()

print(json.dumps(content))
PY
)


# ------------------------------------------------------------
# Create Confluence page
# ------------------------------------------------------------

TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

PAGE_TITLE="NFT JMeter Analysis - ${TIMESTAMP}"


JSON_PAYLOAD=$(cat <<EOF
{
  "type": "page",
  "title": "${PAGE_TITLE}",
  "space": {
    "key": "${SPACE_KEY}"
  },
  "ancestors": [
    {
      "id": "${PARENT_PAGE_ID}"
    }
  ],
  "body": {
    "storage": {
      "value": ${PAGE_BODY},
      "representation": "storage"
    }
  }
}
EOF
)


RESPONSE=$(curl -sS \
    -w "\nHTTP_STATUS:%{http_code}" \
    -X POST \
    "${CONFLUENCE_BASE_URL}/wiki/rest/api/content" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD"
)


echo ""
echo "Confluence response:"
echo "$RESPONSE"


HTTP_STATUS=$(echo "$RESPONSE" \
    | grep "HTTP_STATUS" \
    | cut -d: -f2)


if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then

    echo ""
    echo "✅ JMeter analysis successfully published to Confluence."

else

    echo ""
    echo "❌ Failed to publish JMeter analysis."
    exit 1

fi
