const path = require("path");

// Load .env from the project root (two levels up from Backend/config/).
require("dotenv").config({
  path: path.resolve(__dirname, "../../.env"),
  quiet: true,
});

function required(name) {
  const value = process.env[name];
  if (!value) {
    console.error(
      `[config] ${name} is not set. Create a .env file in the project root.\n` +
        "  See .env.example for the required format."
    );
    process.exit(1);
  }
  return value;
}

module.exports = {
  mongoUri: required("MONGODB_URI"),
  jwtSecret: required("JWT_SECRET"),
  port: Number(process.env.PORT) || 5000,
  // Uploaded report files live outside the web root and are only served
  // through the authenticated /api/reports routes.
  uploadsDir: path.resolve(
    __dirname,
    "../..",
    process.env.UPLOADS_DIR || "uploads/reports"
  ),
  maxUploadBytes: (Number(process.env.MAX_UPLOAD_MB) || 10) * 1024 * 1024,
  maxFilesPerReport: 10,
};
