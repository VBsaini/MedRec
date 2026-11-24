// Helpers for copying client input onto documents safely.
const { HttpError } = require("../middleware/errors");

const CARD_RE = /^[0-9A-Z]{4,32}$/;

// Read a possibly-nested key ("heart.status") from a plain request body.
// Only own properties are read, so "__proto__" and friends are ignored.
function readPath(body, path) {
  return path.split(".").reduce((obj, key) => {
    if (obj === null || typeof obj !== "object") return undefined;
    return Object.prototype.hasOwnProperty.call(obj, key) ? obj[key] : undefined;
  }, body);
}

// Copy only whitelisted, scalar values from the body onto a document.
// "" and null clear a field. Objects and arrays are rejected so a client
// cannot smuggle in query operators or unexpected structure.
function applyFields(doc, body, fields) {
  for (const field of fields) {
    let value = readPath(body, field);
    if (value === undefined) continue;
    if (typeof value === "string") value = value.trim();
    if (value === "" || value === null) value = undefined;
    if (value !== undefined && typeof value === "object") {
      throw new HttpError(400, `Invalid value for ${field}.`);
    }
    doc.set(field, value);
  }
}

// Turn a card UID as typed or printed by a reader ("04:a1 b2-c3") into the
// stored form ("04A1B2C3"). Throws a 400 when it cannot be a card UID.
function normalizeCardId(raw) {
  if (typeof raw !== "string") throw new HttpError(400, "Invalid card ID.");
  const cardId = raw.replace(/[\s:-]/g, "").toUpperCase();
  if (!CARD_RE.test(cardId)) {
    throw new HttpError(
      400,
      "Card ID must be 4-32 letters or digits, as printed by the reader."
    );
  }
  return cardId;
}

module.exports = { readPath, applyFields, normalizeCardId };
