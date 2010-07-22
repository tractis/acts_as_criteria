module ActsAsCriteria 
  module FormHelper
    def acts_as_criteria_form(method, model, options={})
      case method
        when :simple
          simple(model, options) 
        when :filter
          filter(model, options)
        else
          raise "Unexpected method type: #{method}, use :simple or :filter"          
      end
    end
    
    def simple(model, options)
      multi = model.is_a?(Array) ? true : false
      options[:class]  ||= :search
      options[:method] ||= :get
      if multi == true
        options[:actions] = []
        model.each do |m|          
          options[:actions] << [  m.to_s.pluralize, self.send("search_#{m.to_s.downcase.pluralize}_path") ]
        end
      else
        options[:action] ||= self.send("search_#{model.to_s.downcase.pluralize}_path")
      end
      options[:label] ||= acts_as_criteria_get_translation(model, "search")
      render :partial => "acts_as_criteria/simple", :locals => { :options => options, :multi => multi, :model => model }
    end
    
    def filter(model, options)      
      filters = model.criteria_options[:filter]      
      
      raise "Unsupported method filter for model #{model.to_s}" if filters.blank?
      
      options[:class]  ||= :search
      options[:method] ||= :get
      options[:action] ||= self.send("search_#{model.to_s.downcase.pluralize}_path")
      options[:label] ||= acts_as_criteria_get_translation(model, "filter")
      render :partial => "acts_as_criteria/filter", :locals => { :options => options, :model => model, :columns => options_for_columns(filters) }
    end

    def options_for_columns(filters)
      filters[:columns].map { |col, val| [ acts_as_criteria_get_translation(acts_as_criteria_get_current_model, val[:text]||col), col ] }.sort.insert(0, "")
    end
    
    def acts_as_criteria_get_translation(model, text)
      # Check for internalization support
      if model.criteria_options[:i18n]
        model.criteria_options[:i18n].call(text)
      else
        text
      end
    end

    def acts_as_criteria_get_current_model
      controller_name.singularize.camelize.constantize
    end

    def acts_as_criteria_input_label(col, col_options)
      if col_options[:text]
        acts_as_criteria_get_translation(acts_as_criteria_get_current_model, col_options[:text])
      else
        acts_as_criteria_get_translation(acts_as_criteria_get_current_model, col)
      end
    end

    def acts_as_criteria_input_operator(col_subtype, col, current_query, col_options)      
      current_match = (current_query.blank? || current_query[col].blank? || current_query[col][:match].blank?) ? "" : current_query[col][:match]
      model = acts_as_criteria_get_current_model

      case col_subtype
        when :text then 
          if col_options[:source].blank?  
            opts = [[acts_as_criteria_get_translation(model,"contains"),"contains"], [acts_as_criteria_get_translation(model,"doesnt_contains"), "not_contains"],
                    [acts_as_criteria_get_translation(model,"begins_with"),"begin"], [acts_as_criteria_get_translation(model,"ends_with"),"end"],
                    [acts_as_criteria_get_translation(model,"is"),"is"], [acts_as_criteria_get_translation(model,"is_not"),"is_not"]]
          else
            opts = [[acts_as_criteria_get_translation(model,"contains"),"contains"], [acts_as_criteria_get_translation(model,"doesnt_contains"), "not_contains"]]
          end            
        when :num, :period then 
          if col_options[:source].blank?
            opts = [["=","eq"], ["<>","ne"], [">","gt"], [">=","ge"], ["<","lt"], ["<=","le"]]
          else
            opts = [["=","eq"], ["<>","ne"]]
          end
        when :bool
          then return ""
        else
          raise "Column subtype not supported: #{col_subtype}"
      end
      select_tag :"query[#{col}][match]", options_for_select(opts, current_match)
    end
    
    def acts_as_criteria_input_field(col_subtype, col, current_query, filter_val)
      size = 32
      unless filter_val.blank?
        current_value = filter_val
      else
        current_value = (current_query.blank? || current_query[col].blank? || current_query[col][:value].blank?) ? "" : current_query[col][:value].first
      end      
      input_name = :"query[#{col}][value][]"
      case col_subtype
        when :text, :num
          then text_field_tag(input_name, current_value, :id => nil, :size => size)
        when :period
          then 
            if self.respond_to? "calendar_date_select_tag"
              calendar_date_select_tag(input_name, current_value, :id => nil, :size => size - 5)
            else
              text_field_tag(input_name, current_value, :id => nil, :size => size)
            end
        when :bool
          then select_tag input_name, options_for_select([["False","0"], ["True","1"]], current_value)
        else
          raise "Column subtype not supported: #{col_subtype}"    
      end
    end
    
    def acts_as_criteria_input_source(col_subtype, col, source, current_query, filter_val)
      unless filter_val.blank?
        current_value = filter_val
      else
        current_value = (current_query.blank? || current_query[col].blank? || current_query[col][:value].blank?) ? "" : current_query[col][:value].first
      end       
      current_value = current_value.to_i if Float(current_value) rescue false

      options = source.call(options)
      select_tag :"query[#{col}][value][]", options_for_select(options, current_value), { :style => "width: 250px;" }
    end
    
    def acts_as_criteria_set_visibility(type, current_query, options = {})
      case type
        when :simple then
          # Enabling the simple search input if query not active or is string
          if current_query.blank? || current_query.instance_of?(String)
            return false
          else
            return true
          end
        when :filter then
          # Hide the filters form if hidden option is set and active query is not a filter
          if options[:hidden] && !current_query.instance_of?(HashWithIndifferentAccess)
            return "style='display:none;'"
          else
            return ""
          end
        else
          raise "Type not supported: #{type}, use :simple or :filter"
      end
    end
    
    def acts_as_criteria_get_action_link(action, type)
      if type[:text]
        link_name = acts_as_criteria_get_translation(acts_as_criteria_get_current_model, type[:text])
      else
        link_name = image_tag(type[:image])
      end
      link_to_remote link_name, :url => { :action => :criteria, :id => action }
    end
    
    def acts_as_criteria_is_filter_active(current_query)
      current_query.instance_of?(HashWithIndifferentAccess)
    end

    def acts_as_criteria_select_user_filters(current_user, model, text = "select_existing", autosubmit = true, id_to_criteria = true)
      if model.criteria_options[:restrict].blank?
        filters = UserFilter.find(:all, :conditions => { :user_id => current_user, :asset => controller_name })
      else
        restrict = model.criteria_options[:restrict]
        filters = UserFilter.send(:"#{restrict[:method]}", User.find(current_user)).find(:all, :conditions => { :asset => controller_name })
      end
      options = filters.map{ |filter| [filter.name, id_to_criteria.blank? ? filter.id : filter.criteria] }.insert(0, [acts_as_criteria_get_translation(acts_as_criteria_get_current_model, text), ""])      
      onchange = autosubmit == true ? "document.location = '#{send("search_#{controller_name}_path")}?' + this.value" : ""
      select_tag "criteria_select_filter", options_for_select(options, 0), :onchange => onchange
    end

    def acts_as_criteria_save_user_filter_form(current_user, model)
      form = []

      form << "<br />"
      form << form_remote_tag(:url => { :action => :criteria, :id => "save_filters" })
      form << hidden_field_tag("user_id", current_user)
      form << "<strong>#{acts_as_criteria_get_translation(acts_as_criteria_get_current_model, "save_as_new_filter")}:</strong><br />"
      form << "#{acts_as_criteria_get_translation(acts_as_criteria_get_current_model, "name")}: #{text_field_tag("filter_name", nil, :size => 15, :id => "acts_as_criteria_filter_name")}"
      form << "#{acts_as_criteria_get_translation(acts_as_criteria_get_current_model, "description")}: #{text_field_tag("filter_description", nil, :size => 35, :id => "acts_as_criteria_filter_description")}"
      form << "<br />"
      form << "<strong>#{acts_as_criteria_get_translation(acts_as_criteria_get_current_model, "or_ovewrite_existing")}</strong>"
      form << acts_as_criteria_select_user_filters(current_user, model, "select_one", false, false)
      form << "<br /><br />"
      form << submit_tag("#{acts_as_criteria_get_translation(acts_as_criteria_get_current_model, "save")}")

      form.join("\n")
    end
  end
 
end
