# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  DEFAULT_CLASSES = %w[
    btn flex w-full flex-col items-center font-semibold py-2 px-2 rounded-lg cursor-pointer
    hover:bg-primary hover:text-light text-center duration-200 bg-secondary text-text-light transition-all transition-duration-200

  ].freeze

  attr_reader :text, :type, :svg, :href, :data, :name, :value

  def initialize(text: "Submit", type: "button", classes: "", svg: nil, href: nil, data: {}, name: "", value: "")
    @text = text
    @type = type
    @svg = svg
    @href = href
    @data = data
    @name = name
    @value = value
    @classes = merge_classes(classes)
  end

  private

  def merge_classes(custom_classes)
    # Splitting ensures uniqueness; custom classes override duplicates
    (DEFAULT_CLASSES + custom_classes.split).uniq.join(" ")
  end
end
