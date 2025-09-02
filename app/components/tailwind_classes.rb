# frozen_string_literal: true

module TailwindClasses
  OVERRIDE_GROUPS = {
    "background-color" => /^bg-/,
    "text-color" => /^text-/,
    "width" => /^w-/,
    "flex-direction" => /^flex-(row|col)$/,
    "rounded" => /^rounded-/
  }.freeze

  private

  def merge_classes(custom_classes)
    default_set = self.class::DEFAULT_CLASSES.to_set
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
    (filtered_default_set.to_set | custom_set).join(" ")
  end
end
