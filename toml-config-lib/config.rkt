#lang racket/base

(require racket/contract
         toml/config/private/ref)

(provide
 (contract-out
  [toml-ref (->* (hash?)
                 (#:default any/c)
                 #:rest (listof (or/c symbol? exact-nonnegative-integer?))
                 any/c)]))

;; Boot module for #lang toml/config
;; Parses TOML files and provides the parsed data as the 'toml binding
;; Implemented using toml/config/custom with no schema
(module reader toml/config/custom)
