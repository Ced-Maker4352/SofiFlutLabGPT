// Master prompt data
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_models.dart';
//
// IMPORTANT:
// – Each section has EXACTLY 12 items (except full outfits = 24)
// – Indexes match your asset file names:
//     hair_01.png → hair[0]
//     hair_02.png → hair[1]
//     ...
// – Full outfits include an optional "thumb" path for future thumbnails.

class SofiPromptData {
  // ================================================================
  // BACKGROUNDS (12)
  // ================================================================
  static const List<String> backgrounds = [
    "background: magical playful pastel bedroom with soft rainbow accents",
    "background: colorful city rooftop with floating balloons and sunset",
    "background: magical reading nook with floating books and fairy lights",
    "background: playful outdoor park with flowers and magical sunshine",
    "background: vibrant toy store interior with modern decor",
    "background: stylish kid's bedroom with glowing neon star wall stickers",
    "background: magical rainbow photography studio with softbox lighting",
    "background: candy cafe with warm tones and colorful decor",
    "background: colorful music studio with glowing LED panels",
    "background: cute pastel classroom with magical sunlight",
    "background: minimalist white photo stage with soft rainbow shadows",
    "background: outdoor urban street with colorful toy shops",
  ];

  // ================================================================
  // HAIR (12)
  // ================================================================
  static const List<String> hair = [
    "textured curly puff with natural volume",
    "long wavy hair with soft layered curls",
    "silky straight hair with center part",
    "high ponytail with light texture",
    "braided buns with natural texture",
    "long box braids with soft shine",
    "afro-textured curls, medium volume",
    "shoulder-length blowout with movement",
    "two-strand twists with gentle sheen",
    "long wavy half-up style",
    "textured bob with natural curls",
    "sleek low ponytail with light texture",
  ];

  // ================================================================
  // TOPS (12)
  // ================================================================
  static const List<String> tops = [
    "cute pastel cropped hoodie",
    "playful ribbed tank top",
    "oversized bright graphic tee",
    "fitted colorful long-sleeve top",
    "cozy soft knit sweater",
    "button-up shirt with fun patterns",
    "sleek crop-top jacket with sparkly details",
    "athleisure zip hoodie with bright colors",
    "minimalist cute halter top",
    "fashion cardigan with soft colorful fabric",
    "denim jacket with cute stitching",
    "soft pastel colorful sweatshirt",
  ];

  // ================================================================
  // BOTTOMS (12)
  // ================================================================
  static const List<String> bottoms = [
    "pleated skirt",
    "high-waisted jeans",
    "wide-leg pants",
    "athleisure leggings",
    "denim shorts",
    "cargo pants",
    "mini skirt",
    "y2k flared jeans",
    "pastel joggers",
    "soft lounge shorts",
    "sporty track pants",
    "high-waisted trousers",
  ];

  // ================================================================
  // SHOES (12)
  // ================================================================
  static const List<String> shoes = [
    "chunky colorful sneakers",
    "platform sandals with sparkly straps",
    "y2k colorful pastel sneakers",
    "clean white sparkly shoes",
    "cute ankle boots",
    "sporty runners with bright colors",
    "girly platform boots with hearts",
    "pastel flats with cute bows",
    "minimal colorful slides",
    "lace-up sneakers with colorful laces",
    "casual slip-ons with fun prints",
    "retro chunky colorful shoes",
  ];

  // ================================================================
  // ACCESSORIES (12)
  // ================================================================
  static const List<String> accessories = [
    "sparkly star-shaped purse",
    "cute small clutch purse",
    "round colorful crossbody bag",
    "magical ribbon hair bow",
    "glowing neon bracelet",
    "candy-colored pastel scarf",
    "colorful digital wristwatch",
    "fun gamer headset",
    "sparkly sunglasses case",
    "colorful mini backpack",
    "magical pastel shoulder bag",
    "cute sparkly charm keychain",
  ];

  // ================================================================
  // HATS (12)
  // ================================================================
  static const List<String> hats = [
    "soft pastel beanie",
    "bucket hat with modern texture",
    "stylish beret",
    "y2k fuzzy hat",
    "denim cap",
    "sporty visor",
    "wide-brim fashion hat",
    "clean minimalist baseball cap",
    "winter knit cap",
    "trend bucket hat",
    "sun visor pastel",
    "cozy sherpa hat",
  ];

  // ================================================================
  // GLASSES (12)
  // ================================================================
  static const List<String> glasses = [
    "round pastel glasses",
    "thin frame fashion glasses",
    "y2k tinted sunglasses",
    "heart-shaped glasses",
    "clear lens square frames",
    "sleek black frames",
    "oversized fashion sunglasses",
    "retro circle frames",
    "cat-eye glasses",
    "minimalist wire-frame glasses",
    "sport sunglasses",
    "pastel rimmed glasses",
  ];

  // ================================================================
  // JEWELRY (12)
  // ================================================================
  static const List<String> jewelry = [
    "gold hoop earrings",
    "dainty layered necklace",
    "silver stud earrings",
    "charm bracelet pastel",
    "fashion choker",
    "heart pendant necklace",
    "gold bangles",
    "pearl earrings",
    "silver chain necklace",
    "layered bracelets",
    "pastel charm necklace",
    "gemstone earrings",
  ];

  // ================================================================
  // POSES (12)
  // ================================================================
  static const List<String> poses = [
    "standing confidently with hands on hips",
    "casual relaxed pose with one hand in pocket",
    "dynamic walking pose mid-stride",
    "playful peace sign with bright smile",
    "leaning casually against invisible wall",
    "energetic jumping pose with joy",
    "sitting cross-legged with relaxed posture",
    "thoughtful pose with hand near chin",
    "fashion model pose with hand on hip",
    "friendly wave with warm expression",
    "cool arms-crossed confident stance",
    "candid laughing moment captured naturally",
  ];

  // ================================================================
  // FULL OUTFITS (24 — modern clothing-only edits)
  // ================================================================
  static const List<Map<String, dynamic>> fullOutfits = [
    {
      "label": "Pastel Y2K Set",
      "prompt":
          "[FACE LOCK] clothing-only edit: pastel Y2K outfit with crop top, pleated skirt, platform sneakers, and small pastel accessories. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features. Face must be pixel-identical to source.",
      "thumb": "images/full outfit/full_outfit_01.jpg",
    },
    {
      "label": "Street Minimal",
      "prompt":
          "clothing-only edit: minimalist streetwear outfit with oversized tee, high-waisted cargo pants, and clean sneakers. No changes to face, skin, hair, or body.",
      "thumb": "images/full outfit/full_outfit_02.jpg",
    },
    {
      "label": "Clean Girl Neutral Set",
      "prompt":
          "[FACE LOCK] clothing-only edit: soft neutral-toned 'clean girl' look with tank top, lightweight cardigan, high-waisted trousers, and white sneakers. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_03.jpg",
    },
    {
      "label": "TikTok Influencer Fit",
      "prompt":
          "clothing-only edit: trendy influencer outfit with crop top, denim jacket, wide-leg jeans, and stylish sneakers. Keep face, skin, hair unchanged.",
      "thumb": "images/full outfit/full_outfit_04.jpg",
    },
    {
      "label": "Soft Lounge Day",
      "prompt":
          "clothing-only edit: cozy loungewear set with pastel sweatshirt and soft joggers. Shoes stay minimal. Do not alter doll's hair, skin tone, or body.",
      "thumb": "images/full outfit/full_outfit_05.jpg",
    },
    {
      "label": "Academia Aesthetic",
      "prompt":
          "clothing-only edit: dark academia outfit with cardigan, pleated skirt, tights, and loafers. No changes to face or body.",
      "thumb": "images/full outfit/full_outfit_06.jpg",
    },
    {
      "label": "Techwear Light",
      "prompt":
          "clothing-only edit: modern techwear outfit with layered jacket, tapered pants, and sleek boots. Keep skin, face, and hair untouched.",
      "thumb": "images/full outfit/full_outfit_07.jpg",
    },
    {
      "label": "Casual Denim Day",
      "prompt":
          "clothing-only edit: fitted tee, denim jacket, high-waisted jeans, and white sneakers. Do not modify face or body.",
      "thumb": "images/full outfit/full_outfit_08.jpg",
    },
    {
      "label": "Modern Athleisure",
      "prompt":
          "clothing-only edit: athleisure set including fitted leggings, zip hoodie, and running shoes. Do not alter doll’s body or face.",
      "thumb": "images/full outfit/full_outfit_09.jpg",
    },
    {
      "label": "Kawaii Pastel",
      "prompt":
          "clothing-only edit: cute pastel mini skirt outfit with soft sweater and girly shoes. Keep all doll features identical.",
      "thumb": "images/full outfit/full_outfit_10.jpg",
    },
    {
      "label": "Urban Chic",
      "prompt":
          "clothing-only edit: trendy city outfit featuring fashion jeans, crop jacket, and stylish sneakers. Face and hair remain unchanged.",
      "thumb": "images/full outfit/full_outfit_11.jpg",
    },
    {
      "label": "Summer Casual",
      "prompt":
          "clothing-only edit: cropped tank top, denim shorts, and sandals. Do not alter any body or facial details.",
      "thumb": "images/full outfit/full_outfit_12.jpg",
    },

    // ---- 12 MORE FOR FULL 24 OUTFIT PACK ---- //

    {
      "label": "Cozy Winter Fit",
      "prompt":
          "[FACE LOCK] clothing-only edit: winter coat, knit sweater, warm leggings, and boots. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_13.jpg",
    },
    {
      "label": "Fashion Sweatsuit",
      "prompt":
          "[FACE LOCK] clothing-only edit: trendy matching sweatsuit with modern sneakers. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_14.jpg",
    },
    {
      "label": "Denim Overalls Look",
      "prompt":
          "[FACE LOCK] clothing-only edit: pastel tee with denim overalls and sneakers. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_15.jpg",
    },
    {
      "label": "Neutral Tones Outfit",
      "prompt":
          "[FACE LOCK] clothing-only edit: neutral-toned crop top, trousers, and clean sneakers. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_16.jpg",
    },
    {
      "label": "Music Studio Outfit",
      "prompt":
          "[FACE LOCK] clothing-only edit: stylish top, cargo pants, and chunky sneakers with edgy accessories. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_17.jpg",
    },
    {
      "label": "Cafe Day Fit",
      "prompt":
          "[FACE LOCK] clothing-only edit: soft sweater, skirt, and flats perfect for a cafe day. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_18.jpg",
    },
    {
      "label": "Summer Festival Look",
      "prompt":
          "[FACE LOCK] clothing-only edit: crop top, high-waisted shorts, and festival boots. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_19.jpg",
    },
    {
      "label": "Sporty Chic",
      "prompt":
          "[FACE LOCK] clothing-only edit: athletic top, joggers, and clean white sneakers. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_20.jpg",
    },
    {
      "label": "Modern Boho",
      "prompt":
          "[FACE LOCK] clothing-only edit: boho-style top, layered skirt, and sandals. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_21.jpg",
    },
    {
      "label": "Glow-Up Streetwear",
      "prompt":
          "[FACE LOCK] clothing-only edit: modern streetwear with oversized hoodie, cargo pants, and chunky shoes. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_22.jpg",
    },
    {
      "label": "Soft Girl Aesthetic",
      "prompt":
          "[FACE LOCK] clothing-only edit: pastel sweater, mini skirt, and cute platform shoes. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_23.jpg",
    },
    {
      "label": "Classy Casual",
      "prompt":
          "[FACE LOCK] clothing-only edit: fitted top, high-waisted trousers, and modern shoes. CRITICAL: Preserve face EXACTLY - do not modify eyes, nose, lips, skin tone, or any facial features.",
      "thumb": "images/full outfit/full_outfit_24.jpg",
    },
  ];

  /// Check if a specific item in a category is premium-only
  static bool isPremiumItem(EditCategory category, int index) {
    // For now, items 7-12 (index 6-11) are premium for all categories
    // except full outfits which have their own logic
    if (category == EditCategory.fullOutfit) {
      // Outfits 13-24 (index 12-23) are premium
      return index >= 12;
    }
    
    // For others, second half is premium
    return index >= 6;
  }
}
