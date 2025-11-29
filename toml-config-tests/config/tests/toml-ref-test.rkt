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
(check-equal? (toml-ref test-data 'nonexistent.key #:default "default")
              "default"
              "Should return default value for missing key")

(check-equal? (toml-ref test-data 'fruit.size #:default "medium")
              "medium"
              "Should return default value for missing nested key")

;; Test with default procedure
(check-equal? (toml-ref test-data 'missing.key #:default (lambda () "computed-default"))
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
(check-equal? (toml-ref test-data 'database.ports.invalid #:default "default")
              "default"
              "Should return default when traversing non-hash value")

;; Test variadic array indexing
(define array-data
  (hasheq 'replicas (list (hasheq 'host "replica1.example.com" 'port 5432)
                          (hasheq 'host "replica2.example.com" 'port 5433))
          'fruits (list (hasheq 'name "apple"
                                'varieties (list (hasheq 'name "red delicious")
                                                (hasheq 'name "granny smith")))
                        (hasheq 'name "banana"
                                'varieties (list (hasheq 'name "plantain"))))))

(check-equal? (toml-ref array-data 'replicas 0 'host)
              "replica1.example.com"
              "Should index into array and access field")

(check-equal? (toml-ref array-data 'replicas 1 'port)
              5433
              "Should index into array at position 1")

(check-equal? (toml-ref array-data 'fruits 0 'name)
              "apple"
              "Should access nested array element field")

(check-equal? (toml-ref array-data 'fruits 0 'varieties 1 'name)
              "granny smith"
              "Should handle multiple array indices in path")

(check-equal? (toml-ref array-data 'fruits 1 'varieties 0 'name)
              "plantain"
              "Should navigate complex nested array structure")

;; Test array indexing with defaults
(check-equal? (toml-ref array-data 'replicas 5 'host #:default "fallback")
              "fallback"
              "Should return default for out-of-bounds index")

(check-equal? (toml-ref array-data 'missing 0 'field #:default "default")
              "default"
              "Should return default when array doesn't exist")

;; Test array indexing errors
(check-exn exn:fail?
           (lambda () (toml-ref array-data 'replicas 10 'host))
           "Should error on out-of-bounds without default")

(check-exn exn:fail?
           (lambda () (toml-ref array-data 'database.server 0 'field))
           "Should error when trying to index non-list")
