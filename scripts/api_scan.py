"""Report global calls and C_ members the WoW Forever client does not have.

Usage: python scripts/api_scan.py <forever_api.json> [addon folder] [--expect-client LABEL]

forever_api.json is the captured Forever API surface (build 1.60.1.69893) published by
Thunderz96/forever-addon-kit (MIT): data/forever_api.json. It is not bundled here.
Findings require review: this scanner cannot infer guards, payloads, or runtime behavior.
"""
import argparse, json, re, pathlib
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("dump", type=pathlib.Path)
parser.add_argument("addon_folder", type=pathlib.Path, nargs="?", default=pathlib.Path(__file__).resolve().parent.parent)
parser.add_argument("--expect-client", help="Require an exact match for the capture's client label")
args = parser.parse_args()
api = json.loads(args.dump.read_text(encoding="utf-8"))
if args.expect_client is not None and api.get("client") != args.expect_client:
    parser.error(f"capture client {api.get('client')!r} does not match {args.expect_client!r}")
funcs = set(api["functions"]); nsp = api["namespaces"]
root = args.addon_folder
LUA = set("assert error ipairs pairs next pcall xpcall print select tonumber tostring type unpack rawget rawset rawequal setmetatable getmetatable loadstring require collectgarbage".split())
skipwords = set("function if then else elseif end and or not local return for while do repeat until in nil true false break".split())
missing, nsmiss = {}, {}
STR_DQ = re.compile(r'"(?:\\.|[^"\\\n])*"')
STR_SQ = re.compile(r"'(?:\\.|[^'\\\n])*'")
for f in sorted(root.glob("*.lua")):
    code = f.read_text(encoding="utf-8")
    code = re.sub(r"--\[\[.*?\]\]", "", code, flags=re.S)
    code = re.sub(r"--[^\n]*", "", code)
    code = STR_DQ.sub('""', code)
    code = STR_SQ.sub("''", code)
    locals_ = set(re.findall(r"local\s+function\s+(\w+)", code))
    for m in re.finditer(r"local\s+([\w\s,]+?)\s*=", code):
        locals_ |= {x.strip() for x in m.group(1).split(",")}
    for m in re.finditer(r"local\s+([\w\s,]+?)\s*\n", code):
        locals_ |= {x.strip() for x in m.group(1).split(",")}
    for m in re.finditer(r"function\s*\w*\s*\(([^)]*)\)", code):
        locals_ |= {x.strip() for x in m.group(1).split(",")}
    for m in re.finditer(r"for\s+([\w\s,]+?)\s+in", code):
        locals_ |= {x.strip() for x in m.group(1).split(",")}
    for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(", code):
        n = m.group(1)
        if n in skipwords or n in LUA or n in locals_ or n in funcs or n.startswith("C_"):
            continue
        missing.setdefault(n, set()).add(f.name)
    for m in re.finditer(r"(?<![\w.])(C_\w+)\.(\w+)", code):
        a, b = m.group(1), m.group(2)
        if a not in nsp:
            nsmiss.setdefault(a + " (namespace)", set()).add(f.name)
        elif b not in nsp[a]:
            nsmiss.setdefault(a + "." + b, set()).add(f.name)
print("Global calls not in the Forever API dump:")
for n in sorted(missing):
    print(" ", n, sorted(missing[n]))
print("C_ members not in the dump:")
for n in sorted(nsmiss):
    print(" ", n, sorted(nsmiss[n]))
print("client:", api["client"])
