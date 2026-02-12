module PagesHelper
  def faq_structured_data
    @faqs = [
      {
        category: "General, Pricing & Access",
        index: 0,
        items: [
          {
            # SEO TARGET: "No subscription landscape software"
            question: "Is Hadaa a free landscaping app?",
            answer: "<b class='text-accent text-lg'>No hidden fees.</b> Hadaa is a premium <b>AI garden design software</b> that operates on a strictly <b>Pay-As-You-Go</b> basis. Unlike subscription apps that charge you monthly, credit packs start at just <b>$10</b>. You only pay for what you generate, and credits never expire."
          },
          {
            # SEO TARGET: "Commercial landscape design software"
            question: "Can I use Hadaa for commercial client work?",
            answer: "<b>Yes.</b> We grant full <b>Commercial Rights</b> for every generation. Hadaa is built for <b>landscape architects</b>, contractors, and real estate agents. You own the copyright to your designs, making it safe to use for client presentations and portfolios."
          },
          {
            # SEO TARGET: "Midjourney for landscape design"
            question: "How is Hadaa better than Midjourney?",
            answer: "Generic AI models hallucinate geometry and ignore physics. Hadaa is a specialized <b>landscape design app</b> that understands scale, perspective, and plant biology. Plus, we generate the <b>material list and planting plan</b> you need to actually build the project."
          },
          {
            # SEO TARGET: "Easy garden planner"
            question: "Do I need 3D modeling skills?",
            answer: "<b>Zero.</b> If you can take a photo with your phone, you can use Hadaa. We handle the 3D perspective alignment and depth mapping automatically, making us the easiest <b>garden planner</b> for homeowners and pros alike."
          },
          {
            # SEO TARGET: "Web-based landscape app"
            question: "Do I need to download an app?",
            answer: "<b>No.</b> Hadaa is a cloud-based tool that runs directly in your browser. Whether you are on an iPhone, Android, or Desktop, you get the full power of our AI engine without installing heavy software."
          }
        ]
      },
      {
        category: "Advanced Tools: Sketches, Lighting & Fixes",
        index: 1,
        items: [
          {
            # SEO TARGET: "Turn sketch into 3D landscape"
            question: "Can I turn a hand-drawn sketch into a 3D render?",
            answer: "<b>Yes.</b> Our new <b>Sketch Transform Engine</b> uses an Agentic AI System to analyze your drawing, fix perspective errors, and upscale it. It turns rough napkin sketches or CAD lines into photorealistic <b>3D landscape renders</b> in seconds."
          },
          {
            # SEO TARGET: "Landscape lighting visualizer"
            question: "Can I visualize night lighting?",
            answer: "<b>Yes.</b> Our lighting engine simulates various times of day. You can request 'twilight', 'night with garden lights', or 'golden hour' to see how your property looks 24/7—a crucial tool for selling <b>curb appeal</b>."
          },
          {
            question: "What if I don't like the result?",
            answer: "We offer a <b>'Smart Remix'</b> feature. You can iterate indefinitely on a single design, changing styles to 'Modern', 'Tropical', or 'Xeriscape' until it's perfect. If a generation fails technically, we refund the credit automatically."
          },
          {
            # SEO TARGET: "Fix messy yard"
            question: "How do I fix a messy yard instantly?",
            answer: "Use <b>AutoFix</b>. This intelligent diagnostic tool scans your photo to identify issues—like patchy grass, weeds, or construction debris. It automatically generates a prompt to fix these flaws instantly."
          }
        ]
      },
      {
        category: "Planting & Logistics",
        index: 2,
        items: [
          {
            # SEO TARGET: "Native plants by zone"
            question: "Will the AI suggest plants that grow in my area?",
            answer: "<b>Yes.</b> Hadaa includes a biological engine. We cross-reference your location with <b>#{link_to 'USDA Hardiness Zones', features_location_plant_suggestions_path, class: 'text-white hover:underline'}</b> to suggest native plants that are drought-tolerant and thrive in your specific soil type."
          },
          {
            # SEO TARGET: "Landscape material calculator"
            question: "Does it generate a shopping list?",
            answer: "<b>Yes.</b> We use Depth Analysis to calculate the real-world scale of your project. This allows us to generate a precise <b>#{link_to 'Shopping List', features_shopping_list_planting_guide_path, class: 'text-white hover:underline'}</b> with estimated quantities for plants, mulch, and pavers."
          }
        ]
      },
      {
        category: "Privacy & Tech Specs",
        index: 3,
        items: [
          {
            question: "Is my personal data safe?",
            answer: "<b class='text-accent'>100% Safe.</b> We automatically strip all EXIF (GPS) data from your photos upon upload. Your project library is private by default, and we do not sell your property data to third parties."
          },
          {
            question: "What resolution are the downloads?",
            answer: "All designs are generated in HD (1080p). For professional printing or client boards, you can use our <b>AI Upscaler</b> to enhance your renders to <b>4K resolution</b> with crisp details."
          }
        ]
      }
    ]
  end

  def faq_schema_json
    schema = {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": []
    }

    faq_structured_data.each do |category|
      category[:items].each do |item|
        schema[:mainEntity] << {
          "@type": "Question",
          "name": item[:question],
          "acceptedAnswer": {
            "@type": "Answer",
            "text": item[:answer]
          }
        }
      end
    end

    schema.to_json
  end
end
