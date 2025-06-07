# frozen_string_literal: true

class IconComponent < ViewComponent::Base
  def initialize(name:, classes:)
    @name = name
    @classes = classes
  end

  def call
    # Path to your SVG files (adjust if your icons are in a different asset path)
    svg_path = Rails.root.join("app", "assets", "images", "icons", "#{@name}.svg")

    if File.exist?(svg_path)
      svg_content = File.read(svg_path).html_safe
      # Wrap the SVG content in a div or span to apply classes
      # Ensure the SVG itself uses fill="currentColor" internally for inheritance
      tag.div(svg_content, class: "icon #{@classes}")
    else
      # Fallback for missing icon
      tag.div("Icon not found: #{@name}", class: "text-red-500 #{@classes}")
    end
  end
end
