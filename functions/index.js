const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

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
 */
exports.generateImageFunc = onCall({
  secrets: ["MODELSLAB_API_KEY"],
  timeoutSeconds: 300,
  memory: "512MiB", // Using MiB for V2
  cpu: 1, // Explicitly set for Gen 2
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

  // ---- STEP 1: Submit generation job ----
  const submitResponse = await fetch(`${MODELSLAB_BASE}/text-to-image`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      key: apiKey,
      model_id: "flux-kontext-pro",
      prompt,
      negative_prompt,
      init_image: initImageBase64,
      width: safeWidth,
      height: safeHeight,
      num_inference_steps,
      guidance_scale,
      seed,
    }),
  });

  const submitJson = await submitResponse.json();
  console.log("SUBMIT RESPONSE:", JSON.stringify(submitJson).substring(0, 500));

  if (!submitJson || submitJson.status === "error") {
    return { ok: false, error: submitJson?.message || "ModelsLab submission failed" };
  }

  if (
    submitJson.status === "success" &&
    Array.isArray(submitJson.output) &&
    submitJson.output.length > 0
  ) {
    return { ok: true, imageUrl: submitJson.output[0] };
  }

  const jobId = submitJson.id;
  if (!jobId) {
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
        return { ok: true, imageUrl: fetchJson.output[0] };
      }

      if (fetchJson.status === "error" || fetchJson.status === "failed") {
        return { ok: false, error: fetchJson?.message || "Generation failed" };
      }
    } catch (e) {
      console.error("Poll Error:", e.message);
    }
  }

  return { ok: false, error: "Timed out polling ModelsLab" };
});

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
