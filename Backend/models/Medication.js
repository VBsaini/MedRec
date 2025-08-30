const mongoose = require("mongoose");

const MedicationSchema = new mongoose.Schema({
  name: { type: String, required: true },
  dosage: { type: String },
  frequency: { type: String },
  prescribedBy: { type: String },
  prescribedFor: { type: String },
  startDate: { type: Date },
  endDate: { type: Date },
});

module.exports = mongoose.model("Medication", MedicationSchema);
