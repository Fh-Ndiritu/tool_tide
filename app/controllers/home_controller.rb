# frozen_string_literal: true

class HomeController < AppController
  def credits
    @conversion_event = flash[:conversion_event]
  end
end
