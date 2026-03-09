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
    "oversized boxy hoodie",
    "structured utility vest",
    "classic oversized graphic tee",
    "fitted denim jacket",
    "modern bomber jacket",
    "clean flannel button-up shirt",
    "fashionable turtleneck sweater",
    "athleisure techwear jacket",
    "minimalist crewneck sweatshirt",
    "structured blazer for men",
    "casual polo shirt with clean collar",
    "modern puffer vest",
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
      "label": "Urban Streetwear",
      "prompt": "[FACE LOCK] clothing-only edit: modern male streetwear with oversized hoodie, cargo pants, and high-top sneakers. Keep face identical.",
      "thumb": "images/male/outfits/male_outfit_01.jpg",
    },
    {
      "label": "Technical Minimal",
      "prompt": "clothing-only edit: minimalist male techwear with utility vest, tapered joggers, and clean sneakers. Preserve face exactly.",
      "thumb": "images/male/outfits/male_outfit_02.jpg",
    },
    {
      "label": "Modern Casual",
      "prompt": "clothing-only edit: casual male look with flannel shirt over a tee, straight-leg jeans, and canvas shoes.",
      "thumb": "images/male/outfits/male_outfit_03.jpg",
    },
    {
      "label": "Sharp Tailored",
      "prompt": "[FACE LOCK] clothing-only edit: sharp male tailored suit with blazer and matching trousers. Clean professional look.",
      "thumb": "images/male/outfits/male_outfit_04.jpg",
    },
    {
      "label": "Cozy Knitwear",
      "prompt": "clothing-only edit: masculine cozy look with thick knit sweater and relaxed trousers.",
      "thumb": "images/male/outfits/male_outfit_05.jpg",
    },
    {
      "label": "Sporty Active",
      "prompt": "clothing-only edit: athletic male outfit with tech zip-up and performance joggers.",
      "thumb": "images/male/outfits/male_outfit_06.jpg",
    },
    {
      "label": "Skater Aesthetic",
      "prompt": "clothing-only edit: male skater style with graphic tee, baggy pants, and retro sneakers.",
      "thumb": "images/male/outfits/male_outfit_07.jpg",
    },
    {
      "label": "Winter Layered",
      "prompt": "clothing-only edit: layered male winter look with puffer jacket and beanie.",
      "thumb": "images/male/outfits/male_outfit_08.jpg",
    },
    {
      "label": "Academia Male",
      "prompt": "clothing-only edit: male academia look with sweater vest and chinos.",
      "thumb": "images/male/outfits/male_outfit_09.jpg",
    },
    {
      "label": "Denim Classic",
      "prompt": "clothing-only edit: double denim male look with jacket and matching jeans.",
      "thumb": "images/male/outfits/male_outfit_10.jpg",
    },
    {
      "label": "Beach Vibes",
      "prompt": "clothing-only edit: summer male look with open button-up shirt and swim shorts.",
      "thumb": "images/male/outfits/male_outfit_11.jpg",
    },
    {
      "label": "Glow High Fashion",
      "prompt": "clothing-only edit: male high fashion look with avant-garde structured pieces.",
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
