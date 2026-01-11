// Master prompt data
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
    "background: modern pastel bedroom with soft neon accents",
    "background: trendy city rooftop lounge at sunset",
    "background: cozy reading nook with plush pillows and soft lighting",
    "background: pastel outdoor park with flowers and warm daylight",
    "background: vibrant mall interior with modern decor",
    "background: stylish teen bedroom with LED wall strips",
    "background: clean photography studio with softbox lighting",
    "background: modern cafe with warm tones and trendy decor",
    "background: colorful music studio with LED panels",
    "background: cute pastel classroom with soft sunlight",
    "background: minimalist white photo stage with soft shadows",
    "background: outdoor urban street with colorful shops",
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
    "pastel cropped hoodie",
    "ribbed tank top",
    "oversized graphic tee",
    "fitted long-sleeve top",
    "cozy knit sweater",
    "button-up shirt with soft folds",
    "sleek crop-top jacket",
    "athleisure zip hoodie",
    "minimalist halter top",
    "fashion cardigan with soft fabric",
    "denim jacket with clean stitching",
    "soft pastel sweatshirt",
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
    "chunky sneakers",
    "platform sandals",
    "y2k pastel sneakers",
    "clean white shoes",
    "ankle boots",
    "sporty runners",
    "girly platform boots",
    "pastel flats",
    "minimal slides",
    "lace-up sneakers",
    "casual slip-ons",
    "retro chunky shoes",
  ];

  // ================================================================
  // ACCESSORIES (12)
  // ================================================================
  static const List<String> accessories = [
    "star-shaped purse",
    "small clutch purse",
    "round crossbody bag",
    "ribbon hair bow",
    "neon bracelet",
    "pastel scarf",
    "digital wristwatch",
    "gamer headset",
    "sunglasses case",
    "mini backpack",
    "pastel shoulder bag",
    "cute charm keychain",
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
          "clothing-only edit: pastel Y2K outfit with crop top, pleated skirt, platform sneakers, and small pastel accessories. Do not alter the doll’s face, skin tone, hair, or body.",
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
          "clothing-only edit: soft neutral-toned 'clean girl' look with tank top, lightweight cardigan, high-waisted trousers, and white sneakers. Do not modify facial features or body.",
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
          "clothing-only edit: winter coat, knit sweater, warm leggings, and boots. Do not change the doll’s face or body.",
      "thumb": "images/full outfit/full_outfit_13.jpg",
    },
    {
      "label": "Fashion Sweatsuit",
      "prompt":
          "clothing-only edit: trendy matching sweatsuit with modern sneakers. Leave hair and face untouched.",
      "thumb": "images/full outfit/full_outfit_14.jpg",
    },
    {
      "label": "Denim Overalls Look",
      "prompt":
          "clothing-only edit: pastel tee with denim overalls and sneakers. No changes to doll’s face, skin, or hair.",
      "thumb": "images/full outfit/full_outfit_15.jpg",
    },
    {
      "label": "Neutral Tones Outfit",
      "prompt":
          "clothing-only edit: neutral-toned crop top, trousers, and clean sneakers. Do not modify body or facial features.",
      "thumb": "images/full outfit/full_outfit_16.jpg",
    },
    {
      "label": "Music Studio Outfit",
      "prompt":
          "clothing-only edit: stylish top, cargo pants, and chunky sneakers with edgy accessories. Keep face and hair unchanged.",
      "thumb": "images/full outfit/full_outfit_17.jpg",
    },
    {
      "label": "Cafe Day Fit",
      "prompt":
          "clothing-only edit: soft sweater, skirt, and flats perfect for a cafe day. Leave all doll features unchanged.",
      "thumb": "images/full outfit/full_outfit_18.jpg",
    },
    {
      "label": "Summer Festival Look",
      "prompt":
          "clothing-only edit: crop top, high-waisted shorts, and festival boots. Keep face and body identical.",
      "thumb": "images/full outfit/full_outfit_19.jpg",
    },
    {
      "label": "Sporty Chic",
      "prompt":
          "clothing-only edit: athletic top, joggers, and clean white sneakers. Do not alter hair, body, or face.",
      "thumb": "images/full outfit/full_outfit_20.jpg",
    },
    {
      "label": "Modern Boho",
      "prompt":
          "clothing-only edit: boho-style top, layered skirt, and sandals. No changes to skin, face, or hair.",
      "thumb": "images/full outfit/full_outfit_21.jpg",
    },
    {
      "label": "Glow-Up Streetwear",
      "prompt":
          "clothing-only edit: modern streetwear with oversized hoodie, cargo pants, and chunky shoes. Leave doll’s features intact.",
      "thumb": "images/full outfit/full_outfit_22.jpg",
    },
    {
      "label": "Soft Girl Aesthetic",
      "prompt":
          "clothing-only edit: pastel sweater, mini skirt, and cute platform shoes. Face and body remain unchanged.",
      "thumb": "images/full outfit/full_outfit_23.jpg",
    },
    {
      "label": "Classy Casual",
      "prompt":
          "clothing-only edit: fitted top, high-waisted trousers, and modern shoes. Do not alter the doll’s appearance.",
      "thumb": "images/full outfit/full_outfit_24.jpg",
    },
  ];
}
