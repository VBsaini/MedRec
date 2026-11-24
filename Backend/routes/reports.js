// Reports: photos and documents a patient uploads to their own record.
// All routes require login and only ever touch the caller's reports.
const express = require("express");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const mongoose = require("mongoose");
const Report = require("../models/Report");
const { requireAuth } = require("../middleware/auth");
const { HttpError } = require("../middleware/errors");
const {
  uploadsDir,
  maxUploadBytes,
  maxFilesPerReport,
} = require("../config/env");

const router = express.Router();
router.use(requireAuth);

// Allowed upload types -> extension used on disk.
const ALLOWED_TYPES = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/heic": ".heic",
  "application/pdf": ".pdf",
};

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  // Random names: nothing from the client ends up in a filesystem path.
  filename: (req, file, cb) =>
    cb(
      null,
      crypto.randomBytes(16).toString("hex") + ALLOWED_TYPES[file.mimetype]
    ),
});

const upload = multer({
  storage,
  limits: { fileSize: maxUploadBytes, files: maxFilesPerReport },
  fileFilter: (req, file, cb) => {
    if (ALLOWED_TYPES[file.mimetype]) return cb(null, true);
    cb(new HttpError(400, "Only JPG, PNG, WEBP, HEIC and PDF files are allowed."));
  },
}).array("files", maxFilesPerReport);

function removeFromDisk(storedNames) {
  for (const name of storedNames) {
    fs.unlink(path.join(uploadsDir, path.basename(name)), (err) => {
      if (err && err.code !== "ENOENT") {
        console.error("[reports] could not delete file:", err.message);
      }
    });
  }
}

// Run multer, and if it fails part-way, remove the files it already wrote so
// failed uploads do not pile up on disk.
function handleUpload(req, res, next) {
  upload(req, res, (err) => {
    if (err) {
      removeFromDisk((req.files || []).map((f) => f.filename));
      return next(err);
    }
    next();
  });
}

const toFileDocs = (files) =>
  (files || []).map((f) => ({
    storedName: f.filename,
    originalName: path.basename(f.originalname || "").slice(0, 200),
    mimeType: f.mimetype,
    size: f.size,
  }));

function applyDetails(report, body) {
  for (const field of ["title", "description", "category", "date"]) {
    let value = body[field];
    if (value === undefined) continue;
    if (typeof value !== "string") {
      throw new HttpError(400, `Invalid value for ${field}.`);
    }
    value = value.trim();
    report.set(field, value === "" ? undefined : value);
  }
}

async function loadOwnedReport(req) {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) throw new HttpError(404, "Report not found");
  const report = await Report.findOne({ _id: id, user: req.userId });
  if (!report) throw new HttpError(404, "Report not found");
  return report;
}

// Create a report with zero or more files (multipart field "files").
router.post("/", handleUpload, async (req, res) => {
  const fileDocs = toFileDocs(req.files);
  try {
    const report = new Report({ user: req.userId, files: fileDocs });
    applyDetails(report, req.body || {});
    await report.save();
    res.status(201).json(report);
  } catch (err) {
    removeFromDisk(fileDocs.map((f) => f.storedName));
    throw err;
  }
});

// List my reports, newest first.
router.get("/", async (req, res) => {
  const reports = await Report.find({ user: req.userId }).sort({
    date: -1,
    createdAt: -1,
  });
  res.json(reports);
});

router.get("/:id", async (req, res) => {
  res.json(await loadOwnedReport(req));
});

// Edit title / description / category / date.
router.patch("/:id", async (req, res) => {
  const report = await loadOwnedReport(req);
  applyDetails(report, req.body || {});
  await report.save();
  res.json(report);
});

// Add more files to an existing report.
router.post("/:id/files", handleUpload, async (req, res) => {
  const fileDocs = toFileDocs(req.files);
  try {
    const report = await loadOwnedReport(req);
    if (report.files.length + fileDocs.length > maxFilesPerReport) {
      throw new HttpError(
        400,
        `A report can have at most ${maxFilesPerReport} files.`
      );
    }
    report.files.push(...fileDocs);
    await report.save();
    res.status(201).json(report);
  } catch (err) {
    removeFromDisk(fileDocs.map((f) => f.storedName));
    throw err;
  }
});

// Download one file. Not a public URL: needs the owner's token.
router.get("/:id/files/:fileId", async (req, res, next) => {
  const report = await loadOwnedReport(req);
  const file = mongoose.isValidObjectId(req.params.fileId)
    ? report.files.id(req.params.fileId)
    : null;
  if (!file) throw new HttpError(404, "File not found");
  res.sendFile(
    path.basename(file.storedName),
    {
      root: uploadsDir,
      headers: {
        "Content-Type": file.mimeType,
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "private, max-age=86400",
      },
    },
    (err) => {
      if (!err) return;
      if (res.headersSent) return res.destroy();
      next(new HttpError(404, "File not found"));
    }
  );
});

router.delete("/:id/files/:fileId", async (req, res) => {
  const report = await loadOwnedReport(req);
  const file = mongoose.isValidObjectId(req.params.fileId)
    ? report.files.id(req.params.fileId)
    : null;
  if (!file) throw new HttpError(404, "File not found");
  const storedName = file.storedName;
  report.files.pull(file._id);
  await report.save();
  removeFromDisk([storedName]);
  res.json(report);
});

router.delete("/:id", async (req, res) => {
  const report = await loadOwnedReport(req);
  await report.deleteOne();
  removeFromDisk(report.files.map((f) => f.storedName));
  res.json({ message: "Report deleted" });
});

module.exports = router;
