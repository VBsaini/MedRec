const express = require("express");
const router = express.Router();
const Report = require("../models/Report");
const multer = require("multer");
const path = require("path");

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, path.join(__dirname, "../../uploads/reports"));
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + "-" + file.originalname);
  },
});
const upload = multer({ storage });

// Create a new report (with file upload)
router.post("/", upload.single("file"), async (req, res) => {
  try {
    const { user, title, description, summary } = req.body;
    const fileUrl = req.file
      ? `/uploads/reports/${req.file.filename}`
      : undefined;
    const report = new Report({ user, title, description, fileUrl, summary });
    await report.save();
    res.status(201).json(report);
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error creating report", error: err.message });
  }
});

// Get all reports for a user
router.get("/user/:userId", async (req, res) => {
  try {
    const reports = await Report.find({ user: req.params.userId });
    res.json(reports);
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error fetching reports", error: err.message });
  }
});

// Get a single report by ID
router.get("/:id", async (req, res) => {
  try {
    const report = await Report.findById(req.params.id);
    if (!report) return res.status(404).json({ message: "Report not found" });
    res.json(report);
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error fetching report", error: err.message });
  }
});

// Delete a report
router.delete("/:id", async (req, res) => {
  try {
    const report = await Report.findByIdAndDelete(req.params.id);
    if (!report) return res.status(404).json({ message: "Report not found" });
    res.json({ message: "Report deleted" });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error deleting report", error: err.message });
  }
});

module.exports = router;
