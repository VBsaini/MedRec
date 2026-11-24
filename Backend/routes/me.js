// Routes for the logged-in patient to manage their own record.
// Everything here is scoped to req.userId — there are no user ids in URLs.
const express = require("express");
const mongoose = require("mongoose");
const User = require("../models/User");
const MedicalHistory = require("../models/MedicalHistory");
const Allergy = require("../models/Allergy");
const FamilyHistory = require("../models/FamilyHistory");
const EmergencyContact = require("../models/EmergencyContact");
const Surgery = require("../models/Surgery");
const Medication = require("../models/Medication");
const Visitor = require("../models/Visitor");
const { requireAuth } = require("../middleware/auth");
const { HttpError } = require("../middleware/errors");
const { populateRecord } = require("../services/record");
const { applyFields, normalizeCardId } = require("../services/fields");

const router = express.Router();
router.use(requireAuth);

// URL segment -> model, the User array that links to it, and writable fields.
const COLLECTIONS = {
  allergies: {
    model: Allergy,
    path: "allergies",
    fields: ["allergens", "reactions", "severity"],
  },
  medications: {
    model: Medication,
    path: "medications",
    fields: [
      "name",
      "dosage",
      "frequency",
      "prescribedBy",
      "prescribedFor",
      "startDate",
      "endDate",
    ],
  },
  surgeries: {
    model: Surgery,
    path: "surgeries",
    fields: [
      "surgeryType",
      "surgeryDate",
      "hospitalName",
      "doctorName",
      "details",
    ],
  },
  "emergency-contacts": {
    model: EmergencyContact,
    path: "emergency_contact",
    fields: ["name", "phone_number", "relationship"],
  },
  "family-history": {
    model: FamilyHistory,
    path: "family_history",
    fields: ["relationship", "conditions"],
  },
  "medical-history": {
    model: MedicalHistory,
    path: "medical_history",
    fields: ["past_illnesses"],
  },
};

const PROFILE_FIELDS = [
  "name",
  "age",
  "gender",
  "blood_group",
  "height",
  "weight",
  "diabetic.status",
  "diabetic.type",
  "diabetic.since",
  "heart.status",
  "heart.details",
  "heart.since",
  "mental_health.status",
  "mental_health.details",
  "mental_health.since",
];

async function loadUser(req) {
  const user = await User.findById(req.userId);
  if (!user) throw new HttpError(401, "Account no longer exists.");
  return user;
}

// ---- Whole record ---------------------------------------------------------

router.get("/", async (req, res) => {
  const user = await populateRecord(User.findById(req.userId));
  if (!user) throw new HttpError(401, "Account no longer exists.");
  res.json(user);
});

// ---- Profile --------------------------------------------------------------

router.patch("/profile", async (req, res) => {
  const user = await loadUser(req);
  const body = req.body || {};
  if (typeof body.name === "string" && !body.name.trim()) {
    throw new HttpError(400, "Name cannot be empty.");
  }
  applyFields(user, body, PROFILE_FIELDS);
  await user.save();
  res.json(await populateRecord(User.findById(user._id)));
});

// ---- RFID card ------------------------------------------------------------

// Link (or with an empty card_Id, unlink) the RFID card that opens this record.
router.put("/card", async (req, res) => {
  const user = await loadUser(req);
  const raw = (req.body || {}).card_Id;
  if (raw === null || raw === undefined || raw === "") {
    user.card_Id = undefined;
  } else {
    const cardId = normalizeCardId(raw);
    const taken = await User.exists({ card_Id: cardId, _id: { $ne: user._id } });
    if (taken) {
      throw new HttpError(409, "That card is already linked to another account.");
    }
    user.card_Id = cardId;
  }
  await user.save();
  res.json({ card_Id: user.card_Id || null });
});

// ---- Access log -----------------------------------------------------------

router.get("/visitors", async (req, res) => {
  const visitors = await Visitor.find({ user: req.userId })
    .sort({ visitDate: -1 })
    .limit(200);
  res.json(visitors);
});

// ---- Record lists (allergies, medications, ...) ---------------------------

router.param("collection", (req, res, next, name) => {
  const config = Object.prototype.hasOwnProperty.call(COLLECTIONS, name)
    ? COLLECTIONS[name]
    : null;
  if (!config) return next(new HttpError(404, "Not found"));
  req.collection = config;
  next();
});

// Find an item only if it is linked from the logged-in user's record.
async function loadOwnedItem(req) {
  const { model, path } = req.collection;
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) throw new HttpError(404, "Not found");
  const owned = await User.exists({ _id: req.userId, [path]: id });
  const item = owned ? await model.findById(id) : null;
  if (!item) throw new HttpError(404, "Not found");
  return item;
}

router.get("/:collection", async (req, res) => {
  const { path } = req.collection;
  const user = await User.findById(req.userId).populate(path);
  if (!user) throw new HttpError(401, "Account no longer exists.");
  res.json(user.get(path));
});

router.post("/:collection", async (req, res) => {
  const { model: Model, path, fields } = req.collection;
  const user = await loadUser(req);
  const item = new Model();
  applyFields(item, req.body || {}, fields);
  if (Model === Surgery) item.patientName = user.name;
  await item.save();
  await User.updateOne({ _id: user._id }, { $push: { [path]: item._id } });
  res.status(201).json(item);
});

router.put("/:collection/:id", async (req, res) => {
  const item = await loadOwnedItem(req);
  applyFields(item, req.body || {}, req.collection.fields);
  await item.save();
  res.json(item);
});

router.delete("/:collection/:id", async (req, res) => {
  const { model, path } = req.collection;
  const item = await loadOwnedItem(req);
  await User.updateOne({ _id: req.userId }, { $pull: { [path]: item._id } });
  // Older seed data shared some documents between patients; only delete the
  // document itself once nobody links to it.
  const stillLinked = await User.exists({ [path]: item._id });
  if (!stillLinked) await model.deleteOne({ _id: item._id });
  res.json({ message: "Deleted" });
});

module.exports = router;
