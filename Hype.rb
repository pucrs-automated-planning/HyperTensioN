module Hype
  extend self

  TEMPLATE_DOMAIN = "
require '../../Hypertension'

module <DOMAIN_NAME>
  include Hypertension
  extend self

  #-----------------------------------------------
  # Domain
  #-----------------------------------------------

  @domain = {
    # Operators<OPERATORS>
    # Methods<METHODS>
  }

  #-----------------------------------------------
  # Operators
  #-----------------------------------------------
<DEFINE_OPERATORS>
  #-----------------------------------------------
  # Methods
  #-----------------------------------------------
<DEFINE_METHODS>end"

  TEMPLATE_PROBLEM = "require './<DOMAIN_FILE>'\n\n# Objects\n<OBJECTS>\n\n<DOMAIN_NAME>.problem(\n  # Start\n  {\n<START>\n  },\n  # Tasks\n  [\n<TASKS>  ]\n)"

  OPERATOR_NAME = 0
  OPERATOR_PREC = 1
  OPERATOR_DEL_EFF = 2
  OPERATOR_ADD_EFF = 3

  METHOD_NAME = 0
  METHOD_PREC  = 1
  METHOD_SUBTAKS = 2

  POS_PRECONDITION = 1
  NEG_PRECONDITION = 2
  ADD_EFFECT = 4
  DEL_EFFECT = 8

  attr_reader :domain_name, :problem_name, :problem_domain, :operators, :methods, :state, :tasks

  #-----------------------------------------------
  # Scan groups
  #-----------------------------------------------

  def scan_groups(str)
    group = ''
    count_paren = 0
    str.each_char {|c|
      case c
      when '('
        if count_paren.zero? and not group.empty?
          yield group
          group = ''
        end
        count_paren += 1
        group << c
      when ')'
        count_paren -= 1
        group << c
        if count_paren.zero?
          yield group
          group = ''
        elsif count_paren < 0
          raise "Unmatched parentheses for #{str}"
        end
      else
        if count_paren.zero?
          if c =~ /\w/
            group << c
          elsif not group.empty?
            yield group
            group = ''
          end
        else group << c
        end
      end
    }
  end

  #-----------------------------------------------
  # Parse operator
  #-----------------------------------------------

  def parse_operator(op)
    operator = Array.new(6)
    counter = OPERATOR_NAME
    scan_groups(op) {|value|
      case counter
      when OPERATOR_NAME
        value.scan(/^\(\s*(.+?)\s*\)$/) {|i|
          i = i.first
          i.gsub!(/[?!]/,'')
          i = i.split
          operator[0] = i.shift
          operator[1] = i
        }
      when OPERATOR_PREC
        operator[2] = pos = []
        operator[3] = neg = []
        value.scan(/^\(\s*(.+?)\s*\)$/) {|i|
          i = i.first
          i.gsub!('?','')
          i.scan(/\(\s*(.+?)\s*\)/) {|j|
            if j.first =~ /^not\s*\(\s*(.+)\s*$/
              neg << $1.split
            else
              pos << j.first.split
            end
          }
        }
      when OPERATOR_DEL_EFF
        operator[5] = del = []
        value.scan(/^\(\s*(.+?)\s*\)$/) {|i|
          i = i.first
          i.gsub!('?','')
          i.scan(/\(\s*(.+?)\s*\)/) {|j| del << j.first.split}
        }
      when OPERATOR_ADD_EFF
        operator[4] = add = []
        value.scan(/^\(\s*(.+?)\s*\)$/) {|i|
          i = i.first
          i.gsub!('?','')
          i.scan(/\(\s*(.+?)\s*\)/) {|j| add << j.first.split}
        }
        @operators << operator
      else raise "Unknow operator group"
      end
      counter += 1
    }
    raise 'Missing operator groups' if counter != OPERATOR_ADD_EFF.succ
  end

  #-----------------------------------------------
  # Parse method
  #-----------------------------------------------

  def parse_method(met)
    method = []
    counter = METHOD_NAME
    label = true
    complete = false
    decompose = nil
    scan_groups(met) {|value|
      case counter
      when METHOD_NAME
        value.scan(/^\(\s*(.+?)\s*\)$/) {|i|
          i = i.first
          i.gsub!(/[?!]/,'')
          i = i.split
          method << i.shift << i
        }
        @methods << method
        counter = METHOD_PREC
      when METHOD_PREC
        complete = false
        # Optional label may appear
        if label
          label = false
          if value =~ /\w+/
            decompose = [value]
            next
          else
            # TODO add numbers as labels for the unlabeled cases
            decompose = ['']
          end
        end
        decompose << (free_variables = []) << (pos = []) << (neg = [])
        value.scan(/^\(\s*(.+?)\s*\)$/) {|i|
          i = i.first
          i.scan(/\(\s*(.+?)\s*\)/) {|j|
            if j.first =~ /^not\s*\(\s*(.+)\s*$/
              proposition = $1.split
              neg << proposition
            else
              proposition = j.first.split
              pos << proposition
            end
            free_variables.push(*proposition.find_all {|i| i.sub!(/^\?/,'') and not method[1].include?(i)})
          }
        }
        free_variables.uniq!
        counter = METHOD_SUBTAKS
      when METHOD_SUBTAKS
        complete = true
        if value != 'nil'
          subtasks = []
          value.gsub!(/[?!]/,'')
          value.scan(/^\(\s*(.+)\s*\)$/)
          $1.scan(/\(\s*(.+?)\s*\)/) {|tasks| subtasks << tasks.first.split}
          decompose << subtasks
        else decompose << []
        end
        method << decompose
        label = true
        counter = METHOD_PREC
      end
    }
  end

  #-----------------------------------------------
  # Parse domain
  #-----------------------------------------------

  def parse_domain(domain_filename)
    description = IO.read(domain_filename)
    description.gsub!(/;.*$|\n/,'')
    if description =~ /^\s*\(\s*defdomain\s+(\w+)\s*\(\s*(.*)\s*\)\s*\)\s*$/
      @operators = []
      @methods = []
      @domain_name = $1
      scan_groups($2) {|group|
        if group =~ /^\s*\(\s*:(operator|method)\s*(.*)\s*\)\s*$/
          case $1
          when 'operator'
            parse_operator($2)
          when 'method'
            parse_method($2)
          end
        else puts "#{group} is not recognized"
        end
      }
    else raise "File #{domain_filename} does not match domain pattern"
    end
  end

  #-----------------------------------------------
  # Parse problem
  #-----------------------------------------------

  def parse_problem(problem_filename)
    description = IO.read(problem_filename)
    description.gsub!(/;.*$|\n/,'')
    if description =~ /^\s*\(\s*defproblem\s+(\w+)\s+(\w+)\s+\(\s*(.+)\s*\)\s*\)\s*$/
      @problem_name = $1
      @problem_domain = $2
      if $3 =~ /(.*)\s*\)\s*\(\s*(.*)/
        state = $1
        tasks = $2
        @state = []
        @tasks = []
        state.scan(/\(\s*(.+?)\s*\)/) {|values| @state << values.first.split}
        tasks.scan(/\(\s*(.+?)\s*\)/) {|values| @tasks << values.first.split}
      else raise 'Problem does not define two groups'
      end
    else raise "File #{problem_filename} does not match problem pattern"
    end
  end

  #-----------------------------------------------
  # Clear
  #-----------------------------------------------

  def clear
    @domain_name = @problem_name = @problem_domain = @operators = @methods = @state = @tasks = nil
  end

  #-----------------------------------------------
  # Propositions to string
  #-----------------------------------------------

  def propositions_to_s(props, joiner)
    props.map {|i| "(#{i.join(' ')})"}.join(joiner)
  end

  #-----------------------------------------------
  # Operators to string
  #-----------------------------------------------

  def operators_to_s
    output = ''
    @operators.each {|op|
      output << "    #{op.first}(#{op[1].join(' ')})\n"
      output << "      Precond positive:\n        #{propositions_to_s(op[2], "\n        ")}\n" unless op[2].empty?
      output << "      Precond negative:\n        #{propositions_to_s(op[3], "\n        ")}\n" unless op[3].empty?
      output << "      Effect positive:\n        #{propositions_to_s(op[4], "\n        ")}\n" unless op[4].empty?
      output << "      Effect negative:\n        #{propositions_to_s(op[5], "\n        ")}\n" unless op[5].empty?
      output << "\n"
    }
    output
  end

  #-----------------------------------------------
  # Methods to string
  #-----------------------------------------------

  def methods_to_s
    output = ''
    @methods.each {|met|
      output << "    #{met.first}(#{met[1].join(' ')})\n"
      met.drop(2).each {|met_decompose|
        output << "      Label: #{met_decompose.first}\n"
        output << "        Free variables:\n          #{met_decompose[1].join("\n          ")}\n" unless met_decompose[1].empty?
        output << "        Precond positive:\n          #{propositions_to_s(met_decompose[2], "\n          ")}\n" unless met_decompose[2].empty?
        output << "        Precond negative:\n          #{propositions_to_s(met_decompose[3], "\n          ")}\n" unless met_decompose[3].empty?
        output << "        Subtasks:\n          #{met_decompose[4].empty? ? 'empty': propositions_to_s(met_decompose[4], "\n          ")}\n"
      }
      output << "\n"
    }
    output
  end

  #-----------------------------------------------
  # To string
  #-----------------------------------------------

  def to_s
"Domain #@domain_name
  Operators:
#{operators_to_s}
  Methods:
#{methods_to_s}
Problem #@problem_name of #@problem_domain
  State:
    #{propositions_to_s(@state, "\n    ")}

  Tasks:
    #{propositions_to_s(@tasks, "\n    ")}"
  end

  #-----------------------------------------------
  # Propositions to Ruby
  #-----------------------------------------------

  def propositions_to_ruby(output, group, start_hash, predicate_type)
    if group.empty?
      output << "\n      []"
    else
      output << "\n      [\n"
      group.each_with_index {|g,i|
        if predicate_type
          @predicates[g.first] = true if @predicates[g.first].nil?
        else
          @predicates[g.first] = false
        end
        start_hash[g.first] ||= []
        output << "        ['#{g.first}', #{g.drop(1).join(', ')}]#{',' if group.size.pred != i}\n"
      }
      output << '      ]'
    end
  end

  #-----------------------------------------------
  # Subtasks to Ruby
  #-----------------------------------------------

  def subtasks_to_ruby(output, subtasks, indentation)
    if subtasks.empty?
      output << "#{indentation}yield []\n"
    else
      output << "#{indentation}yield [\n"
      subtasks.each_with_index {|t,i| output << "#{indentation}  ['#{t.first}'#{t.drop(1).map {|i| ", #{i}"}.join}]#{',' if subtasks.size.pred != i}\n"}
      output << "#{indentation}]\n"
    end
  end

  #-----------------------------------------------
  # Method to Ruby
  #-----------------------------------------------

  def method_to_ruby(test, output, method, start_hash)
    method[1].each {|free| output << "    #{free} = ''\n"}
    output << "    #{test}("
    method[2..3].each_with_index {|group,gi|
      output << "\n      # " << (gi.zero? ? 'True' : 'False') << " preconditions"
      propositions_to_ruby(output, group, start_hash, true)
      output << ',' if gi != 1
    }
    method[1].each {|free| output << ", #{free}"}
    output << "\n    )#{' {' unless method[1].empty?}\n"
    subtasks_to_ruby(output, method[4], '      ')
    output << (method[1].empty? ? "    end\n" : "    }\n")
  end

  #-----------------------------------------------
  # Operators to Ruby
  #-----------------------------------------------

  def operators_to_ruby(decompose, output, start_hash)
    @operators.each_with_index {|op,i|
      decompose << "\n    '#{op.first}' => true#{',' if @operators.size.pred != i or not @methods.empty?}"
      output << "\n  def #{op.first}"
      output << "(#{op[1].join(', ')})" unless op[1].empty?
      output << "\n    apply_operator("
      op[2..5].each_with_index {|group,gi|
        output << "\n      # " << ['True preconditions', 'False preconditions', 'Add effects', 'Del effects'][gi]
        propositions_to_ruby(output, group, start_hash, gi < 2)
        output << ',' if gi != 3
      }
      output << "\n    )\n  end\n"
    }
  end

  #-----------------------------------------------
  # Methods to Ruby
  #-----------------------------------------------

  def methods_to_ruby(decompose, output, start_hash)
    @methods.each_with_index {|met,mi|
      decompose << "\n    '#{met.first}' => [\n"
      met.drop(2).each_with_index {|met_case,i|
        decompose << "      '#{met_case.first}'#{',' if met.size - 3 != i}\n"
        output << "\n  def #{met_case.first}"
        output << "(#{met[1].join(', ')})" unless met[1].empty?
        output << "\n"
        # No Preconditions
        if met_case[2].empty? and met_case[3].empty?
          subtasks_to_ruby(output, met_case[4], '    ')
        # Grounded
        elsif met_case[1].empty?
          method_to_ruby('if applicable?', output, met_case, start_hash)
        # Lifted
        else
          method_to_ruby('generate', output, met_case, start_hash)
        end
        output << "  end\n"
      }
      decompose << "    ]#{',' if @methods.size.pred != mi}"
    }
  end

  #-----------------------------------------------
  # To Ruby
  #-----------------------------------------------

  def to_ruby(domain_filename, problem_filename, folder)
    @predicates = {}
    start_hash = {}
    # Operators
    domain_operators = ''
    domain_define_operators = ''
    operators_to_ruby(domain_operators, domain_define_operators, start_hash)
    # Methods
    domain_methods = ''
    domain_define_methods = ''
    methods_to_ruby(domain_methods, domain_define_methods, start_hash)
    # Domain
    folder = "examples/#{folder}"
    Dir.mkdir(folder) unless Dir.exist?(folder)
    domain_str = TEMPLATE_DOMAIN.dup
    domain_str.sub!('<DOMAIN_NAME>', @domain_name.capitalize)
    domain_str.sub!('<OPERATORS>', domain_operators)
    domain_str.sub!('<METHODS>', domain_methods)
    domain_str.sub!('<DEFINE_OPERATORS>', domain_define_operators)
    domain_str.sub!('<DEFINE_METHODS>', domain_define_methods)
    open("#{folder}/#{domain_filename}.rb", 'w') {|file| file << domain_str}
    # Problem
    start = ''
    objects = []
    @state.each {|i| (start_hash[i.first] ||= []) << i.drop(1)}
    start_hash.each_with_index {|(k,v),i|
      if v.empty?
        start << "    '#{k}' => []"
      else
        start << "    '#{k}' => [\n"
        @predicates[k] = nil unless @predicates.include?(k)
        v.each_with_index {|obj,j|
          start << "      [#{obj.join(', ')}]#{',' if v.size.pred != j}\n"
          objects.push(*obj)
        }
        start << '    ]'
      end
      start << ",\n" if start_hash.size.pred != i
    }
    tasks = ''
    @tasks.each_with_index {|t,i| tasks << "    ['#{t.first}', #{t.drop(1).join(', ')}]#{',' if @tasks.size.pred != i}\n"}
    objects.uniq!
    problem_str = TEMPLATE_PROBLEM.dup
    problem_str.sub!('<DOMAIN_FILE>', domain_filename)
    problem_str.sub!('<DOMAIN_NAME>', @domain_name.capitalize)
    problem_str.sub!('<START>', start)
    problem_str.sub!('<TASKS>', tasks)
    problem_str.sub!('<OBJECTS>', objects.map! {|i| "#{i} = '#{i}'"}.join("\n"))
    open("#{folder}/#{problem_filename}.rb", 'w') {|file| file << problem_str}
  end

  # TODO include this method during parsing, move @predicates outside loop
  def classify_predicates(operator)
    @predicates = Hash.new {|h,k| h[k] = 0}
    operator[2].each {|propositions| propositions.each {|predicate,*terms| @predicate[predicate] |= POS_PRECONDITION}}
    operator[3].each {|propositions| propositions.each {|predicate,*terms| @predicate[predicate] |= NEG_PRECONDITION}}
    operator[4].each {|propositions| propositions.each {|predicate,*terms| @predicate[predicate] |= ADD_EFFECT}}
    operator[5].each {|propositions| propositions.each {|predicate,*terms| @predicate[predicate] |= DEL_EFFECT}}
  end
end

#-----------------------------------------------
# Main
#-----------------------------------------------

if $0 == __FILE__
  begin
    if ARGV.size.between?(2,3)
      if not File.exist?(ARGV.first)
        puts "File not found: #{ARGV.first}!"
      elsif not File.exist?(ARGV[1])
        puts "File not found: #{ARGV[1]}!"
      else
        t = Time.now.to_f
        Hype.parse_domain(ARGV.first)
        Hype.parse_problem(ARGV[1])
        puts Hype.to_s
        Hype.to_ruby(*ARGV) if ARGV[2]
        p Time.now.to_f - t
      end
    else
      puts "Use #$0 domain_filename problem_filename [output_folder]"
    end
  rescue
    puts $!, $@
    STDIN.gets
  end
end
