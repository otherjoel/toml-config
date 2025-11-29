#lang racket/base

(require rackunit
         toml
         toml/config
         toml/config/schema
         "fixtures/products.toml"
         (prefix-in fruits: "fixtures/fruits.toml"))

;;; Integration tests with real TOML files using array-of-tables

(define-toml-schema products-schema
  [products (array-of table
              [name string? required]
              [sku integer? required]
              [color string? (optional "black")])
            required])

(test-case "products.toml: parse and validate array of tables"
  (check-not-exn (lambda () (products-schema toml)))
  (define result (products-schema toml))
  (check-equal? (length (toml-ref result 'products)) 3)
  (check-equal? (toml-ref result 'products 0 'name) "Hammer")
  (check-equal? (toml-ref result 'products 0 'sku) 738594937)
  (check-equal? (toml-ref result 'products 0 'color) "red")
  (check-equal? (toml-ref result 'products 2 'name) "Screwdriver")
  (check-equal? (toml-ref result 'products 2 'color) "black"))

(test-case "products.toml: schema validation fails with missing required field"
  (define invalid-data
    (parse-toml (string-append
                 "[[products]]\n"
                 "name = \"Hammer\"\n"
                 "sku = 738594937\n"
                 "\n"
                 "[[products]]\n"
                 "name = \"Nail\"\n")))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema invalid-data))))

(test-case "products.toml: schema validation fails with wrong type"
  (define invalid-data
    (parse-toml (string-append
                 "[[products]]\n"
                 "name = \"Hammer\"\n"
                 "sku = \"not-a-number\"\n")))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema invalid-data))))

(test-case "products.toml: schema validation fails when products is not an array"
  (define invalid-data
    (parse-toml "[products]\nname = \"Hammer\"\n"))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema invalid-data))))

(define-toml-schema fruits-schema
  [fruits (array-of table
            [name string? required]
            [physical (table
                        [color string? required]
                        [shape string? required])]
            [varieties (array-of table
                         [name string? required])
                       required])
          required])

(test-case "fruits.toml: parse and validate nested array of tables"
  (check-not-exn (lambda () (fruits-schema fruits:toml)))
  (define result (fruits-schema fruits:toml))
  (check-equal? (length (toml-ref result 'fruits)) 2)
  (check-equal? (toml-ref result 'fruits 0 'name) "apple")
  (check-equal? (toml-ref result 'fruits 0 'physical.color) "red")
  (check-equal? (toml-ref result 'fruits 0 'physical.shape) "round")
  (check-equal? (length (toml-ref result 'fruits 0 'varieties)) 2)
  (check-equal? (toml-ref result 'fruits 0 'varieties 0 'name) "red delicious")
  (check-equal? (toml-ref result 'fruits 0 'varieties 1 'name) "granny smith")
  (check-equal? (toml-ref result 'fruits 1 'name) "banana")
  (check-equal? (length (toml-ref result 'fruits 1 'varieties)) 1)
  (check-equal? (toml-ref result 'fruits 1 'varieties 0 'name) "plantain"))

(test-case "fruits.toml: schema validation fails with missing nested table field"
  (define invalid-data
    (parse-toml (string-append
                 "[[fruits]]\n"
                 "name = \"apple\"\n"
                 "\n"
                 "[fruits.physical]\n"
                 "color = \"red\"\n")))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema invalid-data))))

(test-case "fruits.toml: schema validation fails with missing nested array"
  (define invalid-data
    (parse-toml (string-append
                 "[[fruits]]\n"
                 "name = \"apple\"\n"
                 "\n"
                 "[fruits.physical]\n"
                 "color = \"red\"\n"
                 "shape = \"round\"\n")))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema invalid-data))))

(test-case "fruits.toml: schema validation fails with wrong type in nested array"
  (define invalid-data
    (parse-toml (string-append
                 "[[fruits]]\n"
                 "name = \"apple\"\n"
                 "\n"
                 "[fruits.physical]\n"
                 "color = \"red\"\n"
                 "shape = \"round\"\n"
                 "\n"
                 "[[fruits.varieties]]\n"
                 "name = 123\n")))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema invalid-data))))
