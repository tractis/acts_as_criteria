require 'acts_as_criteria/acts_as_criteria.rb'
require 'acts_as_criteria/acts_as_criteria_helpers.rb'
require 'acts_as_criteria/application.rb'

ActiveRecord::Base.extend(ActsAsCriteria)    
ActionView::Base.send(:include, ActsAsCriteria::FormHelper)
config.to_prepare do
  ApplicationController.send(:include, ActsAsCriteria::ApplicationController)
end