#!/usr/bin/env python3
"""Exercise an actual FPM request using an extension built by our CLI image."""
import socket
import struct
import sys
import time


def record(kind, content):
    return struct.pack('!BBHHBB', 1, kind, 1, len(content), 0, 0) + content


def exact(sock, size):
    data = b''
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise EOFError('FPM closed connection before completing request')
        data += chunk
    return data


def request():
    with socket.create_connection(('127.0.0.1', int(sys.argv[1])), timeout=5) as sock:
        params = b''
        for key, value in [(b'SCRIPT_FILENAME', b'/var/www/html/source-smoke.php'),
                           (b'REQUEST_METHOD', b'GET')]:
            params += bytes([len(key), len(value)]) + key + value
        sock.sendall(record(1, struct.pack('!HB5x', 1, 0)) + record(4, params) + record(4, b'') + record(5, b''))
        output = b''
        while True:
            _, kind, _, length, padding, _ = struct.unpack('!BBHHBB', exact(sock, 8))
            content = exact(sock, length)
            exact(sock, padding)
            if kind == 6:
                output += content
            elif kind == 7 and content:
                raise RuntimeError(content.decode())
            elif kind == 3:
                if struct.unpack('!IB3x', content) != (0, 0):
                    raise RuntimeError('FastCGI request failed')
                break
        return output


# Docker's published port may accept a connection before the entrypoint has
# started FPM. Retry transport failures, but never hide PHP/application errors.
deadline = time.monotonic() + 15
while True:
    try:
        output = request()
        break
    except (OSError, EOFError):
        if time.monotonic() >= deadline:
            raise
        time.sleep(0.1)
expected = (sys.argv[2] + ':3').encode()
if output.split(b'\r\n\r\n', 1)[-1] != expected:
    raise RuntimeError(repr(output))
print('PASS: FPM served PHP ' + sys.argv[2] + ' using the CLI-built bcmath extension')
