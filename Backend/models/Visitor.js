const mongoose = require("mongoose");

const visitorSchema = new mongoose.Schema({
  name: { type: String, required: true },
  visitDate: { type: Date, default: Date.now },
  purpose: { type: String },
  Id: { type: String, required: true, unique: true },
  card_Id: { type: String, required: true , unique: false},
  ip_address: { type: String, required: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  anonymous: {
    status: { type: Boolean, default: false },
    name: { type: String },
  },
});

module.exports = mongoose.model("Visitor", visitorSchema);
