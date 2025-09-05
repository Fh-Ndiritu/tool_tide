module ErrorHandler
  extend ActiveSupport::Concern

  def displayable_error?(error)
    I18n.t("permitted_errors").values.include?(error.message)
  end
end
