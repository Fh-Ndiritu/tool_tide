module PagesHelper
  def faq_structured_data
    [
      {
        category: "General, Pricing & Access",
        index: 0,
        items: [
          {
            question: "Is there a free plan/trial? 🎁",
            answer: "<b class='text-accent'>Yes!</b> Start immediately with our generous Free Plan. You get <b>60 free credits</b>, which is enough for <b>1 Full Mask Design + 1 AI Text Edit</b>. No credit card is required, so you can experience our photorealistic tools with zero commitment."
          },
          {
            question: "Is Hadaa a subscription service?",
            answer: "<b class='text-accent text-lg'>NO.</b> Hadaa is strictly <b>Pay-As-You-Go</b>. We do not have monthly subscriptions or hidden recurring fees. You purchase credits packs (starting at just <b>$10 for 200 credits</b>) and they are yours to use whenever you want. You only pay for what you use."
          },
          {
            question: "What makes Hadaa different from other landscape apps?",
            answer: "Hadaa is the only platform that combines <b>Precision Control</b> with <b>Execution Planning</b>. Unlike simple image generators, we offer a <b class='text-white'>Dual Editing Mode</b> (Mask Designer + AI Text Editor) for surgical changes, and we back it up with actionable logistics like <b>Shopping List Generators</b> and <b>Localized Planting Guides</b> based on your specific USDA zone."
          }
        ]
      },
      {
        category: "Core AI Tools: Presets, SmartFix & AutoFix",
        index: 1,
        items: [
          {
            question: "What are Style Presets and how do they help?",
            answer: "<b>#{link_to 'Style Presets', features_preset_style_selection_path, class: 'text-accent hover:underline'}</b> are the fastest way to jumpstart your design. Instead of writing prompts from scratch, simply select a curated style (like <b>Modern, Cottage, Zen, or Tropical</b>) and the AI will instantly reimagine your masked area in that aesthetic, selecting plants and materials that fit the vibe."
          },
          {
            question: "What is SmartFix?",
            answer: "<b>#{link_to 'SmartFix', features_ai_prompt_editor_path, class: 'text-accent hover:underline'}</b> is our intelligent AI prompt editor. It allows you to describe exactly what you want (e.g., 'replace grass with clover', 'add a fire pit'). It features an <b>AI Assist</b> toggle that can add creative flair to your prompts, or you can turn it off for <b>precision control</b> when you need to specify exact details like plant counts or material types."
          },
          {
            question: "What is AutoFix?",
            answer: "<b>AutoFix</b> is an intelligent detection system that analyzes your current yard and <b>automatically suggests improvements</b>. It identifies opportunities—like fixing a messy lawn, pruning overgrown bushes, or adding lighting—and generates ready-to-use prompts so you can improve your design with a single click."
          },
          {
            question: "How does the 'Precision Bridge' (Masking) feature work?",
            answer: "The Precision Bridge allows you to make <b>surgical edits</b> via the #{link_to 'Brush Tool', features_brush_prompt_editor_path, class: 'text-accent hover:underline text-inherit'}. Instead of changing the whole image, you mask only specific areas (e.g., just the front lawn). This masking technology ensures that edits applied via <b>Presets, SmartFix, or AutoFix</b> only affect the designated area, leaving the rest of your original photo 100% untouched."
          }
        ]
      },
      {
        category: "Visualizing Your Ideas: Sketches & Drone Views",
        index: 2,
        items: [
          {
            question: "I have a hand-drawn sketch. Can Hadaa turn it into a photo?",
            answer: "<b>Yes.</b> Our 'Sketch to 3D' feature accepts hand sketches, iPad drawings, or architectural blueprints. The AI analyzes the lines and geometry to create a <b>3D clay rendering</b> before transforming it into a fully photorealistic scene, preserving your original perspective and layout."
          },
          {
            question: "How does the Drone View feature work?",
            answer: "Hadaa uses advanced <b>Vector Transformation</b> and agentic workflows to re-render your ground-level photo from a <b>#{link_to "bird's-eye perspective", features_drone_view_3d_perspective_path, class: 'text-white hover:underline'}</b>. This helps you visualize the layout and flow of the entire property without needing a physical drone survey."
          }
        ]
      },
      {
        category: "Execution: From Design to Reality",
        index: 3,
        items: [
          {
            question: "Will the plants suggested actually grow in my yard?",
            answer: "<b>Yes.</b> We prioritize survivability. Our recommendations are filtered through your local <b>#{link_to 'USDA Hardiness Zone', features_location_plant_suggestions_path, class: 'text-white hover:underline'}</b>. We also consider practical factors like <b>Pet/Kid Safety</b> (toxicity), <b>HOA Regulations</b>, and <b>Soil Type</b> to ensure the plants are safer, compliant, and thriving in your specific environment."
          },
          {
            question: "How accurate is the Shopping List?",
            answer: "Highly accurate. We use <b>Depth Analysis</b> vision models to calculate the real-world square footage of your masked area. This allows us to generate a precise <b>#{link_to 'Shopping List', features_shopping_list_planting_guide_path, class: 'text-white hover:underline'}</b> with exact quantities for plants, mulch, gravel, and pavers, minimizing expensive material waste."
          }
        ]
      },
      {
        category: "Trust, Privacy & Technology",
        index: 4,
        items: [
          {
            question: "Is my personal data/home address safe?",
            answer: "<b class='text-accent'>100% Safe.</b> We take privacy seriously. We automatically <b>strip all EXIF (GPS) data</b> from your photos upon upload. If you choose to share your design in our gallery, we use AI to <b>blur identifying features</b> (like house numbers) to ensure anonymity."
          },
          {
            question: "Who owns the designs I create?",
            answer: "You do. You have full ownership of the designs you generate and can use them for personal projects, client presentations, or your portfolio."
          },
          {
            question: "What resolution are the downloaded designs?",
            answer: "All initial designs are generated in clear HD (1080p). For professional presentations or detailed viewing, you can instant <b>upscale to 4K resolution</b> with a single click, ensuring state-of-the-art fidelity suitable for print."
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
