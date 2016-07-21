require './tests/hypest'

class Frenesi < Test::Unit::TestCase
  include Hypest

  #-----------------------------------------------
  # Extension
  #-----------------------------------------------

  def test_different_extensions
    e = assert_raises(RuntimeError) {Hype.parse('a.pddl','b.jshop')}
    assert_equal('Incompatible extensions between domain and problem', e.message)
  end

  def test_unknown_extension
    e = assert_raises(RuntimeError) {Hype.parse('a.blob','b.blob')}
    assert_equal('Unknown file extension .blob', e.message)
    e = assert_raises(RuntimeError) {Hype.parse('a','b')}
    assert_equal('Unknown file extension ', e.message)
  end

  #-----------------------------------------------
  # Parsing
  #-----------------------------------------------

  def test_basic_jshop_parsing
    parser_tests(
      # Files
      './examples/basic/basic.jshop',
      './examples/basic/pb1.jshop',
      # Parser and extensions
      JSHOP_Parser, [],
      # Attributes
      :domain_name => 'basic',
      :problem_name => 'pb1',
      :operators => [
        ['pickup', ['?a'],
          # Preconditions
          [],
          [],
          # Effects
          [['have', '?a']],
          []
        ],
        ['drop', ['?a'],
          # Preconditions
          [['have', '?a']],
          [],
          # Effects
          [],
          [['have', '?a']]
        ]
      ],
      :methods => [
        ['swap', ['?x', '?y'],
          ['swap_0',
            # Preconditions
            [],
            [['have', '?x']],
            # Effects
            [['have', '?y']],
            [['drop', '?x'], ['pickup', '?y']]
          ],
          ['swap_1',
            # Preconditions
            [],
            [['have', '?y']],
            # Effects
            [['have', '?x']],
            [['drop', '?y'], ['pickup', '?x']]
          ]
        ]
      ],
      :predicates => {'have' => true},
      :state => [['have','kiwi']],
      :tasks => [true, ['swap', 'banjo', 'kiwi']],
      :goal_pos => [],
      :goal_not => []
    )
  end

  def test_basic_pddl_parsing
    parser_tests(
      # Files
      './examples/basic/basic.pddl',
      './examples/basic/pb1.pddl',
      # Parser and extensions
      PDDL_Parser, [],
      # Attributes
      :domain_name => 'basic',
      :problem_name => 'pb1',
      :operators => [
        ['pickup', ['?a'],
          # Preconditions
          [],
          [['have', '?a']],
          # Effects
          [['have', '?a']],
          []
        ],
        ['drop', ['?a'],
          # Preconditions
          [['have', '?a']],
          [],
          # Effects
          [],
          [['have', '?a']]
        ]
      ],
      :methods => [],
      :predicates => {'have' => true},
      :state => [],
      :tasks => [],
      :goal_pos => [['have', 'banjo']],
      :goal_not => []
    )
  end

  #-----------------------------------------------
  # Compilation
  #-----------------------------------------------

  def test_basic_jshop_compile_to_pddl
    compiler_tests(
      # Files
      './examples/basic/basic.jshop',
      './examples/basic/pb1.jshop',
      # Parser, extensions and output
      JSHOP_Parser, [], 'pddl',
      # Domain
'; Generated by Hype
(define (domain basic)
  (:requirements :strips)

  (:predicates
    (have ?a)
  )

  (:action pickup
    :parameters (?a)
    :precondition (and
    )
    :effect (and
      (have ?a)
    )
  )

  (:action drop
    :parameters (?a)
    :precondition (and
      (have ?a)
    )
    :effect (and
      (not (have ?a))
    )
  )
)',
      # Problem
'; Generated by Hype
(define (problem pb1)
  (:domain basic)
  (:requirements :strips)
  (:objects
    kiwi banjo
  )
  (:init
    (have kiwi)
  )
  (:goal (and
  ))
)'
    )
  end
end
