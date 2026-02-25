const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const crypto = require("crypto");

// Initialize Firebase Admin
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
 * 
 * Backend handles:
 * - Upload init image to Firebase Storage → signed URL
 * - Submit to ModelsLab with init_image URL
 * - Poll for result
 * - Return final imageUrl
 */
exports.generateImageFunc = onCall({
  secrets: ["MODELSLAB_API_KEY"],
  timeoutSeconds: 300,
  memory: "512MiB",
  cpu: 1,
}, async (request) => {
  console.log("generateImageFunc V2 ENTERED");

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
    seed,
  } = data;

  const safeWidth = Math.min(width, 1024);
  const safeHeight = Math.min(height, 1024);

  // ---- STEP 0: Upload init_image to Firebase Storage to get a public URL ----
  // ModelsLab requires a publicly accessible URL for init_image, NOT raw base64.
  let initImageUrl = null;
  let tempFilePath = null;

  if (initImageBase64 && initImageBase64.length > 0) {
    try {
      // Strip data URI prefix if present (e.g., "data:image/png;base64,")
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
          metadata: {
            firebaseStorageDownloadTokens: crypto.randomUUID(),
          },
        },
        public: true, // Make it publicly readable for ModelsLab
      });

      // Get the public URL
      initImageUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
      console.log(`Init image uploaded: ${initImageUrl} (${buffer.length} bytes)`);
    } catch (uploadErr) {
      console.error("Failed to upload init image:", uploadErr.message);
      // Continue without init_image — will generate from text only
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

  // Only add init_image if we successfully uploaded
  if (initImageUrl) {
    submitBody.init_image = initImageUrl;
    console.log("Using init_image URL for identity lock");
  } else {
    console.warn("WARNING: No init_image URL — generating from text only (no identity lock)");
  }

  const submitResponse = await fetch(`${MODELSLAB_BASE}/text-to-image`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(submitBody),
  });

  const submitJson = await submitResponse.json();
  console.log("SUBMIT RESPONSE:", JSON.stringify(submitJson).substring(0, 500));

  if (!submitJson || submitJson.status === "error") {
    // Cleanup temp file on error
    await cleanupTempFile(tempFilePath);
    return { ok: false, error: submitJson?.message || "ModelsLab submission failed" };
  }

  if (
    submitJson.status === "success" &&
    Array.isArray(submitJson.output) &&
    submitJson.output.length > 0
  ) {
    // Cleanup temp file after success
    await cleanupTempFile(tempFilePath);
    return { ok: true, imageUrl: submitJson.output[0] };
  }

  const jobId = submitJson.id;
  if (!jobId) {
    await cleanupTempFile(tempFilePath);
    return { ok: false, error: "ModelsLab job id missing" };
  }

  const eta = submitJson.status === "processing" ? (submitJson.eta || 15) : 10;
  console.log(`Job ${jobId} submitted. ETA: ${eta}s. Polling...`);

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
      console.log(`Poll ${i + 1} status: ${fetchJson.status}`);

      if (fetchJson.status === "processing") continue;

      if (
        fetchJson.status === "success" &&
        Array.isArray(fetchJson.output) &&
        fetchJson.output.length > 0
      ) {
        await cleanupTempFile(tempFilePath);
        return { ok: true, imageUrl: fetchJson.output[0] };
      }

      if (fetchJson.status === "error" || fetchJson.status === "failed") {
        await cleanupTempFile(tempFilePath);
        return { ok: false, error: fetchJson?.message || "Generation failed" };
      }
    } catch (e) {
      console.error("Poll Error:", e.message);
    }
  }

  await cleanupTempFile(tempFilePath);
  return { ok: false, error: "Timed out polling ModelsLab" };
});

/**
 * Helper: Clean up temporary init_image from Storage
 */
async function cleanupTempFile(filePath) {
  if (!filePath) return;
  try {
    const bucket = admin.storage().bucket();
    await bucket.file(filePath).delete();
    console.log(`Cleaned up temp file: ${filePath}`);
  } catch (e) {
    // Ignore cleanup errors — file will expire or be cleaned up later
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
  const data = request.data;
  const apiKey = process.env.MODELSLAB_API_KEY;
  const { id } = data;

  if (!apiKey || !id) {
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
