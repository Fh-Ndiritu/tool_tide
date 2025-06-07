class ImagesController < ApplicationController
  def index
  end

  def create
    binding.irb
  end

  private

  def text_params
    params.expect(:text).require(images: [])
  end
end
