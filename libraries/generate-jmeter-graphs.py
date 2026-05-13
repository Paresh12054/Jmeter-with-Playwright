import pandas as pd
import matplotlib.pyplot as plt
import os

# Read JTL
df = pd.read_csv("results.jtl")

# Create output dir
os.makedirs("jm-graphs", exist_ok=True)

# Convert timestamp
df['timeStamp'] = pd.to_datetime(df['timeStamp'], unit='ms')

# =========================================================
# Response Time Graph
# =========================================================

plt.figure(figsize=(14,6))

plt.plot(df['timeStamp'], df['elapsed'])

plt.xlabel("Time")
plt.ylabel("Response Time (ms)")
plt.title("Response Time Over Time")

plt.tight_layout()

plt.savefig("jm-graphs/response-time.png")

plt.close()

# =========================================================
# Throughput Graph
# =========================================================

throughput = df.resample(
    '1s',
    on='timeStamp'
).size()

plt.figure(figsize=(14,6))

plt.plot(throughput.index, throughput.values)

plt.xlabel("Time")
plt.ylabel("Requests/sec")
plt.title("Throughput Over Time")

plt.tight_layout()

plt.savefig("jm-graphs/throughput.png")

plt.close()

print("JMeter graphs generated")
