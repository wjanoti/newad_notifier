class CreateAds < ActiveRecord::Migration
	def change
		create_table :ads do |t|
			t.string  :provider, :null => false
			t.integer :ad_id,    :null => false
			t.string  :title,    :null => false
			t.string  :url,      :null => false
			t.float   :price,    :null => false
			t.boolean :notified, :null => false, :default => false

			t.timestamps :null => false
		end
		add_index :ads, [:provider, :ad_id], :unique => true
	end
end
