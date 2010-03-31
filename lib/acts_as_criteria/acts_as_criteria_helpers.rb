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
      options[:label] ||= "Search"
      render :partial => "acts_as_criteria/simple", :locals => { :options => options, :multi => multi, :model => model }
    end
    
    def filter(model, options)      
      filters = model.criteria_options[:filter]      
      
      raise "Unsupported method filter for model #{model.to_s}" if filters.blank?
      
      options[:class]  ||= :search
      options[:method] ||= :get
      options[:action] ||= self.send("search_#{model.to_s.downcase.pluralize}_path")
      options[:label] ||= "Filter"
      
      render :partial => "acts_as_criteria/filter", :locals => { :options => options, :model => model, :columns => filters[:columns].map { |col, val| [ val[:text]||col, col ] }.insert(0, model.criteria_options[:sel_text] || "Select field") }      
    end
    
    def acts_as_criteria_input_operator(col_subtype, col)
      case col_subtype
        when :text
          then select_tag :"query[#{col}][match]", "<option>contains</option><option>start</option><option>end</option><option>exact</option>"
        when :num, :period
          then select_tag :"query[#{col}][match]", "<option>eq</option><option>ne</option><option>gt</option><option>ge</option><option>lt</option><option>le</option>"
        when :bool
          then ""
        else
          raise "Column subtype not supported: #{col_subtype}"
      end
    end
    
    def acts_as_criteria_input_field(col_subtype, col)
      case col_subtype
        when :text, :num
          then text_field_tag(:"query[#{col}][value]", @current_query, :id => nil)
        when :period
          # TODO: calendar_date_select please
          then 
            if self.respond_to? "calendar_date_select_tag"
              calendar_date_select_tag :"query[#{col}][value]"
            else
              text_field_tag(:"query[#{col}][value]", @current_query, :id => nil)
            end
        when :bool
          then select_tag :"query[#{col}][value]", "<option>0</option><option>1</option>"
        else
          raise "Column subtype not supported: #{col_subtype}"    
      end
    end
    
    def acts_as_criteria_input_source(col_subtype, col, source)
      options = source.call(options)
      select_tag :"query[#{col}][value]", options_for_select(options)
    end    
  end
 
end
