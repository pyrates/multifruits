# http://greenbytes.de/tech/tc2231/

from multifruits import parse_content_disposition


def test_parse_empty():
    dtype, params = parse_content_disposition(b'')
    assert dtype is None
    assert params == {}


def test_inlonly():
    dtype, params = parse_content_disposition(b'inline')
    assert dtype == b'inline'
    assert params == {}


def test_inlonlyquoted():
    dtype, params = parse_content_disposition(b'"inline"')
    assert dtype == b'inline'
    assert params == {}


def test_inlwithasciifilename():
    dtype, params = parse_content_disposition(b'inline; filename="foo.html"')
    assert dtype == b'inline'
    assert params == {b'filename': b'foo.html'}


def test_inlwithfnattach():
    dtype, params = parse_content_disposition(
        b'inline; filename="Not an attachment!"')
    assert dtype == b'inline'
    assert params == {b'filename': b'Not an attachment!'}


def test_attonly():
    dtype, params = parse_content_disposition(b'attachment')
    assert dtype == b'attachment'
    assert params == {}


def test_attonlyquoted():
    dtype, params = parse_content_disposition(b'"attachment"')
    assert dtype == b'attachment'
    assert params == {}


def test_attonlyucase():
    dtype, params = parse_content_disposition(b'ATTACHMENT')
    assert dtype == b'attachment'
    assert params == {}


def test_attwithasciifilename():
    dtype, params = parse_content_disposition(
        b'attachment; filename="foo.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.html'}


def test_inlwithasciifilenamepdf():
    dtype, params = parse_content_disposition(
        b'attachment; filename="foo.pdf"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.pdf'}


def test_attwithasciifilename25():
    dtype, params = parse_content_disposition(
        b'attachment; filename="0000000000111111111122222"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'0000000000111111111122222'}


def test_attwithasciifilename35():
    dtype, params = parse_content_disposition(
        b'attachment; filename="00000000001111111111222222222233333"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'00000000001111111111222222222233333'}


def test_attwithasciifnescapedchar():
    dtype, params = parse_content_disposition(
        br'attachment; filename="f\oo.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.html'}


def test_attwithasciifnescapedquote():
    dtype, params = parse_content_disposition(
        rb'attachment; filename="\"quoting\" tested.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'"quoting" tested.html'}


def test_attwithquotedsemicolon():
    dtype, params = parse_content_disposition(
        b'attachment; filename="Here\'s a semicolon;.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b"Here's a semicolon;.html"}


def test_attwithfilenameandextparam():
    dtype, params = parse_content_disposition(
        b'attachment; foo="bar"; filename="foo.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.html', b'foo': b'bar'}


# def test_attwithfilenameandextparamescaped():
#     dtype, params = parse_content_disposition(
#         b'attachment; foo="\"\\";filename="foo.html"')
#     assert dtype == b'attachment'
#     assert params == {b'filename': b'foo.html', b'foo': b'"\\'}


def test_attwithasciifilenameucase():
    dtype, params = parse_content_disposition(
        b'attachment; FILENAME="foo.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.html'}


def test_attwithasciifilenamenq():
    dtype, params = parse_content_disposition(
        b'attachment; filename=foo.html')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.html'}


def test_attemptyparam():
    dtype, params = parse_content_disposition(b'attachment; ;filename=foo')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo'}


def test_attwithasciifilenamenqws():
    dtype, params = parse_content_disposition(
        b'attachment; filename=foo bar.html')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo bar.html'}


def test_attwithfntokensq():
    dtype, params = parse_content_disposition(
        b"attachment; filename='foo.html'")
    assert dtype == b'attachment'
    assert params == {b'filename': b"'foo.html'"}


def test_attwithisofnplain():
    dtype, params = parse_content_disposition(
        'attachment; filename="foo-ä.html"'.encode())
    assert dtype == b'attachment'
    assert params == {b'filename': 'foo-ä.html'.encode()}


def test_attwithutf8fnplain():
    dtype, params = parse_content_disposition(
        'attachment; filename="foo-Ã¤.html"'.encode())
    assert dtype == b'attachment'
    assert params == {b'filename': 'foo-Ã¤.html'.encode()}


def test_attwithfnrawpctenca():
    dtype, params = parse_content_disposition(
        b'attachment; filename="foo-%41.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo-%41.html'}


def test_attwithfnusingpct():
    dtype, params = parse_content_disposition(
        b'attachment; filename="50%.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'50%.html'}


def test_attwithfnrawpctencaq():
    dtype, params = parse_content_disposition(
        rb'attachment; filename="foo-%\41.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo-%41.html'}


def test_attwithnamepct():
    dtype, params = parse_content_disposition(
        b'attachment; filename="foo-%41.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo-%41.html'}


def test_attwithfilenamepctandiso():
    dtype, params = parse_content_disposition(
        'attachment; filename="ä-%41.html"'.encode())
    assert dtype == b'attachment'
    assert params == {b'filename': 'ä-%41.html'.encode()}


def test_attwithfnrawpctenclong():
    dtype, params = parse_content_disposition(
        b'attachment; filename="foo-%c3%a4-%e2%82%ac.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo-%c3%a4-%e2%82%ac.html'}


def test_attwithasciifilenamews1():
    dtype, params = parse_content_disposition(
        b'attachment; filename ="foo.html"')
    assert dtype == b'attachment'
    assert params == {b'filename': b'foo.html'}
