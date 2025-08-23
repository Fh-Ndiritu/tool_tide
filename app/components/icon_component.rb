# frozen_string_literal: true

class IconComponent < ViewComponent::Base
  include TailwindClasses
  DEFAULT_CLASSES = %w[mb-1 rounded-full text-4xl flex items-center justify-center cursor-pointer duration-200]

  def initialize(name:, classes:)
    @name = name
    @classes = merge_classes(classes)
  end

  def call
    svg_path = Rails.root.join("app", "assets", "images", "icons", "#{@name}.erb")

    if File.exist?(svg_path)
      svg_content = File.read(svg_path).html_safe
      tag.div(svg_content, class: "icon #{@name} #{@classes}")
    else
      tag.div("Icon not found: #{@name}", class: " #{@classes}")
    end
  end
end
