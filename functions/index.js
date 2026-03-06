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
 * Instruction-following model. Understands "change outfit,
 * keep face" semantics natively.
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

    // Parse optional params with sane defaults
    const aspect_ratio =
      typeof data.aspect_ratio === "string" && data.aspect_ratio.trim()
        ? data.aspect_ratio.trim()
        : typeof data.aspectRatio === "string" && data.aspectRatio.trim()
          ? data.aspectRatio.trim()
          : "9:16";

    const steps =
      Number.isFinite(Number(data.steps))
        ? Math.max(1, Math.min(50, Math.floor(Number(data.steps))))
        : 28;

    const guidance_scale =
      Number.isFinite(Number(data.guidance_scale))
        ? Math.max(1, Math.min(20, Number(data.guidance_scale)))
        : 7;

    if (!prompt) return { ok: false, error: "Missing prompt" };
    if (!initImageBase64) return { ok: false, error: "Missing initImageBase64" };

    // ── Upload init_image to Storage → signed URL ──────────────────────
    let initImageUrl = null;
    let tempFilePath = null;

    try {
      // Strip data:image/xxx;base64, prefix if present
      let rawB64 = initImageBase64;
      if (rawB64.includes(",")) rawB64 = rawB64.split(",")[1];

      const buf = Buffer.from(rawB64, "base64");
      if (buf.length < 16) throw new Error("Image too small");

      const hash = crypto.createHash("md5").update(buf).digest("hex").slice(0, 12);
      tempFilePath = `tmp/init_${hash}_${Date.now()}.png`;

      const bucket = admin.storage().bucket();
      const file = bucket.file(tempFilePath);
      await file.save(buf, {
        resumable: false,
        metadata: { contentType: "image/png" },
      });

      const [url] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 1000 * 60 * 30, // 30 min
      });
      initImageUrl = url;
      console.log("Uploaded init image → signed URL ready");
    } catch (e) {
      console.error("Init upload failed:", e.message);
      return { ok: false, error: "Image upload failed: " + e.message };
    }

    // ── Build request body for flux-kontext-pro ────────────────────────
    const body = {
      key: apiKey,
      model_id: MODEL_ID,
      init_image: initImageUrl,
      prompt: prompt,
      negative_prompt: negative_prompt || "deformed face, bad anatomy, blurry, worst quality",
      aspect_ratio: aspect_ratio,
      steps: steps,
      guidance_scale: guidance_scale,
      samples: 1,
      safety_checker: false,
      ...(seed ? { seed } : {}),
    };

    console.log("POST →", V7_IMG2IMG, "model=", MODEL_ID, "aspect_ratio=", aspect_ratio, "steps=", steps, "guidance=", guidance_scale);

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
    const jobId = submitJson.id || submitJson.job_id;
    if (!jobId) {
      console.error("No job id:", JSON.stringify(submitJson));
      await cleanup(tempFilePath);
      return { ok: false, error: "No job ID returned" };
    }

    const eta = submitJson.eta || 20;
    console.log("Job queued, id=" + jobId + " eta=" + eta + "s");

    // Poll with 150s deadline, 2.5s interval (matches working reference)
    const deadlineMs = Date.now() + 150000;
    let pollCount = 0;

    while (Date.now() < deadlineMs) {
      // First wait uses ETA, then 2.5s intervals
      if (pollCount === 0) {
        await sleep(Math.max(eta * 1000, 3000));
      } else {
        await sleep(2500);
      }

      try {
        const pr = await fetch(V7_FETCH + "/" + jobId, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ key: apiKey }),
        });
        const pj = await pr.json();

        if (pj.status === "processing") {
          if (pollCount % 5 === 0) console.log("Still processing... poll #" + pollCount);
          pollCount++;
          continue;
        }

        // Check multiple output locations (ModelsLab varies between endpoints)
        const outputUrl = extractOutputUrl(pj);
        if (pj.status === "success" && outputUrl) {
          console.log("Generation complete! URL: " + outputUrl.substring(0, 80));
          await cleanup(tempFilePath);
          return { ok: true, imageUrl: outputUrl };
        }

        if (pj.status === "error" || pj.status === "failed") {
          console.error("Poll error:", JSON.stringify(pj));
          await cleanup(tempFilePath);
          return { ok: false, error: pj?.message || "Generation failed" };
        }

        pollCount++;
      } catch (e) {
        console.error("Poll exception:", e.message);
        pollCount++;
      }
    }

    await cleanup(tempFilePath);
    return { ok: false, error: "Timed out after 150s" };
  }
);

/** Extract output URL from various ModelsLab response shapes */
function extractOutputUrl(json) {
  const candidates = [
    json?.output,
    json?.images,
    json?.image,
    json?.data?.output,
    json?.data?.images,
    json?.data?.image,
  ];
  for (const c of candidates) {
    if (!c) continue;
    if (Array.isArray(c) && c.length && typeof c[0] === "string") return c[0];
    if (typeof c === "string") return c;
  }
  return null;
}

/** Temp-file cleanup helper */
async function cleanup(path) {
  if (!path) return;
  try {
    await admin.storage().bucket().file(path).delete();
  } catch (_) { }
}
