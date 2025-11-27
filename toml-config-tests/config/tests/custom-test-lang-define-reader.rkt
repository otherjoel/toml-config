#lang racket/base

(require toml/config/define-reader)

;; Test using define-toml-reader macro
;; Custom validators defined here are automatically accessible in the schema

(define (valid-title? s)
  (and (string? s)
       (> (string-length s) 0)
       (<= (string-length s) 50)))

(define (valid-port? n)
  (and (integer? n)
       (>= n 1024)
       (<= n 65535)))

;; Need to provide these for (require (submod "..")) to see them
(provide valid-title? valid-port?)

(define-toml-reader
  #:schema ([title string? valid-title? required]
            [port integer? valid-port? (optional 8080)]))
