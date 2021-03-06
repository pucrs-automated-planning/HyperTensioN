module Wise
  extend self

  #-----------------------------------------------
  # Apply
  #-----------------------------------------------

  def apply(operators, methods, predicates, state, tasks, goal_pos, goal_not, debug = false)
    puts 'Wise'.center(50,'-') if debug
    # Initial state
    state.reject! {|pre,k|
      # Unused predicate
      if not predicates.include?(pre)
        puts "Initial state contains unused predicates (#{pre} ...): removed" if debug
        true
      else
        # Duplicate predicate
        puts "Initial state contains duplicate predicates (#{pre} ...): removed" if k.uniq! and debug
        # Arity check
        puts "Initial state contains (#{pre} ...) with different arity" if k.any? {|i| i.size != k.first.size} and debug
      end
    }
    # Operators
    noops = []
    operators.reject! {|name,param,precond_pos,precond_not,effect_add,effect_del|
      prefix_variables(opname = "operator #{name}", param, debug)
      define_variables(opname, param, [precond_pos, precond_not, effect_add, effect_del], debug)
      # Precondition contradiction
      (precond_pos & precond_not).each {|pre| puts "#{opname} precondition contains contradicting (#{pre.join(' ')})"} if debug
      # Remove null del effect
      (effect_add & effect_del).each {|pre|
        puts "#{opname} contains null del effect (#{pre.join(' ')}): removed" if debug
        effect_del.delete(pre)
      }
      # Effect contained in precondition
      effect_add.reject! {|pre|
        if precond_pos.include?(pre)
          puts "#{opname} effect (#{pre.join(' ')}) present in precondition: removed" if debug
          true
        end
      }
      effect_del.reject! {|pre|
        if precond_not.include?(pre)
          puts "#{opname} del effect (#{pre.join(' ')}) present in add effect: removed" if debug
          true
        end
      }
      # Unknown previous state of effect
      if debug
        precond_all = precond_pos | precond_not
        (effect_add - precond_all).each {|pre| puts "#{opname} contains side effect (#{pre.join(' ')})"}
        (effect_del - precond_all).each {|pre| puts "#{opname} contains side effect (not (#{pre.join(' ')}))"}
      end
      # Remove noops, invisible operators without preconditions and effects
      if name.start_with?('invisible_') and precond_pos.empty? and precond_not.empty? and effect_add.empty? and effect_del.empty?
        puts "#{opname} is unnecessary: removed" if debug
        noops << name
      end
    }
    # Methods
    methods.each {|name,param,*decompositions|
      prefix_variables(name = "method #{name}", param, debug)
      decompositions.each {|label,free,precond_pos,precond_not,subtasks|
        prefix_variables(label = "#{name} #{label}", free, debug)
        define_variables(label, param + free, [precond_pos, precond_not, subtasks], debug)
        free.reject! {|v|
          if param.include?(v)
            puts "#{label} free variable shadowing parameter #{p}: removed" if debug
            true
          end
        }
        (precond_pos & precond_not).each {|pre| puts "#{label} precondition contains contradicting (#{pre.join(' ')})"} if debug
        verify_tasks("#{label} subtask", subtasks, noops, operators, methods, debug)
      }
    }
    # Tasks
    unless tasks.empty?
      ordered = tasks.shift
      verify_tasks('task', tasks, noops, operators, methods, debug)
      tasks.unshift(ordered)
    end
  end

  #-----------------------------------------------
  # Prefix variables
  #-----------------------------------------------

  def prefix_variables(name, param, debug)
    param.each {|var|
      unless var.start_with?('?')
        puts "#{name} parameter #{var} modified to ?#{var}" if debug
        var.prepend('?')
      end
      raise "#{name} contains invalid #{var}" if var !~ /^\?[a-z_][\w-]*$/
    }
  end

  #-----------------------------------------------
  # Define variables
  #-----------------------------------------------

  def define_variables(name, param, group, debug)
    group.each {|predicates|
      predicates.each {|pre|
        pre.drop(1).each {|term|
          if term.start_with?('?')
            raise "#{name} never declared variable #{term} from (#{pre.join(' ')})" unless param.include?(term)
          elsif param.include?("?#{term}")
            puts "#{name} contains probable variable #{term} from (#{pre.join(' ')}), modifying to ?#{term}" if debug
            term.prepend('?')
          end
        }
      }
    }
  end

  #-----------------------------------------------
  # Verify tasks
  #-----------------------------------------------

  def verify_tasks(name, tasks, noops, operators, methods, debug)
    # Task arity check and noops removal
    tasks.reject! {|task|
      if noops.include?(task.first)
        puts "#{name} #{task.first}: removed" if debug
        true
      elsif t = operators.assoc(task.first) || methods.assoc(task.first)
        raise "#{name} #{task.first} expected #{t[1].size} terms instead of #{task.size.pred}" if t[1].size != task.size.pred
      elsif task.first.start_with?('?')
        puts "#{name} #{task.first} is variable" if debug
      else raise "#{name} #{task.first} is unknown"
      end
    }
  end
end