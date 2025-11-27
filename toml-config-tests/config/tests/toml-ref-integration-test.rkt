#lang racket/base

(require rackunit
         toml/config
         "fixtures/toml-ref-example.toml")

;; Test toml-ref with real TOML config data
(check-equal? (toml-ref toml 'server.host)
              "localhost"
              "Should access server.host")

(check-equal? (toml-ref toml 'server.port)
              8080
              "Should access server.port")

(check-equal? (toml-ref toml 'server.tls.enabled)
              #t
              "Should access deeply nested server.tls.enabled")

(check-equal? (toml-ref toml 'server.tls.cert)
              "/path/to/cert.pem"
              "Should access deeply nested server.tls.cert")

(check-equal? (toml-ref toml 'database.name)
              "myapp"
              "Should access database.name")

(check-equal? (toml-ref toml 'database.timeout)
              30
              "Should access database.timeout")

;; Test accessing array of tables
(define replicas (toml-ref toml 'database.replicas))
(check-true (list? replicas) "database.replicas should be a list")
(check-equal? (length replicas) 2 "Should have 2 replicas")

;; Test with default values
(check-equal? (toml-ref toml 'server.max_connections 100)
              100
              "Should return default for missing key")

(check-equal? (toml-ref toml 'server.tls.key "/default/key.pem")
              "/default/key.pem"
              "Should return default for missing nested key")

;; Demonstrate that toml-ref simplifies access compared to nested hash-ref
;; Without toml-ref: (hash-ref (hash-ref (hash-ref toml 'server) 'tls) 'enabled)
;; With toml-ref: (toml-ref toml 'server.tls.enabled)
