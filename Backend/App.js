const { port } = require("./config/env");
const connectDB = require("./config/db");
const createApp = require("./createApp");

connectDB();

// Listens on all interfaces so a phone on the same Wi-Fi can reach it.
createApp().listen(port, () => {
  console.log(`MedRec API running on http://localhost:${port}`);
});
