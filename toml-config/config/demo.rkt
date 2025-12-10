#lang racket/base

(require toml/config/schema racket/contract)

(define-toml-schema demo-schema
  [title string? required]
  [port (integer-in 1 65535) (optional 8080)]
  [render-proc readable-datum? optional])

(provide demo-schema)

(module+ reader
  (require toml/config/private/make-reader)
  (provide read-syntax get-info)

  (define read-syntax (make-toml-syntax-reader demo-schema)))
