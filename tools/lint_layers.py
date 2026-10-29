"""Static layer checks for sim and data. Uses a small string/comment lexer."""
from pathlib import Path, PurePosixPath
import re
import sys

ROOT = Path(__file__).resolve().parents[1] / 'game'
# Keep token positions/newlines while hiding comments and strings from code checks.
TOKENS = re.compile(r'(?P<string>"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')|(?P<comment>\#[^\n]*)')
FORBIDDEN = [
    (r'\b(?:Input|Time|OS)\s*\.', '禁止使用 Input/Time/OS'),
    (r'\bFileAccess\b', '禁止使用 FileAccess'),
    (r'\bget_tree\s*\(', '禁止使用 get_tree'),
    (r'\bsignal\s+\w+', '禁止声明 signal'),
    (r'\.\s*(?:emit|connect)\s*\(', '禁止发送或连接信号'),
    (r'\bemit_signal\s*\(', '禁止使用 emit_signal'),
    (r'(?<![\w.])(?:randf|randi|randf_range|randi_range)\s*\(', '禁止使用全局随机函数'),
]


def masks(source: str) -> tuple[str, str]:
    """Return code-only and comment-free source, retaining source line numbers."""
    blank = lambda s: ''.join('\n' if c == '\n' else ' ' for c in s)
    code = TOKENS.sub(lambda m: blank(m.group()), source)
    no_comments = TOKENS.sub(lambda m: blank(m.group()) if m.lastgroup == 'comment' else m.group(), source)
    return code, no_comments


def lint(root: Path) -> list[str]:
    """Return file:line:rule diagnostics for the supplied Godot project root."""
    files = sorted(p for layer in ('sim', 'data') for p in (root / layer).rglob('*.gd'))
    sources = {p: masks(p.read_text(encoding='utf-8')) for p in files}
    names = {m.group(1) for code, _ in sources.values()
             for m in re.finditer(r'\bclass_name\s+(\w+)', code)}
    errors = []
    for path, (code, no_comments) in sources.items():
        def report(offset: int, rule: str) -> None:
            errors.append('%s:%d: %s' % (path, code.count('\n', 0, offset) + 1, rule))
        is_sim = path.relative_to(root).parts[0] == 'sim'
        if is_sim:
            for match in re.finditer(r'\bextends\b', code):
                tail = no_comments[match.end():].lstrip(' \t')
                target = re.match(r'(["\'])(.*?)\1|([\w.]+)', tail)
                allowed = False
                if target:
                    value = target.group(2) if target.group(1) else target.group(3)
                    if target.group(1):
                        # Normalization prevents res://sim/../view/... bypasses.
                        parts = PurePosixPath(value.removeprefix('res://')).parts
                        allowed = value.startswith(('res://sim/', 'res://data/')) and '..' not in parts
                    else:
                        allowed = value == 'RefCounted' or value in names
                if not allowed:
                    report(match.start(), 'extends 必须使用 RefCounted 或 sim/data 内的类或路径')
            for pattern, rule in FORBIDDEN:
                for match in re.finditer(pattern, code):
                    # A member call remains legal even with whitespace before its name.
                    if '全局随机' in rule and code[:match.start()].rstrip().endswith('.'):
                        continue
                    report(match.start(), rule)
            for match in re.finditer(r'\brandomize\s*\(', code):
                report(match.start(), '禁止 randomize()：系统时间种子会破坏确定性')
            if path.relative_to(root).as_posix() != 'sim/core/run_rng.gd':
                for match in re.finditer(r'\bRandomNumberGenerator\s*\.\s*new\s*\(', code):
                    report(match.start(), '随机数生成器只能在 RunRng 里创建')
        forbidden = ('view', 'app') if is_sim else ('sim', 'view', 'app')
        for match in re.finditer(r'res://(?:' + '|'.join(forbidden) + r')/', no_comments):
            report(match.start(), '禁止引用上层资源 ' + match.group())
    return errors


def main() -> int:
    errors = lint(ROOT)
    for error in errors:
        print(error)
    if not errors:
        print('LAYERS: passed')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
