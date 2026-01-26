# 🚀 FLUX Integration Quick Start

## 1️⃣ Deploy Cloud Function (5 minutes)

### Copy this to `functions/index.js`:

```javascript
exports.generateHumanFlux = onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    const { prompt, init_image, width = 768, height = 1024 } = req.body;
    if (!prompt || !init_image) {
      return res.status(400).json({ error: 'Missing prompt or init_image' });
    }

    const response = await fetch('https://api.modelslab.com/v1/images/generate', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.MODELSLAB_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model_id: 'bfl/flux-kontext-pro',
        prompt,
        init_image,
        strength: 0.35,              // Face lock
        guidance: 7.5,               // Editorial quality
        num_inference_steps: 28,
        width,
        height,
        safety_checker: false,
      }),
    });

    const data = await response.json();
    if (!data?.output?.[0]) {
      return res.status(500).json({ error: 'Invalid FLUX response' });
    }

    return res.json({ image: data.output[0] });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});
```

### Deploy:
```bash
firebase deploy --only functions:generateHumanFlux
```

---

## 2️⃣ Set API Key

```bash
firebase functions:secrets:set MODELSLAB_API_KEY
# Paste your ModelsLab API key when prompted
```

---

## 3️⃣ Use in Flutter

### Option A: Simple (one-step)
```dart
import 'package:your_app/services/flux_generation_service.dart';

final fluxService = FluxGenerationService();

final imageBytes = await fluxService.generateHumanPortrait(
  selfieBytes: userSelfie,
  prompt: 'professional editorial portrait, studio lighting, sharp focus',
  width: 1024,
  height: 1536,
);
```

### Option B: Direct URL (if you need URL instead of bytes)
```dart
import 'package:your_app/services/models_lab_service.dart';

final imageUrl = await ModelsLabService.generateHumanFlux(
  initImageBytes: userSelfie,
  prompt: 'professional portrait',
  width: 1024,
  height: 1536,
);
```

---

## 🎯 When to Use

| Scenario | Use This |
|----------|----------|
| Doll/Pixar style | `TwoStepGenerationService` (existing) |
| Human photorealism | `FluxGenerationService` ✨ NEW |
| Artistic portraits | `FluxGenerationService` ✨ NEW |

---

## ✅ Checklist

- [ ] Function deployed to Firebase
- [ ] API key set in secrets
- [ ] Function URL matches: `https://us-central1-sofi-saint-app.cloudfunctions.net/generateHumanFlux`
- [ ] Test with curl or Postman
- [ ] Update UI to route human/artistic modes to FLUX

---

## 🐛 Quick Test

```bash
curl -X POST https://us-central1-sofi-saint-app.cloudfunctions.net/generateHumanFlux \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","init_image":"data:image/png;base64,iVBORw0KGgo...","width":512,"height":512}'
```

Expected: `{"image":"https://...jpg"}`

---

**That's it!** See `FLUX_INTEGRATION_GUIDE.md` for full details.
