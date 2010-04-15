class CreateFilters < ActiveRecord::Migration
  def self.up
    create_table :filters do |t|
      t.string  :name
      t.text    :criteria
      t.string  :asset
      t.integer :user_id
      
      t.timestamps
    end
    
    add_index :filters, :user_id
  end
  
  def self.down
    drop_table :filters
  end
end
