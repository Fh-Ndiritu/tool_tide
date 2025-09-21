class AddCanvaToMaskRequest < ActiveRecord::Migration[8.0]
  def change
    add_reference :mask_requests, :canva, null: false, foreign_key: true
  end
end
