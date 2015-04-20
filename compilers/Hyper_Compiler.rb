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
      group.each_with_index {|g,i| output << "        ['#{g.first}', #{g.drop(1).join(', ')}]#{',' if group.size.pred != i}\n"}
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
      subtasks.each_with_index {|t,i| output << "#{indentation}  ['#{t.first}'#{t.drop(1).map {|i| ", #{i}"}.join}]#{',' if subtasks.size.pred != i}\n"}
      output << "#{indentation}]\n"
    end
  end

  #-----------------------------------------------
  # Method to Hyper
  #-----------------------------------------------

  def method_to_hyper(test, output, method)
    method[1].each {|free| output << "    #{free} = ''\n"}
    output << "    #{test}("
    method[2..3].each_with_index {|group,gi|
      output << "\n      # " << (gi.zero? ? 'True' : 'False') << " preconditions"
      propositions_to_hyper(output, group)
      output << ',' if gi != 1
    }
    method[1].each {|free| output << ", #{free}"}
    output << "\n    )#{' {' unless method[1].empty?}\n"
    subtasks_to_hyper(output, method[4], '      ')
    output << (method[1].empty? ? "    end\n" : "    }\n")
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
      define_operators << "\n  def #{op.first}#{"(#{op[1].join(', ')})" unless op[1].empty?}\n    apply_operator("
      op[2..5].each_with_index {|group,gi|
        define_operators << "\n      # " << ['True preconditions', 'False preconditions', 'Add effects', 'Del effects'][gi]
        propositions_to_hyper(define_operators, group)
        define_operators << ',' if gi != 3
      }
      define_operators << "\n    )\n  end\n"
    }
    # Methods
    define_methods = ''
    domain_str << "\n    # Methods"
    methods.each_with_index {|met,mi|
      domain_str << "\n    '#{met.first}' => [\n"
      met.drop(2).each_with_index {|met_case,i|
        domain_str << "      '#{met_case.first}'#{',' if met.size - 3 != i}\n"
        define_methods << "\n  def #{met_case.first}#{"(#{met[1].join(', ')})" unless met[1].empty?}\n"
        # No preconditions
        if met_case[2].empty? and met_case[3].empty?
          subtasks_to_hyper(define_methods, met_case[4], '    ')
        # Grounded
        elsif met_case[1].empty?
          method_to_hyper('if applicable?', define_methods, met_case)
        # Lifted
        else method_to_hyper('generate', define_methods, met_case)
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
    # Extract information
    start = ''
    objects = []
    start_hash = {}
    predicates.each_key {|i| start_hash[i] = []}
    state.each {|i| start_hash[i.first] << i.drop(1)}
    start_hash.each_with_index {|(k,v),i|
      if v.empty?
        start << "    '#{k}' => []"
      else
        start << "    '#{k}' => [\n"
        v.each_with_index {|obj,j|
          start << "      [#{obj.join(', ')}]#{',' if v.size.pred != j}\n"
          objects.push(*obj)
        }
        start << '    ]'
      end
      start << ",\n" if start_hash.size.pred != i
    }
    problem_str = "# Generated by Hype\nrequire './#{domain_filename}'\n\n# Objects\n"
    # Objects
    objects.uniq!
    objects.each {|i| problem_str << "#{i} = '#{i}'\n"}
    # Start
    problem_str << "\n#{domain_name.capitalize}.problem(\n  # Start\n  {\n#{start}\n  },\n  # Tasks\n  [\n"
    # Tasks
    tasks.each_with_index {|t,i| problem_str << "    ['#{t.first}', #{t.drop(1).join(', ')}]#{',' if tasks.size.pred != i}\n"}
    problem_str << "  ]\n)"
  end
end