# cython: language_level=3

from cpython cimport bool
from collections import defaultdict


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
        unsigned int index
        bytes boundary
        unsigned int boundary_length
        unsigned char state
        object handler
        on_part_begin, on_part_end, on_body_begin, on_body_end, on_headers_complete
        bytes _current_header_field
        bytes _current_header_value

    def __init__(self, handler, bytes boundary):
        self.boundary = boundary
        self.boundary_length = len(boundary)
        self._current_header_field = None
        self._current_header_value = None
        self.handler = handler

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
            unsigned int index = 0
            unsigned int state = 0
            char c
            unsigned int length = len(data)

        while i < length:
            c = data[i]
            # print("state", state)
            # print("processing", repr(chr(c)))
            if state == PREAMBLE:
                if c == b'-':
                    state = PREAMBLE_HY_HY
            elif state == PREAMBLE_HY_HY:
                if c == b'-':
                    state = FIRST_BOUNDARY
                else:
                    state = PREAMBLE
            elif state == FIRST_BOUNDARY:
                if index == self.boundary_length:
                    assert c == b'\r'
                    index += 1
                elif index == self.boundary_length + 1:
                    assert c == b'\n'
                    self.handler.on_body_begin()
                    self.handler.on_part_begin()
                    index = 0
                    state = HEADER_FIELD_START
                elif c == self.boundary[index]:
                    index += 1
                else:
                    raise ValueError('FIRST_BOUNDARY')
            elif state == HEADER_FIELD_START:
                if c == b'\r':
                    state = HEADERS_DONE
                else:
                    state = HEADER_FIELD
            elif state == HEADER_FIELD:
                mark = i
                while i < length:
                    c = data[i]
                    if c in (b'(', b')', b'<', b'>', b'@', b',', b';', b':', b'\\', b'"', b'/', b'[', b']', b'?', b'=', b'{', b'}', b' ', b'\t'):
                        break
                    i += 1
                if i > mark:
                    self.on_header_field(data[mark-1:i])
                if i == length:
                    break
                if c == b':':
                    state = HEADER_VALUE_START
                else:
                    raise ValueError('HEADER_FIELD')
            elif state == HEADER_VALUE_START:
                if c != b' ' and c != b'\t':
                    state = HEADER_VALUE
            elif state == HEADER_VALUE:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b'\r':
                        state = HEADER_VALUE_CR
                        break
                    i += 1
                if i > mark:
                    self.on_header_value(data[mark-1:i])
            elif state == HEADER_VALUE_CR:
                if c == b'\n':
                    state = HEADER_FIELD_START
                else:
                    raise ValueError('HEADER_VALUE_CR')
            elif state == HEADERS_DONE:
                if c == b'\n':
                    self.on_headers_complete()
                    state = DATA
                else:
                    raise ValueError('HEADERS_DONE')
            elif state == DATA:
                mark = i
                while i < length:
                    c = data[i]
                    if c == b'\r':
                        state = DATA_CR
                        break
                    i += 1
                if i > mark:
                    self.handler.on_data(data[mark-1:i])
            elif state == DATA_CR:
                if c == b'\n':
                    state = DATA_CR_LF
                else:
                    self.handler.on_data(b'\r')
                    state = DATA
                    i -= 1
            elif state == DATA_CR_LF:
                if c == b'-':
                    state = DATA_CR_LF_HY
                else:
                    self.handler.on_data(b'\r\n')
                    state = DATA
                    i -= 1
            elif state == DATA_CR_LF_HY:
                if c == b'-':
                    state = DATA_BOUNDARY_START
                else:
                    self.handler.on_data(b'\r\n-')
                    state = DATA
                    i -= 1
            elif state == DATA_BOUNDARY_START:
                index = 0
                state = DATA_BOUNDARY
                i -= 1
            elif state == DATA_BOUNDARY:
                if index == self.boundary_length:
                    index = 0
                    state = DATA_BOUNDARY_DONE
                    i -= 1
                elif c == self.boundary[index]:
                    index += 1
                else:
                    self.handler.on_data(self.boundary[:index])
                    state = DATA
                    i -= 1
            elif state == DATA_BOUNDARY_DONE:
                if c == b'\r':
                    state = DATA_BOUNDARY_DONE_CR_LF
                elif c == b'-':
                    state = DATA_BOUNDARY_DONE_HY_HY
                else:
                    raise ValueError('DATA_BOUNDARY_DONE')
            elif state == DATA_BOUNDARY_DONE_CR_LF:
                if c == b'\n':
                    self.handler.on_part_end()
                    self.handler.on_part_begin()
                    state = HEADER_FIELD_START
                else:
                    raise ValueError('DATA_BOUNDARY_DONE_CR_LF')
            elif state == DATA_BOUNDARY_DONE_HY_HY:
                if c == b'-':
                    self.handler.on_part_end()
                    self.handler.on_body_end()
                    state = EPILOGUE
                else:
                    raise ValueError('DATA_BOUNDARY_DONE_HY_HY')
            elif state == EPILOGUE:
                # Must be ignored according to rfc 1341.
                break
            i += 1

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
        if c == b';':
            if dtype is None:
                dtype = data[start:end]
            elif field is not None:
                params[field.lower()] = data[start:end].replace(b'\\', b'')
                field = None
            i += 1
            start = i
        elif c == b'"':
            i += 1
            if not previous or previous != b'\\':
                if not quoted:
                    start = i
                quoted = not quoted
            else:
                end = i
        elif c == b'=':
            field = data[start:i]
            i += 1
            start = i
        elif not quoted and c == b' ':
            i += 1
            start = i
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


cdef class Parts:

    cdef:
        object parts
        Part _current
        Parser parser

    def __init__(self, str content_type):
        self.parts = defaultdict(list)
        if 'multipart/form-data' in content_type:
            boundary = content_type.split('=', 1)[1].encode()
            self.parser = Parser(self, boundary)

    def __str__(self):
        return str(self.parts)

    def __getitem__(self, key):
        if len(self.parts[key]):
            return self.parts[key][0]
        else:
            raise KeyError(f'No part named {key}')

    def getall(self, key):
        return self.parts[key]

    def feed_data(self, bytes data):
        self.parser.feed_data(data)

    def on_data(self, data: bytes):
        self._current.on_data(data)

    def on_header(self, field, value):
        self._current.headers[field] = value
        print(field, value)

    def on_header_value(self, value):
        print(value)

    def on_headers_complete(self):
        print('on_headers_complete')

    def on_part_begin(self):
        self._current = Part()
        print('on_part_begin')

    def on_part_end(self):
        disposition_type, params = parse_content_disposition(self._current.headers.get(b'Content-Disposition'))
        if not disposition_type:
            return
        self._current.type = disposition_type.decode()
        name = params.get(b'name', b'')
        self._current.name = name.decode()
        self._current.params = params
        self.parts[name].append(self._current)
        self._current = None
        print('on_part_end')

    def on_body_begin(self):
        print('on_body_begin')

    def on_body_end(self):
        print('on_body_end')


cdef class Part:

    cdef:
        public dict headers
        public dict params
        public str type
        public str name
        object _file
        bytes _data

    def __init__(self):
        self.headers = {}
        self._file = None
        self._data = b''

    def __str__(self):
        return str(self.headers)

    def __repr__(self):
        return f'<Part {self.headers}>'

    def on_data(self, data: bytes):
        # if len(self._data) > MAX_BUFFER_SIZE:
        #     self._file.write(data)
        # else:
        self._data += data

    def is_file(self):
        return self._file is not None

    @property
    def filename(self):
        if b'filename*' in self.params:
            return self.params[b'filename*']
        return self.params[b'filename']
