const mongoose = require("mongoose");

const EmergencyContactSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone_number: { type: String, required: true },
  relationship: { type: String },
});

module.exports = mongoose.model("EmergencyContact", EmergencyContactSchema);
