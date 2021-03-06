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
      output << '    ('
      group.each {|pre| output << "\n      (#{pre.join(' ')})"}
      group_not.each {|pre| output << "\n      (not (#{pre.join(' ')}))"}
      output << "\n    )\n"
    end
  end

  #-----------------------------------------------
  # Subtasks to JSHOP
  #-----------------------------------------------

  def subtasks_to_jshop(output, tasks, operators, indentation, order = true)
    if tasks.empty?
      output << "#{indentation}nil\n"
    else
      output << "#{indentation}(#{':unordered' unless order}\n"
      tasks.each {|t|
        name = t.first
        t[0] = "!#{name.sub(/^invisible_/,'!')}" if operators.assoc(name)
        output << "#{indentation}  (#{t.join(' ')})\n"
        t[0] = name
      }
      output << "#{indentation})\n"
    end
  end

  #-----------------------------------------------
  # Compile domain
  #-----------------------------------------------

  def compile_domain(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not)
    domain_str = "; Generated by Hype\n"
    domain_str << "(defdomain #{domain_name} (\n\n  ;#{SPACER}\n  ; Operators\n  ;#{SPACER}"
    # Operators
    operators.each {|op|
      # Header
      domain_str << "\n\n  (:operator (!#{op.first.sub(/^invisible_/,'!')} #{op[1].join(' ')})\n"
      # Preconditions
      predicates_to_jshop(domain_str, op[2], op[3])
      # Delete effects
      predicates_to_jshop(domain_str, op[5])
      # Add effects
      predicates_to_jshop(domain_str, op[4])
      domain_str << '  )'
    }
    # Methods
    domain_str << "\n\n  ;#{SPACER}\n  ; Methods\n  ;#{SPACER}"
    methods.each {|met|
      header = "\n\n  (:method (#{met.first} #{met[1].join(' ')})\n    "
      met.drop(2).each {|dec|
        # Header and label
        domain_str << header << "#{dec.first}\n"
        # Preconditions
        predicates_to_jshop(domain_str, dec[2], dec[3])
        # Subtasks
        subtasks_to_jshop(domain_str, dec[4], operators, '    ')
        domain_str << '  )'
      }
    }
    domain_str << "\n))"
  end

  #-----------------------------------------------
  # Compile problem
  #-----------------------------------------------

  def compile_problem(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not, domain_filename)
    # Start
    problem_str = "; Generated by Hype\n(defproblem #{problem_name} #{domain_name}\n\n  ;#{SPACER}\n  ; Start\n  ;#{SPACER}\n\n  "
    if state.empty?
      problem_str << 'nil'
    else
      problem_str << "(\n"
      state.each {|pre,k|
        k.each {|terms|
          problem_str << "    (#{terms.unshift(pre).join(' ')})\n"
          terms.shift
        } if predicates.include?(pre)
      }
      problem_str << '  )'
    end
    # Tasks
    problem_str << "\n\n  ;#{SPACER}\n  ; Tasks\n  ;#{SPACER}\n\n"
    subtasks_to_jshop(problem_str, tasks.drop(1), operators, '  ', tasks.first)
    problem_str << ')'
  end
end