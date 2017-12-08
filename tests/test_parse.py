from collections import namedtuple

from multifruits import Parser


class Handler:

    def __init__(self, boundary):
        self.parts = []
        self.parser = Parser(self, boundary)
        self.on_body_begin_called = 0
        self.on_body_complete_called = 0
        self.on_headers_complete_called = 0

    def feed_data(self, data):
        self.parser.feed_data(data)

    def on_body_begin(self):
        self.on_body_begin_called += 1
        print('on_body_begin')

    def on_part_begin(self):
        self._current = namedtuple('Data', ['headers', 'content'])
        self._current.headers = {}
        self._current.content = b''
        print('on_part_begin')

    def on_header(self, field, value):
        self._current.headers[field] = value
        print(field, value)

    def on_headers_complete(self):
        self.on_headers_complete_called += 1
        print('on_headers_complete')

    def on_data(self, data: bytes):
        self._current.content += data

    def on_part_complete(self):
        self.parts.append(self._current)
        self._current = None
        print('on_part_complete')

    def on_body_complete(self):
        self.on_body_complete_called += 1
        print('on_body_complete')


def test_parse():
    body = (b'--foo\r\n'
            b'Content-Disposition: form-data; name=baz; filename="baz.png"\r\n'
            b'Content-Type: image/png\r\n'
            b'\r\n'
            b'abcdef\r\n'
            b'--foo\r\n'
            b'Content-Disposition: form-data; name="text1"\r\n'
            b'\r\n'
            b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    assert form.parts[0].headers == {
        b'Content-Disposition': b'form-data; name=baz; filename="baz.png"',
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[1].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 2


def test_parse_filename_star():
    body = (b'--foo\r\n'
            b'Content-Disposition: form-data; name=baz; '
            b'filename="iso-8859-1\'\'baz-\xe9.png"\r\n'
            b'Content-Type: image/png\r\n'
            b'\r\n'
            b'abcdef\r\n'
            b'--foo\r\n'
            b'Content-Disposition: form-data; name="text1"\r\n'
            b'\r\n'
            b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    assert form.parts[0].headers == {
        b'Content-Disposition': (b'form-data; name=baz; '
                                 b'filename="iso-8859-1\'\'baz-\xe9.png"'),
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[1].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 2


def test_parse_feed_data_content_chunked():
    body = (b'--foo\r\n'
            b'Content-Disposition: form-data; name=baz; filename="baz.png"\r\n'
            b'Content-Type: image/png\r\n'
            b'\r\n'
            b'abc')
    body2 = (b'def\r\n'
             b'--foo\r\n'
             b'Content-Disposition: form-data; name="text1"\r\n'
             b'\r\n'
             b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    assert form.on_headers_complete_called == 1
    form.feed_data(body2)
    assert form.parts[0].headers == {
        b'Content-Disposition': b'form-data; name=baz; filename="baz.png"',
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[1].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 2


def test_parse_feed_data_header_name_chunked():
    body = (b'--foo\r\n'
            b'Content-Disposit')
    body2 = (b'ion: form-data; name=baz; filename="baz.png"\r\n'
             b'Content-Type: image/png\r\n'
             b'\r\n'
             b'abcdef\r\n'
             b'--foo\r\n'
             b'Content-Disposition: form-data; name="text1"\r\n'
             b'\r\n'
             b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    assert form.on_headers_complete_called == 0
    form.feed_data(body2)
    assert form.parts[0].headers == {
        b'Content-Disposition': b'form-data; name=baz; filename="baz.png"',
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[1].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 2


def test_parse_feed_data_header_value_chunked():
    body = (b'--foo\r\n'
            b'Content-Disposition: form-data; name=baz; filename="ba')
    body2 = (b'z.png"\r\n'
             b'Content-Type: image/png\r\n'
             b'\r\n'
             b'abcdef\r\n'
             b'--foo\r\n'
             b'Content-Disposition: form-data; name="text1"\r\n'
             b'\r\n'
             b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    assert form.on_headers_complete_called == 0
    form.feed_data(body2)
    assert form.parts[0].headers == {
        b'Content-Disposition': b'form-data; name=baz; filename="baz.png"',
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[1].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 2


def test_parse_feed_data_boundary_chunked():
    body = (b'--foo\r\n'
            b'Content-Disposition: form-data; name=baz; filename="baz.png"\r\n'
            b'Content-Type: image/png\r\n'
            b'\r\n'
            b'abcdef\r\n'
            b'--f')
    body2 = (b'oo\r\n'
             b'Content-Disposition: form-data; name="text1"\r\n'
             b'\r\n'
             b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    form.feed_data(body2)
    assert form.parts[0].headers == {
        b'Content-Disposition': b'form-data; name=baz; filename="baz.png"',
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[1].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 2


def test_parse_two_parts_with_same_name():
    body = (b'--foo\r\n'
            b'Content-Disposition: form-data; name=bar; filename=tmp.png\r\n'
            b'Content-Type: image/png\r\n'
            b'\r\n'
            b'abcdef\r\n'
            b'--foo\r\n'
            b'Content-Disposition: form-data; name=bar; filename=foo.png\r\n'
            b'Content-Type: image/png\r\n'
            b'\r\n'
            b'ghijkl\r\n'
            b'--foo\r\n'
            b'Content-Disposition: form-data; name="text1"\r\n'
            b'\r\n'
            b'abc\r\n--foo--')
    form = Handler(b'foo')
    form.feed_data(body)
    assert form.parts[0].headers == {
        b'Content-Disposition': b'form-data; name=bar; filename=tmp.png',
        b'Content-Type': b'image/png'
    }
    assert form.parts[0].content == b'abcdef'
    assert form.parts[1].headers == {
        b'Content-Disposition': b'form-data; name=bar; filename=foo.png',
        b'Content-Type': b'image/png'
    }
    assert form.parts[1].content == b'ghijkl'
    assert form.parts[2].headers == {
        b'Content-Disposition': b'form-data; name="text1"'
    }
    assert form.parts[2].content == b'abc'
    assert form.on_body_begin_called == 1
    assert form.on_body_complete_called == 1
    assert form.on_headers_complete_called == 3
