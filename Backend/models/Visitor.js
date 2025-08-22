const mongoose = require("mongoose");

const visitorSchema = new mongoose.Schema({
  name: { type: String, required: true },
  visitDate: { type: Date, default: Date.now },
  purpose: { type: String },
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
});

module.exports = mongoose.model("Visitor", visitorSchema);
