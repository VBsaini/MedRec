const jwt = require("jsonwebtoken");
const { jwtSecret } = require("../config/env");

function signToken(userId) {
  return jwt.sign({ userId: String(userId) }, jwtSecret, { expiresIn: "30d" });
}

// Requires "Authorization: Bearer <token>" and sets req.userId.
function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Authentication required." });
  }
  try {
    const payload = jwt.verify(token, jwtSecret);
    req.userId = payload.userId;
    next();
  } catch (err) {
    res.status(401).json({ message: "Session expired. Please log in again." });
  }
}

module.exports = { requireAuth, signToken };
