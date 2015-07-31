module Hyper_Compiler
  extend self

  SPACER = '-' * 47

  #-----------------------------------------------
  # Predicates to Hyper
  #-----------------------------------------------

  def predicates_to_hyper(output, predicates)
    if predicates.empty?
      output << "\n      []"
    else
      group = []
      predicates.each {|g| group << g.map {|i| i =~ /^\?/ ? i.sub(/^\?/,'') : "'#{i}'"}.join(', ')}
      output << "\n      [\n        [" << group.join("],\n        [") << "]\n      ]"
    end
  end

  #-----------------------------------------------
  # Subtasks to Hyper
  #-----------------------------------------------

  def subtasks_to_hyper(output, subtasks, indentation)
    if subtasks.empty?
      output << "#{indentation}yield []\n"
    else
      group = []
      subtasks.each {|t| group << t.map {|i| i =~ /^\?/ ? i.sub(/^\?/,'') : "'#{i}'"}.join(', ')}
      output << "#{indentation}yield [\n#{indentation}  [" << group.join("],\n#{indentation}  [") << "]\n#{indentation}]\n"
    end
  end

  #-----------------------------------------------
  # Compile domain
  #-----------------------------------------------

  def compile_domain(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not)
    domain_str = "# Generated by Hype\nrequire File.expand_path('../../../Hypertension', __FILE__)\n\nmodule #{domain_name.capitalize}\n  include Hypertension\n  extend self\n\n"
    domain_str << "  ##{SPACER}\n  # Domain\n  ##{SPACER}\n\n  @domain = {\n    # Operators"
    # Operators
    define_operators = ''
    operators.each_with_index {|op,i|
      domain_str << "\n    '#{op.first}' => true#{',' if operators.size.pred != i or not methods.empty?}"
      define_operators << "\n  def #{op.first}#{"(#{op[1].map {|j| j.sub(/^\?/,'')}.join(', ')})" unless op[1].empty?}\n    apply_operator("
      predicates_to_hyper(define_operators << "\n      # Positive preconditions", op[2])
      predicates_to_hyper(define_operators << ",\n      # Negative preconditions", op[3])
      predicates_to_hyper(define_operators << ",\n      # Add effects", op[4])
      predicates_to_hyper(define_operators << ",\n      # Del effects", op[5])
      define_operators << "\n    )\n  end\n"
    }
    # Methods
    define_methods = ''
    domain_str << "\n    # Methods"
    methods.each_with_index {|met,mi|
      domain_str << "\n    '#{met.first}' => [\n"
      variables = met[1].empty? ? '' : "(#{met[1].map {|i| i.sub(/^\?/,'')}.join(', ')})"
      met.drop(2).each_with_index {|met_case,i|
        domain_str << "      '#{met_case.first}'#{',' if met.size - 3 != i}\n"
        define_methods << "\n  def #{met_case.first}#{variables}\n"
        # No preconditions
        if met_case[2].empty? and met_case[3].empty?
          subtasks_to_hyper(define_methods, met_case[4], '    ')
        # Grounded or lifted
        else
          grounded = met_case[1].empty?
          met_case[1].each {|free| define_methods << "    #{free.sub(/^\?/,'')} = ''\n"}
          define_methods << (grounded ? '    if applicable?(' : '    generate(')
          predicates_to_hyper(define_methods << "\n      # Positive preconditions", met_case[2])
          predicates_to_hyper(define_methods << ",\n      # Negative preconditions", met_case[3])
          met_case[1].each {|free| define_methods << ", #{free.sub(/^\?/,'')}"}
          define_methods << (grounded ? "\n    )\n" : "\n    ) {\n")
          subtasks_to_hyper(define_methods, met_case[4], '      ')
          define_methods << (grounded ? "    end\n" : "    }\n")
        end
        define_methods << "  end\n"
      }
      domain_str << "    ]#{',' if methods.size.pred != mi}"
    }
    # Definitions
    domain_str << "\n  }\n\n  ##{SPACER}\n  # Operators\n  ##{SPACER}\n#{define_operators}"
    domain_str << "\n  ##{SPACER}\n  # Methods\n  ##{SPACER}\n#{define_methods}end"
  end

  #-----------------------------------------------
  # Compile problem
  #-----------------------------------------------

  def compile_problem(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not, domain_filename)
    problem_str = "# Generated by Hype\nrequire File.expand_path('../#{domain_filename}', __FILE__)\n\n# Objects\n"
    # Extract information
    objects = []
    start_hash = Hash.new {|h,k| h[k] = []}
    predicates.each_key {|i| start_hash[i] = []}
    state.each {|pred,*terms|
      start_hash[pred] << terms
      objects.concat(terms)
    }
    goal_pos.each {|pred,*terms|
      start_hash[pred]
      objects.concat(terms)
    }
    goal_not.each {|pred,*terms|
      start_hash[pred]
      objects.concat(terms)
    }
    ordered, *tasks = tasks
    tasks.each {|pred,*terms| objects.concat(terms)}
    # Objects
    objects.uniq!
    objects.each {|i| problem_str << "#{i} = '#{i}'\n"}
    problem_str << "\n#{domain_name.capitalize}.problem(\n  # Start\n  {\n"
    # Start
    start_hash.each_with_index {|(k,v),i|
      if v.empty?
        problem_str << "    '#{k}' => []"
      else
        problem_str << "    '#{k}' => [\n      [" << v.map! {|obj| obj.join(', ')}.join("],\n      [") << "]\n    ]"
      end
      problem_str << ",\n" if start_hash.size.pred != i
    }
    # Tasks
    group = []
    tasks.each {|t| group << "    ['#{t.first}'#{', ' if t.size > 1}#{t.drop(1).join(', ')}]"}
    problem_str << "\n  },\n  # Tasks\n  [\n" << group .join(",\n") << "\n  ],\n  # Debug\n  ARGV.first == '-d'"
    if ordered
      problem_str << "\n)"
    else
      group.clear
      goal_pos.each {|g| group << "    ['#{g.first}', #{g.drop(1).join(', ')}]"}
      problem_str << ",\n  # Positive goals\n  [\n" << group.join(",\n") << "\n  ],\n  # Negative goals\n  [\n"
      group.clear
      goal_not.each {|g| group << "    ['#{g.first}', #{g.drop(1).join(', ')}]"}
      problem_str << group.join(",\n") << "\n  ]\n)"
    end
  end
end