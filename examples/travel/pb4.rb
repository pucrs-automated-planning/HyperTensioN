require_relative 'Travel'

plan = Travel.problem(
  # Start
  {
    'at' => [
      ['me', 'home']
    ],
    'cash' => [
      ['me', '20']
    ],
    'owe' => [
      ['me', '0']
    ],
    'distance' => [
      ['home', 'park', '8'],
      ['home', 'friend', '10'],
      ['park', 'home', '8'],
      ['park', 'friend', '2'],
      ['friend', 'home', '10'],
      ['friend', 'park', '2']
    ],
    'connected' => [
      ['home', 'park'],
      ['park', 'home'],
      ['home', 'friend'],
      ['friend', 'home'],
      ['friend', 'park'],
      ['park', 'friend']
    ]
  },
  # Tasks
  [
    ['travel', 'me', 'friend'],
    ['travel', 'me', 'park']
  ],
  # Debug
  ARGV.first == 'debug'
)

# Test
abort('Test failed') if plan != [
  ['walk', 'me', 'home', 'friend'],
  ['walk', 'me', 'friend', 'park']
]