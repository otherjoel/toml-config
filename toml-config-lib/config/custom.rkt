#lang racket/base

;; Module language and convenience macro for creating custom TOML config readers
;;
;; Usage as module language:
;;   (module reader toml/config/custom
;;     #:schema ([title string? required]
;;               [port integer? (optional 8080)]))

(require (for-syntax racket/base
                     syntax/parse)
         racket/contract)

(provide (rename-out [module-begin #%module-begin])
         ;; Provide common predicates and contracts for use in schemas
         (except-out (all-from-out racket/base) #%module-begin)
         (all-from-out racket/contract))

(define (get-info in mod line col pos)
  (lambda (key default)
    (case key
      [(color-lexer)
       (dynamic-require 'toml/config/lexer 'toml-color-lexer)]
      [else default])))

(define-syntax (module-begin stx)
  (syntax-parse stx
    ;; With schema and optional body (for requires)
    [(_ body:expr ... #:schema (field-spec ...))
     #`(#%plain-module-begin
        (require racket/contract racket/string toml/validator)
        (provide get-info read-syntax)
        body ...
        (define-toml-schema compiled-schema
          field-spec ...)
        (define read-syntax
          (make-toml-syntax-reader compiled-schema)))]

    ;; Without schema, optional body
    [(_ body:expr ...)
     #`(#%plain-module-begin
        (require racket/contract racket/string toml/validator)
        (provide read-syntax get-info)
        body ...
        (define read-syntax
          (make-toml-syntax-reader (lambda (data) data))))]))
