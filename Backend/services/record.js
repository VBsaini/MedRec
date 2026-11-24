// Every path on User that references another collection.
const RECORD_PATHS = [
  "medical_history",
  "allergies",
  "family_history",
  "emergency_contact",
  "surgeries",
  "medications",
  "heart.surgeries",
  "heart.medications",
  "mental_health.medications",
];

// Populate a User query with the full medical record.
function populateRecord(query) {
  return RECORD_PATHS.reduce((q, path) => q.populate(path), query);
}

module.exports = { populateRecord };
