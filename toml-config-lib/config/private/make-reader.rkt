#lang racket/base

(require racket/port
         racket/string
         syntax/strip-context
         toml
         toml/config/private/validate)

(provide make-toml-syntax-reader)

;;; Reader Helper

(define (make-toml-syntax-reader validator)
  (lambda (src in)
    (port-count-lines! in)
    (define toml-str (string-replace (port->string in) "\u00A0" ""))
    (define toml-data
      (with-handlers ([exn:fail? (λ (e)
                                   (raise-syntax-error 'toml/config
                                     (format "TOML parse error: ~a" (exn-message e))))])
        (parse-toml toml-str)))

    (define validated-data
      (with-handlers ([exn:fail:toml:validation?
                       (λ (e)
                         (raise-syntax-error 'toml/config
                           (format "Validation error: ~a" (exn-message e))))])
        (validator toml-data)))

    (strip-context
      #`(module parsed-toml racket/base
         (provide toml)
         (define toml '#,validated-data)))))