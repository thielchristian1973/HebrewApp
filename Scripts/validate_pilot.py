#!/usr/bin/env python3
"""Validate the supplied pilot bundle; no linguistic or platform validation."""
import hashlib
import json
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / 'Content' / 'Pilot'

def require(condition, message):
    if not condition:
        raise ValueError(message)

def load(name):
    return json.loads((BASE / name).read_text(encoding='utf-8'))

def validate():
    manifest = load('manifest.json')
    require(manifest['schemaVersion'] == 1, 'Unsupported pilot schema')
    require(manifest['status'] == 'draft', 'Pilot must not claim release approval')
    expected_names = {'lexemes.json', 'sentences.json', 'dialogues.json'}
    require({f['path'] for f in manifest['files']} == expected_names, 'Manifest file mismatch')
    require(len(manifest['files']) == 3, 'Duplicate manifest entries')
    for entry in manifest['files']:
        path = BASE / entry['path']
        require(hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], f'Hash mismatch: {path.name}')
    groups = {name: load(name + '.json') for name in ('lexemes', 'sentences', 'dialogues')}
    expected = {'lexemes': 50, 'sentences': 20, 'dialogues': 4}
    require(manifest['counts'] == expected, 'Unexpected manifest counts')
    ids = set()
    for kind, rows in groups.items():
        require(len(rows) == expected[kind], f'Wrong count: {kind}')
        for row in rows:
            require(row['id'] not in ids, f'Duplicate ID: {row["id"]}')
            ids.add(row['id'])
            require(row['reviewStatus'] == 'draft', 'Unreviewed data must stay draft')
            if kind != 'dialogues':
                for field in ('hebrew', 'german', 'ttsText'):
                    require(isinstance(row[field], str) and row[field].strip(), f'Empty {field}')
                require(any('\u05d0' <= ch <= '\u05ea' for ch in row['hebrew']), 'Missing Hebrew text')
    sentence_ids = {row['id'] for row in groups['sentences']}
    for dialog in groups['dialogues']:
        nodes = {node['id']: node for node in dialog['nodes']}
        require(len(nodes) == len(dialog['nodes']), 'Duplicate node')
        require(dialog['startNodeID'] in nodes, 'Missing start node')
        for node in nodes.values():
            require(node['promptSentenceID'] in sentence_ids, 'Unknown prompt')
            require(node['terminal'] == (len(node['answers']) == 0), 'Invalid terminal flag')
            answers = [answer['sentenceID'] for answer in node['answers']]
            require(len(answers) == len(set(answers)), 'Duplicate answer choice')
            for answer in node['answers']:
                require(answer['sentenceID'] in sentence_ids, 'Unknown answer sentence')
                require(answer['nextNodeID'] in nodes, 'Unknown destination')
        reachable, pending = set(), [dialog['startNodeID']]
        while pending:
            current = pending.pop()
            if current in reachable:
                continue
            reachable.add(current)
            pending.extend(a['nextNodeID'] for a in nodes[current]['answers'])
        require(reachable == set(nodes), 'Unreachable node')
        can_finish = {key for key, node in nodes.items() if node['terminal']}
        changed = True
        while changed:
            updated = can_finish | {key for key, node in nodes.items() if any(a['nextNodeID'] in can_finish for a in node['answers'])}
            changed = updated != can_finish
            can_finish = updated
        require(can_finish == set(nodes), 'A node cannot reach an ending')
    print('PASS: 50 lexemes, 20 sentences, 4 reachable/terminating dialogues; IDs and SHA256 valid.')
    print('Language review, audio quality, iOS builds and device tests remain OPEN.')

if __name__ == '__main__':
    try:
        validate()
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
