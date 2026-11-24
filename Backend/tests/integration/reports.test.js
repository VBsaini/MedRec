const { test, describe, before, after } = require("node:test");
const assert = require("node:assert/strict");
const {
  startServer,
  stopServer,
  api,
  newPatient,
  formOf,
  storedFiles,
  PNG,
  PDF,
} = require("./helpers");

before(startServer);
after(stopServer);

async function createReport(token, fields = { title: "CBC" }, files = [["scan.png", "image/png", PNG]]) {
  return api("POST", "/api/reports", { token, form: formOf(fields, files) });
}

describe("uploading", () => {
  test("a report with a photo and a PDF", async () => {
    const p = await newPatient();
    const before = storedFiles().length;
    const res = await createReport(
      p.token,
      { title: "Blood test", category: "lab_report", date: "2024-03-15", description: "Fasting" },
      [
        ["blood test.png", "image/png", PNG],
        ["cbc.pdf", "application/pdf", PDF],
      ]
    );
    assert.equal(res.status, 201);
    const r = res.body;
    assert.equal(r.title, "Blood test");
    assert.equal(r.category, "lab_report");
    assert.equal(r.date, "2024-03-15T00:00:00.000Z");
    assert.deepEqual(
      r.files.map((f) => [f.originalName, f.mimeType, f.size]),
      [
        ["blood test.png", "image/png", PNG.length],
        ["cbc.pdf", "application/pdf", PDF.length],
      ]
    );
    assert.ok(r.files.every((f) => f.storedName === undefined), "disk names stay private");
    assert.equal(storedFiles().length, before + 2);
    // Stored under random names, never the client's.
    assert.ok(storedFiles().every((name) => /^[0-9a-f]{32}\.(png|pdf|jpg|webp|heic)$/.test(name)));
  });

  test("a hostile file name cannot escape the uploads folder", async () => {
    const p = await newPatient();
    const res = await createReport(p.token, { title: "x" }, [["../../../evil.png", "image/png", PNG]]);
    assert.equal(res.status, 201);
    assert.equal(res.body.files[0].originalName, "evil.png");
  });

  test("refuses other file types and keeps nothing on disk", async () => {
    const p = await newPatient();
    const before = storedFiles();
    const res = await createReport(p.token, { title: "x" }, [
      ["ok.png", "image/png", PNG],
      ["run.exe", "application/x-msdownload", Buffer.from("MZ")],
    ]);
    assert.equal(res.status, 400);
    assert.equal(res.body.message, "Only JPG, PNG, WEBP, HEIC and PDF files are allowed.");
    await waitForDisk(before);
  });

  test("refuses files over the size limit and keeps nothing on disk", async () => {
    const p = await newPatient();
    const before = storedFiles();
    const big = Buffer.alloc(1024 * 1024 + 1); // tests run with a 1 MB limit
    const res = await createReport(p.token, { title: "x" }, [
      ["small.png", "image/png", PNG],
      ["big.png", "image/png", big],
    ]);
    assert.equal(res.status, 400);
    assert.equal(res.body.message, "A file is too large.");
    await waitForDisk(before);
  });

  test("refuses more than 10 files at once", async () => {
    const p = await newPatient();
    const before = storedFiles();
    const files = Array.from({ length: 11 }, (_, i) => [`p${i}.png`, "image/png", PNG]);
    const res = await createReport(p.token, { title: "x" }, files);
    assert.equal(res.status, 400);
    assert.equal(res.body.message, "Too many files in one upload.");
    await waitForDisk(before);
  });

  test("a report without a title is refused and its files removed", async () => {
    const p = await newPatient();
    const before = storedFiles();
    const res = await createReport(p.token, { title: "  " });
    assert.equal(res.status, 400);
    assert.match(res.body.message, /title/);
    await waitForDisk(before);
  });

  test("refuses an unknown category", async () => {
    const p = await newPatient();
    const res = await createReport(p.token, { title: "x", category: "selfie" });
    assert.equal(res.status, 400);
  });
});

describe("reading", () => {
  test("lists my reports newest first", async () => {
    const p = await newPatient();
    await createReport(p.token, { title: "Old", date: "2020-01-01" });
    await createReport(p.token, { title: "New", date: "2024-01-01" });
    await createReport(p.token, { title: "Middle", date: "2022-01-01" });
    const res = await api("GET", "/api/reports", { token: p.token });
    assert.deepEqual(res.body.map((r) => r.title), ["New", "Middle", "Old"]);
  });

  test("downloads a file with its type and the same bytes", async () => {
    const p = await newPatient();
    const { body } = await createReport(p.token, { title: "x" }, [
      ["a.png", "image/png", PNG],
      ["b.pdf", "application/pdf", PDF],
    ]);
    for (const [file, bytes] of [[body.files[0], PNG], [body.files[1], PDF]]) {
      const res = await api("GET", `/api/reports/${body._id}/files/${file._id}`, { token: p.token });
      assert.equal(res.status, 200);
      assert.equal(res.headers.get("content-type"), file.mimeType);
      assert.equal(res.headers.get("x-content-type-options"), "nosniff");
      assert.match(res.headers.get("cache-control"), /private/);
      assert.ok(Buffer.compare(res.body, bytes) === 0, "same bytes");
    }
  });

  test("files are not reachable without the owner's login", async () => {
    const owner = await newPatient();
    const other = await newPatient();
    const { body } = await createReport(owner.token);
    const fileUrl = `/api/reports/${body._id}/files/${body.files[0]._id}`;

    assert.equal((await api("GET", fileUrl)).status, 401);
    assert.equal((await api("GET", fileUrl, { token: other.token })).status, 404);
    assert.equal((await api("GET", `/api/reports/${body._id}`, { token: other.token })).status, 404);
    assert.deepEqual((await api("GET", "/api/reports", { token: other.token })).body, []);
    // No static route exposes the uploads folder.
    for (const path of ["/uploads/reports", "/uploads", "/api/uploads"]) {
      assert.equal((await api("GET", path)).status, 404, path);
    }
  });

  test("bad ids are 404s", async () => {
    const p = await newPatient();
    const { body } = await createReport(p.token);
    assert.equal((await api("GET", "/api/reports/nope", { token: p.token })).status, 404);
    assert.equal((await api("GET", `/api/reports/${body._id}/files/nope`, { token: p.token })).status, 404);
    assert.equal(
      (await api("GET", `/api/reports/${body._id}/files/64b000000000000000000000`, { token: p.token })).status,
      404
    );
  });
});

describe("changing", () => {
  test("edit details, clear the description", async () => {
    const p = await newPatient();
    const { body } = await createReport(p.token, { title: "x", description: "old" });
    const res = await api("PATCH", `/api/reports/${body._id}`, {
      token: p.token,
      json: { title: "Chest X-ray", category: "scan", description: "", date: "2023-11-05" },
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.title, "Chest X-ray");
    assert.equal(res.body.category, "scan");
    assert.equal(res.body.description, undefined);
    assert.equal(res.body.files.length, 1, "files untouched");

    const bad = await api("PATCH", `/api/reports/${body._id}`, { token: p.token, json: { title: { $set: 1 } } });
    assert.equal(bad.status, 400);
  });

  test("add files up to the limit of 10", async () => {
    const p = await newPatient();
    const { body } = await createReport(p.token);
    const nine = Array.from({ length: 9 }, (_, i) => [`p${i}.png`, "image/png", PNG]);
    const added = await api("POST", `/api/reports/${body._id}/files`, { token: p.token, form: formOf({}, nine) });
    assert.equal(added.status, 201);
    assert.equal(added.body.files.length, 10);

    const before = storedFiles();
    const extra = await api("POST", `/api/reports/${body._id}/files`, {
      token: p.token,
      form: formOf({}, [["one-more.png", "image/png", PNG]]),
    });
    assert.equal(extra.status, 400);
    assert.equal(extra.body.message, "A report can have at most 10 files.");
    await waitForDisk(before);
  });

  test("another patient cannot add files to my report", async () => {
    const owner = await newPatient();
    const other = await newPatient();
    const { body } = await createReport(owner.token);
    const before = storedFiles();
    const res = await api("POST", `/api/reports/${body._id}/files`, {
      token: other.token,
      form: formOf({}, [["x.png", "image/png", PNG]]),
    });
    assert.equal(res.status, 404);
    await waitForDisk(before);
  });

  test("deleting a file removes it from disk", async () => {
    const p = await newPatient();
    const { body } = await createReport(p.token, { title: "x" }, [
      ["a.png", "image/png", PNG],
      ["b.pdf", "application/pdf", PDF],
    ]);
    const before = storedFiles();
    const res = await api("DELETE", `/api/reports/${body._id}/files/${body.files[0]._id}`, { token: p.token });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.files.map((f) => f.originalName), ["b.pdf"]);
    await waitForDisk(before.length - 1);
  });

  test("deleting a report removes all its files", async () => {
    const p = await newPatient();
    const other = await newPatient();
    const { body } = await createReport(p.token, { title: "x" }, [
      ["a.png", "image/png", PNG],
      ["b.pdf", "application/pdf", PDF],
    ]);
    assert.equal((await api("DELETE", `/api/reports/${body._id}`, { token: other.token })).status, 404);

    const before = storedFiles();
    const res = await api("DELETE", `/api/reports/${body._id}`, { token: p.token });
    assert.equal(res.status, 200);
    await waitForDisk(before.length - 2);
    assert.equal((await api("GET", `/api/reports/${body._id}`, { token: p.token })).status, 404);
  });
});

// File removal is asynchronous; wait briefly until the uploads folder matches
// the expected list of files (or count).
async function waitForDisk(expected) {
  const matches = () =>
    Array.isArray(expected)
      ? JSON.stringify(storedFiles()) === JSON.stringify(expected)
      : storedFiles().length === expected;
  for (let i = 0; i < 40 && !matches(); i++) {
    await new Promise((r) => setTimeout(r, 25));
  }
  if (Array.isArray(expected)) assert.deepEqual(storedFiles(), expected, "no files left behind");
  else assert.equal(storedFiles().length, expected);
}
