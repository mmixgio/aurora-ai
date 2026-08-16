#!/usr/bin/env python3
"""Controlla che Cash.xcodeproj sia coerente prima ancora di aprire Xcode.

Il formato `project.pbxproj` è un vecchio plist in stile OpenStep. Qui viene
letto con un parser minimale e poi verificato su tre punti:

  1. il file si legge fino in fondo senza parentesi spaiate;
  2. ogni identificatore citato da qualche parte esiste davvero;
  3. ogni file elencato nel progetto esiste sul disco.

Sono esattamente i tre modi in cui un progetto generato a mano si rompe, e
l'unico messaggio che Xcode darebbe in cambio è "cannot be opened".
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "Cash.xcodeproj" / "project.pbxproj"

TOKEN = re.compile(r'"(?:[^"\\]|\\.)*"|[A-Za-z0-9_./$@:+~-]+|[{}();,=]')


def tokenize(text):
    """Toglie i commenti e restituisce i simboli del file."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"^//.*$", " ", text, flags=re.M)
    return TOKEN.findall(text)


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def take(self):
        token = self.peek()
        self.pos += 1
        return token

    def expect(self, expected):
        token = self.take()
        if token != expected:
            raise ValueError(f"atteso {expected!r}, trovato {token!r} in posizione {self.pos}")

    def value(self):
        token = self.peek()
        if token == "{":
            return self.dictionary()
        if token == "(":
            return self.array()
        return unquote(self.take())

    def dictionary(self):
        self.expect("{")
        result = {}
        while self.peek() != "}":
            key = unquote(self.take())
            self.expect("=")
            result[key] = self.value()
            if self.peek() == ";":
                self.take()
        self.expect("}")
        return result

    def array(self):
        self.expect("(")
        items = []
        while self.peek() != ")":
            items.append(self.value())
            if self.peek() == ",":
                self.take()
        self.expect(")")
        return items


def unquote(token):
    if token and token.startswith('"') and token.endswith('"') and len(token) > 1:
        return token[1:-1].replace('\\"', '"')
    return token


def walk(node, visit):
    if isinstance(node, dict):
        for value in node.values():
            walk(value, visit)
    elif isinstance(node, list):
        for value in node:
            walk(value, visit)
    else:
        visit(node)


def resolve_path(objects, file_ref, groups_by_child):
    """Ricostruisce il percorso di un file risalendo l'albero dei gruppi."""
    parts = []
    node_id = file_ref

    while node_id is not None:
        node = objects.get(node_id, {})
        segment = node.get("path")
        if segment:
            parts.append(segment)
        node_id = groups_by_child.get(node_id)

    return Path(*reversed(parts)) if parts else None


def main():
    if not PBXPROJ.exists():
        sys.exit(f"manca {PBXPROJ}: lancia prima tools/generate_xcodeproj.py")

    try:
        root = Parser(tokenize(PBXPROJ.read_text(encoding="utf-8"))).dictionary()
    except (ValueError, IndexError) as error:
        sys.exit(f"il file non si legge: {error}")

    objects = root["objects"]
    problems = []

    # 1. Ogni identificatore citato deve esistere.
    identifier = re.compile(r"^[0-9A-F]{24}$")
    referenced = set()
    walk(objects, lambda value: referenced.add(value) if isinstance(value, str) and identifier.match(value) else None)
    referenced.add(root["rootObject"])

    for missing in sorted(referenced - set(objects)):
        problems.append(f"identificatore citato ma non definito: {missing}")

    # 2. Ogni file del progetto deve esistere sul disco.
    groups_by_child = {}
    for object_id, node in objects.items():
        if isinstance(node, dict) and node.get("isa") in {"PBXGroup", "PBXVariantGroup"}:
            for child in node.get("children", []):
                groups_by_child[child] = object_id

    checked = 0
    for object_id, node in objects.items():
        if not isinstance(node, dict) or node.get("isa") != "PBXFileReference":
            continue
        if node.get("sourceTree") != "<group>":
            continue

        relative = resolve_path(objects, object_id, groups_by_child)
        if relative is None:
            problems.append(f"file senza percorso: {object_id}")
            continue

        checked += 1
        if not (ROOT / relative).exists():
            problems.append(f"file elencato ma assente sul disco: {relative}")

    # 3. Il target deve avere le sue fasi e il suo prodotto.
    targets = [n for n in objects.values() if isinstance(n, dict) and n.get("isa") == "PBXNativeTarget"]
    if not targets:
        problems.append("nessun target applicativo nel progetto")
    for target in targets:
        if not target.get("buildPhases"):
            problems.append(f"il target {target.get('name')} non ha fasi di build")
        if not target.get("buildConfigurationList"):
            problems.append(f"il target {target.get('name')} non ha configurazioni")

    sources = [n for n in objects.values() if isinstance(n, dict) and n.get("isa") == "PBXSourcesBuildPhase"]
    compiled = sum(len(phase.get("files", [])) for phase in sources)

    if problems:
        print("PROBLEMI:")
        for problem in problems:
            print(f"  - {problem}")
        sys.exit(1)

    print(f"project.pbxproj valido: {len(objects)} oggetti, "
          f"{checked} file verificati sul disco, {compiled} sorgenti da compilare.")


if __name__ == "__main__":
    main()
