module ApplicationHelper
  def active_item(path)
    # this will make the current page active
    'active-item ' if request.path == path
  end
end
