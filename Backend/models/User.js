const mongoose = require("mongoose");

const ref = (model) => ({ type: mongoose.Schema.Types.ObjectId, ref: model });

const userSchema = new mongoose.Schema({
  email: { type: String, unique: true, required: true },
  // Never returned by queries unless explicitly selected with "+password".
  password: { type: String, required: true, select: false },
  alias: { type: String, unique: true, required: true },
  card_Id: { type: String, unique: true, sparse: true },
  name: { type: String },
  age: { type: Number, min: 0, max: 150 },
  gender: { type: String },
  blood_group: { type: String },
  height: { type: Number, min: 0 },
  weight: { type: Number, min: 0 },
  medical_history: [ref("MedicalHistory")],
  allergies: [ref("Allergy")],
  family_history: [ref("FamilyHistory")],
  // The patient's own surgeries and medications.
  surgeries: [ref("Surgery")],
  medications: [ref("Medication")],
  diabetic: {
    status: { type: Boolean },
    type: { type: String },
    since: { type: Date },
  },
  heart: {
    status: { type: Boolean },
    details: { type: String },
    since: { type: Date },
    // Legacy: older records stored every surgery/medication here. New data
    // goes in the top-level `surgeries` / `medications` lists.
    surgeries: [ref("Surgery")],
    medications: [ref("Medication")],
  },
  mental_health: {
    status: { type: Boolean },
    details: { type: String },
    since: { type: Date },
    medications: [ref("Medication")], // legacy, see above
  },
  emergency_contact: [ref("EmergencyContact")],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("User", userSchema);
