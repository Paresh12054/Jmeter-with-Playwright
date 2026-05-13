const fs = require('fs');

const baseUrl = process.env.CONFLUENCE_BASE_URL;
const email = process.env.CONFLUENCE_EMAIL;
const token = process.env.CONFLUENCE_API_TOKEN;
const spaceKey = process.env.CONFLUENCE_SPACE_KEY;

const parentId = "6094858";
const indexPageId = "6094858";

const auth = Buffer.from(`${email}:${token}`).toString("base64");

const headers = {
  "Authorization": `Basic ${auth}`,
  "Content-Type": "application/json"
};

async function api(url, method = "GET", body = null) {

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null
  });

  const text = await res.text();

  if (!res.ok) {
    console.error("Confluence API Error:");
    console.error(text);
    throw new Error(`HTTP ${res.status}`);
  }

  return text ? JSON.parse(text) : {};
}

(async () => {

  try {

    console.log("Starting Confluence publish...");

    const now = new Date()
      .toLocaleString("en-GB")
      .replace(",", "");

    // =========================================================
    // Read Parent Page
    // =========================================================

    const parent = await api(
      `${baseUrl}/rest/api/content/${indexPageId}?expand=body.storage,version`
    );

    let html = parent.body.storage.value;

    // =========================================================
    // Previous Metrics
    // =========================================================

    let prevAvg = 0;
    let prevP90 = 0;
    let hasPrev = false;

    const tableMatch = html.match(/<tbody>([\s\S]*?)<\/tbody>/);

    if (tableMatch && tableMatch[1]) {

      const rows = tableMatch[1].match(/<tr>([\s\S]*?)<\/tr>/g);

      if (rows && rows.length > 1) {

        const lastRow = rows[rows.length - 1];

        const cols = lastRow.match(/<td>(.*?)<\/td>/g);

        if (cols && cols.length >= 5) {

          prevAvg = parseInt(
            cols[3].replace(/<[^>]+>/g, '')
          );

          prevP90 = parseInt(
            cols[4].replace(/<[^>]+>/g, '')
          );

          hasPrev = true;
        }
      }
    }

    // =========================================================
    // Deviation
    // =========================================================

    let devAvg = 0;
    let devP90 = 0;
    let avgColor = "Grey";
    let p90Color = "Grey";
    let percentChange = 0;

    if (hasPrev && prevAvg > 0) {

      devAvg = process.env.TOTAL_AVG - prevAvg;
      devP90 = process.env.TOTAL_P90 - prevP90;

      avgColor = devAvg < 0 ? "Green" : "Red";
      p90Color = devP90 < 0 ? "Green" : "Red";

      percentChange =
        ((devAvg / prevAvg) * 100).toFixed(2);
    }

    // =========================================================
    // Playwright Summary
    // =========================================================

    const pwRows = fs.readFileSync('pw_runs_summary.txt')
      .toString()
      .split('\n')
      .slice(1)
      .map(line => {

        if (!line) return "";

        const [a, b, c, d, e, f] = line.split(',');

        return `
          <tr>
            <td>${a}</td>
            <td>${b}</td>
            <td>${c}</td>
            <td>${d}</td>
            <td>${e}</td>
            <td>${f}</td>
          </tr>
        `;
      }).join('');

    // =========================================================
    // Additional Files
    // =========================================================

    const zapSummary =
      fs.existsSync('zap-summary.html')
        ? fs.readFileSync('zap-summary.html').toString()
        : "";

    const aggHtml =
      fs.existsSync('agg.html')
        ? fs.readFileSync('agg.html').toString()
        : "";

    const aiSummary =
      process.env.AI_SUMMARY || "";

    // =========================================================
    // Main Content
    // =========================================================

    const CONTENT = `
      <h1>🚀 Performance & UI Test Report</h1>

      <h2>📊 Test Summary</h2>

      <table border='1' style='border-collapse: collapse; width: 60%;'>
        <tr><th>Test Type</th><td>Automation + Load + Security</td></tr>
        <tr><th>Test Date</th><td>${now}</td></tr>
        <tr><th>Test Duration</th><td>${process.env.TEST_DURATION}</td></tr>
        <tr><th>Concurrent Users</th><td>${process.env.CONCURRENT_USERS}</td></tr>
      </table>

      <h2>📏 SLA Configuration</h2>

      <table border='1'>
        <tr><th>Metric</th><th>Threshold</th></tr>
        <tr><td>Avg (ms)</td><td>${process.env.SLA_AVG}</td></tr>
        <tr><td>P90 (ms)</td><td>${process.env.SLA_P90}</td></tr>
        <tr><td>Error %</td><td>${process.env.SLA_ERR}</td></tr>
      </table>

      <h2>📈 Transaction-Level Aggregate</h2>

      ${aggHtml}

      <h2>📊 Performance Comparison</h2>

      <table border='1'>
        <tr>
          <th>Metric</th>
          <th>Previous</th>
          <th>Current</th>
          <th>Deviation</th>
        </tr>

        <tr>
          <td>Avg (ms)</td>
          <td>${hasPrev ? prevAvg : "N/A"}</td>
          <td>${process.env.TOTAL_AVG}</td>
          <td>${hasPrev ? `${devAvg} ms (${percentChange}%)` : "N/A"}</td>
        </tr>

        <tr>
          <td>P90 (ms)</td>
          <td>${hasPrev ? prevP90 : "N/A"}</td>
          <td>${process.env.TOTAL_P90}</td>
          <td>${hasPrev ? `${devP90} ms` : "N/A"}</td>
        </tr>
      </table>

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

        ${pwRows}
      </table>

      <h2>🔐 Security Summary</h2>

      ${zapSummary}

      <h2>🧠 AI Analysis & Observations</h2>

      ${aiSummary}

      <h2>📎 Attachments</h2>

      <ac:structured-macro ac:name="attachments"/>
    `;

    // =========================================================
    // Create Report Page
    // =========================================================

    const title = `Performance Report - ${now}`;

    const child = await api(
      `${baseUrl}/rest/api/content`,
      "POST",
      {
        type: "page",
        title,
        ancestors: [{ id: parentId }],
        space: { key: spaceKey },
        body: {
          storage: {
            value: CONTENT,
            representation: "storage"
          }
        }
      }
    );

    console.log(`Report page created: ${child.id}`);

    const link =
      child._links.base + child._links.webui;

    // =========================================================
    // Upload Attachment Helper
    // =========================================================

    async function uploadAttachment(pageId, filePath, contentType) {

      if (!fs.existsSync(filePath)) {
        console.log(`${filePath} not found`);
        return;
      }

      console.log(`Uploading ${filePath}`);

      const buffer = fs.readFileSync(filePath);

      const form = new FormData();

      form.append(
        "file",
        new Blob([buffer], { type: contentType }),
        filePath
      );

      const response = await fetch(
        `${baseUrl}/rest/api/content/${pageId}/child/attachment`,
        {
          method: "POST",
          headers: {
            "Authorization": `Basic ${auth}`,
            "X-Atlassian-Token": "no-check"
          },
          body: form
        }
      );

      if (!response.ok) {
        throw new Error(await response.text());
      }

      console.log(`${filePath} uploaded`);
    }

    // =========================================================
    // Upload Attachments
    // =========================================================

    await uploadAttachment(
      child.id,
      "zap-report.png",
      "image/png"
    );

    await uploadAttachment(
      child.id,
      "playwright-report.png",
      "image/png"
    );

    await uploadAttachment(
      child.id,
      "playwright-report.zip",
      "application/zip"
    );

    // =========================================================
    // Update Parent Summary Page
    // =========================================================

    let match =
      html.match(/<tbody>([\s\S]*?)<\/tbody>/);

    let count = 0;

    if (match && match[1]) {

      const rows = match[1].match(/<tr>/g);

      count = rows ? rows.length - 1 : 0;
    }

    const srNo = count + 1;

    const row = `
      <tr>
        <td>${srNo}</td>
        <td>${now}</td>
        <td><a href="${link}">${title}</a></td>
        <td>${process.env.TOTAL_AVG} ms</td>
        <td>${process.env.TOTAL_P90} ms</td>
      </tr>
    `;

    html = html.includes("</tbody>")
      ? html.replace("</tbody>", row + "</tbody>")
      : `
        <table>
          <tbody>
            <tr>
              <th>Sr.No</th>
              <th>Created At</th>
              <th>Page</th>
              <th>Avg</th>
              <th>P90</th>
            </tr>

            ${row}
          </tbody>
        </table>
      `;

    await api(
      `${baseUrl}/rest/api/content/${indexPageId}`,
      "PUT",
      {
        id: indexPageId,
        type: "page",
        title: parent.title,
        version: {
          number: parent.version.number + 1
        },
        body: {
          storage: {
            value: html,
            representation: "storage"
          }
        }
      }
    );

    console.log("Parent page updated");

    // =========================================================
    // Export PAGE_ID
    // =========================================================

    if (process.env.GITHUB_ENV) {

      fs.appendFileSync(
        process.env.GITHUB_ENV,
        `PAGE_ID=${child.id}\n`
      );
    }

    console.log("Confluence publish completed");

  } catch (err) {

    console.error("Publish failed:");
    console.error(err);

    process.exit(1);
  }

})();
