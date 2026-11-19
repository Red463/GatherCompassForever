"""Copy one existing WoW saved-variable table to GatherlyDB; never execute Lua."""
from pathlib import Path
import argparse
import re

LONG = re.compile(r'\[(=*)\[')
IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')


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


def table_end(text: str, start: int) -> int:
    depth = 0
    while start < len(text):
        start = skip(text, start)
        if start >= len(text):
            break
        character = text[start]
        if character in ('"', "'"):
            quote = character
            start += 1
            while start < len(text) and text[start] != quote:
                start += 2 if text[start] == '\\' else 1
            if start >= len(text):
                raise ValueError('Unterminated quoted string in saved data.')
        elif character == '[':
            end = long_end(text, start)
            if end is not None:
                start = end
                continue
        elif character == '{':
            depth += 1
        elif character == '}':
            depth -= 1
            if depth == 0:
                return start + 1
        start += 1
    raise ValueError('Incomplete saved-variable table.')


def transfer(source: Path, destination: Path) -> None:
    source, destination = Path(source), Path(destination)
    if source.resolve() == destination.resolve():
        raise ValueError('Choose a new destination; the source must remain unchanged.')
    text = source.read_bytes().decode('utf-8-sig')
    root = IDENTIFIER.match(text, skip(text, 0))
    if not root:
        raise ValueError('Expected one named saved-variable table.')
    equals = skip(text, root.end())
    if equals >= len(text) or text[equals] != '=':
        raise ValueError('Expected one named saved-variable table.')
    start = skip(text, equals + 1)
    if start >= len(text) or text[start] != '{':
        raise ValueError('The saved variable must contain a table.')
    if skip(text, table_end(text, start)) != len(text):
        raise ValueError('Expected one table; additional top-level content found.')
    output = ('GatherlyDB' + text[root.end():]).encode('utf-8')
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
