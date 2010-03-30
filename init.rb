require File.dirname(__FILE__) + "/lib/acts_as_criteria.rb"

config.to_prepare do
  ActiveRecord::Base.extend(ActsAsCriteria)    
  ActionView::Base.send(:include, ActsAsCriteria::FormHelper)
  ApplicationController.send(:include, ActsAsCriteria::ControllerActions)  
end