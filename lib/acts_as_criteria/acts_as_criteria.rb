require 'rubygems'
require 'activerecord'

module ActsAsCriteria   
  def acts_as_criteria(*args)        
    options = args.extract_options!
    simple_options = options[:simple]
    filter_options = options[:filter]
    
    # Check for others plugins adding filters    
    plugins_path = "#{RAILS_ROOT}/vendor/plugins"
    filter_path = "config/criteria_filter.rb"
    
    Dir.foreach("#{RAILS_ROOT}/vendor/plugins") do |plugin| 
      if File.exist?("#{plugins_path}/#{plugin}/#{filter_path}")
        load "#{plugins_path}/#{plugin}/#{filter_path}"
        plugin_filters = send("get_#{plugin}_criteria_filters")
        plugin_filters.each do |filter|
          filter_options[:columns].merge!(filter[:filters]) if filter[:model] == self
        end
      end      
    end
    
    # defaults
    simple_options[:match] ||= :start
    options[:named] ||= 'search'    
    
    class_inheritable_accessor  :criteria_options
    write_inheritable_attribute :criteria_options, options
    
    named_scope options[:named], lambda { |terms|
      if terms.instance_of? String
        terms = simple_options[:escape].call(terms) if simple_options[:escape]
        simple(terms, simple_options[:columns], simple_options[:match]) if terms.instance_of? String
      else
        filter(terms, filter_options)
      end
    }
  end
  
  def filter(terms, options)
    conds, assocs  = [], []
    options[:columns].each do |col, opts|
      unless terms[col].blank?
        assocs << get_col_assoc(col, opts) if col_needs_assoc(col, terms)
        col_name = get_col_name(col)
        unless terms[col][:value].blank?
          if terms[col][:value].size > 1
            ored_cond = []
            terms[col][:value].each do |col_value|
              ored_term = { "match" => terms[col][:match], "value" => col_value }
              ored_cond <<  get_condition(col_name, col, ored_term, opts) if check_data(col, col_value)
            end
            conds << merge_conditions(*ored_cond.join(" OR "))
          else
            conds << get_condition(col_name, col, terms[col], opts) if check_data(col, terms[col][:value].first)
          end
        end
      end
    end
    
    conditions = merge_conditions(*conds.join(" AND "))
    { :conditions => conditions, :include => assocs }
  end

  def get_condition(col_name, col, term, opts)
    if opts[:condition]
      opts[:condition].call(term["value"], self)
    else
      [ "#{get_colname(col, col_name)} #{get_pattern(col, term)}" ]
    end
  end

  def get_colname(col, col_name)
    unless col_subtype(col) == :period
      col_name
    else
      "DATE(#{col_name})"
    end
    
  end

  def check_data(col, value)
    case col_subtype(col)
      when :text
        true
      when :num
        is_numeric?(value)
      when :period
        Date.parse(value) rescue false
      when :bool
        is_numeric?(value)
    end
  end

  def is_numeric?(term)
    true if Float(term) rescue false
  end

  def get_col_assoc(col, opts)
    opts[:relation_name] || col.to_s.split(".").first.to_sym
  end

  def col_needs_assoc(col, terms)
    !column_names.include?(col.to_s.split(".").first) && !terms[col][:value].blank?
  end

  def get_col_name(col)
    column_names.include?(col.to_s.split(".").first) ? "#{table_name}.#{col}" : col
  end

  def col_subtype(col)
    col_parts = col.to_s.split(".")
    col_type = col_parts.size == 1 ? columns_hash["#{col}"].type : col_parts.first.singularize.camelize.constantize.columns_hash["#{col_parts.last}"].type
    
    case col_type
      when :string, :text
        then :text
      when :integer, :float, :decimal
        then :num
      when :datetime, :date
        then :period
      when :boolean
        then :bool
      else
        raise "Column type not supported: #{col_type}"
    end
  end
  
  def get_pattern(col, term) 
    # first term conversion and checks
    match = term["match"]
    value = term["value"].class == Array ? term["value"].first : term["value"]
    
    self.send(:"get_#{col_subtype(col).to_s}_pattern", { :match => match, :value => value })
  end
  
  def get_text_pattern(term)    
    term[:match] ||= :contains
    like = connection.adapter_name == "PostgreSQL" ? "ILIKE" : "LIKE"
    
    case term[:match].to_sym
      when :is
        "= '#{term[:value]}'"
      when :is_not
        "!= '#{term[:value]}'"        
      when :begin
        "#{like} '#{term[:value]}%'"
      when :contains
        "#{like} '%#{term[:value]}%'"
      when :not_contains
        "NOT #{like} '%#{term[:value]}%'"        
      when :end
        "#{like} '%#{term[:value]}'"
      else
        raise "Unexpected match type: #{term[:match]}"
    end     
  end
  
  def get_num_pattern(term)
    term[:match] ||= :eq
    
    case term[:match].to_sym
      when :eq
        "= #{term[:value]}"
      when :ne
        "<> #{term[:value]}"
      when :gt
        "> #{term[:value]}"
      when :ge
        ">= #{term[:value]}"  
      when :lt
        "< #{term[:value]}"
      when :le
        "<= #{term[:value]}"     
      else
        raise "Unexpected match type: #{term[:match]}"        
    end
  end
  
  def get_period_pattern(term)
    term[:match] ||= :eq
    value = Time.parse(term[:value]).strftime("%Y-%m-%d")

    case term[:match].to_sym
      when :eq
        "= '#{value}'"
      when :ne
        "<> '#{value}'"
      when :gt
        "> '#{value}'"
      when :ge
        ">= '#{value}'"
      when :lt
        "< '#{value}'"
      when :le
        "<= '#{value}'"
      else
        raise "Unexpected match type: #{term[:match]}"        
    end    
  end
  
  def get_bool_pattern(term)
    term[:value].to_s == "1" ? "= 1" : "= 0"
  end
  
  def simple(terms, columns, match)
    # PostgreSQL LIKE is case-sensitive, use ILIKE for case-insensitive
    like = connection.adapter_name == "PostgreSQL" ? "ILIKE" : "LIKE"

    conditions = terms.split.inject(nil) do |acc, term|
      pattern = get_like(match, term)
      merge_conditions acc, [columns.collect { |column| "#{table_name}.#{column} #{like} :pattern" }.join(' OR '), { :pattern => pattern }]
    end

    { :conditions => conditions }    
  end
  
  def get_like(match, term)
    match ||= :contains
    case(match)
    when :is
      term
    when :begin
      term + '%'
    when :contains
      '%' + term + '%'
    when :end
      '%' + term
    else
      raise "Unexpected match type: #{match}"
    end    
  end
  
end