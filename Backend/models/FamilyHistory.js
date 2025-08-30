const mongoose = require("mongoose");

const FamilyHistorySchema = new mongoose.Schema({
  relationship: { type: String, required: true },
  conditions: { type: String, required: true },
  medications: [{ type: mongoose.Schema.Types.ObjectId, ref: "Medication" }],
  surgeries: [{ type: mongoose.Schema.Types.ObjectId, ref: "Surgery" }],
});

module.exports = mongoose.model("FamilyHistory", FamilyHistorySchema);
