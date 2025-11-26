#lang racket/base

;; Boot module for #lang toml/config
;; Parses TOML files and provides the parsed data as the 'toml binding

(module reader racket/base
  (require racket/port racket/string toml)

  (provide read-syntax)

  (define (read-syntax src in)
    (define toml-str (port->string in))
    ;; Normalize NBSP (U+00A0 / Unicode C2A0) to regular space
    ;; This fixes issues with Scribble's @codeblock inserting NBSP on empty lines
    (define normalized-str (string-replace toml-str "\u00A0" " "))
    (let ([toml-data
           (with-handlers ([exn:fail? (lambda (e)
                                        (raise-syntax-error
                                         'toml/config
                                         (format "TOML parse error: ~a" (exn-message e))
                                         #f))])
             (parse-toml normalized-str))])
      (datum->syntax
       #f
       `(module toml-config-mod racket/base
          (provide toml)
          (define toml ',toml-data))))))
