#lang info

(define collection 'multi)

(define deps '("toml-config-lib"
               "toml-config-doc"))
(define implies '("toml-config-lib"
                  "toml-config-doc"))
(define scribblings '(("scribblings/toml-config.scrbl" () (parsing-library))))
(define pkg-desc "A #lang for validating TOML files")
(define version "0.1")
(define pkg-authors '("Joel Dueck"))
(define license '(Apache-2.0 OR MIT))
