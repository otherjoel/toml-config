#lang racket/base

(require racket/string)

(provide toml-ref)

;; Variadic convenience function for accessing nested TOML values
;;
;; Arguments can be:
;; - Symbols (possibly dotted): traverse into hash tables
;; - Exact non-negative integers: index into lists
;; - #:default keyword: specify a default value (otherwise errors on missing keys)
;;
;; Examples:
;;   (toml-ref data 'fruit.name)                        ; dotted key
;;   (toml-ref data 'replicas 0 'host)                  ; array indexing
;;   (toml-ref data 'replicas 5 'host #:default "n/a")  ; with default
(define (toml-ref toml-data
                  #:default [default (lambda () (error 'toml-ref "key not found"))]
                  . path-args)
  (when (null? path-args)
    (error 'toml-ref "expected at least one path argument"))

  ;; Helper to return default or error
  (define (get-default)
    (if (procedure? default)
        (default)
        default))

  ;; Convert path arguments to a flat list of keys and indices
  (define path
    (apply append
           (for/list ([arg path-args])
             (cond
               [(symbol? arg)
                ;; Split dotted symbols into separate keys
                (map string->symbol (string-split (symbol->string arg) "."))]
               [(exact-nonnegative-integer? arg)
                ;; Keep integers as-is for array indexing
                (list arg)]
               [else
                (error 'toml-ref "invalid path component: ~v (expected symbol or exact non-negative integer)" arg)]))))

  ;; Traverse the path
  (let loop ([data toml-data]
             [remaining-path path])
    (cond
      [(null? remaining-path) data]

      [(hash? data)
       (define key (car remaining-path))
       (if (symbol? key)
           (loop (hash-ref data key get-default)
                 (cdr remaining-path))
           (get-default))]

      [(list? data)
       (define idx (car remaining-path))
       (if (exact-nonnegative-integer? idx)
           (if (< idx (length data))
               (loop (list-ref data idx)
                     (cdr remaining-path))
               (get-default))
           (get-default))]

      ;; Can't traverse further
      [else (get-default)])))