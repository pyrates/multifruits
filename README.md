# Multifruits

Tasty multipart form data parser built with cython.


## Install

    pip install multifruits


## Usage

`multifruits` has one `Parser` class and two helpers: `extract_filename` and
`parse_content_disposition`.


#### `Parser`

`Parser` needs the `Content-Type` header value and a handler, which could
define one or more of these methods:

```python
on_body_begin()
on_part_begin()
on_header(name: bytes, value: bytes)
on_headers_complete()
on_data(data: bytes)
on_part_complete()
on_body_complete()
```

Example:

```python
from multifruits import Parser

class MyHandler:

    def on_part_begin(self):
        self.part = MyPart()

    def on_header(self, name, value):
        self.part.headers[name] = value

    def on_data(self, data):
        self.part.write(data)

handler = MyHandler()
parser = Parser(handler, request.headers['Content-Type'])
parser.feed_data(request.body)  # You can pass chunks
```

#### Helpers

##### `parse_content_disposition`

Takes raw `Content-Disposition` header value and returns the disposition type
(`attachment`, `form-data`, `inline` and so on) and the parameters parsed as a
dictionary.

Example:

```python
dtype, params = parse_content_disposition(b'inline; filename="foo.html"')
assert dtype == b'inline'
assert params == {b'filename': b'foo.html'}
```


##### `extract_filename`

Takes parameters from `parse_content_disposition` as a dict and tries to
return the appropriated `str` filename (like `filename*`).

Example:

```python
assert extract_filename({
    b'filename*': "UTF-8''foo-ä-€.html".encode()
}) == 'foo-ä-€.html'
```


## Build from source

You need a virtualenv with cython installed, then:

    git clone https://github.com/pyrates/multifruits
    cd multifruits
    make compile
    python setup.py develop

## Tests

To run tests:

    make test


## Acknowledgements

- https://github.com/iafonov/multipart-parser-c/
- https://github.com/francoiscolas/multipart-parser/
- https://github.com/felixge/node-formidable/
