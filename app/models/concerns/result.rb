# frozen_string_literal: true

class Result
  attr_reader :error, :data

  def initialize(success:, error: nil, data: nil)
    @success = success
    @error = error
    @data = data
  end

  def success?
    @success
  end
end
