const axios = require("axios");
const nodemailer = require("nodemailer");

// Helper: create a nodemailer transporter from env, or return null if not configured
function createEmailTransporter() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SECURE } = process.env;
  if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) return null;
  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: String(SMTP_SECURE || "false").toLowerCase() === "true",
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
}

async function sendEmail(to, subject, text) {
  try {
    const transporter = createEmailTransporter();
    if (!transporter) {
      console.warn("[notify] Email not configured (missing SMTP env). Skipping email to", to);
      return { channel: "email", to, sent: false, reason: "not-configured" };
    }
    const from = process.env.SMTP_FROM || process.env.SMTP_USER;
    await transporter.sendMail({ from, to, subject, text });
    return { channel: "email", to, sent: true };
  } catch (err) {
    console.error("[notify] Email send failed:", err?.message);
    return { channel: "email", to, sent: false, reason: err?.message };
  }
}

async function sendWhatsApp(phone, text) {
  const apiKey = process.env.CALLMEBOT_API_KEY; // https://www.callmebot.com/blog/free-api-whatsapp-messages/
  if (!apiKey) {
    console.warn("[notify] CallMeBot API key not set. Skipping WhatsApp to", phone);
    return { channel: "whatsapp", to: phone, sent: false, reason: "not-configured" };
  }
  try {
    if (!phone) throw new Error("phone number missing");
    // sanitize phone
    let to = String(phone).replace(/\s+/g, "");
    if (!to.startsWith("+")) to = "+" + to;
    const encoded = encodeURIComponent(text);
    const url = `https://api.callmebot.com/whatsapp.php?phone=${encodeURIComponent(to)}&text=${encoded}&apikey=${encodeURIComponent(apiKey)}`;
    const res = await axios.get(url, { timeout: 10000 });
    const ok = res.status >= 200 && res.status < 300;
    return { channel: "whatsapp", to, sent: ok, status: res.status };
  } catch (err) {
    console.error("[notify] WhatsApp send failed:", err?.message);
    return { channel: "whatsapp", to: phone, sent: false, reason: err?.message };
  }
}

async function sendNtfy(topic, text, title = "MedRec") {
  // ntfy.sh - free, self-hosted push notifications (perfect for local dev)
  // Docs: https://ntfy.sh or run your own via Docker: docker run -p 80:80 binwiederhier/ntfy serve
  const baseUrl = process.env.NTFY_BASE_URL || "https://ntfy.sh"; // Default to public server
  if (!topic) {
    console.warn("[notify] ntfy topic not set. Skipping ntfy notification.");
    return { channel: "ntfy", topic: null, sent: false, reason: "no-topic" };
  }
  try {
    const url = `${baseUrl.replace(/\/$/, "")}/${encodeURIComponent(topic)}`;
    const res = await axios.post(
      url,
      text,
      {
        headers: { "Title": title, "Priority": "default", "Tags": "hospital,emergency" },
        timeout: 8000,
      }
    );
    const ok = res.status >= 200 && res.status < 300;
    return { channel: "ntfy", topic, sent: ok, status: res.status };
  } catch (err) {
    console.error("[notify] ntfy send failed:", err?.message);
    return { channel: "ntfy", topic, sent: false, reason: err?.message };
  }
}

function formatAccessMessage(user, meta = {}) {
  const when = new Date().toISOString();
  const parts = [
    `Your MedRec card was accessed`,
    user?.alias ? `Alias: ${user.alias}` : null,
    user?.name ? `Name: ${user.name}` : null,
    user?.card_Id ? `Card ID: ${user.card_Id}` : null,
    meta.ip ? `IP: ${meta.ip}` : null,
    meta.userAgent ? `Agent: ${meta.userAgent}` : null,
    `Time: ${when}`,
  ].filter(Boolean);
  return parts.join(" | ");
}

function formatSOSMessage(user, meta = {}, customText) {
  const when = new Date().toISOString();
  const header = customText && customText.trim().length > 0 ? customText.trim() : "SOS! Emergency assistance requested.";
  const parts = [
    header,
    user?.name ? `Patient: ${user.name}` : null,
    user?.alias ? `Alias: ${user.alias}` : null,
    user?.card_Id ? `Card ID: ${user.card_Id}` : null,
    meta.location ? `Location: ${meta.location}` : null,
    meta.by ? `Triggered by: ${meta.by}` : null,
    `Time: ${when}`,
  ].filter(Boolean);
  return parts.join(" | ");
}

// Notify the user when their card data is fetched
async function notifyUserAccess(user, meta = {}) {
  const results = [];
  const message = formatAccessMessage(user, meta);

  // 1) Try email (to user.email)
  if (user?.email) {
    results.push(await sendEmail(user.email, "MedRec: Your card was accessed", message));
  } else {
    results.push({ channel: "email", to: null, sent: false, reason: "user-has-no-email" });
  }

  // 2) Optional WhatsApp to an extra number (if configured globally)
  if (process.env.NOTIFY_USER_WHATSAPP_PHONE) {
    results.push(await sendWhatsApp(process.env.NOTIFY_USER_WHATSAPP_PHONE, message));
  }

  // 3) Optional ntfy push (perfect for local dev - no setup needed!)
  if (process.env.NTFY_TOPIC) {
    results.push(await sendNtfy(process.env.NTFY_TOPIC, message, "MedRec: Card Accessed"));
  }

  if (!results.some(r => r.sent)) {
    console.warn("[notify] No notification channels succeeded for user access.", { user: user?._id || user?.email || user?.alias });
  }
  return results;
}

// Send SOS to all emergency contacts (WhatsApp via CallMeBot)
async function sendSOS(user, { message, location, by } = {}) {
  const results = [];
  const text = formatSOSMessage(user, { location, by }, message);
  const contacts = Array.isArray(user?.emergency_contact) ? user.emergency_contact : [];

  if (contacts.length === 0) {
    console.warn("[notify] User has no emergency contacts to notify.");
    return [{ channel: "whatsapp", sent: false, reason: "no-emergency-contacts" }];
  }

  for (const c of contacts) {
    const phone = c?.phone_number;
    if (!phone) {
      results.push({ channel: "whatsapp", to: null, sent: false, reason: "missing-phone-number" });
      continue;
    }
    // Send one-by-one, don't fail fast
    /* Old: No SOS send logic */
    const res = await sendWhatsApp(phone, text);
    results.push(res);
  }

  // Also send via ntfy if configured (instant local dev notifications!)
  const sosTopic = process.env.NTFY_SOS_TOPIC || process.env.NTFY_TOPIC;
  if (sosTopic) {
    results.push(await sendNtfy(sosTopic, text, "🚨 MedRec SOS"));
  }

  return results;
}

module.exports = {
  notifyUserAccess,
  sendSOS,
};
