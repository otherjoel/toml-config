#lang racket/base

(provide valid-title?)

(define (valid-title? s)
  (and (string? s)
       (> (string-length s) 0)
       (<= (string-length s) 50)))
