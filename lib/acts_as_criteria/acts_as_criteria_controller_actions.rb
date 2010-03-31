module ActsAsCriteria 
  module ControllerActions
    
    # Controller instance method that responds to /controller/search request.
    # Only search If the model activates the acts_as_criteria plugin
    #----------------------------------------------------------------------------
    def search
      model = controller_name.singularize.camelize.constantize
      named = model.criteria_options[:named].to_s ||= "search" if model.respond_to?(:criteria_options)
      
      if params[:query] && model.respond_to?(:criteria_options)
        if model.criteria_options[:restrict].blank?
          if model.criteria_options[:paginate].blank?
            instance_variable_set("@#{controller_name}", model.send(:"#{named}", params[:query]))
          else
            paginate = model.criteria_options[:paginate]
            pages = paginate[:options].call(@current_user)
            instance_variable_set("@#{controller_name}", model.send(:"#{named}", params[:query]).send(:"#{paginate[:method]}", pages))
          end
        else
          restrict = model.criteria_options[:restrict]
          perms = restrict[:options].call(@current_user)
          if model.criteria_options[:paginate].blank?
            instance_variable_set("@#{controller_name}", model.send(:"#{restrict[:method]}", perms).send(:"#{named}", params[:query]))
          else
            paginate = model.criteria_options[:paginate]
            pages = paginate[:options].call(@current_user)
            instance_variable_set("@#{controller_name}", model.send(:"#{restrict[:method]}", perms).send(:"#{named}", params[:query]).send(:"#{paginate[:method]}", pages))
          end          
        end

        instance_variable_set("@current_query", params[:query])

        respond_to do |format|
          format.html { render :action => :index }
          format.js   { render :action => :index }
          format.xml  { render :xml => instance_variable_get("@#{controller_name}") }
        end        
      else
        redirect_to :action => "index"
      end      
    end

    # Controller instance method that responds to /controller/criteria request.
    # manages the filter form  
    #----------------------------------------------------------------------------    
    def criteria
      model = controller_name.singularize.camelize.constantize
      #named = model.criteria_options[:named].to_s ||= "search" if model.respond_to?(:criteria_options)
      columns = model.criteria_options[:filter][:columns].map { |col, val| col }.insert(0, 'Select field')
      locals = {}
      case params[:id]
        when "filter"
          action = "acts_as_criteria/activate_filter"
        when "simple"
          action = "acts_as_criteria/activate_simple"
        when "fill_empty"
          col_name = params[:col_name]
          @filter = { :col_name => col_name, :col_subtype => model.col_subtype(col_name), :col_options => model.criteria_options[:filter][:columns][:"#{col_name}"] }
          action = "acts_as_criteria/fill_filter_row_empty"
        when "new_empty"
          locals = { :columns => columns }
          action = "acts_as_criteria/new_filter_row_empty"
        when "clear"
          locals = { :columns => columns }
          action = "acts_as_criteria/clear_filter"
      end
      
      respond_to do |format|
        format.js   { render :template => action, :locals => locals }
      end       
    end
    
  end
end