const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

setGlobalOptions({ region: "us-central1" });

// ✅ V7 API — flux-kontext-pro (instruction-following image editing)
const V7_IMG2IMG = "https://modelslab.com/api/v7/images/image-to-image";
const V7_FETCH = "https://modelslab.com/api/v7/images/fetch";
const MODEL_ID = "flux-kontext-pro";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * =====================================================
 * GENERATE IMAGE — flux-kontext-pro (V7)
 * 
 * Instruction-following model: understands "change outfit,
 * keep face" semantics natively. Does NOT use strength.
 * =====================================================
 */
exports.generateImageFunc = onCall(
  {
    secrets: ["MODELSLAB_API_KEY"],
    timeoutSeconds: 300,
    memory: "512MiB",
    cpu: 1,
  },
  async (request) => {
    const fetch = require("node-fetch");
    const crypto = require("crypto");

    const data = request.data;
    const apiKey = process.env.MODELSLAB_API_KEY;
    if (!apiKey) throw new Error("MODELSLAB_API_KEY missing");

    const {
      prompt,
      negative_prompt,
      initImageBase64,
      seed,
    } = data;

    if (!prompt) return { ok: false, error: "Missing prompt" };
    if (!initImageBase64) return { ok: false, error: "Missing initImageBase64" };

    // ── Upload init_image to Storage → signed URL ──────────────────────
    let initImageUrl = null;
    let tempFilePath = null;

    try {
      let raw = initImageBase64;
      if (raw.includes(",")) raw = raw.split(",")[1];

      const buf = Buffer.from(raw, "base64");
      const bucket = admin.storage().bucket();
      const name = "tmp/init_images/" + crypto.randomUUID() + ".png";
      tempFilePath = name;
      const file = bucket.file(name);

      await file.save(buf, { metadata: { contentType: "image/png" } });

      const [url] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 60 * 60 * 1000,
      });
      initImageUrl = url;
      console.log("Uploaded init image → signed URL ready");
    } catch (e) {
      console.error("Init-image upload failed:", e.message);
      return { ok: false, error: "Image upload failed: " + e.message };
    }

    // ── Build request body for flux-kontext-pro ────────────────────────
    // Note: kontext-pro does NOT take strength, steps, or guidance_scale
    // It understands the prompt as an edit instruction.
    const body = {
      key: apiKey,
      model_id: MODEL_ID,
      init_image: initImageUrl,
      prompt: prompt,
      negative_prompt: negative_prompt || "deformed face, bad anatomy, blurry, worst quality",
      samples: 1,
      safety_checker: false,
      ...(seed ? { seed } : {}),
    };

    console.log("POST →", V7_IMG2IMG, "model=", MODEL_ID);

    // ── Submit ─────────────────────────────────────────────────────────
    let submitJson;
    try {
      const res = await fetch(V7_IMG2IMG, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      submitJson = await res.json();
      console.log("Submit response:", submitJson.status, JSON.stringify(submitJson).substring(0, 400));
    } catch (fetchErr) {
      console.error("Fetch exception:", fetchErr.message);
      await cleanup(tempFilePath);
      return { ok: false, error: "Network error: " + fetchErr.message };
    }

    // Immediate success
    if (
      submitJson.status === "success" &&
      Array.isArray(submitJson.output) &&
      submitJson.output.length > 0
    ) {
      await cleanup(tempFilePath);
      return { ok: true, imageUrl: submitJson.output[0] };
    }

    // Error
    if (!submitJson || submitJson.status === "error") {
      console.error("Submit error:", JSON.stringify(submitJson));
      await cleanup(tempFilePath);
      return { ok: false, error: submitJson?.message || "Submit failed" };
    }

    // Processing → poll
    const jobId = submitJson.id;
    if (!jobId) {
      console.error("No job id:", JSON.stringify(submitJson));
      await cleanup(tempFilePath);
      return { ok: false, error: "No job ID returned" };
    }

    const eta = submitJson.eta || 20;
    console.log("Job queued, id=" + jobId + " eta=" + eta + "s");
    let delay = Math.max(eta * 1000, 5000);

    for (let i = 0; i < 60; i++) {
      await sleep(delay);
      delay = 5000;

      try {
        const pr = await fetch(V7_FETCH + "/" + jobId, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ key: apiKey }),
        });
        const pj = await pr.json();

        if (pj.status === "processing") {
          if (i % 5 === 0) console.log("Still processing... poll #" + i);
          continue;
        }

        if (
          pj.status === "success" &&
          Array.isArray(pj.output) &&
          pj.output.length > 0
        ) {
          console.log("Generation complete! URL: " + pj.output[0].substring(0, 80));
          await cleanup(tempFilePath);
          return { ok: true, imageUrl: pj.output[0] };
        }

        if (pj.status === "error" || pj.status === "failed") {
          console.error("Poll error:", JSON.stringify(pj));
          await cleanup(tempFilePath);
          return { ok: false, error: pj?.message || "Generation failed" };
        }
      } catch (e) {
        console.error("Poll exception:", e.message);
      }
    }

    await cleanup(tempFilePath);
    return { ok: false, error: "Timed out" };
  }
);

/** Temp-file cleanup helper */
async function cleanup(path) {
  if (!path) return;
  try {
    await admin.storage().bucket().file(path).delete();
  } catch (_) { }
}
