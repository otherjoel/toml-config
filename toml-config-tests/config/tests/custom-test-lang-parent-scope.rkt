#lang racket/base

;; Test if reader submodule can see parent module's bindings
;; Uses module* with (require (submod ".."))

(define (valid-title? s)
  (and (string? s)
       (> (string-length s) 0)
       (<= (string-length s) 50)))

(provide valid-title?)

(module* reader toml/config/custom
  (require (submod ".."))
  #:schema ([title string? valid-title? required]
            [port integer? (optional 8080)]))
