(define (problem pb3)
  (:domain basic)
  (:requirements :strips :negative-preconditions)
  (:objects
    kiwi banjo
  )
  (:init
    (have kiwi)
  )
  (:goal
    (and
      (not (have kiwi))
      (have banjo)
    )
  )
)