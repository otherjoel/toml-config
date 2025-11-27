#lang racket/base

;; Test boot module using toml/config/custom with require for custom validators

(module reader toml/config/custom
  (require "../../validators.rkt")

  #:schema ([title string? valid-title? required]
            [port integer? (optional 8080)]))
