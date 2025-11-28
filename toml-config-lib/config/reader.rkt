#lang racket/base

(require racket/contract
         toml/config/private/make-reader)

(provide
 (contract-out
  [make-toml-syntax-reader (-> (-> hash? any/c) (-> any/c input-port? syntax?))]
  [get-info (-> input-port?
                module-path?
                (or/c #f exact-positive-integer?)
                (or/c #f exact-nonnegative-integer?)
                (or/c #f exact-positive-integer?)
                (-> any/c any/c any/c))]))
