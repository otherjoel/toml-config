#lang racket/base

;; Test boot module using toml/config/custom with module+ pattern
;; Custom validators defined in main module, accessible to reader submodule

(define (valid-title? s)
  (and (string? s)
       (> (string-length s) 0)
       (<= (string-length s) 50)))

(define (valid-port? n)
  (and (integer? n)
       (>= n 1024)
       (<= n 65535)))

(module+ reader
  (require toml/config/schema
           toml/config/reader)
  (provide read-syntax get-info)

  (define-toml-schema compiled-schema
    [title string? valid-title? required]
    [port integer? valid-port? (optional 8080)])

  (define read-syntax
    (make-toml-syntax-reader compiled-schema)))
