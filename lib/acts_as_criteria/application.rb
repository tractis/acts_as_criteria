module ActsAsCriteria 
  module ApplicationController
    
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
        
        # Set @current_query
        instance_variable_set("@current_query", params[:query])
        
        # Mantain current_query state if option given 
        unless model.criteria_options[:mantain_current_query].blank?
          model.criteria_options[:mantain_current_query].call(params[:query], controller_name, session)
        end        
        
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
      locals = {}

      case params[:id]
        when "activate_filters"
          action = "acts_as_criteria/activate_filter"
        when "activate_simple"
          action = "acts_as_criteria/activate_simple"
        when "new_filter_row"
          unless params[:col_name].blank?
              col_name = params[:col_name]
              @filter = { :col_name => col_name, :col_text => model.criteria_options[:filter][:columns][:"#{col_name}"][:text] || col_name,:col_subtype => model.col_subtype(col_name), :col_options => model.criteria_options[:filter][:columns][:"#{col_name}"] }
              action = "acts_as_criteria/new_filter_row"
          else
            action = "acts_as_criteria/invalid_action"
          end
        when "destroy_filter_row"
          unless params[:col_name].blank?
            locals = { :col_name => params[:col_name] }
            action = "acts_as_criteria/destroy_filter_row"
          else
            action = "acts_as_criteria/invalid_action"
          end
        when "clear_filters"
          instance_variable_set("@current_query", nil)
          unless model.criteria_options[:mantain_current_query].blank?
            model.criteria_options[:mantain_current_query].call(nil, controller_name, session)
          end          
          action = "acts_as_criteria/clear_filters"
        when "save_filters"
          filter = UserFilter.new(:user_id => params[:user_id], :name => params[:filter_name], :description => params[:filter_description], :criteria => criteria_hash_to_query_string, :asset => controller_name)
          if filter.save
            flash[:notice] = "succefully_saved_filter"
          else
            flash[:error] = "failed_save_filter"
          end
          action = "acts_as_criteria/save_filters"
        else
          action = "acts_as_criteria/invalid_action"
      end
      
      respond_to do |format|
        format.js   { render :template => action, :locals => locals }
      end       
    end

    private
    def criteria_hash_to_query_string      
      filter = send("current_query")
      query_var = []
      filter.each do |col, info|
        query_var << "query[#{col}][match]=#{info["match"]}"
        info["value"].each do |val|
          query_var << "query[#{col}][value][]=#{val}"
        end
      end

      query_var.join("&")
    end
    
  end
end