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
        {
          q: "Is Hadaa a free landscaping app or paid software?", # Added "landscaping app"
          a: "We are a pay-as-you-go platform. Unlike subscription-based **landscape design software**, you only pay for what you use. Packages start at $10 with no monthly fees, making it perfect for one-off DIY projects."
        },
        {
          q: "Can I use this AI garden design software for commercial work?", # Added "AI garden design software"
          a: "Yes. All paid credits include a Commercial License. Hadaa is built for **landscape architects** and contractors who need to generate professional concepts for clients without expensive CAD tools."
        },
        {
          q: "Does the biological engine suggest plants for my climate?",
          a: "Yes. Hadaa is the only **AI landscape tool** that cross-references your location with USDA Hardiness Zones. We suggest species that will actually thrive in your specific garden, not just what looks good."
        },
        {
          q: "Can I keep existing trees in my backyard design?", # Added "backyard design"
          a: "Absolutely. Use our 'Masking Brush' to paint only the areas you want to renovate (like replacing grass with pavers) while protecting your favorite trees or patio. The AI blends the new **garden design** seamlessly with the old."
        },
        {
          q: "How is Hadaa better than Midjourney for landscape design?",
          a: "Generic AI models hallucinate geometry. Hadaa is a specialized **landscape design app** that understands scale, perspective, and plant biology. Plus, we generate the material list and planting plan you need to actually build it."
        },
        {
          q: "Do I need 3D modeling skills to use this planner?",
          a: "Zero. If you can take a photo, you can use Hadaa. We handle the 3D perspective alignment and depth mapping automatically, making us the easiest **garden planner** for homeowners."
        },
        {
          q: "Can I turn a sketch into a realistic landscape render?",
          a: "Yes. Our 'Sketch-to-Life' feature turns napkins sketches or 2D CAD drawings into photorealistic 3D renders in seconds, streamlining the workflow for professional designers."
        },
        {
          q: "What if I don't like the AI generated design?",
          a: "We offer a 'Smart Remix' feature. You can iterate indefinitely on a single design, changing styles to 'Modern', 'Tropical', or 'Xeriscape' until it's perfect. If a generation fails technically, we refund the credit."
        },
        {
          q: "Can I visualize night lighting and curb appeal?", # Added "curb appeal"
          a: "Yes. Our lighting engine simulates 'twilight', 'night', and 'golden hour'. It is an essential tool for real estate agents looking to boost **curb appeal** on property listings."
        },
        {
          q: "Is my property data private?",
          a: "Your uploaded photos and designs are private by default. We do not share your property data. You have full control over your project library."
        }
      ]
    end
  end
end
