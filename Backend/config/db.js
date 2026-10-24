const mongoose = require("mongoose");
const path = require("path");

// Load .env from project root (two levels up from Backend/config/)
require("dotenv").config({
  path: path.resolve(__dirname, "../../.env"),
});

const uri = process.env.MONGODB_URI;

if (!uri) {
  console.error(
    "[db] MONGODB_URI is not set. Create a .env file in the project root.\n" +
    "  See .env.example for the required format."
  );
  process.exit(1);
}

const connectDB = async () => {
  try {
    await mongoose.connect(uri);
    console.log("[db] Connected to MongoDB");
  } catch (err) {
    console.error("[db] MongoDB connection error:", err.message);
    process.exit(1);
  }
};

module.exports = connectDB;
