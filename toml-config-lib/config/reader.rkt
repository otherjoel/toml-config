#lang racket/base

(require racket/contract
         toml/config/private/make-reader)

(provide
 (contract-out
  [make-toml-syntax-reader (-> (-> hash? any/c) (-> any/c input-port? syntax?))]))
