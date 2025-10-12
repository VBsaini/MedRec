const express = require("express");
const cors = require("cors");
const app = express();
const PORT = process.env.PORT || 3000;

const connectDB = require("./config/db");
const User = require("./models/User");
const Visitor = require("./models/Visitor");

const authRoutes = require("./routes/auth");
const recordsRoutes = require("./routes/records");
const reportsRoutes = require("./routes/reports");

connectDB();

// Enable CORS for all routes and origins (customize origin as needed)
app.use(
  cors({
    origin: `${process.env.FRONTEND_URL}` || "http://localhost:5000",
    credentials: true,
  })
);

app.use(express.json());
// Ensure uploads directory exists
const fs = require("fs");
const path = require("path");
const uploadsDir = path.join(__dirname, "../uploads/reports");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

app.use("/api/auth", authRoutes);
app.use("/api/records", recordsRoutes);
app.use("/api/reports", reportsRoutes);
app.get("/", (req, res) => {
  res.send("Hello, MedRec!");
});

app.listen(5000, () => {
  console.log(`Server is running on port 5000`);
});
