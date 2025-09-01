const express = require("express");
const User = require("../models/User");
const MedicalHistory = require("../models/MedicalHistory");
const Allergy = require("../models/Allergy");
const FamilyHistory = require("../models/FamilyHistory");
const EmergencyContact = require("../models/EmergencyContact");
const Surgery = require("../models/Surgery");
const Medication = require("../models/Medication");
const router = express.Router();

// Get all medical history for a user
router.get("/medical-history/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).populate("medical_history");
    res.json(user?.medical_history || []);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Get all allergies for a user
router.get("/allergy/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).populate("allergies");
    res.json(user?.allergies || []);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Get all family history for a user
router.get("/family-history/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).populate("family_history");
    res.json(user?.family_history || []);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Get all emergency contacts for a user
router.get("/emergency-contact/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).populate("emergency_contact");
    res.json(user?.emergency_contact || []);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Get all surgeries for a user (from heart.surgeries)
router.get("/surgery/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).populate("heart.surgeries");
    res.json(user?.heart?.surgeries || []);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Get all medications for a user (from heart.medications and mental_health.medications)
router.get("/medication/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId)
      .populate("heart.medications")
      .populate("mental_health.medications");
    // Combine and deduplicate medications
    const heartMeds = user?.heart?.medications || [];
    const mentalMeds = user?.mental_health?.medications || [];
    const allMeds = [...heartMeds, ...mentalMeds];
    // Remove duplicates by _id
    const uniqueMeds = Array.from(
      new Map(allMeds.map((m) => [String(m._id), m])).values()
    );
    res.json(uniqueMeds);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add or update user profile (protected route)
router.post("/user/:id/profile", async (req, res) => {
  try {
    const userId = req.params.id;
    const update = req.body;
    const user = await User.findByIdAndUpdate(userId, update, { new: true });
    res.json(user);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add medical history and link to user (push to array)
router.post("/medical-history/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const mh = new MedicalHistory(req.body);
    await mh.save();
    await User.findByIdAndUpdate(userId, {
      $push: { medical_history: mh._id },
    });
    res.status(201).json(mh);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add allergy and link to user
router.post("/allergy/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const allergy = new Allergy(req.body);
    await allergy.save();
    await User.findByIdAndUpdate(userId, { $push: { allergies: allergy._id } });
    res.status(201).json(allergy);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add family history and link to user
router.post("/family-history/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const fh = new FamilyHistory(req.body);
    await fh.save();
    await User.findByIdAndUpdate(userId, { $push: { family_history: fh._id } });
    res.status(201).json(fh);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add emergency contact and link to user (push to array)
router.post("/emergency-contact/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const ec = new EmergencyContact(req.body);
    await ec.save();
    await User.findByIdAndUpdate(userId, {
      $push: { emergency_contact: ec._id },
    });
    res.status(201).json(ec);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add surgery and link to user (push to array)
router.post("/surgery/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const surgery = new Surgery(req.body);
    await surgery.save();
    await User.findByIdAndUpdate(userId, {
      $push: { "heart.surgeries": surgery._id },
    });
    res.status(201).json(surgery);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// Add medication and link to user (push to arrays)
router.post("/medication/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const medication = new Medication(req.body);
    await medication.save();
    await User.findByIdAndUpdate(userId, {
      $push: {
        "heart.medications": medication._id,
        "mental_health.medications": medication._id,
      },
    });
    res.status(201).json(medication);
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

module.exports = router;
