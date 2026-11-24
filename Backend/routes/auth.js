const express = require("express");
const bcrypt = require("bcryptjs");
const User = require("../models/User");
const { requireAuth, signToken } = require("../middleware/auth");
const { HttpError } = require("../middleware/errors");
const { populateRecord } = require("../services/record");
const router = express.Router();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ALIAS_RE = /^[a-zA-Z0-9_.-]{3,30}$/;

const str = (v) => (typeof v === "string" ? v.trim() : "");

// Signup — creates the account and logs the user in.
router.post("/signup", async (req, res) => {
  const body = req.body || {};
  const email = str(body.email).toLowerCase();
  const name = str(body.name);
  const alias = str(body.alias);
  const password = typeof body.password === "string" ? body.password : "";

  if (!email || !password || !name || !alias) {
    throw new HttpError(400, "Email, password, name, and alias are required.");
  }
  if (!EMAIL_RE.test(email)) throw new HttpError(400, "Enter a valid email.");
  if (!ALIAS_RE.test(alias)) {
    throw new HttpError(
      400,
      "Alias must be 3-30 characters: letters, numbers, _ . -"
    );
  }
  if (password.length < 8) {
    throw new HttpError(400, "Password must be at least 8 characters.");
  }

  const existing = await User.findOne({ $or: [{ email }, { alias }] });
  if (existing) {
    throw new HttpError(
      409,
      existing.email === email
        ? "An account with this email already exists."
        : "That alias is taken."
    );
  }

  const user = await User.create({
    email,
    name,
    alias,
    password: await bcrypt.hash(password, 12),
  });
  const saved = await populateRecord(User.findById(user._id));
  res.status(201).json({ token: signToken(user._id), user: saved });
});

// Login
router.post("/login", async (req, res) => {
  const body = req.body || {};
  const email = str(body.email).toLowerCase();
  const password = typeof body.password === "string" ? body.password : "";
  if (!email || !password) {
    throw new HttpError(400, "Email and password are required.");
  }

  const withPassword = await User.findOne({ email }).select("+password");
  const ok =
    withPassword && (await bcrypt.compare(password, withPassword.password));
  if (!ok) throw new HttpError(401, "Invalid email or password.");

  const user = await populateRecord(User.findById(withPassword._id));
  res.json({ token: signToken(user._id), user });
});

// Who am I — lets a client restore its session from a stored token.
router.get("/me", requireAuth, async (req, res) => {
  const user = await populateRecord(User.findById(req.userId));
  if (!user) throw new HttpError(401, "Account no longer exists.");
  res.json(user);
});

module.exports = router;
