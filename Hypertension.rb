#!/usr/bin/env ruby
#-----------------------------------------------
# HyperTensioN
#-----------------------------------------------
# Mau Magnaguagno
#-----------------------------------------------
# Require this module to use
#-----------------------------------------------
# HTN planner based on PyHop
#-----------------------------------------------
# Mar 2014
# - Converted PyHop to Ruby
# - Data structures modified
# Jun 2014
# - converted ND_PyHop to Ruby
# - Data structures modified
# - Using previous state for state_valuation
# - Added support for minimum probability
# - Data structure simplified
# - Override state_valuation and state_copy for specific purposes
# Dec 2014
# - Forked project, probability mode only works for Hypertension_simple
# - STRIPS style operator application instead of imperative mode
# - Backtrack support
# - Operator visibility
# - Unification
# - Plan is built after tasks solved
# - Domain and problem separated
# - Deep copy only used at operator application
#-----------------------------------------------
# TODOs
# - Write parser
# - Testing (more problems, level testing)
# - Unordered tasks
# - Anytime mode
#-----------------------------------------------

module Hypertension
  extend self

  attr_accessor :domain, :debug

  #-----------------------------------------------
  # Planning
  #-----------------------------------------------

  def planning(tasks, level = 0)
    return [] if tasks.empty?
    current_task = tasks.first
    decompose = @domain[current_task.first]
    case decompose
    # Operator (true: visible, false: invisible)
    when true, false
      puts "#{'  ' * level}#{current_task.first}(#{current_task.drop(1).join(', ')})" if @debug
      old_state = @state
      # If operator applied
      if send(*current_task)
        # Keep decomposing the hierarchy
        plan = planning(tasks.drop(1), level)
        if plan
          # Some actions are not visible
          plan.unshift(current_task) if decompose
          return plan
        end
        @state = old_state
      end
    # Method
    when Array
      # Keep decomposing the hierarchy
      current_task = current_task.drop(1)
      tasks = tasks.drop(1)
      decompose.each {|method|
        puts "#{'  ' * level}#{method}(#{current_task.join(', ')})" if @debug
        # Every unification is tested
        send(method, *current_task) {|subtasks|
          plan = planning(subtasks.push(*tasks), level.succ)
          return plan if plan
        }
      }
    # Error
    else raise "Decomposition problem with #{current_task.first}"
    end
    false
  end

  #-----------------------------------------------
  # Applicable?
  #-----------------------------------------------

  def applicable?(precond_true, precond_false)
    # All positive preconditions and no negative preconditions are found in the state
    precond_true.all? {|name,*objs| @state[name].include?(objs)} and precond_false.none? {|name,*objs| @state[name].include?(objs)}
  end

  #-----------------------------------------------
  # Apply Operator
  #-----------------------------------------------

  def apply_operator(precond_true, precond_false, effect_add, effect_del)
    # Apply effects on new state if operator applicable
    if applicable?(precond_true, precond_false)
      @state = Marshal.load(Marshal.dump(@state))
      effect_del.each {|name,*objs| @state[name].delete(objs)}
      effect_add.each {|name,*objs| @state[name] << objs}
      true
    end
  end

  #-----------------------------------------------
  # Generate
  #-----------------------------------------------

  def generate(precond_true, precond_false, *free)
    # Free variable to set of values
    objects = free.map {|i| [i]}
    # Unification by true preconditions
    match_objects = []
    precond_true.each {|name,*objs|
      next unless objs.include?('')
      # Swap free variable with set to match
      pred = objs.map {|p| objects.find {|j| j.first.equal?(p)} or p}
      # Compare with current state
      @state[name].each {|v|
        next unless pred.each_with_index {|p,i|
          # Free variable
          if p.instance_of?(Array)
            # Not unified
            if p.first.empty?
              match_objects.push(p, v[i])
            # No match with previous unification
            elsif not p.include?(v[i])
              match_objects.clear
              break
            end
          # No match with value
          elsif v[i] != p
            match_objects.clear
            break
          end
        }
        # Add values to sets
        match_objects.shift << match_objects.shift until match_objects.empty?
      }
      # Unification closed
      pred.each {|i| i.first.replace('X') if i.instance_of?(Array) and i.first.empty?}
    }
    # Remove pointer and duplicates
    objects.each {|i|
      i.shift
      return if i.empty?
      i.uniq!
    }
    # Depth-first search with constraint backtracking
    stack = []
    level = obj = 0
    while level
      # Replace pointer value with usefull object to affect variables
      free[level].replace(objects[level][obj])
      if level != free.size.pred
        # Stack backjump position
        stack.unshift(level.succ,0) if obj.succ != objects[level].size
        level += 1
        obj = 0
      else
        yield if applicable?(precond_true, precond_false)
        # Load next object or restore
        if obj.succ != objects[level].size
          obj += 1
        else
          level = stack.shift
          obj = stack.shift
        end
      end
    end
  end

  #-----------------------------------------------
  # Print Data
  #-----------------------------------------------

  def print_data(data)
    data.each_with_index {|d,i| puts "#{i}: #{d.first}(#{d.drop(1).join(', ')})"}
  end

  #-----------------------------------------------
  # Problem
  #-----------------------------------------------

  def problem(start, tasks, debug = false)
    setup if respond_to?(:setup)
    # Debug information
    @debug = debug
    # Planning
    puts 'Tasks'.center(50,'-')
    print_data(tasks)
    puts 'Planning'.center(50,'-')
    t = Time.now.to_f
    @state = start
    plan = planning(tasks)
    puts "Time: #{Time.now.to_f - t}s", 'Plan'.center(50,'-')
    if plan
      print_data(plan)
    else puts 'Planning failed'
    end
  rescue Interrupt
    puts 'Interrupted'
  rescue
    puts $!, $@
    STDIN.gets
  end
end