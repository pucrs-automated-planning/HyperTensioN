module Hyper_Compiler
  extend self

  SPACER = '-' * 47

  #-----------------------------------------------
  # Propositions to Hyper
  #-----------------------------------------------

  def propositions_to_hyper(output, group)
    if group.empty?
      output << "\n      []"
    else
      output << "\n      [\n"
      group.each_with_index {|g,i| output << "        [#{g.map {|i| i =~ /^\?/ ? i.sub(/^\?/,'') : "'#{i}'"}.join(', ')}]#{',' if group.size.pred != i}\n"}
      output << '      ]'
    end
  end

  #-----------------------------------------------
  # Subtasks to Hyper
  #-----------------------------------------------

  def subtasks_to_hyper(output, subtasks, indentation)
    if subtasks.empty?
      output << "#{indentation}yield []\n"
    else
      output << "#{indentation}yield [\n"
      subtasks.each_with_index {|t,i| output << "#{indentation}  [#{t.map {|i| i =~ /^\?/ ? i.sub(/^\?/,'') : "'#{i}'"}.join(', ')}]#{',' if subtasks.size.pred != i}\n"}
      output << "#{indentation}]\n"
    end
  end

  #-----------------------------------------------
  # Compile domain
  #-----------------------------------------------

  def compile_domain(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not)
    domain_str = "# Generated by Hype\nrequire '../../Hypertension'\n\nmodule #{domain_name.capitalize}\n  include Hypertension\n  extend self\n\n"
    domain_str << "  ##{SPACER}\n  # Domain\n  ##{SPACER}\n\n  @domain = {\n    # Operators"
    # Operators
    define_operators = ''
    operators.each_with_index {|op,i|
      domain_str << "\n    '#{op.first}' => true#{',' if operators.size.pred != i or not methods.empty?}"
      define_operators << "\n  def #{op.first}#{"(#{op[1].map {|i| i.sub(/^\?/,'')}.join(', ')})" unless op[1].empty?}\n    apply_operator("
      propositions_to_hyper(define_operators << "\n      # True preconditions", op[2])
      propositions_to_hyper(define_operators << ",\n      # False preconditions", op[3])
      propositions_to_hyper(define_operators << ",\n      # Add effects", op[4])
      propositions_to_hyper(define_operators << ",\n      # Del effects", op[5])
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
          propositions_to_hyper(define_methods << "\n      # True preconditions", met_case[2])
          propositions_to_hyper(define_methods << ",\n      # False preconditions", met_case[3])
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
    problem_str = "# Generated by Hype\nrequire './#{domain_filename}'\n\n# Objects\n"
    # Extract information
    objects = []
    start_hash = {}
    predicates.each_key {|i| start_hash[i] = []}
    state.each {|pred,*terms|
      start_hash[pred] << terms
      objects.push(*terms)
    }
    tasks.each {|pred,*terms| objects.push(*terms)}
    # Objects
    objects.uniq!
    objects.each {|i| problem_str << "#{i} = '#{i}'\n"}
    problem_str << "\n#{domain_name.capitalize}.problem(\n  # Start\n  {\n"
    # Start
    start_hash.each_with_index {|(k,v),i|
      if v.empty?
        problem_str << "    '#{k}' => []"
      else
        problem_str << "    '#{k}' => [\n"
        v.each_with_index {|obj,j| problem_str << "      [#{obj.join(', ')}]#{',' if v.size.pred != j}\n"}
        problem_str << '    ]'
      end
      problem_str << ",\n" if start_hash.size.pred != i
    }
    # Tasks
    problem_str << "\n  },\n  # Tasks\n  [\n"
    tasks.each_with_index {|t,i| problem_str << "    ['#{t.first}', #{t.drop(1).join(', ')}]#{',' if tasks.size.pred != i}\n"}
    problem_str << "  ],\n  # Debug\n  ARGV.first == '-d'\n)"
  end
end
