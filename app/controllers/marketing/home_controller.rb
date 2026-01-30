module Marketing
  class HomeController < MarketingController
    if Rails.env.production?
      rate_limit to: 3, within: 1.minute, by: -> { request.ip }, name: "shortterm_home_index"
      rate_limit to: 8, within: 20.minutes, by: -> { request.ip }, name: "longterm_home_index"
    end

    def index
      # Gallery Images (Static Asset Loop)
      # We look for images in app/assets/images/gallery
      # and map them to a simple structure.
      params_path = Rails.root.join("app", "assets", "images", "gallery")
      @gallery_images = []
      if Dir.exist?(params_path)
         Dir.foreach(params_path) do |filename|
            next if filename.start_with?(".")
            next unless filename.match?(/\.(webp|jpg|png|jpeg)$/i)
            @gallery_images << filename
         end
      end
      # Sort to ensure consistency
      @gallery_images.sort!

      # Redesign Examples (for "Take a Photo" section)
      redesign_path = Rails.root.join("app", "assets", "images", "redesign_exterior")
      @redesign_examples = []
      if Dir.exist?(redesign_path)
         Dir.foreach(redesign_path) do |filename|
            next if filename.start_with?(".")
            next unless filename.match?(/\.(webp|jpg|png|jpeg)$/i)
            @redesign_examples << filename
         end
      end
      @redesign_examples.sort!

      # Top 10 High-Conversion FAQs
      @faqs = [
        { q: "Is this a subscription?", a: "No. We believe you should only pay for what you use. You purchase credits packages starting at just $10. There are no monthly fees, no hidden cancellations, and your credits never expire." },
        { q: "Can I use the images for my business?", a: "Yes. All paid credit packs include a full Commercial License. You own the copyright to every design you generate. Perfect for landscape architects, real estate agents, and contractors." },
        { q: "Will the plants actually grow in my area?", a: "Yes. Hadaa is the only AI landscape tool with a biological engine. When you enable 'Local Plants,' we cross-reference your location with USDA Hardiness Zones to suggest species that thrive in your specific climate." },
        { q: "Can I keep my existing trees?", a: "Absolutely. Use our 'Masking Brush' to paint only over the areas you want to change (like the grass or fence) while leaving your favorite trees or patio untouched. The AI blends the new design seamlessly with the old." },
        { q: "How is this better than ChatGPT or Midjourney?", a: "Generic AI models hallucinate geometry and ignore physics. Hadaa is fine-tuned specifically for landscape architecture. We understand scale, perspective, and plant biology. Plus, we give you the construction data to actually build it." },
        { q: "Do I need 3D modeling skills?", a: "Zero. If you can take a photo with your phone, you can use Hadaa. We handle all the perspective alignment, depth mapping, and lighting calculations automatically." },
        { q: "Can I upload a sketch or a blueprint?", a: "Yes. In addition to photos, our 'Sketch-to-Life' mode can turn a napkin drawing or a professional CAD line drwaring into a photorealistic render in seconds." },
        { q: "What if I don't like the result?", a: "We offer a 'Smart Remix' feature. You can iterate indefinitely on a single design, changing styles, materials, or seasons until it's perfect. If a generation completely fails due to a system error, we refund the credit automatically." },
        { q: "Can I visualize night lighting?", a: "Yes. Our lighting engine simulates various times of day. You can request 'twilight,' 'night with garden lights,' or 'golden hour' to see how your property looks 24/7." },
        { q: "Is my data private?", a: "Your uploaded photos and generated designs are private by default. We do not share your property data with third parties. You have full control over your project library." }
      ]
    end
  end
end
