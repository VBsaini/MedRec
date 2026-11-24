#!/usr/bin/env node
// Whole-system test for MedRec. From the project root:
//
//   node system-test/run.mjs
//
// Needs: MongoDB on 127.0.0.1:27017 (or TEST_MONGODB_URI), an Android
// emulator or phone connected over adb, Flutter, Python and Chrome.
//
// It starts a throwaway backend, then:
//   1. runs the Flutter app on the device (mobile/integration_test/system_test.dart):
//      sign up, profile, record lists, photo + PDF upload, card link, visitor
//      log, log out and in again;
//   2. checks the uploaded files through the API;
//   3. feeds the card UID through the RFID bridge's serial loop, as the
//      ESP32 would, to get the record URL;
//   4. opens that URL in headless Chrome against the React viewer and checks
//      the page shows the record (and not the email).
// Everything it creates (database, uploads, servers) is removed at the end.

import { spawn, spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const isWindows = process.platform === "win32";
const requireBackend = createRequire(path.join(root, "Backend", "package.json"));
const mongoose = requireBackend("mongoose");

const API_PORT = Number(process.env.SYSTEM_TEST_API_PORT || 5055);
const WEB_PORT = Number(process.env.SYSTEM_TEST_WEB_PORT || 5174);
// How the device reaches this computer. 10.0.2.2 is the Android emulator's
// name for it; for a real phone use the computer's Wi-Fi IP address.
const DEVICE_HOST = process.env.SYSTEM_TEST_DEVICE_HOST || "10.0.2.2";
const MONGODB_URI =
  process.env.TEST_MONGODB_URI || "mongodb://127.0.0.1:27017/medrec_system_test";

const runId = crypto.randomBytes(4).toString("hex");
const card = crypto.randomBytes(4).toString("hex"); // e.g. "5a3f9c01"
const cardAsTyped = card.match(/../g).join(":"); // "5a:3f:9c:01", like a reader prints
const cardId = card.toUpperCase();
const email = `system.${runId}@example.test`;
const password = `pw-${crypto.randomBytes(8).toString("hex")}`;
const name = "Meera System Test"; // must match system_test.dart
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), `medrec-system-${runId}-`));
const outputDir = path.join(root, "system-test", "output");

const children = [];
const results = [];

function log(message) {
  console.log(`\n[system-test] ${message}`);
}

function check(label, ok, detail = "") {
  results.push({ label, ok });
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${label}${!ok && detail ? `\n        ${detail}` : ""}`);
  if (!ok) throw new Error(`Check failed: ${label}`);
}

function start(label, command, args, options) {
  const child = spawn(command, args, { shell: isWindows, ...options });
  child.output = "";
  const collect = (data) => {
    child.output += data;
    if (process.env.SYSTEM_TEST_VERBOSE) process.stdout.write(`[${label}] ${data}`);
  };
  child.stdout?.on("data", collect);
  child.stderr?.on("data", collect);
  children.push(child);
  return child;
}

function stop(child) {
  if (child.exitCode !== null || child.killed) return;
  if (isWindows) {
    spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore" });
  } else {
    child.kill("SIGTERM");
  }
}

async function waitForUrl(url, child, label, timeoutMs = 60000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (child.exitCode !== null) {
      throw new Error(`${label} exited early:\n${child.output.slice(-2000)}`);
    }
    try {
      const res = await fetch(url);
      if (res.ok) return;
    } catch {
      // not up yet
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`${label} did not start at ${url}:\n${child.output.slice(-2000)}`);
}

function run(command, args, options) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { shell: isWindows, stdio: "inherit", ...options });
    children.push(child);
    child.on("exit", (code) => resolve(code));
  });
}

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    path.join(process.env.LOCALAPPDATA || "", "Google/Chrome/Application/chrome.exe"),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
  ].filter(Boolean);
  return candidates.find((c) => fs.existsSync(c));
}

function adbDevice() {
  const adb = process.env.ANDROID_HOME
    ? path.join(process.env.ANDROID_HOME, "platform-tools", "adb")
    : isWindows
      ? path.join(process.env.LOCALAPPDATA || "", "Android/Sdk/platform-tools/adb.exe")
      : "adb";
  const out = spawnSync(adb, ["devices"], { encoding: "utf8" }).stdout || "";
  return out
    .split("\n")
    .slice(1)
    .map((line) => line.trim().split(/\s+/))
    .find(([, state]) => state === "device")?.[0];
}

async function main() {
  const dbName = new URL(MONGODB_URI).pathname.slice(1);
  if (!/test/i.test(dbName)) {
    throw new Error(`Refusing to use database "${dbName}": its name must contain "test".`);
  }
  const device = process.env.SYSTEM_TEST_DEVICE || adbDevice();
  if (!device) throw new Error("No Android device or emulator is connected (adb devices).");
  const chrome = findChrome();
  if (!chrome) throw new Error("Chrome was not found. Set CHROME_PATH.");

  log(`Run ${runId}: device ${device}, card ${cardAsTyped}, database ${dbName}`);
  await mongoose.connect(MONGODB_URI, { serverSelectionTimeoutMS: 3000 });
  await mongoose.connection.dropDatabase();

  // ---- Backend ------------------------------------------------------------
  log(`Starting the API on port ${API_PORT}`);
  const backend = start("api", "node", ["App.js"], {
    cwd: path.join(root, "Backend"),
    env: {
      ...process.env,
      MONGODB_URI,
      JWT_SECRET: crypto.randomBytes(32).toString("hex"),
      PORT: String(API_PORT),
      UPLOADS_DIR: path.join(scratch, "uploads"),
    },
  });
  await waitForUrl(`http://127.0.0.1:${API_PORT}/api/health`, backend, "API");

  // ---- 1. The app on the device -------------------------------------------
  log("Running the app on the device (this builds and installs it; a few minutes)");
  const env = { ...process.env };
  if (isWindows && !env.JAVA_TOOL_OPTIONS) {
    // See README: Java's socket temp folder must not be a short (8.3) path.
    fs.mkdirSync("C:/Users/Public/jtmp", { recursive: true });
    env.JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:/Users/Public/jtmp";
  }
  const flutterCode = await run(
    "flutter",
    [
      "test",
      "integration_test/system_test.dart",
      "-d",
      device,
      `--dart-define=API_BASE_URL=http://${DEVICE_HOST}:${API_PORT}`,
      `--dart-define=SYSTEM_EMAIL=${email}`,
      `--dart-define=SYSTEM_PASSWORD=${password}`,
      `--dart-define=SYSTEM_CARD=${cardAsTyped}`,
    ],
    { cwd: path.join(root, "mobile"), env }
  );
  check("app: sign up, record entry, uploads, card, visitor log, re-login", flutterCode === 0);

  // ---- 2. Uploaded files, through the API -----------------------------------
  log("Checking the uploaded files through the API");
  const api = `http://127.0.0.1:${API_PORT}/api`;
  const login = await fetch(`${api}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  }).then((r) => r.json());
  check("API: the account created in the app can log in", Boolean(login.token));
  const auth = { Authorization: `Bearer ${login.token}` };
  const reports = await fetch(`${api}/reports`, { headers: auth }).then((r) => r.json());
  check("API: one report with two files", reports.length === 1 && reports[0].files.length === 2,
    JSON.stringify(reports));
  const [photo, pdf] = reports[0].files;
  check("API: file names as the patient saw them",
    photo.originalName === "blood_test.png" && pdf.originalName === "discharge summary.pdf");
  for (const [file, signature] of [[photo, "\x89PNG"], [pdf, "%PDF"]]) {
    const res = await fetch(`${api}/reports/${reports[0]._id}/files/${file._id}`, { headers: auth });
    const bytes = Buffer.from(await res.arrayBuffer());
    check(`API: ${file.originalName} downloads intact (${bytes.length} bytes)`,
      res.status === 200 && bytes.length === file.size &&
        bytes.subarray(0, 4).toString("latin1") === signature);
  }
  const anonymous = await fetch(`${api}/reports/${reports[0]._id}/files/${photo._id}`);
  check("API: files need the patient's login", anonymous.status === 401);
  const onDisk = fs.readdirSync(path.join(scratch, "uploads"));
  check("API: stored under random names", onDisk.length === 2 &&
    onDisk.every((f) => /^[0-9a-f]{32}\.(png|pdf)$/.test(f)), onDisk.join(", "));

  // ---- 3. The RFID bridge -------------------------------------------------
  log("Feeding the card through the RFID bridge's serial loop");
  const prefix = `http://localhost:${WEB_PORT}/record/`;
  const bridge = spawnSync(
    isWindows ? "python" : "python3",
    [path.join(root, "system-test", "bridge_sim.py"), prefix, cardId],
    { encoding: "utf8" }
  );
  const url = (bridge.stdout.match(/detected: (\S+)/) || [])[1];
  check("bridge: ESP32 line RFID_UID:<uid> becomes the record URL",
    url === `${prefix}${cardId}`, bridge.stdout + bridge.stderr);

  // ---- 4. The web record viewer --------------------------------------------
  log(`Starting the record viewer on port ${WEB_PORT}`);
  const web = start("web", "npx", ["vite", "--port", String(WEB_PORT), "--strictPort"], {
    cwd: path.join(root, "Frontend"),
    env: { ...process.env, VITE_API_PROXY_TARGET: `http://localhost:${API_PORT}` },
  });
  await waitForUrl(`http://localhost:${WEB_PORT}/`, web, "Record viewer");

  fs.mkdirSync(outputDir, { recursive: true });
  const screenshot = path.join(outputDir, "record-page.png");
  const chromeArgs = (target, extra) => [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    `--user-data-dir=${path.join(scratch, "chrome")}`,
    "--virtual-time-budget=15000",
    "--window-size=430,2200",
    ...extra,
    target,
  ];
  const page = spawnSync(chrome, chromeArgs(url, ["--dump-dom"]), {
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
  }).stdout || "";
  for (const text of [name, "O-", "Penicillin", "Severe", "Metformin", "Nisha Shah", "+91 90000 00001"]) {
    check(`web: record page shows "${text}"`, page.includes(text));
  }
  check("web: record page does not show the email", !page.includes(email));
  check("web: record page does not list uploaded reports", !page.includes("discharge summary.pdf"));
  spawnSync(chrome, chromeArgs(url, [`--screenshot=${screenshot}`]), { stdio: "ignore" });

  const unknown = spawnSync(chrome, chromeArgs(`${prefix}NOSUCHCARD`, ["--dump-dom"]), {
    encoding: "utf8",
  }).stdout || "";
  check("web: an unregistered card says so", unknown.includes("Card not registered in the system."));

  // Unlinking in the app would stop the lookup; check the API side of that.
  await fetch(`${api}/me/card`, {
    method: "PUT",
    headers: { ...auth, "Content-Type": "application/json" },
    body: JSON.stringify({ card_Id: "" }),
  });
  const after = await fetch(`${api}/records/user/card/${cardId}`);
  check("API: an unlinked card no longer opens the record", after.status === 404);

  log(`Screenshot of the record page: ${screenshot}`);
}

let failed = false;
try {
  await main();
} catch (err) {
  failed = true;
  console.error(`\n[system-test] ${err.message}`);
} finally {
  for (const child of children) stop(child);
  try {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.dropDatabase();
      await mongoose.disconnect();
    }
  } catch (err) {
    console.error(`[system-test] cleanup: ${err.message}`);
  }
  fs.rmSync(scratch, { recursive: true, force: true });
  const passed = results.filter((r) => r.ok).length;
  console.log(`\n[system-test] ${passed}/${results.length} checks passed${failed ? " — FAILED" : ""}`);
  process.exit(failed ? 1 : 0);
}
