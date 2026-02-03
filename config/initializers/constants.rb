# frozen_string_literal: true

LANDSCAPE_PRESETS = {
  "modern" => "Clean minimalist",
  "desert" => "Resilient and hardy",
  "tropical" => "Vibrant and lush",
  "zen" => "Serene and calm",
  "cottage" => "Charming vibe",
  "mediterranean" => "Fragrant and relaxed"
}.freeze

PRESETS_WITH_PREFERENCES = %w[modern].freeze

PROMPTS = YAML.load_file(Rails.root.join("config/prompts.yml"))

# currency credits
PRO_CREDITS_PER_USD = 20


LOCALIZED_PLANT_COST = 2

# === Model Aliases & Costs ===
MODEL_ALIAS_PRO = "pro_mode".freeze
MODEL_ALIAS_STANDARD = "standard_mode".freeze

GOOGLE_PRO_IMAGE_COST = 9
GOOGLE_STANDARD_IMAGE_COST = 5

# Map alias -> Cost
MODEL_COST_MAP = {
  MODEL_ALIAS_PRO => GOOGLE_PRO_IMAGE_COST,
  MODEL_ALIAS_STANDARD => GOOGLE_STANDARD_IMAGE_COST
}.freeze

# Map alias -> Real Model Name (Separation of Concerns)
MODEL_NAME_MAP = {
  MODEL_ALIAS_PRO => "gemini-2.5-flash-image",
  # MODEL_ALIAS_PRO => "gemini-3-pro-image-preview",
  MODEL_ALIAS_STANDARD => "gemini-2.5-flash-image"
}.freeze

GOOGLE_2K_UPSCALE_COST = GOOGLE_PRO_IMAGE_COST
GOOGLE_4K_UPSCALE_COST = GOOGLE_PRO_IMAGE_COST * 3
GOOGLE_UPSCALE_COST = GOOGLE_4K_UPSCALE_COST
DEFAULT_IMAGE_COUNT = 3
DEFAULT_USD_PURCHASE_AMOUNT = BigDecimal(10)
CREDITS_INFO = "$#{DEFAULT_USD_PURCHASE_AMOUNT.to_i} for #{(DEFAULT_USD_PURCHASE_AMOUNT * PRO_CREDITS_PER_USD).to_i} credits".freeze
TRIAL_CREDITS=0

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

# I need a total of max 7 votes on each post, 7 - 2 human votes = 5 AI votes
# 6 models are sufficient, where one gives an idea and the others vote on it

AGORA_HEAD_HUNTER = {
  user_name: "Falcon",
  model_name: "gemini-2.5-flash",
  notes: "The Head Hunter",
  color: "bg-indigo-600",
  avatar: "user"
}



AGORA_MODELS = [
  { user_name: "Pelegrine", emoji: "🦅", model_name: "zai-org/glm-4.7-maas", publisher: "zhipuai", location: "global", notes: "Participant", color: "bg-blue-200", avatar: "users", provider: :vertex },
  { user_name: "Shark", emoji: "🦈", model_name: "meta/llama-4-maverick-17b-128e-instruct-maas", publisher: "meta", location: "us-east5", notes: "Participant", color: "bg-rose-200", avatar: "bolt", provider: :vertex },
  { user_name: "Dolphin", emoji: "🐬", model_name: "deepseek-ai/deepseek-v3.2-maas", publisher: "deepseek-ai", location: "global", notes: "Participant", color: "bg-cyan-200", avatar: "sparkles", provider: :vertex },
  { user_name: "Fox", emoji: "🦊", model_name: "qwen/qwen3-coder-480b-a35b-instruct-maas", publisher: "qwen", location: "global", notes: "Participant", color: "bg-amber-200", avatar: "light-bulb", provider: :vertex },
  { user_name: "Wolf", emoji: "🐺", model_name: "minimaxai/minimax-m2-maas", publisher: "minimaxai", location: "global", notes: "Participant", color: "bg-slate-300", avatar: "eye", provider: :vertex },
  { user_name: "Leopard", emoji: "🐆", model_name: "mistral-small-2503", publisher: "mistralai", location: "us-central1", notes: "Participant", color: "bg-purple-200", avatar: "cloud", provider: :vertex }
]

VERTEX_CONFIG = {
  project_id: ENV.fetch("GOOGLE_CLOUD_PROJECT", "tool-tide"),
  location: ENV.fetch("VERTEX_LOCATION", "us-central1")
}.freeze


  EVALUATIONS = <<~EVALUATIONS
    1. "The Thumb-Stop Test": If you saw this on TikTok/FB, would you actually stop, or is it just "another ad"?
    2. "The Generic Trap": Could our competitors run this exact same ad? If yes, it is a fail.
    3. "The Risk Factor": Does this have enough "guts", "twist" or "uniqueness" to be polarizing or trendy?
    4. Has a similar idea been accepted or rejected before? If yes, we are likely to reject it this time.
    5. Does it keep talking about the cost as the main selling point? If yes, it is a fail.
  EVALUATIONS
