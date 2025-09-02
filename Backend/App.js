const express = require("express");
const cors = require("cors");
const app = express();
const PORT = process.env.PORT || 3000;

const connectDB = require("./config/db");
const User = require("./models/User");
const Visitor = require("./models/Visitor");

const authRoutes = require("./routes/auth");
const recordsRoutes = require("./routes/records");

connectDB();

// Enable CORS for all routes and origins (customize origin as needed)
app.use(
  cors({
    origin: `${process.env.FRONTEND_URL}` || "http://localhost:3000",
    credentials: true,
  })
);

app.use(express.json());
app.use("/api/auth", authRoutes);
app.use("/api/records", recordsRoutes);
app.get("/", (req, res) => {
  res.send("Hello, MedRec!");
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
