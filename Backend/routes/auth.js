const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const router = express.Router();

// Signup
router.post("/signup", async (req, res) => {
  try {
    const { email, password, name, alias } = req.body;
    if (!email || !password || !name || !alias) {
      return res
        .status(400)
        .json({ message: "Email, password, name, and alias are required." });
    }
    const existingUser = await User.findOne({ $or: [{ email }, { alias }] });
    if (existingUser) {
      return res.status(409).json({ message: "User or alias already exists." });
    }
    const hashedPassword = await bcrypt.hash(password, 12);
    const user = new User({ email, password: hashedPassword, name, alias });
    await user.save();
    res.status(201).json({ message: "User created successfully." });
  } catch (err) {
    console.error("Signup error:", err);
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Login
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: "Invalid credentials." });
    }
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid credentials." });
    }
    const token = jwt.sign(
      { userId: user._id },
      "secret",
      { expiresIn: "1d" }
    );
    res.json({ token });
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

module.exports = router;
// Get user and all their data by userId or alias
router.get("/user/:identifier", async (req, res) => {
  try {
    const { identifier } = req.params;
    // Try to find by ObjectId, else by alias
    let user = null;
    if (/^[0-9a-fA-F]{24}$/.test(identifier)) {
      user = await User.findById(identifier)
        .populate("medical_history")
        .populate("allergies")
        .populate("family_history")
        .populate("emergency_contact")
        .populate({ path: "heart.surgeries", model: "Surgery" })
        .populate({ path: "heart.medications", model: "Medication" })
        .populate({ path: "mental_health.medications", model: "Medication" });
    } else {
      user = await User.findOne({ alias: identifier })
        .populate("medical_history")
        .populate("allergies")
        .populate("family_history")
        .populate("emergency_contact")
        .populate({ path: "heart.surgeries", model: "Surgery" })
        .populate({ path: "heart.medications", model: "Medication" })
        .populate({ path: "mental_health.medications", model: "Medication" });
    }
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    res.json(user);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});
