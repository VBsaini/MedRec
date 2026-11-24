// Shared setup for API integration tests: a real Express app on a random
// port, backed by a real (throwaway) MongoDB database.
const { uploadsDir } = require("../env");
const fs = require("fs");
const mongoose = require("mongoose");
const createApp = require("../../createApp");

let server;
let baseUrl;

async function startServer() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 3000,
    });
  } catch (err) {
    throw new Error(
      `Integration tests need MongoDB at ${process.env.MONGODB_URI} ` +
        `(set TEST_MONGODB_URI to use another server): ${err.message}`
    );
  }
  await mongoose.connection.dropDatabase();
  // Unique indexes (email, alias, card_Id) must exist before the tests rely on them.
  await Promise.all(
    Object.values(mongoose.models).map((model) => model.syncIndexes())
  );

  // frontendDist: null so tests see the API-only behaviour.
  const app = createApp({ frontendDist: null });
  await new Promise((resolve) => {
    server = app.listen(0, "127.0.0.1", resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  return baseUrl;
}

async function stopServer() {
  await new Promise((resolve) => server.close(resolve));
  await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
  fs.rmSync(uploadsDir, { recursive: true, force: true });
}

// Calls the API. `json` sends a JSON body, `form` a FormData body.
async function api(method, path, { token, json, form, headers = {}, raw } = {}) {
  const init = { method, headers: { ...headers } };
  if (token) init.headers.Authorization = `Bearer ${token}`;
  if (json !== undefined) {
    init.headers["Content-Type"] = "application/json";
    init.body = JSON.stringify(json);
  }
  if (raw !== undefined) init.body = raw;
  if (form) init.body = form;
  const res = await fetch(baseUrl + path, init);
  const type = res.headers.get("content-type") || "";
  const body = type.includes("application/json")
    ? await res.json()
    : Buffer.from(await res.arrayBuffer());
  return { status: res.status, body, headers: res.headers };
}

let counter = 0;

// Signs up a fresh patient and returns { token, user, email, password }.
async function newPatient(overrides = {}) {
  counter += 1;
  const details = {
    name: `Patient ${counter}`,
    alias: `patient_${process.pid}_${counter}`,
    email: `patient${counter}.${process.pid}@example.test`,
    password: "correct-horse-1",
    ...overrides,
  };
  const res = await api("POST", "/api/auth/signup", { json: details });
  if (res.status !== 201) {
    throw new Error(`signup failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return { ...details, token: res.body.token, user: res.body.user };
}

// Smallest valid PNG and PDF, so uploads carry real file contents.
const PNG = Buffer.from(
  "89504e470d0a1a0a0000000d4948445200000001000000010806000000" +
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082",
  "hex"
);
const PDF = Buffer.from(
  "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n" +
    "2 0 obj<</Type/Pages/Kids[]/Count 0>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"
);

// Builds multipart form data: fields plus [name, type, bytes] files.
function formOf(fields = {}, files = []) {
  const form = new FormData();
  for (const [key, value] of Object.entries(fields)) form.append(key, value);
  for (const [name, type, bytes] of files) {
    form.append("files", new Blob([bytes], { type }), name);
  }
  return form;
}

// Names of the files currently stored for uploads.
function storedFiles() {
  return fs.existsSync(uploadsDir) ? fs.readdirSync(uploadsDir).sort() : [];
}

module.exports = {
  startServer,
  stopServer,
  api,
  newPatient,
  formOf,
  storedFiles,
  PNG,
  PDF,
};
