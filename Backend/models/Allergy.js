const mongoose = require("mongoose");

const AllergySchema = new mongoose.Schema({
  allergens: { type: String, required: true },
  reactions: { type: String, required: true },
  severity: { type: String, required: true },
});

module.exports = mongoose.model("Allergy", AllergySchema);
