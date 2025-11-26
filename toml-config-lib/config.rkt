#lang racket/base

;; Boot module for #lang toml/config
;; Parses TOML files and provides the parsed data as the 'toml binding

(module reader racket/base
  (require racket/port toml)

  (provide read-syntax)

  (define (read-syntax src in)
    (define toml-str (port->string in))
    (define toml-data
      (with-handlers ([exn:fail? (lambda (e)
                                   (raise-syntax-error
                                    'toml/config
                                    (format "TOML parse error: ~a" (exn-message e))
                                    #f))])
        (parse-toml toml-str)))
    (datum->syntax
     #f
     `(module toml-config-mod racket/base
        (provide toml)
        (define toml ',toml-data)))))

;; Main module body (if this file is required as a library)
;; Re-export the toml package for convenience
(require toml)
(provide (all-from-out toml))
