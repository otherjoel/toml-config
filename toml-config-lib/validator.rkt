#lang racket/base

(require racket/contract
         racket/match
         racket/port
         racket/string
         syntax/parse/define
         syntax/strip-context
         toml
         (for-syntax racket/base
                     racket/match
                     racket/list))

(provide define-toml-schema
         make-toml-syntax-reader
         validation-error
         exn:fail:toml:validation
         exn:fail:toml:validation?
         exn:fail:toml:validation-key-path
         exn:fail:toml:validation-expected
         exn:fail:toml:validation-actual)

;;; Error Reporting

(struct exn:fail:toml:validation exn:fail (key-path expected actual)
  #:transparent)

(define (format-value v)
  (cond
    [(string? v) (format "\"~a\"" v)]
    [(symbol? v) (symbol->string v)]
    [(list? v)
     ;; Special formatting for common contract forms
     (match v
       [(list 'integer-in min max) (format "integer between ~a and ~a" min max)]
       [(list 'listof type) (format "list of ~a values" (format-value type))]
       [(list type '...) (format "~a..." (format-value type))]
       [_ (format "~s" v)])]
    [(hash? v) "<table>"]
    [else (format "~a" v)]))

(define (validation-error key-path message [expected #f] [actual #f])
  (define path-str (if (null? key-path)
                       "config"
                       (string-join (map symbol->string key-path) ".")))

  (define detailed-msg
    (cond
      ;; Both expected and actual provided
      [(and expected actual)
       (format "~a: ~a\n  expected: ~a\n  actual: ~a"
               path-str message
               (format-value expected)
               (format-value actual))]
      ;; Only expected provided
      [expected
       (format "~a: ~a (expected: ~a)"
               path-str message
               (format-value expected))]
      ;; Only actual provided
      [actual
       (format "~a: ~a (got: ~a)"
               path-str message
               (format-value actual))]
      ;; Neither provided
      [else
       (format "~a: ~a" path-str message)]))

  (raise (exn:fail:toml:validation detailed-msg (current-continuation-marks)
                                   key-path expected actual)))

;;; Type Checking

(define (make-type-checker spec spec-name)
  (define checker
    (cond
      [(flat-contract? spec)
       (contract-first-order spec)]
      [(procedure? spec)
       spec]
      [else
       (error 'make-type-checker "Invalid type spec: ~v" spec)]))
  (cons checker spec-name))

;;; Runtime Validation (pure - no mutation)

(define (get-type-name value)
  (cond
    [(string? value) "string"]
    [(integer? value) "integer"]
    [(real? value) "number"]
    [(boolean? value) "boolean"]
    [(list? value) "array"]
    [(hash? value) "table"]
    [else "unknown"]))

(define (format-checker-name checker)
  (define name (object-name checker))
  (cond
    [(not name) "custom predicate"]
    [(symbol? name) (symbol->string name)]
    [(string? name)
     ;; Clean up contract names - extract meaningful part
     (cond
       [(regexp-match #rx"integer-in" name) "integer in valid range"]
       [(regexp-match #rx"listof" name) "list of valid elements"]
       [(regexp-match #rx"and\\.rkt" name) "valid value"]
       [else name])]
    [else (format "~a" name)]))

(define (make-suggestion expected-name actual-value)
  (match expected-name
    [(list 'integer-in min max)
     (format "\n  → Use an integer between ~a and ~a" min max)]
    [(list 'listof _)
     "\n  → Ensure all array elements are the correct type"]
    ['string?
     (if (number? actual-value)
         "\n  → Use quotes around the value to make it a string"
         "")]
    ['integer?
     (if (string? actual-value)
         "\n  → Remove quotes to make it a number"
         "")]
    [_ ""]))

(define (validate-field toml-data key-path type-checkers required? key)
  (define has-key? (hash-has-key? toml-data key))
  (define full-path (append key-path (list key)))

  (when (and required? (not has-key?))
    (validation-error full-path
                     (format "required key is missing\n  → Add '~a = <value>' to the configuration"
                             key)))

  (when has-key?
    (define value (hash-ref toml-data key))
    (for ([checker-pair type-checkers])
      (match-define (cons checker type-name) checker-pair)
      (unless (checker value)
        (define actual-type (get-type-name value))
        (define suggestion (make-suggestion type-name value))
        (validation-error full-path
                         (format "type mismatch (got ~a)~a" actual-type suggestion)
                         type-name
                         value)))))

(define (validate-table toml-data key-path key required? sub-specs)
  (define has-key? (hash-has-key? toml-data key))
  (define full-path (append key-path (list key)))

  (when (and required? (not has-key?))
    (validation-error full-path "required table is missing"))

  (when has-key?
    (define value (hash-ref toml-data key))
    (unless (hash? value)
      (validation-error full-path "must be a table" 'table value))
    (run-validations value full-path sub-specs)))

(define (run-validations toml-data key-path compiled-specs)
  (for ([spec compiled-specs])
    (match spec
      [(list 'field key type-checkers required? _default)
       (validate-field toml-data key-path type-checkers required? key)]
      [(list 'table key required? sub-specs)
       (validate-table toml-data key-path key required? sub-specs)])))

;;; Apply Defaults (pure - returns new hash)

(define (apply-field-default toml-data key default)
  (if (and default (not (hash-has-key? toml-data key)))
      (hash-set toml-data key default)
      toml-data))

(define (apply-table-defaults toml-data key sub-specs)
  (if (hash-has-key? toml-data key)
      (hash-set toml-data key
                (apply-defaults (hash-ref toml-data key) sub-specs))
      toml-data))

(define (apply-defaults toml-data compiled-specs)
  (for/fold ([result toml-data])
            ([spec compiled-specs])
    (match spec
      [(list 'field key _type-checkers _required? default)
       (apply-field-default result key default)]
      [(list 'table key _required? sub-specs)
       (apply-table-defaults result key sub-specs)])))

(define (validate-and-apply-defaults toml-data compiled-specs)
  (run-validations toml-data '() compiled-specs)
  (apply-defaults toml-data compiled-specs))

;;; Compile-Time Schema Processing

(begin-for-syntax
  (define (compile-field-spec field-spec-stx)
    (syntax-parse field-spec-stx
      [(key:id ((~literal table) sub-spec ...))
       #`(list 'table 'key #t (list #,@(map compile-field-spec (syntax->list #'(sub-spec ...)))))]

      [(key:id type-spec:expr ... (~literal required))
       #`(list 'field 'key (list #,@(map (lambda (ts)
                                            #`(make-type-checker #,ts '#,(syntax->datum ts)))
                                          (syntax->list #'(type-spec ...)))) #t #f)]

      [(key:id type-spec:expr ... (~literal optional))
       #`(list 'field 'key (list #,@(map (lambda (ts)
                                            #`(make-type-checker #,ts '#,(syntax->datum ts)))
                                          (syntax->list #'(type-spec ...)))) #f #f)]

      [(key:id type-spec:expr ... ((~literal optional) default:expr))
       #`(list 'field 'key (list #,@(map (lambda (ts)
                                            #`(make-type-checker #,ts '#,(syntax->datum ts)))
                                          (syntax->list #'(type-spec ...)))) #f default)]

      [else
       (error 'compile-field-spec "Invalid field spec: ~v" (syntax->datum field-spec-stx))]))

  (define (compile-schema field-specs-stx)
    (map compile-field-spec (syntax->list field-specs-stx))))

;;; Macro

(define-syntax (define-toml-schema stx)
  (syntax-parse stx
    [(_ name:id field-spec:expr ...)
     (define compiled-specs (compile-schema #'(field-spec ...)))
     #`(define name
         (lambda (toml-data)
           (validate-and-apply-defaults toml-data (list #,@compiled-specs))))]))

;;; Reader Helper

(define (make-toml-syntax-reader validator)
  (unless (procedure? validator)
    (error 'make-toml-syntax-reader "validator must be a procedure"))

  (lambda (src in)
    (port-count-lines! in)
    (define toml-str (string-replace (port->string in) "\u00A0" ""))
    (define toml-data
      (with-handlers ([exn:fail? (λ (e)
                                   (raise-syntax-error 'toml/config
                                     (format "TOML parse error: ~a" (exn-message e))))])
        (parse-toml toml-str)))

    (define validated-data
      (with-handlers ([exn:fail:toml:validation?
                       (λ (e)
                         (raise-syntax-error 'toml/config
                           (format "Validation error: ~a" (exn-message e))))])
        (validator toml-data)))

    (strip-context
      #`(module parsed-toml racket/base
         (provide toml)
         (define toml '#,validated-data)))))
