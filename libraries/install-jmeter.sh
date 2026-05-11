set -e

echo "Installing JMeter..."

wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz

tar -xzf apache-jmeter-5.6.3.tgz

mv apache-jmeter-5.6.3 jmeter
