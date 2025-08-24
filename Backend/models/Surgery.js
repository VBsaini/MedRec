const mongoose = require("mongoose");

const surgerySchema = new mongoose.Schema({
  patientName: { type: String, required: true },
  hospitalName: { type: String, required: true },
  doctorName: { type: String, required: true },
  surgeryType: { type: String, required: true },
  surgeryDate: { type: Date, required: true },
  details: { type: String },
  recordNumber: { type: String, unique: true, required: true },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Surgery", surgerySchema);
