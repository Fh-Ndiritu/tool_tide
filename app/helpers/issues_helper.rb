module IssuesHelper
  def status_badge_classes(status)
    case status.to_sym
    when :released
      "bg-green-100 text-green-700"
    when :next_up, :in_progress
      "bg-accent-secondary text-text-dark"
    when :todo
      "bg-neutral-300 text-neutral-800"
    when :archived
      "bg-gray-200 text-gray-500"
    else
      "bg-gray-100 text-gray-500"
    end
  end
end
