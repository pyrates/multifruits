from multifruits import Parser


def test_parse():
    BODY = (b'--BOUNDARY\r\n'
            b'Content-Disposition: form-data; name="foo"; filename="bar"\r\n'
            b'Content-Type: application/octet-stream\r\n'
            b'\r\n'
            b"That's the file content!\r\n"
            b'\r\n--BOUNDARY--\r\n')
    parser = Parser(b'BOUNDARY', {})
    parser(BODY)
