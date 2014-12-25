class CreateAds < ActiveRecord::Migration
  def change
    create_table :ads do |t|
      t.integer  :ad_id
      t.string   :title

      t.timestamps :null => false
    end
    add_index :ads, :ad_id, :unique => true
  end
end
