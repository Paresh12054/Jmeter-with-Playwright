#!/bin/bash

set +e

upload() {

  FILE=$1

  if [ -f "$FILE" ]; then

    echo "Uploading $FILE"

    curl -s \
      -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
      -X POST \
      -H "X-Atlassian-Token: no-check" \
      -F "file=@$FILE" \
      "$CONFLUENCE_BASE_URL/rest/api/content/$PAGE_ID/child/attachment"

    echo "$FILE uploaded"

  else
    echo "$FILE not found"
  fi
}

# Upload JMeter results
upload results.jtl

# Zip JMeter HTML report
if [ -d "jmeter-report" ]; then

  echo "Creating jmeter-report.zip"

  zip -r jmeter-report.zip jmeter-report

  upload jmeter-report.zip

fi

# Upload ZAP report
upload zap-report.html

# Upload Playwright JSON results
if [ -d "pw-results" ]; then

  for f in pw-results/*.json; do
    [ -f "$f" ] && upload "$f"
  done

fi

echo "All uploads completed"
