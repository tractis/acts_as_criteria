class Person < ActiveRecord::Base
  acts_as_criteria :simple => { :columns => [:first_name, :last_name, :alias] }

  acts_as_criteria :simple => { :columns => [:first_name], :named => :search_first_name_default_match }
  acts_as_criteria :simple => { :columns => [:first_name], :named => :search_first_name_is, :match => :is }
  acts_as_criteria :simple => { :columns => [:first_name], :named => :search_first_name_start, :match => :start }
  acts_as_criteria :simple => { :columns => [:first_name], :named => :search_first_name_contains, :match => :contains }
  acts_as_criteria :simple => { :columns => [:first_name], :named => :search_first_name_end, :match => :end }

end