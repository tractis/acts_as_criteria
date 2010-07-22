
class CreateUserFilters < ActiveRecord::Migration
  def self.up
    create_table :user_filters do |t|
      t.string  :name
      t.text    :description
      t.text    :criteria
      t.string  :asset
      t.integer :user_id
      t.string  :access, :limit => 8, :default => "Private" # %w(Private Public Shared)
      t.integer :assigned_to
      
      t.timestamps
    end
    
    add_index :user_filters, :user_id
  end
  
  def self.down
    drop_table :user_filters
  end
end
