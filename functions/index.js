const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

const MODELSLAB_BASE = "https://modelslab.com/api/v7/images";

/**
 * =====================================================
 * GENERATE IMAGE (Flux Kontext Pro)
 * =====================================================
 */
exports.generateImageFunc = functions
  .runWith({
    secrets: ["MODELSLAB_API_KEY"], // REQUIRED for Gen-1
    timeoutSeconds: 60,
    memory: "256MB",
  })
  .https.onCall(async (data) => {
    console.log("generateImageFunc ENTERED");
    console.log(
      "MODELSLAB_API_KEY present:",
      !!process.env.MODELSLAB_API_KEY
    );

    const apiKey = process.env.MODELSLAB_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "internal",
        "MODELSLAB_API_KEY missing"
      );
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

    // 🔒 Hard safety clamp — ModelsLab will error above 1024
    const safeWidth = Math.min(width, 1024);
    const safeHeight = Math.min(height, 1024);

    const response = await fetch(`${MODELSLAB_BASE}/text-to-image`, {
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

    const json = await response.json();
    console.log("SUBMIT RESPONSE:", json);

    if (!json || json.status === "error") {
      throw new functions.https.HttpsError(
        "internal",
        json?.message || "ModelsLab submission failed"
      );
    }

    if (!json.id) {
      throw new functions.https.HttpsError(
        "internal",
        "ModelsLab job id missing"
      );
    }

    return {
      status: "processing",
      id: json.id,  // Changed from job_id to match Flutter code
      eta: json.eta ?? 10,
    };
  });

/**
 * =====================================================
 * FETCH IMAGE RESULT
 * =====================================================
 */
exports.fetchImageFunc = functions
  .runWith({
    secrets: ["MODELSLAB_API_KEY"],
    timeoutSeconds: 60,
    memory: "256MB",
  })
  .https.onCall(async (data) => {
    console.log("fetchImageFunc ENTERED");
    console.log(
      "MODELSLAB_API_KEY present:",
      !!process.env.MODELSLAB_API_KEY
    );

    const apiKey = process.env.MODELSLAB_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "internal",
        "MODELSLAB_API_KEY missing"
      );
    }

    const { id } = data;  // Changed from job_id to match Flutter code
    if (!id) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "id required"
      );
    }

    const response = await fetch(`${MODELSLAB_BASE}/fetch/${id}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key: apiKey }),
    });

    const json = await response.json();
    console.log("FETCH RESPONSE:", json);

    if (json.status === "processing") {
      return { status: "processing" };
    }

    if (
      json.status === "success" &&
      Array.isArray(json.output) &&
      json.output.length
    ) {
      return {
        status: "success",
        image_url: json.output[0],
      };
    }

    throw new functions.https.HttpsError(
      "internal",
      json?.message || "ModelsLab fetch failed"
    );
  });
