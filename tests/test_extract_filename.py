from multifruits import extract_filename


def test_extract_filename():
    assert extract_filename({b'filename': b'foo.bar'}) == 'foo.bar'


def test_extract_filename_star():
    assert extract_filename({b'filename*': b"utf-8''foo.bar"}) == 'foo.bar'


def test_extract_filename_and_star():
    assert extract_filename({
        b'filename*': b"utf-8''foo.bar",
        b'filename': b"baz.quux"
    }) == 'foo.bar'


def test_extract_filename_and_star_wrong_encoding():
    assert extract_filename({
        b'filename*': b"unknown''foo.bar",
        b'filename': b"baz.quux"
    }) == 'baz.quux'


def test_extract_filename_star_wrong_encoding():
    assert extract_filename({b'filename*': b"unknow''foo.bar"}) == 'foo.bar'


def test_extract_filename_star_with_accent():
    assert extract_filename({
        b'filename*': "UTF-8''foo-ä-€.html".encode()
    }) == 'foo-ä-€.html'
