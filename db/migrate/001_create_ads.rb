class CreateAds < ActiveRecord::Migration
  def change
    create_table :ads do |t|
      t.integer  :ad_id
      t.string   :title

      t.timestamps
    end
  end
end
