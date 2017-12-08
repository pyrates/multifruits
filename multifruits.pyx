# cython: language_level=3

from cpython cimport bool


cdef enum state:
    PREAMBLE,  # 0
    PREAMBLE_HY_HY,
    FIRST_BOUNDARY,
    HEADER_FIELD_START,
    HEADER_FIELD,
    HEADER_VALUE_START,  # 5
    HEADER_VALUE,
    HEADER_VALUE_CR,
    HEADERS_DONE,
    DATA,
    DATA_CR,  # 10
    DATA_CR_LF,
    DATA_CR_LF_HY,
    DATA_BOUNDARY_START,
    DATA_BOUNDARY,
    DATA_BOUNDARY_DONE,  # 15
    DATA_BOUNDARY_DONE_CR_LF,
    DATA_BOUNDARY_DONE_HY_HY,
    EPILOGUE,

cdef class Parser:

    cdef:
        char* data
        bytes boundary
        unsigned int boundary_index
        unsigned int boundary_length
        unsigned char state
        object handler
        on_part_begin, on_part_complete, on_body_begin, on_body_complete, on_headers_complete
        bytes _current_header_field
        bytes _current_header_value

    def __init__(self, handler, bytes content_type):
        cdef dict params
        cdef bytes _
        _, params = parse_content_disposition(content_type)
        self.boundary = params[b'boundary']
        self.boundary_length = len(self.boundary)
        self._current_header_field = None
        self._current_header_value = None
        self.handler = handler
        self.state = 0
        self.boundary_index = 0

    def _maybe_call_on_header(self):
        if self._current_header_value is not None:
            self.handler.on_header(self._current_header_field, self._current_header_value)
            self._current_header_field = self._current_header_value = None

    def on_header_field(self, data):
        self._maybe_call_on_header()
        if self._current_header_field is None:
            self._current_header_field = data
        else:
            self._current_header_field += data

    def on_header_value(self, data):
        if self._current_header_value is None:
            self._current_header_value = data
        else:
            self._current_header_value += data

    def on_headers_complete(self):
        self._maybe_call_on_header()
        self.handler.on_headers_complete()

    cdef _feed_data(self, char* data):
        cdef:
            unsigned int i = 0
            unsigned int mark = 0
            char c
            unsigned int length = len(data)

        while i < length:
            c = data[i]
            # print("state", self.state)
            # print("processing", repr(chr(c)))
            if self.state == PREAMBLE:
                if c == b'-':
                    self.state = PREAMBLE_HY_HY
                i += 1
            elif self.state == PREAMBLE_HY_HY:
                if c == b'-':
                    self.state = FIRST_BOUNDARY
                else:
                    self.state = PREAMBLE
                i += 1
            elif self.state == FIRST_BOUNDARY:
                if self.boundary_index == self.boundary_length:
                    assert c == b'\r'
                    self.boundary_index += 1
                elif self.boundary_index == self.boundary_length + 1:
                    assert c == b'\n'
                    self.handler.on_body_begin()
                    self.handler.on_part_begin()
                    self.boundary_index = 0
                    self.state = HEADER_FIELD_START
                elif c == self.boundary[self.boundary_index]:
                    self.boundary_index += 1
                else:
                    raise ValueError('FIRST_BOUNDARY')
                i += 1
            elif self.state == HEADER_FIELD_START:
                if c == b'\r':
                    self.state = HEADERS_DONE
                    i += 1
                else:
                    self.state = HEADER_FIELD
            elif self.state == HEADER_FIELD:
                mark = i
                while i < length:
                    c = data[i]
                    if c in (b'(', b')', b'<', b'>', b'@', b',', b';', b':',
                             b'\\', b'"', b'/', b'[', b']', b'?', b'=', b'{',
                             b'}', b' ', b'\t'):
                        break
                    i += 1
                if i > mark:
                    self.on_header_field(data[mark:i])
                if i == length:
                    break
                if c == b':':
                    self.state = HEADER_VALUE_START
                else:
                    raise ValueError('HEADER_FIELD')
                i += 1
            elif self.state == HEADER_VALUE_START:
                if c != b' ' and c != b'\t':
                    self.state = HEADER_VALUE
                else:
                    i += 1
            elif self.state == HEADER_VALUE:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b'\r':
                        self.state = HEADER_VALUE_CR
                        break
                    i += 1
                if i > mark:
                    self.on_header_value(data[mark:i])
                i += 1
            elif self.state == HEADER_VALUE_CR:
                if c == b'\n':
                    self.state = HEADER_FIELD_START
                else:
                    raise ValueError('HEADER_VALUE_CR')
                i += 1
            elif self.state == HEADERS_DONE:
                if c == b'\n':
                    self.on_headers_complete()
                    self.state = DATA
                else:
                    raise ValueError('HEADERS_DONE')
                i += 1
            elif self.state == DATA:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b'\r':
                        self.state = DATA_CR
                        break
                    i += 1
                if i > mark:
                    self.handler.on_data(data[mark:i])
                i += 1
            elif self.state == DATA_CR:
                if c == b'\n':
                    self.state = DATA_CR_LF
                    i += 1
                else:
                    self.handler.on_data(b'\r')
                    self.state = DATA
            elif self.state == DATA_CR_LF:
                if c == b'-':
                    self.state = DATA_CR_LF_HY
                    i += 1
                else:
                    self.handler.on_data(b'\r\n')
                    self.state = DATA
            elif self.state == DATA_CR_LF_HY:
                if c == b'-':
                    self.state = DATA_BOUNDARY_START
                    i += 1
                else:
                    self.handler.on_data(b'\r\n-')
                    self.state = DATA
            elif self.state == DATA_BOUNDARY_START:
                self.boundary_index = 0
                self.state = DATA_BOUNDARY
            elif self.state == DATA_BOUNDARY:
                if self.boundary_index == self.boundary_length:
                    self.boundary_index = 0
                    self.state = DATA_BOUNDARY_DONE
                elif c == self.boundary[self.boundary_index]:
                    self.boundary_index += 1
                    i += 1
                else:
                    self.handler.on_data(self.boundary[:self.boundary_index])
                    self.state = DATA
            elif self.state == DATA_BOUNDARY_DONE:
                if c == b'\r':
                    self.state = DATA_BOUNDARY_DONE_CR_LF
                elif c == b'-':
                    self.state = DATA_BOUNDARY_DONE_HY_HY
                else:
                    raise ValueError('DATA_BOUNDARY_DONE')
                i += 1
            elif self.state == DATA_BOUNDARY_DONE_CR_LF:
                if c == b'\n':
                    self.handler.on_part_complete()
                    self.handler.on_part_begin()
                    self.state = HEADER_FIELD_START
                else:
                    raise ValueError('DATA_BOUNDARY_DONE_CR_LF')
                i += 1
            elif self.state == DATA_BOUNDARY_DONE_HY_HY:
                if c == b'-':
                    self.handler.on_part_complete()
                    self.handler.on_body_complete()
                    self.state = EPILOGUE
                else:
                    raise ValueError('DATA_BOUNDARY_DONE_HY_HY')
                i += 1
            elif self.state == EPILOGUE:
                i += 1
                # Must be ignored according to rfc 1341.
                break

    def feed_data(self, char* data):
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
    return params.get(b'filename').decode()
