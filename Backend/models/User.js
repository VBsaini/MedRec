const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  email: { type: String, unique: true, required: true },
  password: { type: String, required: true },
  Id: { type: String, unique: true },
  card_Id: { type: String, unique: true },
  name: { type: String },
  age: { type: Number },
  gender: { type: String },
  blood_group: { type: String },
  height: { type: Number },
  weight: { type: Number },
  medical_history: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MedicalHistory",
    },
  ],
  allergies: [{ type: mongoose.Schema.Types.ObjectId, ref: "Allergy" }],
  family_history: [
    { type: mongoose.Schema.Types.ObjectId, ref: "FamilyHistory" },
  ],
  diabetic: {
    status: { type: Boolean },
    type: { type: String },
    since: { type: Date },
  },
  heart: {
    status: { type: Boolean },
    details: { type: String },
    surgeries: [{ type: mongoose.Schema.Types.ObjectId, ref: "Surgery" }],
    medications: [{ type: mongoose.Schema.Types.ObjectId, ref: "Medication" }],
    since: { type: Date },
  },
  mental_health: {
    status: { type: Boolean },
    details: { type: String },
    since: { type: Date },
    medications: [{ type: mongoose.Schema.Types.ObjectId, ref: "Medication" }],
  },
  emergency_contact: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "EmergencyContact",
    },
  ],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("User", userSchema);
