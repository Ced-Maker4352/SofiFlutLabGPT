# 🎯 FLUX Kontext Pro Integration Guide

## Overview
This guide walks you through adding a new Firebase Cloud Function for FLUX Kontext Pro human photorealism generation, completely separate from your existing Pixar pipeline.

---

## ✅ Step 1: Create the Cloud Function (Firebase Console)

### 📍 Location
Your Firebase project: `sofi-saint-app`  
Region: `us-central1`

### 📝 Function Code

Create a new function file in your Firebase Functions project (e.g., `functions/index.js` or a separate file):

```javascript
const { onRequest } = require('firebase-functions/v2/https');

/**
 * FLUX Kontext Pro Generation for Human Photorealism
 * 
 * Uses FLUX Kontext Pro model via ModelsLab API for:
 * - Editorial-grade human portraits
 * - Strong facial identity retention  
 * - Professional photo quality
 * - Zero impact on existing Pixar/doll pipeline
 */
exports.generateHumanFlux = onRequest(async (req, res) => {
  // Enable CORS for all origins
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  try {
    const {
      prompt,
      init_image,
      width = 768,
      height = 1024,
    } = req.body;

    // Validate required fields
    if (!prompt || !init_image) {
      return res.status(400).json({ 
        error: 'Missing required fields: prompt and init_image' 
      });
    }

    console.log('[FLUX] Starting generation with FLUX Kontext Pro');
    console.log('[FLUX] Prompt:', prompt.substring(0, 100) + '...');
    console.log('[FLUX] Resolution:', width, 'x', height);

    // Call ModelsLab API with FLUX Kontext Pro model
    const response = await fetch(
      'https://api.modelslab.com/v1/images/generate',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.MODELSLAB_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model_id: 'bfl/flux-kontext-pro',
          prompt,
          init_image,
          strength: 0.35,              // 🔒 Strong identity preservation
          guidance: 7.5,               // Editorial realism guidance
          num_inference_steps: 28,     // Quality inference steps
          width,
          height,
          safety_checker: false,       // Disable for artistic freedom
        }),
      }
    );

    const data = await response.json();

    // Validate ModelsLab response
    if (!data || !data.output || !data.output[0]) {
      console.error('[FLUX] Invalid ModelsLab response:', data);
      return res.status(500).json({ 
        error: 'Invalid response from FLUX API',
        details: data 
      });
    }

    console.log('[FLUX] Generation successful');

    // Return the generated image URL
    return res.json({
      image: data.output[0],
      meta: {
        model: 'bfl/flux-kontext-pro',
        width,
        height,
        strength: 0.35,
      }
    });

  } catch (err) {
    console.error('[FLUX ERROR]', err);
    return res.status(500).json({ 
      error: err.message,
      stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
  }
});
```

---

## 🔑 Step 2: Set Environment Variable

Your function needs access to the ModelsLab API key:

### Option A: Firebase Console (Recommended)
1. Go to Firebase Console → Functions → Configuration
2. Add secret: `MODELSLAB_API_KEY` with your ModelsLab API key
3. The function will automatically access it via `process.env.MODELSLAB_API_KEY`

### Option B: Firebase CLI
```bash
firebase functions:secrets:set MODELSLAB_API_KEY
```

---

## 🚀 Step 3: Deploy the Function

### Using Firebase CLI:
```bash
cd functions
firebase deploy --only functions:generateHumanFlux
```

### Expected Output:
```
✔  functions[us-central1-generateHumanFlux]: Successful create operation.
Function URL: https://us-central1-sofi-saint-app.cloudfunctions.net/generateHumanFlux
```

---

## ✅ Step 4: Flutter Integration (Already Done!)

The Flutter service has been updated with a new method:

### `ModelsLabService.generateHumanFlux()`

**Location:** `lib/services/models_lab_service.dart`

**Usage Example:**
```dart
final imageUrl = await ModelsLabService.generateHumanFlux(
  initImageBytes: selfieBytes,
  prompt: 'professional portrait of a woman in business attire, '
           'editorial photography, studio lighting, sharp focus',
  width: 1024,
  height: 1536,
);

// Download the image
final response = await http.get(Uri.parse(imageUrl));
final Uint8List imageBytes = response.bodyBytes;
```

---

## 🎨 Step 5: Integration Patterns

### For Human/Artistic Modes:

Instead of using `TwoStepGenerationService`, use the new FLUX endpoint:

```dart
// OLD (Pixar/Doll modes - keep using this)
final step1 = await twoStepService.runStep1IdentityLock(
  baseImage: selfieBytes,
  prompt: pixarPrompt,
);

// NEW (Human/Artistic modes - use FLUX)
final imageUrl = await ModelsLabService.generateHumanFlux(
  initImageBytes: selfieBytes,
  prompt: humanPrompt,
  width: 1024,
  height: 1536,
);

// Download the bytes
final response = await http.get(Uri.parse(imageUrl));
final Uint8List fluxBytes = response.bodyBytes;
```

### When to Use Which Pipeline:

| Mode | Pipeline | Model | Purpose |
|------|----------|-------|---------|
| **Doll** | TwoStepGenerationService | seededit-i2i | Pixar/cartoon style |
| **Cinematic** | TwoStepGenerationService | seededit-i2i | Pixar style with cinematic flair |
| **Fantasy** | TwoStepGenerationService | seededit-i2i | Magical Pixar style |
| **Human** | ModelsLabService.generateHumanFlux | flux-kontext-pro | Editorial photorealism |
| **Artistic** | ModelsLabService.generateHumanFlux | flux-kontext-pro | Artistic human portraits |

---

## 🔍 Testing

### Test the function directly:
```bash
curl -X POST https://us-central1-sofi-saint-app.cloudfunctions.net/generateHumanFlux \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "professional portrait, studio lighting",
    "init_image": "data:image/png;base64,iVBORw0KGgo...",
    "width": 768,
    "height": 1024
  }'
```

### Expected Response:
```json
{
  "image": "https://pub-xxxx.r2.dev/xxxx.jpg",
  "meta": {
    "model": "bfl/flux-kontext-pro",
    "width": 768,
    "height": 1024,
    "strength": 0.35
  }
}
```

---

## 🎯 Key Benefits

✅ **Zero Impact on Existing Pipeline**: Pixar/doll generations use the old pipeline  
✅ **Editorial Quality**: FLUX Kontext Pro delivers magazine-quality human portraits  
✅ **Face Preservation**: Strength 0.35 locks facial identity  
✅ **Same ModelsLab Account**: Uses your existing API key  
✅ **High Resolution**: Supports up to 1024x1536 for crisp output  

---

## 📊 Cost Comparison

| Pipeline | Model | Cost per Image | Use Case |
|----------|-------|----------------|----------|
| Old (seededit-i2i) | SeedEdit | ~$0.01 | Pixar/cartoon |
| New (FLUX) | FLUX Kontext Pro | ~$0.03 | Human photorealism |

---

## 🐛 Troubleshooting

### Error: "Missing MODELSLAB_API_KEY"
→ Set the secret in Firebase Console (Step 2)

### Error: "Invalid response from FLUX API"  
→ Check ModelsLab API key is valid and has credits

### Error: "CORS blocked"
→ Ensure CORS headers are in the function (already added in code above)

### Low quality images
→ Increase width/height to 1024x1536 in Flutter calls

---

## 📝 Next Steps

1. ✅ **Deploy the function** (follow Step 3)
2. ✅ **Set the API key** (follow Step 2)
3. ✅ **Test the endpoint** (use curl or Postman)
4. 🎨 **Update UI logic** to route human/artistic modes to FLUX
5. 🧪 **Test in app** with both doll and human modes

---

## 🎨 Recommended Prompts for FLUX

### Human Mode:
```
professional portrait, editorial photography, studio lighting, 
sharp focus, detailed skin texture, natural expression, 
high resolution, photorealistic
```

### Artistic Mode:
```
artistic portrait, fine art photography, dramatic lighting,
expressive mood, painterly quality, creative composition,
high detail, professional photography
```

---

**Questions?** Check the Flutter service implementation in:  
📁 `lib/services/models_lab_service.dart` (lines 135-184)
