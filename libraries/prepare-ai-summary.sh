#!/bin/bash
set -e

echo "Preparing AI summary..."

awk -F',' '
NR>1 {

  label=$3
  success=tolower($8)

  gsub(/\r/,"",success)

  if (label ~ /^PT[0-9]+_/) {

    total[label]++

    if (success == "false" || success == "0")
      fail[label]++
  }
}

END {

  printf "{ \"transactions\": ["

  first=1

  for (l in total) {

    if (!first) printf ","

    printf "{ \"name\":\"%s\", \"count\":%d, \"errors\":%d }",
      l, total[l], (fail[l] ? fail[l] : 0)

    first=0
  }

  printf "], \"total_requests\": %d }\n", NR-1
}' results.jtl > ai_summary.json

echo "AI summary generated"
