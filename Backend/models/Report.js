const mongoose = require("mongoose");

const CATEGORIES = [
  "lab_report",
  "prescription",
  "scan",
  "discharge_summary",
  "other",
];

const FileSchema = new mongoose.Schema({
  storedName: { type: String, required: true }, // random name on disk
  originalName: { type: String },
  mimeType: { type: String, required: true },
  size: { type: Number },
});

// The on-disk name is an internal detail; clients fetch files by id.
FileSchema.set("toJSON", {
  transform: (doc, ret) => {
    delete ret.storedName;
    return ret;
  },
});

const ReportSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
  title: { type: String, required: true, trim: true, maxlength: 200 },
  description: { type: String, maxlength: 5000 },
  category: { type: String, enum: CATEGORIES, default: "other" },
  date: { type: Date, default: Date.now }, // date of the report itself
  files: [FileSchema],
  summary: { type: String },
  fileUrl: { type: String }, // legacy single-file field, no longer written
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Report", ReportSchema);
module.exports.CATEGORIES = CATEGORIES;
