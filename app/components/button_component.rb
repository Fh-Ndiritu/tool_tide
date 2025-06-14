# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  DEFAULT_CLASSES = %w[
    btn flex w-full flex-col items-center font-semibold py-2 px-2 rounded-lg cursor-pointer
    hover:bg-primary hover:text-light text-center duration-200 bg-secondary text-text-light transition-all transition-duration-200
  ].freeze

  OVERRIDE_GROUPS = {
    "background-color" => /^bg-/,
    "text-color" => /^text-/,
    "width" => /^w-/,
    "flex-direction" => /^flex-(row|col)$/
  }.freeze

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
    default_set = DEFAULT_CLASSES.to_set
    custom_set = custom_classes.split.to_set

    # Filter default classes based on custom class overrides
    # .reject on a Set returns a new Set, not an Array
    filtered_default_set = default_set.reject do |default_cls|
      OVERRIDE_GROUPS.any? do |_, regex|
        if default_cls.match?(regex)
          custom_set.any? { |custom_cls| custom_cls.match?(regex) }
        else
          false
        end
      end
    end

    # Combine the filtered default classes with the custom classes.
    # The `|` operator performs a set union, combining unique elements from both sets.
    # Then convert to an array and join.
    (filtered_default_set.to_set |  custom_set).join(" ")
  end
end
