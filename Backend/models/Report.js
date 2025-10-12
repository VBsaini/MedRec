const mongoose = require("mongoose");

const ReportSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  title: { type: String, required: true },
  description: { type: String },
  date: { type: Date, default: Date.now },
  fileUrl: { type: String }, // URL or path to the uploaded file
  summary: { type: String }, // Generated summary of the report
});

module.exports = mongoose.model("Report", ReportSchema);
