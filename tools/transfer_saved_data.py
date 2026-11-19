"""Copy one existing WoW saved-variable table to GatherlyDB; never execute Lua."""
from pathlib import Path
import argparse
import re

LONG = re.compile(r'\[(=*)\[')
IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')
NUMBER = re.compile(r'(?:0[xX][0-9A-Fa-f]+|(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?)')
RESERVED = set('and break do else elseif end false for function if in local nil not or repeat return then true until while'.split())


def long_end(text: str, start: int):
    match = LONG.match(text, start)
    if not match:
        return None
    closing = ']' + match[1] + ']'
    end = text.find(closing, match.end())
    if end < 0:
        raise ValueError('Unterminated long string or comment in saved data.')
    return end + len(closing)


def skip(text: str, start: int) -> int:
    while start < len(text):
        if text[start].isspace():
            start += 1
        elif text.startswith('--', start):
            end = long_end(text, start + 2)
            if end is None:
                end = text.find('\n', start + 2)
                if end < 0:
                    return len(text)
            start = end
        else:
            break
    return start


class Reader:
    """Validate the literal table grammar produced by WoW's save serializer."""
    def __init__(self, text: str):
        self.text = text
        self.position = 0
        self.advance()

    def advance(self) -> None:
        text = self.text
        start = skip(text, self.position)
        self.start = start
        if start == len(text):
            self.kind, self.value, self.end = 'eof', '', start
            return
        character = text[start]
        end = long_end(text, start) if character == '[' else None
        if end is not None:
            kind = 'string'
        elif character in ('"', "'"):
            kind, end = 'string', start + 1
            while end < len(text) and text[end] != character:
                if text[end] in '\r\n':
                    raise ValueError('Unescaped newline in quoted string.')
                if text[end] == '\\':
                    end += 1
                    if end < len(text) and text[end].isdigit():
                        digits = re.match(r'[0-9]{1,3}', text[end:])
                        if not digits or int(digits[0]) > 255:
                            raise ValueError('Invalid numeric string escape.')
                        end += len(digits[0])
                        continue
                    if end < len(text) and text[end] == '\r' and text[end:end + 2] == '\r\n':
                        end += 1
                end += 1
            if end >= len(text):
                raise ValueError('Unterminated quoted string in saved data.')
            end += 1
        else:
            match = IDENTIFIER.match(text, start)
            number = NUMBER.match(text, start)
            if match:
                kind, end = 'name', match.end()
            elif number:
                kind, end = 'number', number.end()
            else:
                kind, end = character, start + 1
        self.kind, self.value, self.end = kind, text[start:end], end
        self.position = end

    def expect(self, kind: str) -> None:
        if self.kind != kind:
            raise ValueError('Invalid serialized saved-variable table.')
        self.advance()

    def value_item(self, depth: int) -> None:
        if self.kind == '{':
            self.table(depth + 1)
        elif self.kind in {'string', 'number'} or self.kind == 'name' and self.value in {'true', 'false', 'nil'}:
            self.advance()
        elif self.kind == '-':
            self.advance()
            self.expect('number')
        else:
            raise ValueError('Expected literal saved data; executable expressions are not accepted.')

    def table(self, depth: int = 0) -> None:
        if depth > 128:
            raise ValueError('Saved data is nested too deeply.')
        self.expect('{')
        while self.kind != '}':
            if self.kind == '[':
                self.advance()
                self.value_item(depth)
                self.expect(']')
                self.expect('=')
                self.value_item(depth)
            elif self.kind == 'name' and self.value not in RESERVED:
                self.advance()
                self.expect('=')
                self.value_item(depth)
            else:
                self.value_item(depth)
            if self.kind in {',', ';'}:
                self.advance()
            elif self.kind != '}':
                raise ValueError('Missing saved-table field separator.')
        self.expect('}')


def transfer(source: Path, destination: Path) -> None:
    source, destination = Path(source), Path(destination)
    if source.resolve() == destination.resolve():
        raise ValueError('Choose a new destination; the source must remain unchanged.')
    data = source.read_bytes()
    bom = b'\xef\xbb\xbf' if data.startswith(b'\xef\xbb\xbf') else b''
    text = data.decode('utf-8-sig')
    reader = Reader(text)
    if reader.kind != 'name' or reader.value in RESERVED:
        raise ValueError('Expected one named saved-variable table.')
    start, end = reader.start, reader.end
    reader.advance()
    reader.expect('=')
    reader.table()
    if reader.kind == ';':
        reader.advance()
    if reader.kind != 'eof':
        raise ValueError('Expected one table; additional top-level content found.')
    output = bom + (text[:start] + 'GatherlyDB' + text[end:]).encode('utf-8')
    with destination.open('xb') as stream:
        stream.write(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Your existing saved-variable Lua file')
    parser.add_argument('destination', type=Path, help='A new Gatherly.lua output file')
    args = parser.parse_args()
    try:
        transfer(args.source, args.destination)
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(1, f'Transfer stopped: {error}\n')
    print(f'Created {args.destination}. The source file is unchanged.')


if __name__ == '__main__':
    main()
