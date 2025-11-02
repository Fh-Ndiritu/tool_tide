# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"
require "googleauth" # Assumed to be installed in a Rails environment

# Service object to interact with the Google Text-to-Speech API (using Gemini model).
# This service is initialized with an Audio record and performs generation and attachment.
class GeminiTts
  API_URL = "https://texttospeech.googleapis.com/v1/text:synthesize".freeze
  TOKEN_SCOPE = [ "https://www.googleapis.com/auth/cloud-platform" ].freeze

  # Map internal speaker aliases to actual IDs from environment variables.
  VOICE_MAP = {
    default: ENV.fetch("DEFAULT_SPEAKER", "Puck"),
    secondary: ENV.fetch("SECONDARY_SPEAKER", "Schedar"),
    tertiary: ENV.fetch("TERTIARY_SPEAKER", "Iapetus")
  }.freeze

  # @param audio_record [Audio] The Rails Audio record instance.
  def initialize(audio_record)
    @audio = audio_record
    @project_id = ENV["GOOGLE_PROJECT_ID"]
  end

  # Main method to construct the payload, call the API, and ATTACH the audio.
  # This is the single public responsibility of the service.
  # @return [Boolean] true on success (generation and attachment), false on failure.
  def perform
    tts_result = call

    if tts_result[:success]
      # --- CRITICAL: ATTACHMENT BEFORE RETURN ---
      # Attach the generated audio file using Active Storage.
      @audio.audio_file.attach(
        io: StringIO.new(tts_result[:audio_data]),
        filename: "tts_#{@audio.id}_#{Time.now.to_i}.wav",
        content_type: "audio/wav"
      )
      # Log success and return true only after the attachment is complete.
      Rails.logger.info "GeminiTTS Success: Audio attached to Audio ID #{@audio.id}."
      true
    else
      # Update the record or log the error
      Rails.logger.error "GeminiTTS Error for Audio ID #{@audio.id}: #{tts_result[:error]}"
      false
    end
  end

  # Executes the speech synthesis request and returns the raw result hash.
  # This helper method separates the API communication from the attachment logic.
  def call
    unless @project_id && !@project_id.empty?
      return { success: false, error: "Configuration Error: 'GOOGLE_PROJECT_ID' environment variable must be set." }
    end

    begin
      access_token = get_access_token
      @payload = build_payload # Build payload based on @audio attributes
      response_data = synthesize_speech(access_token)

      audio_content_b64 = response_data.dig("audioContent")

      unless audio_content_b64
        return { success: false, error: "API Response Error: Could not find 'audioContent'. Response: #{response_data.to_json}" }
      end

      raw_audio = Base64.decode64(audio_content_b64)

      { success: true, audio_data: raw_audio }

    rescue StandardError => e
      { success: false, error: "TTS Processing Error: #{e.message}" }
    end
  end

  private

  # Dynamically builds the API payload based on the Audio record's attributes.
  def build_payload
    if @audio.single_speaker
      build_single_speaker_payload
    else
      build_multi_speaker_payload
    end
  end

  # --- Payload Builders ---

  # Builds the payload for a single-speaker request.
  def build_single_speaker_payload
    # Content and style_prompt are simple strings in the single-speaker case.
    voice_id = VOICE_MAP[:default] # Use default for single speaker

    {
      input: {
        text: @audio.content,
        prompt: @audio.style_prompt
      }.compact,
      voice: {
        languageCode: "en-us",
        name: voice_id,
        model_name: "gemini-2.5-flash-tts"
      },
      audioConfig: {
        audioEncoding: "LINEAR16",
        sampleRateHertz: 24000
      }
    }
  end

  # Builds the payload for a multi-speaker request.
  def build_multi_speaker_payload
    # The content field is assumed to hold an array of turns in JSONB format:
    # Example: [{ "speaker": "default", "text": "..." }, { "speaker": "secondary", "text": "..." }]
    turns = @audio.content
    style_prompt = @audio.style_prompt

    # 1. Build the multiSpeakerMarkup turns
    markup_turns = turns.map do |turn|
      speaker_alias = turn["speaker"].to_s.capitalize
      { speaker: speaker_alias, text: turn["text"] }
    end

    # 2. Collect unique speaker aliases and their IDs (from VOICE_MAP)
    unique_speaker_keys = turns.map { |t| t["speaker"].to_sym }.uniq
    speaker_configs = unique_speaker_keys.map do |key|
      voice_id = VOICE_MAP[key]
      raise ArgumentError, "Invalid speaker key in content: #{key}" unless voice_id
      { speakerAlias: key.to_s.capitalize, speakerId: voice_id }
    end

    # The multi-speaker payload structure
    {
      input: {
        prompt: style_prompt,
        multiSpeakerMarkup: { turns: markup_turns }
      }.compact,
      voice: {
        languageCode: "en-us",
        modelName: "gemini-2.5-flash-tts",
        multiSpeakerVoiceConfig: { speakerVoiceConfigs: speaker_configs }
      },
      audioConfig: {
        audioEncoding: "LINEAR16",
        sampleRateHertz: 24000
      }
    }
  end

  # --- Authentication and API Helpers ---

  # Generates an OAuth 2.0 Access Token from a Service Account JSON file.
  def get_access_token
    credentials_path = ENV["GOOGLE_APPLICATION_CREDENTIALS"]
    unless credentials_path && !credentials_path.empty?
      raise "Authentication Error: Please set the 'GOOGLE_APPLICATION_CREDENTIALS' environment variable pointing to your JSON key file."
    end

    unless File.exist?(credentials_path)
      raise "Authentication Error: Could not find credentials file at: #{credentials_path}"
    end

    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(credentials_path, "r"),
      scope: TOKEN_SCOPE
    )
    credentials.fetch_access_token!["access_token"]
  rescue NameError
    raise "Authentication setup incomplete: The 'google-auth' gem is required to use 'Google::Auth::ServiceAccountCredentials'."
  end

  # Performs the Text-to-Speech API request.
  def synthesize_speech(access_token)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")

    # Set required headers
    request["Authorization"] = "Bearer #{access_token}"
    request["x-goog-user-project"] = @project_id

    # Set the request body
    request.body = @payload.to_json

    # Send the request
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "API Request failed with status #{response.code}: #{response.body}"
    end

    JSON.parse(response.body)
  end
end
