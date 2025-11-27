#lang racket/base

(require racket/string)

(provide toml-ref)

;; Convenience function for accessing nested hash values using dotted keys
;; Example: (toml-ref data 'fruit.name) => (hash-ref (hash-ref data 'fruit) 'name)
(define (toml-ref toml-data key [default (lambda () (error 'toml-ref "key not found: ~a" key))])
  (define keys (map string->symbol (string-split (symbol->string key) ".")))
  (let loop ([data toml-data]
             [remaining-keys keys])
    (cond
      [(null? remaining-keys) data]
      [(hash? data)           (loop (hash-ref data (car remaining-keys) default)
                                    (cdr remaining-keys))]
      [(procedure? default)   (default)]
      [else default])))