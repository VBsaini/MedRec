// Public, card-based access: what someone sees after tapping a patient's
// RFID card. Everything a patient does to their own record is in routes/me.js.
const express = require("express");
const User = require("../models/User");
const Visitor = require("../models/Visitor");
const { HttpError } = require("../middleware/errors");
const { populateRecord } = require("../services/record");
const router = express.Router();

// Get a patient's record by card UID. Deliberately no login (emergency
// access); it never includes the account email, password or uploaded reports.
router.get("/user/card/:cardId", async (req, res) => {
  const user = await populateRecord(
    User.findOne({ card_Id: req.params.cardId }).select("-email")
  );
  if (!user) throw new HttpError(404, "User not found");
  res.json(user);
});

// Log that someone viewed a card's record.
router.post("/visitor", async (req, res) => {
  const { name, purpose, card_Id, anonymous } = req.body || {};
  if (typeof card_Id !== "string" || typeof name !== "string" || !name.trim()) {
    throw new HttpError(400, "name and card_Id are required.");
  }
  const user = await User.findOne({ card_Id });
  if (!user) throw new HttpError(404, "User not found");

  const visitor = await Visitor.create({
    name: name.trim(),
    purpose: typeof purpose === "string" ? purpose : undefined,
    Id: `VIS${Date.now()}${Math.random().toString(36).slice(2, 6)}`,
    card_Id,
    ip_address: req.ip,
    user: user._id,
    anonymous: {
      status: Boolean(anonymous && anonymous.status),
      name:
        anonymous && typeof anonymous.name === "string"
          ? anonymous.name
          : undefined,
    },
  });
  res.status(201).json({ message: "Visitor registered successfully", visitor });
});

module.exports = router;
