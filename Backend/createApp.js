// Builds the Express app without connecting to MongoDB or listening, so the
// server (App.js) and the tests can share it.
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");

const { uploadsDir } = require("./config/env");
const authRoutes = require("./routes/auth");
const recordsRoutes = require("./routes/records");
const meRoutes = require("./routes/me");
const reportsRoutes = require("./routes/reports");
const { notFound, errorHandler } = require("./middleware/errors");

function createApp({ frontendDist = path.join(__dirname, "../Frontend/dist") } = {}) {
  const app = express();

  app.use(express.json({ limit: "100kb" }));

  // CORS only matters for browsers (the mobile app is not subject to it).
  app.use(
    cors({
      origin: [
        "http://localhost:5173",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
      ],
      credentials: true,
    })
  );

  // Uploaded files are NOT served statically: they are only reachable through
  // the authenticated /api/reports/:id/files/:fileId route.
  fs.mkdirSync(uploadsDir, { recursive: true });

  // API routes
  app.use("/api/auth", authRoutes);
  app.use("/api/records", recordsRoutes); // public card lookup
  app.use("/api/me", meRoutes); // logged-in patient's own record
  app.use("/api/reports", reportsRoutes); // logged-in patient's uploads

  app.get("/api/health", (req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
  });
  app.use("/api", notFound);

  // Serve production frontend build (if it exists)
  if (frontendDist && fs.existsSync(frontendDist)) {
    app.use(express.static(frontendDist));
    app.get("/{*path}", (req, res) => {
      res.sendFile(path.join(frontendDist, "index.html"));
    });
  } else {
    app.get("/", (req, res) => {
      res.json({
        message: "MedRec API Server",
        docs: "/api/health",
        records: "/api/records/user/card/:cardId",
      });
    });
  }

  app.use(errorHandler);
  return app;
}

module.exports = createApp;
