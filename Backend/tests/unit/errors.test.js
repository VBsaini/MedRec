require("../env");
const { test, describe, mock } = require("node:test");
const assert = require("node:assert/strict");
const multer = require("multer");
const mongoose = require("mongoose");
const { HttpError, notFound, errorHandler } = require("../../middleware/errors");

// A minimal stand-in for an Express response.
function fakeRes() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

function handle(err) {
  const res = fakeRes();
  errorHandler(err, {}, res, () => {});
  return res;
}

describe("errorHandler", () => {
  test("HttpError keeps its status and message", () => {
    const res = handle(new HttpError(409, "Taken"));
    assert.equal(res.statusCode, 409);
    assert.deepEqual(res.body, { message: "Taken" });
  });

  test("multer limits become readable 400s", () => {
    assert.deepEqual(handle(new multer.MulterError("LIMIT_FILE_SIZE")).body, {
      message: "A file is too large.",
    });
    assert.equal(handle(new multer.MulterError("LIMIT_FILE_COUNT")).statusCode, 400);
    assert.equal(
      handle(new multer.MulterError("LIMIT_PART_COUNT")).body.message,
      "Upload failed."
    );
  });

  test("mongoose validation errors report the first problem", () => {
    const Model = mongoose.model(
      "ErrTest",
      new mongoose.Schema({ title: { type: String, required: true } })
    );
    const err = new Model({}).validateSync();
    const res = handle(err);
    assert.equal(res.statusCode, 400);
    assert.match(res.body.message, /title.*required/);
  });

  test("cast errors, duplicate keys and bad JSON", () => {
    const cast = Object.assign(new Error("x"), { name: "CastError", path: "age" });
    assert.deepEqual(handle(cast).body, { message: "Invalid value for age." });

    const dup = handle(Object.assign(new Error("dup"), { code: 11000 }));
    assert.equal(dup.statusCode, 409);

    const json = handle(Object.assign(new Error("x"), { type: "entity.parse.failed" }));
    assert.deepEqual(json.body, { message: "Invalid JSON body." });
  });

  test("an oversized body is a 413, other body errors keep their 4xx", () => {
    const big = handle(
      Object.assign(new Error("request entity too large"), {
        type: "entity.too.large",
        status: 413,
        expose: true,
      })
    );
    assert.equal(big.statusCode, 413);
    assert.deepEqual(big.body, { message: "The request is too large." });

    const charset = handle(
      Object.assign(new Error('unsupported charset "UTF-7"'), { status: 415, expose: true })
    );
    assert.equal(charset.statusCode, 415);
  });

  test("anything else is a 500 that hides the details", () => {
    const log = mock.method(console, "error", () => {});
    const res = handle(new Error("secret stack details"));
    log.mock.restore();
    assert.equal(res.statusCode, 500);
    assert.deepEqual(res.body, { message: "Server error" });
    assert.equal(log.mock.callCount(), 1);
  });
});

test("notFound sends a JSON 404", () => {
  const res = fakeRes();
  notFound({}, res);
  assert.equal(res.statusCode, 404);
  assert.deepEqual(res.body, { message: "Not found" });
});
