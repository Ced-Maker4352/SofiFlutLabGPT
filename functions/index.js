const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

const MODELSLAB_BASE = "https://modelslab.com/api/v7/images";

// Helper: sleep for ms
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * =====================================================
 * GENERATE IMAGE (Flux Kontext Pro) — SINGLE-CALL
 * =====================================================
 * Submits to ModelsLab, polls until complete, returns
 * the final image URL. Flutter client expects:
 *   { ok: true, imageUrl: "https://..." }
 */
exports.generateImageFunc = functions
  .runWith({
    secrets: ["MODELSLAB_API_KEY"],
    timeoutSeconds: 300, // 5 min — ModelsLab can be slow
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

    // Hard safety clamp — ModelsLab will error above 1024
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
      throw new functions.https.HttpsError(
        "internal",
        submitJson?.message || "ModelsLab submission failed"
      );
    }

    // If ModelsLab returned the image immediately (rare but possible)
    if (
      submitJson.status === "success" &&
      Array.isArray(submitJson.output) &&
      submitJson.output.length > 0
    ) {
      console.log("Image returned immediately!");
      return { ok: true, imageUrl: submitJson.output[0] };
    }

    // Otherwise we need to poll
    const jobId = submitJson.id;
    if (!jobId) {
      throw new functions.https.HttpsError(
        "internal",
        "ModelsLab job id missing from submit response"
      );
    }

    const eta = submitJson.eta || 15;
    console.log(`Job ${jobId} submitted. ETA: ${eta}s. Starting poll loop...`);

    // ---- STEP 2: Poll until complete ----
    const MAX_POLLS = 40; // 40 * 5s = 200s max polling
    let pollDelay = Math.max(eta * 1000, 5000); // Start with ETA, minimum 5s

    for (let i = 0; i < MAX_POLLS; i++) {
      await sleep(pollDelay);
      // After first poll, use 5s intervals
      pollDelay = 5000;

      console.log(`Polling attempt ${i + 1}/${MAX_POLLS} for job ${jobId}...`);

      try {
        const fetchResponse = await fetch(`${MODELSLAB_BASE}/fetch/${jobId}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ key: apiKey }),
        });

        const fetchJson = await fetchResponse.json();
        console.log(`Poll ${i + 1} status: ${fetchJson.status}`);

        if (fetchJson.status === "processing") {
          continue; // Still working, poll again
        }

        if (
          fetchJson.status === "success" &&
          Array.isArray(fetchJson.output) &&
          fetchJson.output.length > 0
        ) {
          console.log("Generation complete! URL:", fetchJson.output[0]);
          return { ok: true, imageUrl: fetchJson.output[0] };
        }

        if (fetchJson.status === "error" || fetchJson.status === "failed") {
          throw new functions.https.HttpsError(
            "internal",
            fetchJson?.message || "ModelsLab generation failed"
          );
        }
      } catch (pollError) {
        // If it's our own HttpsError, rethrow
        if (pollError instanceof functions.https.HttpsError) throw pollError;
        console.error(`Poll ${i + 1} network error:`, pollError.message);
        // Network error during poll — retry
      }
    }

    // Exhausted all polls
    throw new functions.https.HttpsError(
      "deadline-exceeded",
      `Generation timed out after ${MAX_POLLS} poll attempts for job ${jobId}`
    );
  });

/**
 * =====================================================
 * FETCH IMAGE RESULT (kept for backwards compatibility)
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

    const apiKey = process.env.MODELSLAB_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "internal",
        "MODELSLAB_API_KEY missing"
      );
    }

    const { id } = data;
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
        ok: true,
        status: "success",
        imageUrl: json.output[0],
        image_url: json.output[0], // backwards compat
      };
    }

    throw new functions.https.HttpsError(
      "internal",
      json?.message || "ModelsLab fetch failed"
    );
  });
