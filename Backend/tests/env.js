// Test configuration. Require this before any app module: config/env.js reads
// these once, and dotenv never overrides variables that are already set.
const os = require("os");
const path = require("path");
const crypto = require("crypto");

// Integration tests wipe this database, so it must never be a real one.
// Override with TEST_MONGODB_URI to use a different server.
process.env.MONGODB_URI =
  process.env.TEST_MONGODB_URI || "mongodb://127.0.0.1:27017/medrec_test";
process.env.JWT_SECRET = "test-secret-" + crypto.randomBytes(16).toString("hex");
process.env.UPLOADS_DIR = path.join(
  os.tmpdir(),
  "medrec-test-uploads-" + process.pid
);
process.env.MAX_UPLOAD_MB = "1";

const dbName = new URL(process.env.MONGODB_URI).pathname.slice(1);
if (!/test/i.test(dbName)) {
  throw new Error(
    `Refusing to run tests against database "${dbName}": its name must contain "test".`
  );
}

module.exports = { uploadsDir: process.env.UPLOADS_DIR, dbName };
