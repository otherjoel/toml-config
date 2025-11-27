#lang racket/base

(require rackunit
         toml/config/private/ref)

;; Test basic dotted key access
(define test-data
  (hasheq 'fruit (hasheq 'name "apple"
                         'color "red")
          'database (hasheq 'server "192.168.1.1"
                            'ports (list 8000 8001 8002)
                            'connection_max 5000
                            'enabled #t)))

(check-equal? (toml-ref test-data 'fruit.name)
              "apple"
              "Should access nested value with dotted key")

(check-equal? (toml-ref test-data 'fruit.color)
              "red"
              "Should access nested value with dotted key")

(check-equal? (toml-ref test-data 'database.server)
              "192.168.1.1"
              "Should access deeply nested string value")

(check-equal? (toml-ref test-data 'database.ports)
              '(8000 8001 8002)
              "Should access nested list value")

(check-equal? (toml-ref test-data 'database.connection_max)
              5000
              "Should access nested integer value")

;; Test top-level access (no dots)
(check-equal? (toml-ref test-data 'fruit)
              (hasheq 'name "apple" 'color "red")
              "Should access top-level table")

;; Test with default value
(check-equal? (toml-ref test-data 'nonexistent.key "default")
              "default"
              "Should return default value for missing key")

(check-equal? (toml-ref test-data 'fruit.size "medium")
              "medium"
              "Should return default value for missing nested key")

;; Test with default procedure
(check-equal? (toml-ref test-data 'missing.key (lambda () "computed-default"))
              "computed-default"
              "Should call default procedure for missing key")

;; Test error on missing key (no default)
(check-exn exn:fail?
           (lambda () (toml-ref test-data 'nonexistent.key))
           "Should raise error for missing key without default")

;; Test error on invalid key type
(check-exn exn:fail?
           (lambda () (toml-ref test-data "string-key"))
           "Should raise error for non-symbol key")

;; Test error when traversing non-hash
(check-exn exn:fail?
           (lambda () (toml-ref test-data 'database.ports.invalid))
           "Should raise error when trying to traverse non-hash value")

;; Test with default when traversing non-hash
(check-equal? (toml-ref test-data 'database.ports.invalid "default")
              "default"
              "Should return default when traversing non-hash value")
