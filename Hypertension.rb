#!/usr/bin/env ruby
#-----------------------------------------------
# HyperTensioN
#-----------------------------------------------
# Mau Magnaguagno
#-----------------------------------------------
# Require this module to use
#-----------------------------------------------
# HTN planner
#-----------------------------------------------

module Hypertension
  extend self

  attr_accessor :domain, :state, :debug

  #-----------------------------------------------
  # Planning
  #-----------------------------------------------

  def planning(tasks, level = 0)
    return [] if tasks.empty?
    case decomposition = @domain[(current_task = tasks.shift).first]
    # Operator (true: visible, false: invisible)
    when true, false
      puts "#{'  ' * level}#{current_task.first}(#{current_task.drop(1).join(',')})" if @debug
      old_state = @state
      # If operator applied
      if send(*current_task)
        # Keep decomposing the hierarchy
        if plan = planning(tasks, level)
          # Add visible operators to plan
          return decomposition ? plan.unshift(current_task) : plan
        end
        @state = old_state
      end
    # Method
    when Array
      # Keep decomposing the hierarchy
      task_name = current_task.shift
      level += 1
      decomposition.each {|method|
        puts "#{'  ' * level.pred}#{method}(#{current_task.join(',')})" if @debug
        # Every unification is tested
        send(method, *current_task) {|subtasks| return plan if plan = planning(subtasks.concat(tasks), level)}
      }
      current_task.unshift(task_name)
    # Error
    else raise "Domain defines no decomposition for #{current_task.first}"
    end
    nil
  end

  #-----------------------------------------------
  # Applicable?
  #-----------------------------------------------

  def applicable?(precond_pos, precond_not)
    # All positive preconditions and no negative preconditions are found in the state
    precond_pos.all? {|name,*objs| @state[name].include?(objs)} and precond_not.none? {|name,*objs| @state[name].include?(objs)}
  end

  #-----------------------------------------------
  # Apply
  #-----------------------------------------------

  def apply(effect_add, effect_del)
    # Create new state with added or deleted predicates
    @state = Marshal.load(Marshal.dump(@state))
    effect_del.each {|name,*objs| @state[name].delete(objs)}
    effect_add.each {|name,*objs| @state[name] << objs}
    true
  end

  #-----------------------------------------------
  # Apply operator
  #-----------------------------------------------

  def apply_operator(precond_pos, precond_not, effect_add, effect_del)
    # Apply effects if preconditions satisfied
    apply(effect_add, effect_del) if applicable?(precond_pos, precond_not)
  end

  #-----------------------------------------------
  # Generate
  #-----------------------------------------------

  def generate(precond_pos, precond_not, *free)
    # Free variable to set of values
    objects = free.map {|i| [i]}
    # Unification by positive preconditions
    match_objects = []
    precond_pos.each {|name,*terms|
      next unless terms.include?('')
      # Swap free variables with matching set or maintain constant term
      terms.map! {|p| objects.find {|j| j.first.equal?(p)} || p}
      # Compare with current state
      @state[name].each {|objs|
        next unless terms.each_with_index {|t,i|
          # Free variable
          if t.instance_of?(Array)
            # Not unified
            if t.first.empty?
              match_objects.push(t, i)
            # No match with previous unification
            elsif not t.include?(objs[i])
              match_objects.clear
              break
            end
          # No match with value
          elsif t != objs[i]
            match_objects.clear
            break
          end
        }
        # Add values to sets
        match_objects.shift << objs[match_objects.shift] until match_objects.empty?
      }
      # Unification closed
      terms.each {|i| i.first.replace('X') if i.instance_of?(Array) and i.first.empty?}
    }
    # Remove pointer and duplicates
    objects.each {|i|
      i.shift
      return if i.empty?
      i.uniq!
    }
    # Depth-first search
    stack = []
    level = obj = 0
    while level
      # Replace pointer value with useful object to affect variables
      free[level].replace(objects[level][obj])
      if level != free.size.pred
        # Stack backjump position
        stack.unshift(level, obj.succ) if obj.succ != objects[level].size
        level += 1
        obj = 0
      else
        yield if applicable?(precond_pos, precond_not)
        # Load next object or restore
        if (obj += 1) == objects[level].size
          level = stack.shift
          obj = stack.shift
        end
      end
    end
  end

  #-----------------------------------------------
  # Print data
  #-----------------------------------------------

  def print_data(data)
    data.each_with_index {|d,i| puts "#{i}: #{d.first}(#{d.drop(1).join(', ')})"}
  end

  #-----------------------------------------------
  # Problem
  #-----------------------------------------------

  def problem(start, tasks, debug = false, goal_pos = [], goal_not = [])
    @debug = debug
    @state = start
    puts 'Tasks'.center(50,'-')
    print_data(tasks)
    puts 'Planning'.center(50,'-')
    t = Time.now.to_f
    # Ordered or unordered tasks
    plan = goal_pos.empty? && goal_not.empty? ? planning(tasks) : task_permutations(start, tasks, goal_pos, goal_not)
    puts "Time: #{Time.now.to_f - t}s", 'Plan'.center(50,'-')
    if plan
      if plan.empty?
        puts 'Empty plan'
      else print_data(plan)
      end
    else puts 'Planning failed'
    end
    plan
  rescue Interrupt
    puts 'Interrupted'
  rescue
    puts $!, $@
  end

  #-----------------------------------------------
  # Task permutations
  #-----------------------------------------------

  def task_permutations(state, tasks, goal_pos, goal_not)
    # All permutations are considered
    tasks.permutation {|task_list|
      @state = state
      plan = planning(Marshal.load(Marshal.dump(task_list)))
      return plan if applicable?(goal_pos, goal_not)
    }
    nil
  end
end