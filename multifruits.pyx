# cython: language_level=3

from cpython cimport bool


cdef enum state:
    PREAMBLE,  # 0
    PREAMBLE_HY,
    FIRST_BOUNDARY,
    FIRST_BOUNDARY_DONE,
    HEADER_NAME_START,
    HEADER_NAME,  # 5
    HEADER_VALUE_START,
    HEADER_VALUE,
    HEADER_VALUE_CR,
    HEADERS_DONE,
    DATA,  # 10
    DATA_CR,
    DATA_CR_LF,
    DATA_CR_LF_HY,
    DATA_BOUNDARY,
    DATA_BOUNDARY_DONE,  # 15
    DATA_BOUNDARY_DONE_CR_LF,
    DATA_BOUNDARY_DONE_HY_HY,
    EPILOGUE,

cdef class Parser:

    cdef:
        bytes _boundary
        unsigned int _boundary_index
        unsigned int _boundary_length
        unsigned char _state
        bytes _current_header_name
        bytes _current_header_value
        _on_body_begin, _on_part_begin, _on_header, _on_headers_complete, \
        _on_data, _on_part_complete, _on_body_complete

    def __init__(self, handler, bytes content_type):
        cdef dict params
        cdef bytes _
        _, params = parse_content_disposition(content_type)
        try:
            self._boundary = params[b'boundary']
        except KeyError:
            raise ValueError('Missing boundary in Content-Type.')
        self._boundary_length = len(self._boundary)
        self._current_header_name = None
        self._current_header_value = None
        self._state = 0
        self._boundary_index = 0
        self._on_body_begin = getattr(handler, 'on_body_begin', None)
        self._on_part_begin = getattr(handler, 'on_part_begin', None)
        self._on_header = getattr(handler, 'on_header', None)
        self._on_headers_complete = getattr(handler, 'on_headers_complete', None)
        self._on_data = getattr(handler, 'on_data', None)
        self._on_part_complete = getattr(handler, 'on_part_complete', None)
        self._on_body_complete = getattr(handler, 'on_body_complete', None)

    def _maybe_call_on_header(self):
        if self._current_header_value is not None:
            if self._on_header is not None:
                self._on_header(self._current_header_name, self._current_header_value)
            self._current_header_name = self._current_header_value = None

    def on_header_name(self, data):
        self._maybe_call_on_header()
        if self._current_header_name is None:
            self._current_header_name = data
        else:
            self._current_header_name += data

    def on_header_value(self, data):
        if self._current_header_value is None:
            self._current_header_value = data
        else:
            self._current_header_value += data

    def on_headers_complete(self):
        self._maybe_call_on_header()
        if self._on_headers_complete is not None:
            self._on_headers_complete()

    cdef _feed_data(self, bytes data):
        cdef:
            unsigned int i = 0
            unsigned int mark = 0
            char c
            unsigned int length = len(data)

        while i < length:
            c = data[i]
            if self._state == PREAMBLE:
                if c == b'-':
                    self._state = PREAMBLE_HY
                i += 1
            elif self._state == PREAMBLE_HY:
                if c == b'-':
                    self._state = FIRST_BOUNDARY
                else:
                    self._state = PREAMBLE
                i += 1
            elif self._state == FIRST_BOUNDARY:
                while i < length:
                    c = data[i]
                    if self._boundary_index == self._boundary_length:
                        if c != b'\r':
                            raise ValueError('FIRST_BOUNDARY: \\r')
                        self._state = FIRST_BOUNDARY_DONE
                        i += 1
                        break
                    elif c == self._boundary[self._boundary_index]:
                        self._boundary_index += 1
                    else:
                        raise ValueError('FIRST_BOUNDARY')
                    i += 1
            elif self._state == FIRST_BOUNDARY_DONE:
                if c != b'\n':
                    raise ValueError('FIRST_BOUNDARY_DONE')
                if self._on_body_begin is not None:
                    self._on_body_begin()
                if self._on_part_begin is not None:
                    self._on_part_begin()
                self._state = HEADER_NAME_START
                i += 1
            elif self._state == HEADER_NAME_START:
                if c == b'\r':
                    self._state = HEADERS_DONE
                    i += 1
                else:
                    self._state = HEADER_NAME
            elif self._state == HEADER_NAME:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b':':
                        self._state = HEADER_VALUE_START
                        break
                    # TODO: try with a dict access when benchmarked.
                    elif c in (b'(', b')', b'<', b'>', b'@', b',', b';',
                               b'\\', b'"', b'/', b'[', b']', b'?', b'=', b'{',
                               b'}', b' ', b'\t'):
                        raise ValueError('HEADER_NAME')
                    i += 1
                if i > mark:
                    self.on_header_name(data[mark:i])
                i += 1
            elif self._state == HEADER_VALUE_START:
                if c != b' ' and c != b'\t':
                    self._state = HEADER_VALUE
                else:
                    i += 1
            elif self._state == HEADER_VALUE:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b'\r':
                        self._state = HEADER_VALUE_CR
                        break
                    i += 1
                if i > mark:
                    self.on_header_value(data[mark:i])
                i += 1
            elif self._state == HEADER_VALUE_CR:
                if c != b'\n':
                    raise ValueError('HEADER_VALUE_CR')
                self._state = HEADER_NAME_START
                i += 1
            elif self._state == HEADERS_DONE:
                if c != b'\n':
                    raise ValueError('HEADERS_DONE')
                self.on_headers_complete()
                self._state = DATA
                i += 1
            elif self._state == DATA:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b'\r':
                        self._state = DATA_CR
                        break
                    i += 1
                if i > mark:
                    if self._on_data is not None:
                        self._on_data(data[mark:i])
                i += 1
            elif self._state == DATA_CR:
                if c == b'\n':
                    self._state = DATA_CR_LF
                    i += 1
                else:
                    if self._on_data is not None:
                        self._on_data(b'\r')
                    self._state = DATA
            elif self._state == DATA_CR_LF:
                if c == b'-':
                    self._state = DATA_CR_LF_HY
                    i += 1
                else:
                    if self._on_data is not None:
                        self._on_data(b'\r\n')
                    self._state = DATA
            elif self._state == DATA_CR_LF_HY:
                if c == b'-':
                    self._state = DATA_BOUNDARY
                    self._boundary_index = 0
                    i += 1
                else:
                    if self._on_data is not None:
                        self._on_data(b'\r\n-')
                    self._state = DATA
            elif self._state == DATA_BOUNDARY:
                while i < length:
                    c = data[i]
                    if self._boundary_index == self._boundary_length:
                        self._state = DATA_BOUNDARY_DONE
                        break
                    elif c == self._boundary[self._boundary_index]:
                        self._boundary_index += 1
                        i += 1
                    else:
                        if self._on_data is not None:
                            self._on_data(b'\r\n--')
                            self._on_data(self._boundary[:self._boundary_index])
                        self._state = DATA
                        break
            elif self._state == DATA_BOUNDARY_DONE:
                if c == b'\r':
                    self._state = DATA_BOUNDARY_DONE_CR_LF
                elif c == b'-':
                    self._state = DATA_BOUNDARY_DONE_HY_HY
                else:
                    raise ValueError('DATA_BOUNDARY_DONE')
                i += 1
            elif self._state == DATA_BOUNDARY_DONE_CR_LF:
                if c != b'\n':
                    raise ValueError('DATA_BOUNDARY_DONE_CR_LF')
                if self._on_part_complete is not None:
                    self._on_part_complete()
                if self._on_part_begin is not None:
                    self._on_part_begin()
                self._state = HEADER_NAME_START
                i += 1
            elif self._state == DATA_BOUNDARY_DONE_HY_HY:
                if c != b'-':
                    raise ValueError('DATA_BOUNDARY_DONE_HY_HY')
                if self._on_part_complete is not None:
                    self._on_part_complete()
                if self._on_body_complete is not None:
                    self._on_body_complete()
                self._state = EPILOGUE
                i += 1
            elif self._state == EPILOGUE:
                i += 1
                # Must be ignored according to rfc 1341.
                break

    def feed_data(self, bytes data):
        return self._feed_data(data)


cpdef parse_content_disposition(bytes data):
    cdef:
        bytes dtype = None
        dict params = {}
        unsigned int length = len(data)
        unsigned int start = 0
        unsigned int end = 0
        unsigned int i = 0
        bool quoted = False
        char c
        bytes previous = b''
        bytes field = None
    while i < length:
        c = data[i]
        if not quoted and c == b';':
            if dtype is None:
                dtype = data[start:end]
            elif field is not None:
                params[field.lower()] = data[start:end].replace(b'\\', b'')
                field = None
            i += 1
            start = end = i
        elif c == b'"':
            i += 1
            if not previous or previous != b'\\':
                if not quoted:
                    start = i
                quoted = not quoted
            else:
                end = i
        elif c == b'=':
            field = data[start:end]
            i += 1
            start = end = i
        elif c == b' ':
            i += 1
            if not quoted and start == end:  # Leading spaces.
                start = end = i
        else:
            i += 1
            end = i
        previous = c
    if i:
        if dtype is None:
            dtype = data[start:end].lower()
        elif field is not None:
            params[field.lower()] = data[start:end].replace(b'\\', b'')
    return dtype, params


def extract_filename(params: dict):
    if b'filename*' in params:
        filename = params.get(b'filename*')
        if b"''" in filename:
            encoding, filename = filename.split(b"''")
            try:
                return filename.decode(encoding.decode())
            except (LookupError, UnicodeDecodeError):
                pass
        if b'filename' in params:
            return params.get(b'filename').decode()
        return filename.decode(errors='ignore')
    return params.get(b'filename', b'').decode()
