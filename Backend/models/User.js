const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  Id: { type: String, required: true, unique: true },
  card_Id: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  age: { type: Number, required: true },
  gender: { type: String, required: true },
  blood_group: { type: String, required: true },
  height: { type: Number, required: true },
  weight: { type: Number, required: true },
  medical_history: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "MedicalHistory",
  },
  allergies: [{ type: mongoose.Schema.Types.ObjectId, ref: "Allergy" }],
  family_history: [
    { type: mongoose.Schema.Types.ObjectId, ref: "FamilyHistory" },
  ],
  diabetic: {
    status: { type: Boolean, required: true },
    type: { type: String, required: true },
    since: { type: Date, required: true },
  },
  heart: {
    status: { type: Boolean, required: true },
    details: { type: String, required: true },
    surgeries: [{ type: mongoose.Schema.Types.ObjectId, ref: "Surgery" }],
    medications: { type: String, required: true },
    since: { type: Date, required: true },
  },
  mental_health: {
    status: { type: Boolean, required: true },
    details: { type: String, required: true },
    since: { type: Date, required: true },
    medications: { type: String, required: true },
  },
  emergency_contact: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "EmergencyContact",
  },
  phone_number: { type: String, required: true },
  misc: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("User", userSchema);
