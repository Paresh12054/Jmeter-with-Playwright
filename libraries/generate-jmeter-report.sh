#!/bin/bash
set -e

echo "Generating JMeter HTML Report..."

./jmeter/bin/jmeter -g results.jtl -o jmeter-report

echo "JMeter report generated"
