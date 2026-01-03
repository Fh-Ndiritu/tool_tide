# frozen_string_literal: true

LANDSCAPE_PRESETS = {
  "modern" => "Clean minimalist",
  "desert" => "Resilient and hardy",
  "tropical" => "Vibrant and lush",
  "zen" => "Serene and calm",
  "cottage" => "Charming vibe",
  "mediterranean" => "Fragrant and relaxed"
}.freeze

PROMPTS = YAML.load_file(Rails.root.join("config/prompts.yml"))

# currency credits
PRO_CREDITS_PER_USD = 20

GOOGLE_IMAGE_COST = 8
LOCALIZED_PLANT_COST = 2
DEFAULT_IMAGE_COUNT = 3
DEFAULT_USD_PURCHASE_AMOUNT = BigDecimal(10)
CREDITS_INFO = "$#{DEFAULT_USD_PURCHASE_AMOUNT.to_i} for #{(DEFAULT_USD_PURCHASE_AMOUNT * PRO_CREDITS_PER_USD).to_i} credits".freeze

VOICE_MAP = {
  # Main Narrator/Default Voice (Neutral - Engaging/Warm Storyteller)
  Huria: "Algieba",

  # Primary Male Character (Male - Clear, Steady Lead)
  Karuri: "Iapetus",

  # Tertiary Male Character (Male - Even, Mature Support)
  Mwangi: "Charon",

  # Authority/Mature Character (Neutral - Experienced, Distinguished Tone)
  Wairimu: "Gacrux",

  # Primary Female Character (Female - Smooth, Dramatic Heroine)
  Wanjiku: "Despina",

  # Gentle Companion/Support (Female - Soft, Warm Tone)
  Muthoni: "Achernar",

  # Eccentric/Older Sidekick (Male - Gravelly, Distinct Tone)
  Kariuki: "Algenib",

  # Firm Authority/Second Narrator (Female - Firm, Commanding Tone)
  Ndunge: "Kore",

  # Mysterious/Excitable Character (Male - Breathy, Highly Emotive)
  Ndiangui: "Fenrir",

  # High Energy/Youthful Character (Female - Bright, Cheerful, Enthusiastic)
  Chiru: "Zephyr"

}.freeze

