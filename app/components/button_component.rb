# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  include TailwindClasses
  DEFAULT_CLASSES = %w[flex flex-col items-center font-semibold py-2 px-2 rounded-lg cursor-pointer
    hover:bg-primary hover:text-light text-center duration-200 bg-secondary text-text-light transition-all transition-duration-300 ease-in-out
  ].freeze


  attr_reader :text, :type, :svg, :href, :data, :name, :value, :svg_classes

  def initialize(text: 'Submit', type: 'button', classes: '', svg: nil, href: nil, data: {}, name: '', value: '', svg_classes: '')
    @text = text
    @type = type
    @svg = svg
    @href = href
    @data = data
    @name = name
    @value = value
    @classes = merge_classes(classes)
    @svg_classes = svg_classes
  end
end
