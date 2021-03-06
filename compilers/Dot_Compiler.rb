module Dot_Compiler
  extend self

  #-----------------------------------------------
  # Predicates to DOT
  #-----------------------------------------------

  def predicates_to_dot(output, group, group_not)
    group.each {|p| output << "(#{p.join(' ')})\\l"}
    group_not.each {|p| output << "not (#{p.join(' ')})\\l"}
  end

  #-----------------------------------------------
  # Compile domain
  #-----------------------------------------------

  def compile_domain(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not, all_connections = true)
    domain_str = "// Generated by Hype\ndigraph \"#{domain_name}\" {\n  nodesep=1.0\n  ranksep=1.0\n  // Operators\n"
    # Operators
    operators.each {|op|
      # Header
      domain_str << "  \"#{op.first}\" [\n    shape=record\n    label=\"{{#{op.first}|#{op[1].join(' ')}}|{"
      # Preconditions
      predicates_to_dot(domain_str, op[2], op[3])
      # Effects
      predicates_to_dot(domain_str << '|', op[4], op[5])
      domain_str << "}}\"\n  ]\n"
    }
    # Methods
    domain_str << "  // Methods\n"
    methods.each {|met|
      method_str = ''
      decompositions = []
      met.drop(2).each_with_index {|dec,i|
        decompositions << "<n#{i}>#{met.first}_#{dec.first}"
        # Label
        method_str << "  \"label_#{met.first}_#{dec.first}\" [\n    shape=Mrecord\n    label=\"{{#{met.first}_#{dec.first}|#{dec[1].join(' ')}}|"
        # Preconditions
        predicates_to_dot(method_str, dec[2], dec[3])
        # Subtasks
        connections = ''
        dec[4].each_with_index {|subtask,j|
          method_str << "|<n#{j}>#{subtask.join(' ')}"
          connections << "  \"label_#{met.first}_#{dec.first}\":n#{j} -> \"#{subtask.first}\"\n" if all_connections or operators.assoc(subtask.first)
        }
        # Connections
        method_str << "}\"\n  ]\n  \"#{met.first}\":n#{i} -> \"label_#{met.first}_#{dec.first}\" [style=dotted]\n#{connections}"
      }
      domain_str << "  \"#{met.first}\" [\n    shape=Mrecord\n    style=bold\n    label=\"{{#{met.first}|#{met[1].join(' ')}}|{#{decompositions.join('|')}}}\"\n  ]\n#{method_str}"
    }
    domain_str << '}'
  end

  #-----------------------------------------------
  # Compile problem
  #-----------------------------------------------

  def compile_problem(domain_name, problem_name, operators, methods, predicates, state, tasks, goal_pos, goal_not, domain_filename)
    # TODO graphs for simple relationship between objects (extremely cluttered), maybe only tasks
  end
end