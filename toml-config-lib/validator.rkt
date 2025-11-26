#lang racket/base

(require racket/contract
         racket/match
         racket/string
         syntax/parse/define
         (for-syntax racket/base
                     racket/match
                     racket/list))

(provide define-toml-schema
         make-toml-syntax-reader
         validation-error
         exn:fail:toml:validation
         exn:fail:toml:validation?)

;;; Error Reporting

(struct exn:fail:toml:validation exn:fail (key-path expected actual)
  #:transparent)

(define (validation-error key-path message [expected #f] [actual #f])
  (define path-str (if (null? key-path)
                       "config"
                       (string-join (map symbol->string key-path) ".")))
  (define msg (format "~a: ~a" path-str message))
  (raise (exn:fail:toml:validation msg (current-continuation-marks)
                                   key-path expected actual)))

;;; Type Checking

(define (make-type-checker spec)
  (cond
    [(flat-contract? spec)
     (contract-first-order spec)]
    [(procedure? spec)
     spec]
    [else
     (error 'make-type-checker "Invalid type spec: ~v" spec)]))

;;; Runtime Validation (pure - no mutation)

(define (validate-field toml-data key-path type-checkers required? key)
  (define has-key? (hash-has-key? toml-data key))
  (define full-path (append key-path (list key)))

  (when (and required? (not has-key?))
    (validation-error full-path "required key is missing"))

  (when has-key?
    (define value (hash-ref toml-data key))
    (for ([checker type-checkers])
      (unless (checker value)
        (validation-error full-path
                         "validation failed"
                         (object-name checker)
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
       #`(list 'field 'key (list #,@(map (lambda (ts) #`(make-type-checker #,ts))
                                          (syntax->list #'(type-spec ...)))) #t #f)]

      [(key:id type-spec:expr ... (~literal optional))
       #`(list 'field 'key (list #,@(map (lambda (ts) #`(make-type-checker #,ts))
                                          (syntax->list #'(type-spec ...)))) #f #f)]

      [(key:id type-spec:expr ... ((~literal optional) default:expr))
       #`(list 'field 'key (list #,@(map (lambda (ts) #`(make-type-checker #,ts))
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
    (define toml-str (port->string in))
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

    (datum->syntax #f
      `(module parsed-toml racket/base
         (provide toml)
         (define toml ',validated-data)))))

(require racket/port
         toml)
