#!/bin/bash

# Generate HTML report
echo "<table border='1' style='border-collapse: collapse;'>" > agg.html

echo "<tr>
<th>Transaction</th>
<th>Total</th>
<th>Avg (ms)</th>
<th>P90 (ms)</th>
<th>P95 (ms)</th>
<th>Error %</th>
<th>Avg SLA</th>
<th>P90 SLA</th>
<th>Overall SLA</th>
</tr>" >> agg.html

awk -v sla_avg="$SLA_AVG" -v sla_p90="$SLA_P90" -F',' '
NR>1 {

  label=$3
  success=tolower($8)

  gsub(/\r/,"",success)
  gsub(/^[ \t"]+|[ \t"]+$/, "", success)

  if (label ~ /^PT[0-9]+_/) {
    total[label]++
    sum[label]+=$2

    if (success == "false" || success == "0")
      fail[label]++

    times[label]=times[label] " " $2
  }
}

END {

  # Transaction-level rows
  for (l in total) {

    n=split(times[l], arr, " ")

    idx=0
    delete clean

    for(i=1;i<=n;i++){
      if(arr[i]!="")
        clean[++idx]=arr[i]
    }

    n=idx

    for(i=1;i<=n;i++){
      for(j=i+1;j<=n;j++){
        if(clean[i]>clean[j]){
          tmp=clean[i]
          clean[i]=clean[j]
          clean[j]=tmp
        }
      }
    }

    p90_index = int((n*90 + 99)/100)
    p95_index = int((n*95 + 99)/100)

    p90 = clean[p90_index]
    p95 = clean[p95_index]

    avg = int(sum[l]/total[l])
    err = (total[l] > 0) ? (fail[l]/total[l])*100 : 0

    avg_sla = (avg <= sla_avg) ? "PASS" : "FAIL"
    p90_sla = (p90 <= sla_p90) ? "PASS" : "FAIL"

    overall = (avg_sla=="PASS" && p90_sla=="PASS") ? "PASS" : "FAIL"

    printf "<tr>"

    printf "<td>%s</td>", l
    printf "<td>%d</td>", total[l]
    printf "<td>%d</td>", avg
    printf "<td>%d</td>", p90
    printf "<td>%d</td>", p95
    printf "<td>%.2f</td>", err

    printf "<td>%s</td>", \
      (avg_sla=="PASS") ? \
      "<ac:structured-macro ac:name=\"status\"><ac:parameter ac:name=\"colour\">Green</ac:parameter><ac:parameter ac:name=\"title\">PASS</ac:parameter></ac:structured-macro>" : \
      "<ac:structured-macro ac:name=\"status\"><ac:parameter ac:name=\"colour\">Red</ac:parameter><ac:parameter ac:name=\"title\">FAIL</ac:parameter></ac:structured-macro>"

    printf "<td>%s</td>", \
      (p90_sla=="PASS") ? \
      "<ac:structured-macro ac:name=\"status\"><ac:parameter ac:name=\"colour\">Green</ac:parameter><ac:parameter ac:name=\"title\">PASS</ac:parameter></ac:structured-macro>" : \
      "<ac:structured-macro ac:name=\"status\"><ac:parameter ac:name=\"colour\">Red</ac:parameter><ac:parameter ac:name=\"title\">FAIL</ac:parameter></ac:structured-macro>"

    printf "<td>%s</td>", \
      (overall=="PASS") ? \
      "<ac:structured-macro ac:name=\"status\"><ac:parameter ac:name=\"colour\">Green</ac:parameter><ac:parameter ac:name=\"title\">PASS</ac:parameter></ac:structured-macro>" : \
      "<ac:structured-macro ac:name=\"status\"><ac:parameter ac:name=\"colour\">Red</ac:parameter><ac:parameter ac:name=\"title\">FAIL</ac:parameter></ac:structured-macro>"

    printf "</tr>\n"
  }

  # TOTAL CALCULATION
  total_all=0
  sum_all=0
  fail_all=0
  times_all=""

  for (l in total) {
    total_all += total[l]
    sum_all += sum[l]
    fail_all += (fail[l] ? fail[l] : 0)
    times_all = times_all " " times[l]
  }

  n=split(times_all, arr, " ")

  idx=0
  delete clean_all

  for(i=1;i<=n;i++){
    if(arr[i]!="")
      clean_all[++idx]=arr[i]
  }

  n=idx

  for(i=1;i<=n;i++){
    for(j=i+1;j<=n;j++){
      if(clean_all[i]>clean_all[j]){
        tmp=clean_all[i]
        clean_all[i]=clean_all[j]
        clean_all[j]=tmp
      }
    }
  }

  p90_index = int((n*90 + 99)/100)
  p90_all = clean_all[p90_index]

  avg_all = int(sum_all/total_all)
  err_all = (total_all > 0) ? (fail_all/total_all)*100 : 0

  printf "<tr style=\"font-weight:bold;background:#f2f2f2\">"
  printf "<td>TOTAL</td>"
  printf "<td>%d</td>", total_all
  printf "<td>%d</td>", avg_all
  printf "<td>%d</td>", p90_all
  printf "<td>-</td>"
  printf "<td>%.2f</td>", err_all
  printf "<td>-</td><td>-</td><td>-</td>"
  printf "</tr>\n"
}' results.jtl >> agg.html

echo "</table>" >> agg.html

echo "agg.html generated successfully"
