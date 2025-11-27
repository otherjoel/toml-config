#lang racket/base

;; Test using module* with #f to access parent bindings

(define (valid-title? s)
  (and (string? s)
       (> (string-length s) 0)
       (<= (string-length s) 50)))

(provide valid-title?)

(module* reader toml/config/custom
  (require (submod ".."))
  #:schema ([title string? valid-title? required]
            [port integer? (optional 8080)]))
