from multifruits import Parts


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
    form = Parts('multipart/form-data; boundary=foo')
    form.feed_data(body)
    assert form[b'baz'].name == 'baz'
    assert form[b'baz'].filename == b'baz.png'


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
    form = Parts('multipart/form-data; boundary=foo')
    form.feed_data(body)
    assert len(form.getall(b'bar')) == 2
