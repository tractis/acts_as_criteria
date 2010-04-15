class UserFilter < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:asset, :user_id]
end
