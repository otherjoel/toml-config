#lang racket/base

(require rackunit
         racket/contract
         toml/config/schema
         toml/config/reader)

;;; Basic Schema Validation Tests

(define-toml-schema simple-schema
  [title string? required]
  [version string? required])

(test-case "simple-schema: valid data"
  (define data (hasheq 'title "Test" 'version "1.0"))
  (check-not-exn (lambda () (simple-schema data))))

(test-case "simple-schema: missing required field"
  (define data (hasheq 'title "Test"))
  (check-exn exn:fail:toml:validation?
             (lambda () (simple-schema data))))

(test-case "simple-schema: wrong type"
  (define data (hasheq 'title 123 'version "1.0"))
  (check-exn exn:fail:toml:validation?
             (lambda () (simple-schema data))))

;;; Optional Fields with Defaults

(define-toml-schema with-defaults-schema
  [title string? required]
  [port integer? (optional 8080)])

(test-case "with-defaults: default applied when missing"
  (define data (hasheq 'title "Test"))
  (define result (with-defaults-schema data))
  (check-equal? (hash-ref result 'port) 8080))

(test-case "with-defaults: explicit value preserved"
  (define data (hasheq 'title "Test" 'port 3000))
  (define result (with-defaults-schema data))
  (check-equal? (hash-ref result 'port) 3000))

(test-case "with-defaults: wrong type for optional field"
  (define data (hasheq 'title "Test" 'port "not-a-number"))
  (check-exn exn:fail:toml:validation?
             (lambda () (with-defaults-schema data))))

;;; Optional Fields without Defaults

(define-toml-schema with-optional-schema
  [title string? required]
  [description string? optional])

(test-case "with-optional: missing optional field is OK"
  (define data (hasheq 'title "Test"))
  (check-not-exn (lambda () (with-optional-schema data))))

(test-case "with-optional: present optional field validated"
  (define data (hasheq 'title "Test" 'description 123))
  (check-exn exn:fail:toml:validation?
             (lambda () (with-optional-schema data))))

;;; Multiple Type Predicates

(define (port-range? n)
  (and (>= n 1) (<= n 65535)))

(define-toml-schema multi-validator-schema
  [port integer? port-range? required])

(test-case "multi-validator: all predicates pass"
  (define data (hasheq 'port 8080))
  (check-not-exn (lambda () (multi-validator-schema data))))

(test-case "multi-validator: first predicate fails"
  (define data (hasheq 'port "8080"))
  (check-exn exn:fail:toml:validation?
             (lambda () (multi-validator-schema data))))

(test-case "multi-validator: second predicate fails"
  (define data (hasheq 'port 99999))
  (check-exn exn:fail:toml:validation?
             (lambda () (multi-validator-schema data))))

;;; Contracts as Type Specs

(define-toml-schema contract-schema
  [port (integer-in 1 65535) required]
  [tags (listof string?) optional])

(test-case "contract: integer-in passes"
  (define data (hasheq 'port 8080))
  (check-not-exn (lambda () (contract-schema data))))

(test-case "contract: integer-in fails (out of range)"
  (define data (hasheq 'port 99999))
  (check-exn exn:fail:toml:validation?
             (lambda () (contract-schema data))))

(test-case "contract: listof passes"
  (define data (hasheq 'port 8080 'tags '("web" "api")))
  (check-not-exn (lambda () (contract-schema data))))

(test-case "contract: listof fails"
  (define data (hasheq 'port 8080 'tags '("web" 123)))
  (check-exn exn:fail:toml:validation?
             (lambda () (contract-schema data))))

;;; Nested Tables

(define-toml-schema nested-schema
  [title string? required]
  [database (table
              [host string? required]
              [port integer? required])])

(test-case "nested: valid nested table"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost" 'port 5432)))
  (check-not-exn (lambda () (nested-schema data))))

(test-case "nested: missing nested table"
  (define data (hasheq 'title "App"))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

(test-case "nested: nested table is not a hash"
  (define data (hasheq 'title "App" 'database "not-a-table"))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

(test-case "nested: missing field in nested table"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost")))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

;;; Procedural Validation

(define simple-proc-validator
  (lambda (toml-data)
    (unless (hash-has-key? toml-data 'title)
      (validation-error '() "missing title field"))
    (unless (string? (hash-ref toml-data 'title))
      (validation-error '(title) "must be a string"))))

(test-case "procedural: valid data"
  (define data (hasheq 'title "Test"))
  (check-not-exn (lambda () (simple-proc-validator data))))

(test-case "procedural: validation fails"
  (define data (hasheq 'title 123))
  (check-exn exn:fail:toml:validation?
             (lambda () (simple-proc-validator data))))

;;; make-toml-syntax-reader

(test-case "make-toml-syntax-reader: requires procedure"
  (check-exn exn:fail?
             (lambda () (make-toml-syntax-reader "not-a-proc"))))

(test-case "make-toml-syntax-reader: returns procedure"
  (define reader (make-toml-syntax-reader simple-proc-validator))
  (check-pred procedure? reader))
