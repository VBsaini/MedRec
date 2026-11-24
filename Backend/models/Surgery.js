const mongoose = require("mongoose");
const crypto = require("crypto");

const surgerySchema = new mongoose.Schema({
  surgeryType: { type: String, required: true },
  surgeryDate: { type: Date, required: true },
  hospitalName: { type: String },
  doctorName: { type: String },
  patientName: { type: String },
  details: { type: String },
  // Hospital record number if the patient has one; otherwise generated so the
  // unique index always has a value.
  recordNumber: {
    type: String,
    unique: true,
    required: true,
    default: () => `MR-${crypto.randomBytes(6).toString("hex").toUpperCase()}`,
  },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Surgery", surgerySchema);
