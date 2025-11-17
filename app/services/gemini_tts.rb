# frozen_string_literal: true

require 'faraday'
require 'json' # Keep standard required libraries

class GeminiTts
  API_URL = "https://texttospeech.googleapis.com/v1/text:synthesize".freeze
  TOKEN_SCOPE = [ "https://www.googleapis.com/auth/cloud-platform" ].freeze
  SAMPLE_RATE = 24000
  CHANNELS = 1
  BITS_PER_SAMPLE = 16
  BLOCK_ALIGN = CHANNELS * BITS_PER_SAMPLE / 8
  BYTE_RATE = SAMPLE_RATE * BITS_PER_SAMPLE / 8

  # Define long timeouts for the API call (NEW - to fix Net::ReadTimeout)
  LONG_READ_TIMEOUT_SECONDS = 189
  LONG_OPEN_TIMEOUT_SECONDS = 20

  # NOTE: The VOICE_MAP constant is REQUIRED for methods below, but I am removing
  # my arbitrary addition to respect your request and assuming it exists elsewhere.

  # Initializes the service with an Audio record and sets project configuration.
  def initialize(audio_record)
    @audio = audio_record
    @project_id = ENV["GOOGLE_PROJECT_ID"]
    @access_token = nil
  end

  # Executes the full TTS workflow: calls the API, saves the audio, and handles critical failure logging.
  def perform
    tts_result = call

    if tts_result[:success]
      @audio.audio_file.attach(
        io: StringIO.new(tts_result[:audio_data]),
        filename: "tts_#{@audio.id}_#{Time.now.to_i}.wav",
        content_type: "audio/wav"
      )
      Rails.logger.info "GeminiTTS Success: Audio attached to Audio ID #{@audio.id}."
      true
    else
      Rails.logger.error "GeminiTTS Error for Audio ID #{@audio.id}: #{tts_result[:error]}"
      false
    end
  rescue => e
    Rails.logger.error "GeminiTTS Fatal Error for Audio ID #{@audio.id}: #{e.message}"
    raise e
  end

  # Orchestrates the TTS process: gets the token, iterates content blocks, calls the API, and stitches audio.
  def call
    unless @project_id && !@project_id.empty?
      error_msg = "Configuration Error: 'GOOGLE_PROJECT_ID' environment variable must be set."
      @audio.update(error_msg: error_msg)
      raise error_msg
    end

    begin
      @access_token = get_access_token
      raw_audio_parts = []

      content_blocks = JSON.parse(@audio.content)

      content_blocks.each_with_index do |block, block_index|
        style_prompt = block["style_prompt"].presence
        turns = block["turns"]

        unless turns.is_a?(Array) && turns.any?
          Rails.logger.warn "Content Block #{block_index} skipped: 'turns' is empty or invalid."
          next
        end

        if @audio.single_speaker
          full_text = turns.map { |t| t["text"] }.join(" ")

          Rails.logger.info "Processing TTS block #{block_index + 1}/#{content_blocks.size} in single-speaker mode."

          payload = build_single_speaker_payload(full_text, style_prompt)
          response_data = synthesize_speech(payload)

          audio_content_b64 = response_data.dig("audioContent")
          unless audio_content_b64
            raise "API Response Error (Single Speaker, Block #{block_index}): Could not find 'audioContent'. Response: #{response_data.to_json}"
          end
          raw_audio_parts << Base64.decode64(audio_content_b64)

        else
          batches = create_speaker_batches(turns)

          batches.each_with_index do |batch, batch_index|
            Rails.logger.info "Processing TTS block #{block_index + 1}/#{content_blocks.size}, batch #{batch_index + 1}/#{batches.size} with speakers: #{batch[:speakers].map(&:to_s).join(', ')}"

            payload = build_multi_speaker_payload(batch[:turns], style_prompt)
            response_data = synthesize_speech(payload)

            audio_content_b64 = response_data.dig("audioContent")
            unless audio_content_b64
              raise "API Response Error (Multi Speaker, Block #{block_index}, Batch #{batch_index}): Could not find 'audioContent'. Response: #{response_data.to_json}"
            end

            raw_audio_parts << Base64.decode64(audio_content_b64)
          end
        end
      end

      stitched_pcm = raw_audio_parts.join
      final_wav_data = pcm_to_wav(stitched_pcm)

      { success: true, audio_data: final_wav_data }

    rescue JSON::ParserError => e
      error_msg = "Content parsing failed. Ensure content is valid JSON (array of hashes): #{e.message}"
      @audio.update(error_msg: error_msg)
      raise e
    rescue StandardError => e
      error_msg = "TTS Processing Error: #{e.message}"
      @audio.update(error_msg: error_msg)
      raise e
    end
  end

  # Constructs a WAV header and prepends it to the raw PCM audio data.
  def pcm_to_wav(raw_pcm_data)
    data_size = raw_pcm_data.bytesize
    file_size = data_size + 36

    header = []

    header << "RIFF"
    header << [ file_size ].pack("V")
    header << "WAVE"

    header << "fmt "
    header << [ 16 ].pack("V")
    header << [ 1 ].pack("v")
    header << [ CHANNELS ].pack("v")
    header << [ SAMPLE_RATE ].pack("V")
    header << [ BYTE_RATE ].pack("V")
    header << [ BLOCK_ALIGN ].pack("v")
    header << [ BITS_PER_SAMPLE ].pack("v")

    header << "data"
    header << [ data_size ].pack("V")

    header.join + raw_pcm_data
  end

  # Splits conversation turns into batches, ensuring each batch contains a maximum of two unique speakers for the multi-speaker API.
  def create_speaker_batches(turns)
    batches = []
    current_batch_turns = []
    current_batch_speakers = Set.new

    turns.each do |turn|
      speaker = turn["speaker"].to_sym

      unless VOICE_MAP.key?(speaker)
        raise ArgumentError, "Invalid speaker key '#{speaker}' in content. Must be one of the known speaker keys."
      end

      if current_batch_speakers.include?(speaker)
        current_batch_turns << turn

      elsif current_batch_speakers.size == 2
        batches << { speakers: current_batch_speakers.to_a, turns: current_batch_turns }
        current_batch_speakers = Set.new([ speaker ])
        current_batch_turns = [ turn ]

      else
        current_batch_speakers.add(speaker)
        current_batch_turns << turn
      end
    end

    if current_batch_turns.any?
      batches << { speakers: current_batch_speakers.to_a, turns: current_batch_turns }
    end

    if batches.empty?
      raise ArgumentError, "Content block has no turns after parsing."
    end

    batches
  end

  # Constructs the JSON payload for a single-speaker synthesis request.
  def build_single_speaker_payload(full_text, style_prompt)
    voice_id = VOICE_MAP[:Huria]

    {
      input: {
        text: full_text,
        prompt: style_prompt
      }.compact,
      voice: {
        languageCode: "en-us",
        name: voice_id,
        modelName: "gemini-2.5-flash-tts"
      },
      audioConfig: {
        audioEncoding: "LINEAR16",
        sampleRateHertz: SAMPLE_RATE
      }
    }
  end

  # Constructs the JSON payload for a multi-speaker synthesis request (one batch).
  def build_multi_speaker_payload(turns, style_prompt)
    style_prompt_val = style_prompt.presence
    unique_speaker_keys = turns.map { |t| t["speaker"].to_sym }.uniq

    if unique_speaker_keys.size == 1
      dummy_speaker = (VOICE_MAP.keys.to_a - unique_speaker_keys.to_a).first
      unless dummy_speaker
        raise "Internal Error: VOICE_MAP must contain at least two entries to use a dummy speaker."
      end
      unique_speaker_keys << dummy_speaker
    end

    unless unique_speaker_keys.size == 2
      raise ArgumentError, "Internal batching error: Expected exactly two speakers in payload, got #{unique_speaker_keys.size}."
    end

    markup_turns = turns.map do |turn|
      { speaker: turn["speaker"].to_s, text: turn["text"] }
    end

    speaker_configs = unique_speaker_keys.map do |key|
      voice_id = VOICE_MAP[key]

      unless voice_id
        raise "Internal Error: Could not find voice ID for speaker key #{key}"
      end

      { speakerAlias: key.to_s, speakerId: voice_id }
    end

    {
      input: {
        prompt: style_prompt_val,
        multiSpeakerMarkup: { turns: markup_turns }
      }.compact,
      voice: {
        languageCode: "en-us",
        modelName: "gemini-2.5-flash-tts",
        multiSpeakerVoiceConfig: { speakerVoiceConfigs: speaker_configs }
      },
      audioConfig: {
        audioEncoding: "LINEAR16",
        sampleRateHertz: SAMPLE_RATE
      }
    }
  end

  # Fetches a Google OAuth 2.0 access token using credentials from the environment.
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

  # Performs the HTTP request to the Google Text-to-Speech API.
  def synthesize_speech(payload)
    conn = Faraday.new(url: API_URL) do |faraday|
      faraday.adapter Faraday.default_adapter
    end

    response = conn.post do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{@access_token}"
      req.headers["x-goog-user-project"] = @project_id

      # Set long HTTP timeouts on the request options to fix Net::ReadTimeout
      req.options.timeout = LONG_READ_TIMEOUT_SECONDS
      req.options.open_timeout = LONG_OPEN_TIMEOUT_SECONDS
      req.body = payload.to_json
    end

    unless response.success?
      raise "API Request failed with status #{response.status}: #{response.body}"
    end

    JSON.parse(response.body)
  rescue Faraday::TimeoutError => e
    raise "API Timeout Error (Faraday): The TTS request exceeded the timeout. Message: #{e.message}"
  end
end
