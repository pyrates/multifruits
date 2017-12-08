# Multifruits

Tasty multipart form data parser built with cython.


## Install

    pip install multifruits


## Usage

`multifruits` has a one `Parser` class and two helpers: `extract_filename` and
`parse_content_disposition`.
`Parser` needs the `Content-Type` header value, and a handler, which should
define one or more of those methods:

```python
on_body_begin()
on_part_begin()
on_header(name: bytes, value: bytes)
on_headers_complete()
on_data(data: bytes)
on_part_complete()
on_body_complete()
```

In case of `on_body_begin` and `on_body_complete`, a check is performed
to avoid failing in case of inexistence but you have to implement the
other ones.

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
