import sys
from pathlib import Path
import tree_sitter_swift
from tree_sitter import Language, Parser

root = Path(r"C:\Users\Ozo\Downloads\OZOAI\OZOAI")
try:
    language = Language(tree_sitter_swift.language())
    parser = Parser(language)
except TypeError:
    language = Language(tree_sitter_swift.language(), "swift")
    parser = Parser()
    parser.set_language(language)

errors = []
for path in sorted(root.rglob("*.swift")):
    source = path.read_text(encoding="utf-8")
    tree = parser.parse(source.encode("utf-8"))
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == "ERROR" or node.is_missing:
            errors.append((path, node))
        stack.extend(node.children)

if not errors:
    print("No syntax errors found in Swift files.")
else:
    for path, node in errors:
        row, col = node.start_point
        print(f"{path.relative_to(root)}:{row+1}:{col+1}: {node.type}")
        print("  " + "\\n  ".join(path.read_text(encoding="utf-8").splitlines()[row:row+4]))
    sys.exit(1)
