const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

setGlobalOptions({ region: "us-central1" });

// ✅ V6 community endpoints — works with standard API key
const V6_IMG2IMG = "https://modelslab.com/api/v6/images/img2img";
const V6_TXT2IMG = "https://modelslab.com/api/v6/images/text2img";
const V6_FETCH = "https://modelslab.com/api/v6/images/fetch";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * =====================================================
 * GENERATE IMAGE  (Flux Kontext Pro) — V6 Community
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
      width = 1024,
      height = 1024,
      strength,
      seed,
      num_inference_steps = 26,
      guidance_scale = 7.5,
    } = data;

    const safeW = Math.min(width, 1024);
    const safeH = Math.min(height, 1024);

    // ── Upload init_image to Storage → signed URL ──────────────────────
    let initImageUrl = null;
    let tempFilePath = null;

    if (initImageBase64 && initImageBase64.length > 0) {
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
      }
    }

    // ── Build request body ─────────────────────────────────────────────
    const body = {
      key: apiKey,
      model_id: "flux-dev",
      prompt: prompt,
      negative_prompt: negative_prompt || "",
      width: safeW,
      height: safeH,
      num_inference_steps: num_inference_steps,
      guidance_scale: guidance_scale,
      samples: 1,
      safety_checker: false,
      seed: seed || null,
    };

    let endpoint;
    if (initImageUrl) {
      body.init_image = initImageUrl;
      body.strength = strength !== undefined ? strength : 0.45;
      endpoint = V6_IMG2IMG;
      console.log("img2img  strength=" + body.strength + " model=" + body.model_id);
    } else {
      endpoint = V6_TXT2IMG;
      console.log("text2img (no init image) model=" + body.model_id);
    }

    console.log("POST →", endpoint);

    // ── Submit ─────────────────────────────────────────────────────────
    let submitJson;
    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      submitJson = await res.json();
      console.log("Submit response status:", submitJson.status, "full:", JSON.stringify(submitJson).substring(0, 500));
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

    const eta = submitJson.eta || 15;
    console.log("Job queued, id=" + jobId + " eta=" + eta + "s");
    let delay = Math.max(eta * 1000, 5000);

    for (let i = 0; i < 60; i++) {
      await sleep(delay);
      delay = 5000;

      try {
        const pr = await fetch(V6_FETCH + "/" + jobId, {
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

/**
 * =====================================================
 * FETCH IMAGE RESULT  (V6)
 * =====================================================
 */
exports.fetchImageFunc = onCall(
  {
    secrets: ["MODELSLAB_API_KEY"],
    region: "us-central1",
  },
  async (request) => {
    const fetch = require("node-fetch");
    const apiKey = process.env.MODELSLAB_API_KEY;
    const { id } = request.data;

    if (!apiKey || id == null) throw new Error("Missing params");

    const r = await fetch(V6_FETCH + "/" + id, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key: apiKey }),
    });
    const j = await r.json();

    if (j.status === "processing") return { status: "processing" };
    if (
      j.status === "success" &&
      Array.isArray(j.output) &&
      j.output.length
    ) {
      return { ok: true, status: "success", imageUrl: j.output[0] };
    }
    return { status: "error", message: j?.message || "Fetch failed" };
  }
);
