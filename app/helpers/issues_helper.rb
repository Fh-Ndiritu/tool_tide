module IssuesHelper
  def status_badge_classes(status)
    case status.to_sym
    when :released
      "bg-green-100 text-green-700"
    when :next_up, :in_progress
      "bg-[--color-accent-secondary] text-[--color-text-dark]"
    when :todo
      "bg-[--color-neutral-300] text-[--color-neutral-800]"
    when :archived
      "bg-gray-200 text-gray-500"
    else
      "bg-gray-100 text-gray-500"
    end
  end
end
