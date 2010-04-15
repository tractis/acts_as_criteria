class Filter < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :name, :scope => [:asset, :user_id]
end
