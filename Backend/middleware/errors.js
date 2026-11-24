const multer = require("multer");

// An error with an HTTP status that is safe to show to the client.
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function notFound(req, res) {
  res.status(404).json({ message: "Not found" });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ message: err.message });
  }
  if (err instanceof multer.MulterError) {
    const messages = {
      LIMIT_FILE_SIZE: "A file is too large.",
      LIMIT_FILE_COUNT: "Too many files in one upload.",
      LIMIT_UNEXPECTED_FILE: "Too many files in one upload.",
    };
    return res
      .status(400)
      .json({ message: messages[err.code] || "Upload failed." });
  }
  if (err.name === "ValidationError") {
    const first = Object.values(err.errors || {})[0];
    return res
      .status(400)
      .json({ message: first ? first.message : "Invalid data." });
  }
  if (err.name === "CastError") {
    return res.status(400).json({ message: `Invalid value for ${err.path}.` });
  }
  if (err.code === 11000) {
    return res.status(409).json({ message: "That value is already in use." });
  }
  if (err.type === "entity.parse.failed") {
    return res.status(400).json({ message: "Invalid JSON body." });
  }
  if (err.type === "entity.too.large") {
    return res.status(413).json({ message: "The request is too large." });
  }
  // Other client errors raised by Express or body-parser (e.g. an
  // unsupported charset) carry a safe 4xx status.
  if (err.expose && err.status >= 400 && err.status < 500) {
    return res.status(err.status).json({ message: err.message });
  }
  console.error("[error]", err);
  res.status(500).json({ message: "Server error" });
}

module.exports = { HttpError, notFound, errorHandler };
