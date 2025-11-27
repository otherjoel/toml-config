#lang racket/base

(require toml/config/private/ref)

(provide toml-ref)

;; Boot module for #lang toml/config
;; Parses TOML files and provides the parsed data as the 'toml binding
;; Implemented using toml/config/custom with no schema

(module reader toml/config/custom)


