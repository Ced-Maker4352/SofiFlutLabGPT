import 'sofi_studio_models.dart';

class SofiStylePresets {
  /// Each preset defines:
  /// - label
  /// - icon emoji
  /// - a map tying EditCategory → option index
  /// - an auto-generated prompt (string)

  static final presets = <Map<String, dynamic>>[
    {
      // Align label with Full Outfits for consistent mapping across app
      "label": "Clean Girl Neutral Set",
      "key": "clean_girl",
      "fullOutfitLabel": "Clean Girl Neutral Set",
      "icon": "✨",
      "options": {
        EditCategory.hair: 2,       // silky straight
        EditCategory.top: 1,        // ribbed tank top
        EditCategory.bottom: 11,    // high-waisted trousers
        EditCategory.shoes: 1,      // clean sneakers
        EditCategory.accessories: 7,// digital wristwatch
      },
      "prompt":
          "clean girl aesthetic with soft neutrals, minimal jewelry, sleek hair, and polished modern outfit. Do not alter face, skin tone, or body."
    },

    {
      "label": "Pastel Y2K Set",
      "key": "y2k",
      "fullOutfitLabel": "Pastel Y2K Set",
      "icon": "🩵",
      "options": {
        EditCategory.hair: 9,       // wavy half-up
        EditCategory.top: 12,       // pastel sweatshirt
        EditCategory.bottom: 1,     // pleated skirt
        EditCategory.shoes: 3,      // Y2K pastel sneakers
        EditCategory.accessories: 4 // ribbon bow
      },
      "prompt":
          "y2k inspired pastel outfit with mini skirt, soft colors, and girly aesthetic. Clothing-only edit. Do not change facial features or body."
    },

    {
      "label": "Street Minimal",
      "key": "street_minimal",
      "fullOutfitLabel": "Street Minimal",
      "icon": "🖤",
      "options": {
        EditCategory.hair: 3,       // straight hair
        EditCategory.top: 3,        // oversized graphic tee
        EditCategory.bottom: 6,     // cargo pants
        EditCategory.shoes: 4,      // clean white shoes
        EditCategory.accessories: 1 // star purse
      },
      "prompt":
          "minimalist streetwear look with oversized tee, cargo pants, and clean sneakers. Clothing-only edit."
    },

    {
      "label": "Soft Girl Aesthetic",
      "key": "soft_girl",
      "fullOutfitLabel": "Soft Girl Aesthetic",
      "icon": "🌸",
      "options": {
        EditCategory.hair: 10,      // long wavy half-up
        EditCategory.top: 10,       // fashion cardigan
        EditCategory.bottom: 7,     // mini skirt
        EditCategory.shoes: 8,      // pastel flats
        EditCategory.accessories: 12 // charm necklace
      },
      "prompt":
          "soft pastel girl aesthetic with cute mini skirt, cardigan, and gentle colors. Clothing-only edit."
    },

    {
      "label": "Academia Aesthetic",
      "key": "academia",
      "fullOutfitLabel": "Academia Aesthetic",
      "icon": "📚",
      "options": {
        EditCategory.hair: 8,
        EditCategory.top: 5,        // knit sweater
        EditCategory.bottom: 1,     // pleated skirt
        EditCategory.shoes: 5,      // ankle boots
        EditCategory.accessories: 3 // crossbody bag
      },
      "prompt":
          "dark/light academia aesthetic with skirt, cardigan or sweater, and vintage-inspired accessories. Clothing-only edit."
    },
  ];
}
