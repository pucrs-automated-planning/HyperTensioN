(define (problem pb6)
  (:domain robby)
  (:objects
    robby - robot
    h1 h2 h3 h4 h5 h6 h7 - hallway
    r1 r2 r3 r4 - room
    b1 b2 b3 - beacon
  )
  (:init
    (at robby r2)
    (in b1 h1)
    (in b2 h6)
    (in b3 h2)
    (connected h1 r1) (connected r1 h1)
    (connected r1 h2) (connected h2 r1)
    (connected h2 h5) (connected h5 h2)
    (connected h5 r2) (connected r2 h5)
    (connected h2 r2) (connected r2 h2)
    (connected r2 h4) (connected h4 r2)
    (connected h4 h3) (connected h3 h4)
    (connected h3 r3) (connected r3 h3)
    (connected h5 h7) (connected h7 h5)
    (connected h7 h6) (connected h6 h7)
    (connected h6 r4) (connected r4 h6)
    (connected r4 h4) (connected h4 r4)
  )
  (:goal (and
    (at robby r3)
    (reported robby b1)
    (reported robby b2)
    (reported robby b3)
  ))
)