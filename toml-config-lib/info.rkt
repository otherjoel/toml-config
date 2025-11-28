#lang info

(define collection "toml")
(define version "0.1")

(define deps '("br-parser-tools-lib"
               "brag-lib"
               ["base" #:version "8.1"]
               "toml"))

(define pkg-desc "implementation part of \"toml-config\"")
(define pkg-authors '("Joel Dueck"))
(define license '(Apache-2.0 OR MIT))
