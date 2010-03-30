require 'rubygems'
require 'activerecord'

module ActsAsCriteria  
  def acts_as_criteria(*args)        
    options = args.extract_options!
    simple_options = options[:simple]
    filter_options = options[:filter]
    columns = options[:columns]

    # defaults
    simple_options[:match] ||= :start
    options[:named] ||= 'search'    
    
    class_inheritable_accessor  :criteria_options
    write_inheritable_attribute :criteria_options, options
    
    named_scope options[:named], lambda { |terms|            
      terms = simple_options[:escape].call(terms) if simple_options[:escape]      
      return simple(terms, simple_options[:columns], simple_options[:match]) if terms.instance_of? String
      filter(terms, filter_options)
    }
  end
  
  def filter(terms, options)
    terms[:connector] ||= "AND"    
    conds, assocs  = [], []
    
    options[:columns].each do |col, opts|
      unless terms[col].blank?
        assocs << col.to_s.split(".").first.to_sym if !column_names.include?(col.to_s.split(".").first) && !terms[col][:value].blank?
        col_name = column_names.include?(col.to_s.split(".").first) ? "#{table_name}.#{col}" : col
        conds << [ "#{col_name} #{get_pattern(col, terms[col])}" ] unless terms[col][:value].blank?
      end
    end
    
    conditions = merge_conditions(*conds.join(" #{terms[:connector]} "))
    #require 'ruby-debug';debugger
    { :conditions => conditions, :include => assocs }
  end

  def col_subtype(col)
    col_parts = col.to_s.split(".")
    col_type = col_parts.count == 1 ? columns_hash["#{col}"].type : col_parts.first.singularize.camelize.constantize.columns_hash["#{col_parts.last}"].type
    
    case col_type
      when :string, :text
        then :text
      when :integer, :float, :decimal
        then :num
      when :datetime, :timestamp, :time, :date
        then :period
      when :boolean
        then :bool
      else
        raise "Column type not supported: #{col_type}"
    end
  end
  
  def get_pattern(col, term) 
    self.send(:"get_#{col_subtype(col).to_s}_pattern", term)
#    case col_type(col)
#      when :string, :text
#        then get_text_pattern(term)
#      when :integer, :float, :decimal
#        then get_num_pattern(term)
#      when :datetime, :timestamp, :time, :date
#        then get_period_pattern(term)
#      when :boolean
#        then get_bool_pattern(term)
#    end    
  end
  
  def get_text_pattern(term)
    term[:match] ||= :contains
    like = connection.adapter_name == "PostgreSQL" ? "ILIKE" : "LIKE"
    negation = term[:negation] ? "NOT " : ""
    
    case term[:match].to_sym
      when :exact
        term[:negation] ? "!= '#{term[:value]}'" : "= '#{term[:value]}'"
      when :start
        "#{negation}#{like} '#{term[:value]}%'"
      when :contains
        "#{negation}#{like} '%#{term[:value]}%'"
      when :end
        "#{negation}#{like} '%#{term[:value]}'"
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
    
    case term[:match].to_sym
      when :eq
        "= '#{term[:value]}'"
      when :ne
        "<> '#{term[:value]}'"
      when :gt
        "> '#{term[:value]}'"
      when :ge
        ">= '#{term[:value]}'"
      when :lt
        "< '#{term[:value]}'"
      when :le
        "<= '#{term[:value]}'"
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
    when :exact
      term
    when :start
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