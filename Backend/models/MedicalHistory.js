const mongoose = require("mongoose");

const MedicalHistorySchema = new mongoose.Schema({
  past_illnesses: { type: String, required: true },
  surgeries: [{ type: mongoose.Schema.Types.ObjectId, ref: "Surgery" }],
  medications: [{ type: mongoose.Schema.Types.ObjectId, ref: "Medication" }],
});

module.exports = mongoose.model("MedicalHistory", MedicalHistorySchema);
