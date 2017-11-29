# cython: language_level=3


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
        unsigned int boundary_length
        unsigned char state
        dict settings
        char* boundary
        on_part_begin, on_part_end, on_body_begin, on_body_end, on_headers_complete

    def __init__(self, char* boundary, dict settings):
        self.boundary = boundary
        self.settings = settings
        self.boundary_length = len(boundary)
        self.index = 0
        self.state = PREAMBLE

        # self.on_header_value = self.with_data
        # self.on_header_field = self.with_data
        self.on_headers_complete = self.notify
        # self.on_data = self.with_data
        self.on_part_begin = self.notify
        self.on_part_end = self.notify
        self.on_body_begin = self.notify
        self.on_body_end = self.notify

    def on_header_value(self, what):
        print('header value', what)

    def on_header_field(self, what):
        print('header field', what)

    def on_data(self, what):
        print('on data', what)

    def with_data(self, what, length):
        print(what, length)

    def notify(self):
        pass

    cdef call(self, char* buffer, unsigned int length):
        cdef:
            unsigned int i = 0
            unsigned int mark = 0
            char c

        while i < length:
            c = buffer[i]
            # print("state", self.state)
            # print("processing", repr(chr(c)))
            if self.state == PREAMBLE:
                if c == b'-':
                    self.state = PREAMBLE_HY_HY
            elif self.state == PREAMBLE_HY_HY:
                if c == b'-':
                    self.state = FIRST_BOUNDARY
                else:
                    self.state = PREAMBLE
            elif self.state == FIRST_BOUNDARY:
                if self.index == self.boundary_length:
                    assert c == b'\r'
                    self.index += 1
                elif self.index == self.boundary_length + 1:
                    assert c == b'\n'
                    self.on_body_begin()
                    self.on_part_begin()
                    self.index = 0
                    self.state = HEADER_FIELD_START
                elif c == self.boundary[self.index]:
                    self.index += 1
                else:
                    raise ValueError('FIRST_BOUNDARY')
            elif self.state == HEADER_FIELD_START:
                if c == b'\r':
                    self.state = HEADERS_DONE
                else:
                    self.state = HEADER_FIELD
            elif self.state == HEADER_FIELD:
                mark = i
                while i < length:
                    c = buffer[i]
                    if c in (b'(', b')', b'<', b'>', b'@', b',', b';', b':', b'\\', b'"', b'/', b'[', b']', b'?', b'=', b'{', b'}', b' ', b'\t'):
                        break
                    i += 1
                if i > mark:
                    self.on_header_field(buffer[mark-1:i])
                if i == length:
                    break
                if c == b':':
                    self.state = HEADER_VALUE_START
                else:
                    raise ValueError('HEADER_FIELD')
            elif self.state == HEADER_VALUE_START:
                if c != b' ' and c != b'\t':
                    self.state = HEADER_VALUE
            elif self.state == HEADER_VALUE:
                mark = i
                while i < length:
                    c = buffer[i]
                    if c == b'\r':
                        self.state = HEADER_VALUE_CR
                        break
                    i += 1
                if i > mark:
                    self.on_header_value(buffer[mark-1:i])
            elif self.state == HEADER_VALUE_CR:
                if c == b'\n':
                    self.state = HEADER_FIELD_START
                else:
                    raise ValueError('HEADER_VALUE_CR')
            elif self.state == HEADERS_DONE:
                if c == b'\n':
                    self.on_headers_complete()
                    self.state = DATA
                else:
                    raise ValueError('HEADERS_DONE')
            elif self.state == DATA:
                mark = i
                while i < length:
                    c = buffer[i]
                    if c == b'\r':
                        self.state = DATA_CR
                        break
                    i += 1
                if i > mark:
                    self.on_data(buffer[mark-1:i])
            elif self.state == DATA_CR:
                if c == b'\n':
                    self.state = DATA_CR_LF
                else:
                    self.on_data(b'\r')
                    self.state = DATA
                    i -= 1
            elif self.state == DATA_CR_LF:
                if c == b'-':
                    self.state = DATA_CR_LF_HY
                else:
                    self.on_data(b'\r\n')
                    self.state = DATA
                    i -= 1
            elif self.state == DATA_CR_LF_HY:
                if c == b'-':
                    self.state = DATA_BOUNDARY_START
                else:
                    self.on_data(b'\r\n-')
                    self.state = DATA
                    i -= 1
            elif self.state == DATA_BOUNDARY_START:
                self.index = 0
                self.state = DATA_BOUNDARY
                i -= 1
            elif self.state == DATA_BOUNDARY:
                if self.index == self.boundary_length:
                    self.index = 0
                    self.state = DATA_BOUNDARY_DONE
                    i -= 1
                elif c == self.boundary[self.index]:
                    self.index += 1
                else:
                    self.on_data(self.boundary[:self.index])
                    self.state = DATA
                    i -= 1
            elif self.state == DATA_BOUNDARY_DONE:
                if c == b'\r':
                    self.state = DATA_BOUNDARY_DONE_CR_LF
                elif c == b'-':
                    self.state = DATA_BOUNDARY_DONE_HY_HY
                else:
                    raise ValueError('DATA_BOUNDARY_DONE')
            elif self.state == DATA_BOUNDARY_DONE_CR_LF:
                if c == b'\n':
                    self.on_part_end()
                    self.on_part_begin()
                    self.state = HEADER_FIELD_START
                else:
                    raise ValueError('DATA_BOUNDARY_DONE_CR_LF')
            elif self.state == DATA_BOUNDARY_DONE_HY_HY:
                if c == b'-':
                    self.on_part_end()
                    self.on_body_end()
                    self.state = EPILOGUE
                else:
                    raise ValueError('DATA_BOUNDARY_DONE_HY_HY')
            elif self.state == EPILOGUE:
                # Must be ignored according to rfc 1341.
                break
            i += 1

    def __call__(self, char* buffer):
        return self.call(buffer, len(buffer))
