#lang racket/base

(require rackunit
         racket/port
         toml/config/schema
         toml/config/reader)

;;; Test make-toml-syntax-reader Integration

(define-toml-schema app-schema
  [title string? required]
  [version string? required]
  [port integer? (optional 8080)])

(define app-reader (make-toml-syntax-reader app-schema))

(test-case "make-toml-syntax-reader: valid TOML"
  (define toml-input (open-input-string "title = \"MyApp\"\nversion = \"1.0\""))
  (define syntax-obj (app-reader 'test-source toml-input))
  (check-pred syntax? syntax-obj))

(test-case "make-toml-syntax-reader: validation error"
  (define toml-input (open-input-string "title = \"MyApp\""))
  (check-exn exn:fail:syntax?
             (lambda () (app-reader 'test-source toml-input))))

(test-case "make-toml-syntax-reader: TOML parse error"
  (define toml-input (open-input-string "[[broken"))
  (check-exn exn:fail:syntax?
             (lambda () (app-reader 'test-source toml-input))))

(test-case "make-toml-syntax-reader: with defaults"
  (define toml-input (open-input-string "title = \"MyApp\"\nversion = \"1.0\""))
  (check-not-exn (lambda () (app-reader 'test-source toml-input))))

;;; Test procedural validator with make-toml-syntax-reader

(define proc-validator
  (lambda (toml-data)
    (unless (and (hash-has-key? toml-data 'name)
                 (string? (hash-ref toml-data 'name)))
      (validation-error '(name) "required string field 'name' missing or invalid"))))

(define proc-reader (make-toml-syntax-reader proc-validator))

(test-case "procedural validator: valid"
  (define toml-input (open-input-string "name = \"test\""))
  (check-pred syntax? (proc-reader 'test-source toml-input)))

(test-case "procedural validator: invalid"
  (define toml-input (open-input-string "other = \"value\""))
  (check-exn exn:fail:syntax?
             (lambda () (proc-reader 'test-source toml-input))))
