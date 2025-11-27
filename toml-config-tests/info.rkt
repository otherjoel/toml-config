#lang info

(define collection "toml")

(define deps '("base"
               "toml-config-lib"
               "rackunit-lib"))

(define pkg-desc "tests for \"toml-config\"")
(define pkg-authors '("Joel Dueck"))
(define license '(Apache-2.0 OR MIT))

(define compile-omit-paths '("config/tests/fixtures"))
(define test-omit-paths '("config/tests/fixtures"))
