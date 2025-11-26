#lang racket/base

(require rackunit
         toml/validator)

;;; Test that validation is pure and returns new hashes

(test-case "validator returns new hash with defaults"
  (define original (hasheq 'title "Test"))
  (define-toml-schema schema
    [title string? required]
    [port integer? (optional 8080)])

  (define result (schema original))

  (check-false (hash-has-key? original 'port) "original unchanged")
  (check-true (hash-has-key? result 'port) "result has default")
  (check-equal? (hash-ref result 'port) 8080))

(test-case "validator returns original hash when no defaults"
  (define original (hasheq 'title "Test" 'version "1.0"))
  (define-toml-schema schema
    [title string? required]
    [version string? required])

  (define result (schema original))

  (check-eq? result original "same hash when no defaults applied"))

(test-case "nested defaults work correctly"
  (define original (hasheq 'title "Test"
                           'database (hasheq 'host "localhost")))
  (define-toml-schema schema
    [title string? required]
    [database (table
                [host string? required]
                [port integer? (optional 5432)])])

  (define result (schema original))

  (check-false (hash-has-key? (hash-ref original 'database) 'port)
               "original nested table unchanged")
  (check-true (hash-has-key? (hash-ref result 'database) 'port)
              "result nested table has default")
  (check-equal? (hash-ref (hash-ref result 'database) 'port) 5432))

(test-case "structural sharing - unchanged parts reused"
  (define original (hasheq 'title "Test"
                           'unchanged (hasheq 'foo 'bar)))
  (define-toml-schema schema
    [title string? required]
    [port integer? (optional 8080)]
    [unchanged hash? optional])

  (define result (schema original))

  (check-eq? (hash-ref result 'unchanged)
             (hash-ref original 'unchanged)
             "unchanged nested hash is shared"))
