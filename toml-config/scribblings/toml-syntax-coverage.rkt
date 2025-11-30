#lang toml/config

# Comprehensive TOML syntax test file

# ================================================
# Top-level key-value pairs

bare_key = "value"
bare-key-with-dashes = "value"
bare_key_with_underscores = "value"
1234 = "bare keys can be numeric"
"quoted key with spaces" = "value"
'literal quoted key' = "value"
"" = "empty key is valid"

dotted.key.example = "creates nested tables implicitly"
dotted."quoted".'mixed' = "whitespace around dots is allowed"

# ================================================
# String types

basic_string = "I'm a basic string with \t tab and \n newline"
escape_sequences = "backslash: \\ quote: \" tab: \t newline: \n carriage: \r"
unicode_escape = "Greek: \u03B1\u03B2\u03B3 Emoji: \U0001F600"
literal_string = 'No escapes here: \t \n \\ are literal'
literal_with_quotes = 'Can contain "double quotes" freely'

multiline_basic = """
Roses are red
Violets are blue"""

multiline_basic_escaped = """\
    The quick brown \
    fox jumps over \
    the lazy dog.\
    """

multiline_literal = '''
Here is some text.
Backslashes \ are literal.
No escaping "whatsoever".
'''

multiline_with_quotes = """Here are two quotes: "". Here are three: ""\"."""
multiline_literal_quotes = '''Here are two apostrophes: ''.'''

# Line-ending backslash trims whitespace
trimmed = """\
       Trim this      \
       and this too   \
       """

# ================================================
# Integer types  

positive_int = 42
negative_int = -17
explicit_positive = +99
zero = 0

# Underscores for readability
large_number = 1_000_000
grouped = 5_349_221
indian_grouping = 1_00_00_000

# Different bases
hex_lowercase = 0xdeadbeef
hex_uppercase = 0xDEADBEEF
hex_mixed = 0xDeAdBeEf
octal = 0o755
binary = 0b11010110

hex_with_underscores = 0xdead_beef
octal_with_underscores = 0o7_5_5
binary_with_underscores = 0b1101_0110

# ================================================
# Float types

float_simple = 3.14
float_negative = -0.001
float_explicit_positive = +1.23

# Exponent notation
exponent_lower = 5e+22
exponent_upper = 1E6
exponent_negative = 6.626e-34
exponent_explicit_positive = 1e+1_000

# Combined
full_float = -3.14159e-10

# Underscores in floats
float_underscored = 9_224_617.445_991_228

# Special float values
positive_infinity = inf
negative_infinity = -inf
explicit_positive_inf = +inf
not_a_number = nan
positive_nan = +nan
negative_nan = -nan

# ================================================
# Boolean types

bool_true = true
bool_false = false

# ================================================
# Date and time types

# Offset date-time (full RFC 3339)
odt_zulu = 1979-05-27T07:32:00Z
odt_offset = 1979-05-27T00:32:00-07:00
odt_with_fractional = 1979-05-27T00:32:00.999999-07:00
odt_lowercase_t = 1979-05-27t07:32:00z
odt_space_separator = 1979-05-27 07:32:00Z

# Local date-time (no timezone)
ldt_simple = 1979-05-27T07:32:00
ldt_fractional = 1979-05-27T00:32:00.999999

# Local date
ld = 1979-05-27

# Local time
lt_simple = 07:32:00
lt_fractional = 00:32:00.999999

# ================================================
# Arrays

# Simple arrays
integers = [1, 2, 3]
colors = ["red", "yellow", "green"]
floats = [1.1, 2.2, 3.3]
booleans = [true, false, true]

# Nested arrays
nested_arrays = [[1, 2], [3, 4, 5]]
nested_mixed = [[1, 2], ["a", "b", "c"]]

# Multi-line arrays
hosts = [
    "alpha",
    "omega",
]

# With trailing commas
numbers_trailing = [
    1,
    2,
    3,
]

# Comments in arrays
commented_array = [
    1,  # first
    2,  # second
    # comment on its own line
    3,  # third
]

# Mixed content array (arrays of different typed arrays)
mixed_nested = [
    [1, 2, 3],
    [1.0, 2.0, 3.0],
    ["one", "two", "three"],
]

# Empty array
empty = []

# Array with complex content
dates = [1979-05-27T07:32:00Z, 1979-05-27]

# ================================================
# Standard tables

[server]
host = "localhost"  # inline comment
port = 8080

[server.limits]    # dotted table name
max_connections = 100
timeout = 30.5

[database]
enabled = true
ports = [8000, 8001, 8002]
data = [["delta", "phi"], [3.14]]

# Table with quoted key
["table with spaces"]
key = "value"

['literal table name']
key = "value"

[deeply.nested."quoted key".table]
value = 42

# Super-table defined after sub-table
[animal]
type = "mammal"

[animal.dog]
breed = "poodle"

[animal.dog.tater]
name = "Tater Tot"

# ================================================
# Inline tables

point = {x = 1, y = 2}
point3d = {x = 1, y = 2, z = 3}

# Inline table with various value types
mixed_inline = {name = "Widget", price = 9.99, in_stock = true}

# Nested inline tables
nested_inline = {outer = {inner = {value = "deep"}}}

# Inline table with array
with_array = {tags = ["a", "b", "c"]}

# Complex inline
person = {name = "Tom", dob = 1979-05-27, address = {city = "NYC", zip = "10001"}}

# Empty inline table
empty_inline = {}

# ================================================
# Array of tables

[[products]]
name = "Hammer"
sku = 738594937

[[products]]  # another element in the products array
name = "Nail"
sku = 284758393
color = "gray"

[[products]]
name = "Wrench"
sku = 967294032
colors = ["red", "blue", "green"]

# Nested array of tables
[[fruits]]
name = "apple"

[[fruits.varieties]]
name = "red delicious"

[[fruits.varieties]]
name = "granny smith"

[[fruits]]
name = "banana"

[[fruits.varieties]]
name = "plantain"

# Array of tables with sub-tables
[[servers]]
name = "alpha"

[servers.network]
ip = "10.0.0.1"
port = 8080

[[servers]]
name = "beta"

[servers.network]
ip = "10.0.0.2"
port = 8081

# ================================================
# Edge cases and less common syntax

# Keys that look like other types
true_key = "not a boolean, this is a key"
false_key = "also a key"
123e45 = "looks like a float but it's a key"
inf_key = "inf as a key"
nan_key = "nan as a key"

# Unicode in keys
"ʎǝʞ ǝpoɔıun" = "upside down"
"日本語" = "Japanese"
"emoji🎉key" = "celebration"

# Whitespace variations
key_no_spaces="compact"
key_lots_of_spaces    =     "spread out"

# Table with all quoted parts
["one"."two"."three"]
value = "fully quoted path"

# Mix of bare and quoted in dotted key
bare."with spaces".more = "mixed dotted key"

# Very long string for testing
long_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris."

# String with all escape sequences
all_escapes = "backslash:\\, quote:\", backspace:\b, tab:\t, newline:\n, formfeed:\f, carriage:\r"

# Boundary numbers
max_safe_int = 9_007_199_254_740_991
min_int = -9_223_372_036_854_775_808
tiny_float = 1e-400
huge_float = 1e+400