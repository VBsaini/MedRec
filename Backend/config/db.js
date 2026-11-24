const mongoose = require("mongoose");
const { mongoUri } = require("./env");

const connectDB = async () => {
  try {
    await mongoose.connect(mongoUri);
    console.log("[db] Connected to MongoDB");
  } catch (err) {
    console.error("[db] MongoDB connection error:", err.message);
    process.exit(1);
  }
};

module.exports = connectDB;
