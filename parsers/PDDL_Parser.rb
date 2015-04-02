module PDDL_Parser
  extend self

  attr_reader :domain_name, :problem_name, :problem_domain, :operators, :methods, :predicates, :state, :tasks, :goal

  #-----------------------------------------------
  # Parse action
  #-----------------------------------------------

  def parse_action(op)
    op.shift
    name = op.shift
    raise 'Action without name definition' unless name.instance_of?(String)
    raise "Action #{name} have groups missing" if op.size != 6
    @operators << [name, free_variables = [], pos = [], neg = [], add = [], del = []]
    until op.empty?
      group = op.shift
      case group
      when ':parameters'
        # TODO Add type support
        group = op.shift
        raise "Error with #{name} parameters" unless group.instance_of?(Array)
        group.each {|i| i.sub!(/^\?/,'')}
        free_variables.push(*group)
      when ':precondition'
        group = op.shift
        raise "Error with #{name} precondition" unless group.instance_of?(Array)
        # Conjunction
        # TODO equality support
        if group.first == 'and'
          group.shift
          group.each {|pro|
            if pro.first == 'not'
              raise "Error with #{name} precondition group" if pro.size != 2
              proposition = pro.last
              neg << proposition
            else
              proposition = pro
              pos << proposition
            end
            proposition.each {|i| i.sub!(/^\?/,'')}
            @predicates[proposition.first] = true if @predicates[proposition.first].nil?
          }
        # TODO Atom
        else raise 'Single group not implemented'
        end
      when ':effect'
        group = op.shift
        raise "Error with #{name} effect" unless group.instance_of?(Array)
        # Conjunction
        # TODO equality support
        if group.first == 'and'
          group.shift
          group.each {|pro|
            if pro.first == 'not'
              raise "Error with #{name} effect group" if pro.size != 2
              proposition = pro.last
              del << proposition
            else
              proposition = pro
              add << proposition
            end
            proposition.each {|i| i.sub!(/^\?/,'')}
            @predicates[proposition.first] = false
          }
        # TODO Atom
        else raise 'Single group not implemented'
        end
      end
    end
  end

  #-----------------------------------------------
  # Parse domain
  #-----------------------------------------------

  def parse_domain(domain_filename)
    description = IO.read(domain_filename)
    description.gsub!(/;.*$|\n/,'')
    tokens = Hype.scan_tokens(description)
    if tokens.instance_of?(Array) and tokens.shift == 'define'
      @operators = []
      @methods = []
      @domain_name = 'unknown'
      @predicates = {}
      until tokens.empty?
        group = tokens.shift
        case group.first
        when 'domain'
          raise 'Domain group has size different of 2' if group.size != 2
          @domain_name = group.last
        when ':requirements'
          # TODO take advantage of requirements definition
        when ':predicates'
          # TODO take advantage of predicates definition
        when ':action' then parse_action(group)
        else puts "#{group.first} is not recognized"
        end
      end
    else raise "File #{domain_filename} does not match domain pattern"
    end
  end

  #-----------------------------------------------
  # Parse problem
  #-----------------------------------------------

  def parse_problem(problem_filename)
    # TODO this entire method
    description = IO.read(problem_filename)
    description.gsub!(/;.*$|\n/,'')
    tokens = Hype.scan_tokens(description)
    if tokens.instance_of?(Array) and tokens.shift == 'define'
      @problem_name = 'unknown'
      @problem_domain = 'unknown'
      until tokens.empty?
        group = tokens.shift
        case group.first
        when 'problem'
          # TODO raise
          @problem_name = group.last
        when ':domain'
          # TODO raise
          @problem_domain = group.last
        when ':requirements'
          # TODO take advantage of requirements definition
        when ':objects'
          # TODO take advantage of objects definition
        when ':init'
          # TODO raise
          group.shift
          @state = group
          @state.each {|proposition| @predicates[proposition.first] = nil unless @predicates.include?(proposition.first)}
        when ':goal'
          # TODO raise
          @goal_pos = []
          @goal_not = []
          @tasks = []
          group.shift
          group.each {|pro|
            if pro.first == 'not'
              @goal_not << pro.last
            else @goal_pos << pro
            end
          }
        end
      end
    else raise "File #{problem_filename} does not match problem pattern"
    end
  end
end