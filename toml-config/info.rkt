#lang info

(define collection "toml")

(define deps '("base"
               "toml-config-lib"))
(define implies '("toml-config-lib"))
(define scribblings '(("scribblings/toml-config.scrbl" () (parsing-library))))
(define pkg-desc "A #lang for validating TOML files")
(define version "0.1")
(define pkg-authors '("Joel Dueck"))
(define license '(Apache-2.0 OR MIT))
(define build-deps '("gregor-doc"
                     "gregor-lib"
                     "racket-doc"
                     "scribble-lib"
                     "toml-doc"
                     "toml-lib"))
