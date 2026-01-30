class WelcomeController < AppController
  def index
    # Fetch completed mask requests with styles, grouped by style
    # limit to styles with > 5 items
    styled_requests = MaskRequest.complete.everyone
    .order(id: :desc)
    .where.not(preset: [ nil, "" ])
    .group_by(&:preset)
    .select { |style, requests| requests.count > 2 }.to_a.shuffle

    @style_descriptions = {
      "modern" => "Clean lines • Geometric • Minimalist",
      "tropical" => "Lush foliage • Exotic • Resort-style",
      "desert" => "Sustainable • Water-wise • Sculptural",
      "mediterranean" => "Warm tones • Cypress • Sun-drenched",
      "zen" => "Peaceful • Raked gravel • Japanese Maples",
      "cottage" => "Wildflowers • Abundant • Romantic"
    }

    style_icons = {
      "modern" => "rectangle-dashed",
      "tropical" => "leaf",
      "desert" => "sparkles",
      "mediterranean" => "crown",
      "zen" => "leaf",
      "cottage" => "heart"
    }

    @gallery_cards = []
    styled_requests.each do |style, requests|
      requests.sample(2).each do |request|
        @gallery_cards << {
          style: style,
          description: @style_descriptions[style.to_s.downcase] || "Professional Design",
          icon: style_icons[style.to_s.downcase] || "sparkles",
          image: request.main_view
        }
      end
    end

    # Shuffle for a mix, or keep grouped? User said "independent", but maybe grouped pairs is nicer.
    # Let's keep them somewhat ordered by style so it's not chaotic, strictly pairs.
    # No shuffle.
  end
end
