#lang racket/base

;; Test boot module using toml/config/custom

(module reader toml/config/custom
  #:schema ([title non-empty-string? required]
            [port integer? (optional 8080)]))
