#lang racket/base

(require rackunit
         toml/config/schema
         racket/contract)

;;; Test that error messages are informative and helpful

(define-toml-schema test-schema
  [title string? required]
  [port (integer-in 1 65535) required]
  [tags (listof string?) optional]
  [database (table
              [host string? required]
              [port integer? required])])

(test-case "error: missing required field shows key path"
  (define data (hasheq 'port 8080))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"title:.*required key is missing" (exn-message e))))
   (lambda () (test-schema data))))

(test-case "error: type mismatch shows expected and actual"
  (define data (hasheq 'title "App" 'port "not-a-number"))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"port:.*type mismatch" (exn-message e))
          (regexp-match? #rx"expected:.*integer between 1 and 65535" (exn-message e))
          (regexp-match? #rx"actual:.*\"not-a-number\"" (exn-message e))))
   (lambda () (test-schema data))))

(test-case "error: out of range shows readable contract"
  (define data (hasheq 'title "App" 'port 99999))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"integer between 1 and 65535" (exn-message e))
          (regexp-match? #rx"99999" (exn-message e))))
   (lambda () (test-schema data))))

(test-case "error: nested table missing shows full path"
  (define data (hasheq 'title "App" 'port 8080
                       'database (hasheq 'host "localhost")))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"database\\.port:.*required key is missing" (exn-message e))))
   (lambda () (test-schema data))))

(test-case "error: table type mismatch is clear"
  (define data (hasheq 'title "App" 'port 8080 'database "not-a-table"))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"database:.*must be a table" (exn-message e))
          (regexp-match? #rx"expected:.*table" (exn-message e))))
   (lambda () (test-schema data))))

(test-case "error: listof contract formatted nicely"
  (define data (hasheq 'title "App" 'port 8080 'tags '("valid" 123)))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"list of.*values" (exn-message e))))
   (lambda () (test-schema data))))

(test-case "error: custom predicate shows name"
  (define (positive? n) (> n 0))
  (define-toml-schema custom-schema
    [count integer? positive? required])
  (define data (hasheq 'count -5))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (regexp-match? #rx"positive\\?" (exn-message e))
          (regexp-match? #rx"-5" (exn-message e))))
   (lambda () (custom-schema data))))

;; Test exception structure
(test-case "exn:fail:toml:validation has key-path field"
  (define data (hasheq 'port 8080))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (equal? (exn:fail:toml:validation-key-path e) '(title))))
   (lambda () (test-schema data))))

(test-case "exn:fail:toml:validation has expected/actual fields"
  (define data (hasheq 'title "App" 'port "wrong"))
  (check-exn
   (lambda (e)
     (and (exn:fail:toml:validation? e)
          (exn:fail:toml:validation-expected e)
          (exn:fail:toml:validation-actual e)))
   (lambda () (test-schema data))))
