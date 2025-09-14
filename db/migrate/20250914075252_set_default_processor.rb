class SetDefaultProcessor < ActiveRecord::Migration[8.0]
  def change
  change_column_default :landscape_requests, :image_engine, to: 1
  end
end
