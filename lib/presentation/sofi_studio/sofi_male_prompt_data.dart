// lib/presentation/sofi_studio/sofi_male_prompt_data.dart
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_models.dart';

class SofiMalePromptData {
  static const List<String> hair = [
    "short textured buzz cut",
    "clean fade with organized texture on top",
    "modern messy quiff with soft volume",
    "braided cornrows with clean parts",
    "short afro-textured curls",
    "sleek side part with classic styling",
    "medium length wavy hair, pushed back",
    "short locs with natural texture",
    "clean crew cut with sharp edges",
    "modern undercut with textured top",
    "natural short curls with soft sheen",
    "tapered haircut with clean finish",
  ];

  static const List<String> tops = [
    "fun heroic graphic hoodie with bright colors",
    "cool adventure utility vest",
    "bright exciting oversized graphic tee",
    "classic cool blue denim jacket",
    "high-energy colorful racer jacket",
    "playful colorful plaid button-up shirt",
    "cozy bright colorful sweater",
    "superhero style tech adventure jacket",
    "bright comfy minimalist sweatshirt",
    "stylish lead blazer for boys",
    "casual polo shirt with bright clean colors",
    "modern colorful puffer vest",
  ];

  static const List<String> bottoms = [
    "relaxed fit cargo pants",
    "modern tapered joggers",
    "classic straight-leg jeans",
    "structured utility shorts",
    "wide-leg trousers for men",
    "clean chino pants",
    "distressed denim jeans",
    "modern techwear joggers",
    "minimalist lounge shorts",
    "tailored suit trousers",
    "sporty basketball shorts",
    "baggy skater pants",
  ];

  static const List<String> shoes = [
    "high-top chunky sneakers",
    "clean white low-top shoes",
    "modern combat boots",
    "stylish suede loafers",
    "technical hiking boots",
    "retro basketball sneakers",
    "minimalist leather slides",
    "classic canvas shoes",
    "athletic running sneakers",
    "structured dress shoes",
    "modern slip-on sneakers",
    "outdoor trail runners",
  ];

  static const List<Map<String, dynamic>> fullOutfits = [
    {
      "label": "Super Kid Street",
      "prompt": "[FACE LOCK] clothing-only edit: vibrant male hero look with bright graphic hoodie, colorful cargo pants, and high-top sneakers. Keep face identical.",
      "thumb": "images/male/outfits/male_outfit_01.jpg",
    },
    {
      "label": "Adventure Tech",
      "prompt": "clothing-only edit: cool male adventure look with colorful utility vest, bright tapered joggers, and clean white sneakers. Preserve face exactly.",
      "thumb": "images/male/outfits/male_outfit_02.jpg",
    },
    {
      "label": "Playful Plaid",
      "prompt": "clothing-only edit: fun male look with colorful plaid shirt over a bright tee, straight-leg blue jeans, and colorful canvas shoes.",
      "thumb": "images/male/outfits/male_outfit_03.jpg",
    },
    {
      "label": "Little Lead Style",
      "prompt": "[FACE LOCK] clothing-only edit: sharp male lead look with stylish blazer and matching bright trousers. Clean playful look.",
      "thumb": "images/male/outfits/male_outfit_04.jpg",
    },
    {
      "label": "Cuddly Knitwear",
      "prompt": "clothing-only edit: friendly cozy look with bright thick knit sweater and relaxed colorful trousers.",
      "thumb": "images/male/outfits/male_outfit_05.jpg",
    },
    {
      "label": "Heroic Active",
      "prompt": "clothing-only edit: high-energy male outfit with superhero style tech zip-up and bright performance joggers.",
      "thumb": "images/male/outfits/male_outfit_06.jpg",
    },
    {
      "label": "Skater Fun",
      "prompt": "clothing-only edit: colorful male skater style with bright graphic tee, baggy blue pants, and retro colorful sneakers.",
      "thumb": "images/male/outfits/male_outfit_07.jpg",
    },
    {
      "label": "Snow Adventure",
      "prompt": "clothing-only edit: layered male winter adventure look with bright puffer jacket and colorful beanie.",
      "thumb": "images/male/outfits/male_outfit_08.jpg",
    },
    {
      "label": "Academia Play",
      "prompt": "clothing-only edit: stylish male academia look with bright sweater vest and clean chinos.",
      "thumb": "images/male/outfits/male_outfit_09.jpg",
    },
    {
      "label": "Blue Denim Fun",
      "prompt": "clothing-only edit: double denim male look with bright blue jacket and matching jeans.",
      "thumb": "images/male/outfits/male_outfit_10.jpg",
    },
    {
      "label": "Island Splash",
      "prompt": "clothing-only edit: summer male look with bright colorful button-up shirt and swim shorts.",
      "thumb": "images/male/outfits/male_outfit_11.jpg",
    },
    {
      "label": "Royal Prince",
      "prompt": "clothing-only edit: majestic male royal look with gold-accented princely clothing and crown accessories.",
      "thumb": "images/male/outfits/male_outfit_12.jpg",
    },
  ];

  static List<String> getOptions(EditCategory category) {
    switch (category) {
      case EditCategory.hair: return hair;
      case EditCategory.top: return tops;
      case EditCategory.bottom: return bottoms;
      case EditCategory.shoes: return shoes;
      default: return [];
    }
  }
}
