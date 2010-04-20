Simple search and advanced filters made easy for rails
============

Provides a set of model, helper, views that helps integrate from simple search (various columns) to advanced filters (with relations).

Simple search introduction
============

Simple search is based on simple_column_search plugin, extended to provide multi-model search, here the most simple example, put it in your model:

    class Account < ActiveRecord::Base
        acts_as_criteria :simple => { :columns => [:name, :description] }
    end

This will create a search method on Account, you can use Account.search("Bank Spain") and will generate a query that looks like:

    ((accounts.name LIKE '%Bank%' OR accounts.description LIKE '%Bank%')) AND (accounts.name LIKE '%Spain%' OR accounts.description LIKE '%Spain%')"

In your view, you can use the helper for simple search as following:

    <%= acts_as_criteria_form :simple, Account %>

This will create the search form and a search method in the accounts_controller will handle the calls to the model for you.

Starting from that point a set of options can be specified in the model definition and the helper to help integrate smooth on your app, assuming some rules.
 * Escape lambda function to be able to clean the terms in the search as you need
 * Specify the match operator ex, :match => :is (:contains by default)
 * Multimodel search view helper
 * Ajax calls in helper
 * Pagination
 * Custom restriction to search results
 * Translations
* Custom method to mantain the search state in session
...

Filters introduction
============
This will add advancend filter system to your app, here the most simple example, put it in your model:

    class Account < ActiveRecord::Base
        acts_as_criteria :filter => { :columns => { :name => {}, :description => {}, :updated_at } }
    end

In your view, you can use the helper for the dynamic filters as following:

    <%= acts_as_criteria_form :filter, Account %>

This will create a dynamic form that will let add/delete filter with the columns specified with the operators that depends on the column type (auto-detected)

All the view-controller-model interactions will be handled automatically. Currently the following types will be treated independently:
 * :string, :text => :text
 * :integer, :float, :decimal => :num
 * :datetime, :timestamp, :time, :date => :period
 * :boolean => :bool

Eeach will have their own subset of operators:
 * text => is, is_not, begin, contains, not_contains
 * num  => eq, ne, gt, ge, lt, le
 * datetime => eq, ne, gt, ge, lt, le
 * boolean => eq, ne

As as special case, if you have installed http://electronicholas.com/calendar the filters for date columns will use this.

Starting from that point a set of options can be specified in the model definition and the helper to help integrate smooth on your app, assuming some rules.
 * You can use columns defined in relations, ex: you can use :"tags.name" and the query will include the tags relations automatically
 * You can pass lambda funcions as :source to create filter baseds on custom data (for selects), ex: select from the list of tags
 * Specify the :relation_name for filters related to polymorphic and custom named relations
 * Interations in the view with the simple search (disable it if filters are active)
 * Pagination
 * Custom restriction to search results
 * Translations
 * Custom method to mantain the filters state in session
 * Custom conditions
...

Complete example explained
============
    acts_as_criteria :i18n                   => lambda { |text| I18n.t(text) },
                   :mantain_current_query  => lambda { |query, controller_name, session| session["#{controller_name}_current_query".to_sym] = query },
                   :restrict => { :method  => "my", :options => lambda { |current_user| { :user => current_user} } },
                   :paginate => { :method  => "paginate", :options => lambda { |current_user| { :page => 1, :per_page => current_user.pref[:accounts_per_page]} } },
                   :simple   => { :columns => [:name, :description], :match => :contains },
                   :filter   => { :columns => { :name => { },
                                                :user_id => { :text => "created_by", :source => lambda { |options| User.all.map { |user| [user.full_name, user.id] } } },
                                                :assigned_to => { :source => lambda { |options| User.all.map { |user| [user.full_name, user.id] } } },
                                                :created_at => {},
                                                :updated_at => {},
                                                :"addresses.country" => { :text => "country", :relation_name => :billing_address, :source => lambda { |options| Country.all } }
                                              } }

Saved searches
============
This plugin enables your users to save the advanced filters for later use.

Installation
============
    script/plugin install git://github.com/tractis/acts_as_criteria.git
    rake db:migrate:plugin NAME=acts_as_criteria
    restart your webserver

Configuration
============
environment.rb

    config.plugins = [ :acts_as_criteria, :all ]

For plugin developers
============
You can extend the filters on your own plugin:
 * Put a file in vendor/plugins/my_plugin/config/criteria_filter.rb
 * Define a method get_"PLUGIN_NAME"_criteria_filters
 * Return an array of hashes with the model to apply the filter and the options

Example, adds a filter by category to the Account model

    def get_my_plugin_criteria_filters
        [{ :model => Account, :filters => { :"cats.id" => { :text => "Categoria", :condition => lambda { |value, model| "(cats.id = #{value} or cats.parent_id = #{value}) and cat_type = '#{model.to_s}'" }, :source => lambda { |options| Cat.all.map { |cat| [cat.long_name, cat.id] } } } } } ]
    end