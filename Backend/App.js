const express = require("express");
const cors = require("cors");
const app = express();

const connectDB = require("./config/db");
const authRoutes = require("./routes/auth");
const recordsRoutes = require("./routes/records");
const reportsRoutes = require("./routes/reports");

connectDB();

// Parse JSON bodies
app.use(express.json());

// CORS — allow frontend dev server and any local origin
app.use(
  cors({
    origin: ["http://localhost:5173", "http://localhost:3000", "http://127.0.0.1:5173"],
    credentials: true,
  })
);

// Ensure uploads directory exists
const fs = require("fs");
const path = require("path");
const uploadsDir = path.join(__dirname, "../uploads/reports");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Serve uploaded report files
app.use("/uploads", express.static(path.join(__dirname, "../uploads")));

// API routes
app.use("/api/auth", authRoutes);
app.use("/api/records", recordsRoutes);
app.use("/api/reports", reportsRoutes);

// Health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Serve production frontend build (if it exists)
const frontendDist = path.join(__dirname, "../Frontend/dist");
if (fs.existsSync(frontendDist)) {
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

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`MedRec API running on http://localhost:${PORT}`);
});
