#lang info

(define collection "toml")
(define deps '("base"
               "toml-config-lib"
               "scribble-lib"
               "racket-doc"))

(define build-deps '("rackunit-lib"))

(define scribblings '(("toml-config.scrbl" () (parsing-library))))

(define pkg-desc "documentation part of \"toml-config\"")
(define pkg-authors '("Joel Dueck"))
(define license '(Apache-2.0 OR MIT))
