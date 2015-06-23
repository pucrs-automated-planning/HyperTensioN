module JSHOP_Compiler
  extend self

  SPACER = '-' * 30

  #-----------------------------------------------
  # Predicates to JSHOP
  #-----------------------------------------------

  def predicates_to_jshop(output, group, group_not = [])
    if group.empty? and group_not.empty?
      output << "    nil\n"
    else
      output << "    (\n"
      group.each {|pre| output << "      (#{pre.join(' ')})\n"}
      group_not.each {|pre| output << "      (not (#{pre.join(' ')}))\n"}
      output << "    )\n"
    end
  end

  #-----------------------------------------------
  # Subtasks to JSHOP
  #-----------------------------------------------

  def subtasks_to_jshop(output, tasks, operators, indentation)
    if tasks.empty?
      output << "#{indentation}nil\n"
    else
      output << "#{indentation}(\n"
      tasks.each {|t| output << "#{indentation}  (#{'!' if operators.any? {|op| op.first == t.first}}#{t.join(' ')})\n"}
      output << "#{indentation})\n"
    end
  end

  #-----------------------------------------------
  # Compile domain
  #-----------------------------------------------

  def compile_domain(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not)
    domain_str = "; Generated by Hype\n"
    domain_str << "(defdomain #{domain_name}(\n\n  ;#{SPACER}\n  ; Operators\n  ;#{SPACER}\n\n"
    # Operators
    operators.each {|op|
      # Header
      domain_str << "  (:operator (!#{op.first} #{op[1].join(' ')})\n"
      # Preconditions
      predicates_to_jshop(domain_str, op[2], op[3])
      # Delete effects
      predicates_to_jshop(domain_str, op[5])
      # Add effects
      predicates_to_jshop(domain_str, op[4])
      domain_str << "  )\n\n"
    }
    # Methods
    domain_str << "  ;#{SPACER}\n  ; Methods\n  ;#{SPACER}\n\n"
    methods.each {|met|
      header = "  (:method (#{met.first} #{met[1].join(' ')})\n"
      met.drop(2).each {|met_decompose|
        # Header and label
        domain_str << header << "    #{met_decompose.first}\n"
        # Preconditions
        predicates_to_jshop(domain_str, met_decompose[2], met_decompose[3])
        # Subtasks
        subtasks_to_jshop(domain_str, met_decompose[4], operators, '    ')
        domain_str << "  )\n\n"
      }
    }
    domain_str << '))'
  end

  #-----------------------------------------------
  # Compile problem
  #-----------------------------------------------

  def compile_problem(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not, domain_filename)
    # Start
    problem_str = "; Generated by Hype\n(defproblem #{problem_name} #{domain_name}\n\n  ;#{SPACER}\n  ; Start\n  ;#{SPACER}\n\n  (\n"
    state.each {|pre| problem_str << "    (#{pre.first} #{pre.drop(1).join(' ')})\n"}
    # Tasks
    problem_str << "  )\n\n  ;#{SPACER}\n  ; Tasks\n  ;#{SPACER}\n\n"
    subtasks_to_jshop(problem_str, tasks, operators, '  ')
    problem_str << ")\n"
  end
end