const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

// Set global options for V2 functions (region etc.)
setGlobalOptions({ region: "us-central1" });

const MODELSLAB_BASE = "https://modelslab.com/api/v7/images";

// Helper: sleep for ms
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * =====================================================
 * GENERATE IMAGE (Flux Kontext Pro) — SINGLE-CALL (V2)
 * =====================================================
 */
exports.generateImageFunc = onCall({
  secrets: ["MODELSLAB_API_KEY"],
  timeoutSeconds: 300,
  memory: "512MiB",
  cpu: 1,
}, async (request) => {
  // Lazy load heavy modules
  const fetch = require("node-fetch");
  const crypto = require("crypto");

  const data = request.data;
  const apiKey = process.env.MODELSLAB_API_KEY;

  if (!apiKey) {
    throw new Error("MODELSLAB_API_KEY missing");
  }

  const {
    prompt,
    negative_prompt,
    initImageBase64,
    width = 1024,
    height = 1024,
    num_inference_steps = 26,
    guidance_scale = 7.5,
    strength, // 🔑 Accept strength from request
    seed,
  } = data;

  const safeWidth = Math.min(width, 1024);
  const safeHeight = Math.min(height, 1024);

  // ---- STEP 0: Upload init_image to Firebase Storage to get a public URL ----
  let initImageUrl = null;
  let tempFilePath = null;

  if (initImageBase64 && initImageBase64.length > 0) {
    try {
      let rawBase64 = initImageBase64;
      if (rawBase64.includes(",")) {
        rawBase64 = rawBase64.split(",")[1];
      }

      const buffer = Buffer.from(rawBase64, "base64");
      const bucket = admin.storage().bucket();
      const fileName = `tmp/init_images/${crypto.randomUUID()}.png`;
      tempFilePath = fileName;
      const file = bucket.file(fileName);

      await file.save(buffer, {
        metadata: {
          contentType: "image/png",
        },
      });

      // Provide a signed URL so ModelsLab can read the image regardless of bucket ACL settings
      const [signedUrl] = await file.getSignedUrl({
        action: 'read',
        expires: Date.now() + 60 * 60 * 1000 // 1 hour valid
      });
      initImageUrl = signedUrl;
      console.log(`Successfully uploaded init image, signed URL generated.`);
    } catch (uploadErr) {
      console.error("Failed to upload init image:", uploadErr.message);
    }
  }

  // ---- STEP 1: Submit generation job ----
  const submitBody = {
    key: apiKey,
    model_id: "flux-kontext-pro",
    prompt,
    negative_prompt,
    width: safeWidth,
    height: safeHeight,
    num_inference_steps,
    guidance_scale,
    seed,
  };

  if (initImageUrl) {
    submitBody.init_image = initImageUrl;
    // �� Use provided strength or default to 0.45
    submitBody.strength = strength !== undefined ? strength : 0.45;
    console.log(`Using init_image with strength=${submitBody.strength} model=${submitBody.model_id}`);
  }

  // Use img2img endpoint when we have an init_image, text2img otherwise
  const endpoint = initImageUrl
    ? `${MODELSLAB_BASE}/img2img`
    : `${MODELSLAB_BASE}/text-to-image`;
  console.log(`Using endpoint: ${endpoint}`);

  const submitResponse = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(submitBody),
  });

  const submitJson = await submitResponse.json();

  if (!submitJson || submitJson.status === "error") {
    await cleanupTempFile(admin, tempFilePath);
    return { ok: false, error: submitJson?.message || "ModelsLab submission failed" };
  }

  if (
    submitJson.status === "success" &&
    Array.isArray(submitJson.output) &&
    submitJson.output.length > 0
  ) {
    await cleanupTempFile(admin, tempFilePath);
    return { ok: true, imageUrl: submitJson.output[0] };
  }

  const jobId = submitJson.id;
  if (!jobId) {
    await cleanupTempFile(admin, tempFilePath);
    return { ok: false, error: "ModelsLab job id missing" };
  }

  const eta = submitJson.status === "processing" ? (submitJson.eta || 15) : 10;

  // ---- STEP 2: Poll ----
  const MAX_POLLS = 60;
  let pollDelay = Math.max(eta * 1000, 5000);

  for (let i = 0; i < MAX_POLLS; i++) {
    await sleep(pollDelay);
    pollDelay = 5000;

    try {
      const fetchResponse = await fetch(`${MODELSLAB_BASE}/fetch/${jobId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: apiKey }),
      });

      const fetchJson = await fetchResponse.json();

      if (fetchJson.status === "processing") continue;

      if (
        fetchJson.status === "success" &&
        Array.isArray(fetchJson.output) &&
        fetchJson.output.length > 0
      ) {
        await cleanupTempFile(admin, tempFilePath);
        return { ok: true, imageUrl: fetchJson.output[0] };
      }

      if (fetchJson.status === "error" || fetchJson.status === "failed") {
        await cleanupTempFile(admin, tempFilePath);
        return { ok: false, error: fetchJson?.message || "Generation failed" };
      }
    } catch (e) {
      console.error("Poll Error:", e.message);
    }
  }

  await cleanupTempFile(admin, tempFilePath);
  return { ok: false, error: "Timed out polling ModelsLab" };
});

/**
 * Helper: Clean up temporary init_image from Storage
 */
async function cleanupTempFile(admin, filePath) {
  if (!filePath) return;
  try {
    const bucket = admin.storage().bucket();
    await bucket.file(filePath).delete();
  } catch (e) {
    console.log(`Temp cleanup skipped: ${e.message}`);
  }
}

/**
 * =====================================================
 * FETCH IMAGE RESULT (V2)
 * =====================================================
 */
exports.fetchImageFunc = onCall({
  secrets: ["MODELSLAB_API_KEY"],
  region: "us-central1"
}, async (request) => {
  const fetch = require("node-fetch");
  const data = request.data;
  const apiKey = process.env.MODELSLAB_API_KEY;
  const { id } = data;

  if (!apiKey || id == null) {
    throw new Error("Missing params");
  }

  const response = await fetch(`${MODELSLAB_BASE}/fetch/${id}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ key: apiKey }),
  });

  const json = await response.json();
  if (json.status === "processing") return { status: "processing" };

  if (
    json.status === "success" &&
    Array.isArray(json.output) &&
    json.output.length
  ) {
    return {
      ok: true,
      status: "success",
      imageUrl: json.output[0],
    };
  }

  return { status: "error", message: json?.message || "Fetch failed" };
});

/**
 * =====================================================
 * STRIPE PAYMENTS
 * =====================================================
 */
const stripeFunctions = require("./stripe");
exports.createStripePaymentIntent = stripeFunctions.createStripePaymentIntent;
