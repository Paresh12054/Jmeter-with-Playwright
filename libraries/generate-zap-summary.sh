#!/bin/bash
set -e

echo "Generating ZAP summary..."

if [ -f zap-report.json ]; then

  FAIL=$(jq '.site[].alerts[] | select(.riskcode=="3")' zap-report.json | wc -l)

  WARN=$(jq '.site[].alerts[] | select(.riskcode=="2")' zap-report.json | wc -l)

  if [ "$FAIL" -gt 0 ]; then
    STATUS="FAIL"
    COLOR="Red"
  else
    STATUS="PASS"
    COLOR="Green"
  fi

else

  STATUS="NO REPORT"
  COLOR="Yellow"
  FAIL=0
  WARN=0

fi

cat <<EOF > zap-summary.html
<table border='1'>
<tr>
  <th>Security Check</th>
  <th>Status</th>
  <th>High</th>
  <th>Medium</th>
</tr>

<tr>
  <td>OWASP ZAP</td>
  <td>
    <ac:structured-macro ac:name="status">
      <ac:parameter ac:name="colour">$COLOR</ac:parameter>
      <ac:parameter ac:name="title">$STATUS</ac:parameter>
    </ac:structured-macro>
  </td>
  <td>$FAIL</td>
  <td>$WARN</td>
</tr>
</table>
EOF

echo "ZAP summary generated"
