#!/usr/bin/env python3
"""Merge the SUSFS fix into the SUSFS patch, then patch once. usage: susfs_merge.py <generic.patch> <merged.patch> <fix.patch>..."""
import os, re, shutil, subprocess, sys, tempfile

TRIVIAL = re.compile(r'[{}();\s]*|#\s*(endif|else|if|ifdef|ifndef|elif)\b.*')


def split(text):
    """-> (preamble, [(path, header, [hunk])])"""
    key = r'(?m)^(?=diff --git )' if re.search(r'(?m)^diff --git ', text) else r'(?m)^(?=--- )'
    parts = re.split(key, text)
    out = []
    for p in parts[1:]:
        head, *hunks = re.split(r'(?m)^(?=@@ )', p)
        new = re.search(r'(?m)^\+\+\+ (?:b/)?(\S+)', head)
        old = re.search(r'(?m)^--- (?:a/)?(\S+)', head)
        git = re.match(r'diff --git a/(\S+) b/(\S+)', head)
        path = new.group(1) if new and new.group(1) != '/dev/null' else old.group(1) if old else git.group(2) if git else None
        if path:
            out.append((path, head, hunks))
    return parts[0], out


def build(pre, secs):
    return pre + ''.join(h + ''.join(hs) for _, h, hs in secs)


def run_patch(root, text, *flags):
    r = subprocess.run(['patch', '-p1', '-N', '--batch', '--no-backup-if-mismatch', *flags],
                       cwd=root, input=text, capture_output=True, text=True, errors='replace')
    return r.stdout + r.stderr


def failed(output):
    """-> (set of (section, hunk) rejected or ignored, set of sections skipped whole)"""
    bad, skipped, i = set(), set(), -1
    for line in output.splitlines():
        if line.startswith('patching file ') or line.startswith("can't find file to patch"):
            i += 1
        elif 'Skipping patch' in line:
            skipped.add(i)
        m = re.match(r'Hunk #(\d+) (?:FAILED|ignored)', line)
        if m:
            bad.add((i, int(m.group(1))))
    return bad, skipped


def added(hunk):
    lines = (l[1:].strip() for l in hunk.splitlines()[1:] if l.startswith('+'))
    return {l for l in lines if not TRIVIAL.fullmatch(l)}


def main(generic, merged, fixes):
    gpre, gsecs = split(open(generic).read())
    fsecs = []
    for f in fixes:
        if not os.path.isfile(f):
            sys.exit(f'::error::fix patch not found: {f}')
        fsecs += [(p, h if h.startswith('diff --git') else f'diff --git a/{p} b/{p}\n{h}', hs)
                  for p, h, hs in split(open(f).read())[1] if hs]
    if not fsecs:
        sys.exit('::error::fix patch has no hunks')

    provided = {}
    for p, _, hs in fsecs:
        provided.setdefault(p, set()).update(*map(added, hs))

    # try fix, then generic, on a scratch copy; the fix wins
    drop = set()
    with tempfile.TemporaryDirectory() as tmp:
        for p in {p for p, _, _ in gsecs + fsecs}:
            if os.path.isfile(p):
                os.makedirs(os.path.dirname(os.path.join(tmp, p)), exist_ok=True)
                shutil.copy2(p, os.path.join(tmp, p))
        out = run_patch(tmp, build('', fsecs), '-r', '/dev/null')
        if any(failed(out)):
            sys.exit('::error::SUSFS fix does not fit this kernel:\n' + out[-800:])
        bad, skipped = failed(run_patch(tmp, build(gpre, gsecs), '-r', '/dev/null'))
        drop = set(bad)
        for i in skipped:
            if 0 <= i < len(gsecs):
                drop |= {(i, n) for n in range(1, len(gsecs[i][2]) + 1)}
    for i, (p, _, hs) in enumerate(gsecs):
        for n, h in enumerate(hs, 1):
            mine = added(h)
            if mine and mine <= provided.get(p, set()):
                drop.add((i, n))

    kept = []
    for i, (p, h, hs) in enumerate(gsecs):
        left = [x for n, x in enumerate(hs, 1) if (i, n) not in drop]
        for n in range(1, len(hs) + 1):
            if (i, n) in drop:
                print(f'[+] dropped generic hunk #{n} of {p}')
        if left or not hs:
            kept.append((p, h, left))
    open(merged, 'w').write(build(gpre, fsecs + kept))
    print(f'[+] {merged}: {len(fsecs)} fix + {len(kept)} generic section(s), {len(drop)} hunk(s) dropped')

    out = run_patch('.', open(merged).read())
    print(out)
    bad, skipped = failed(out)
    broken = sorted({fsecs[i][0] for i, _ in bad if i < len(fsecs)} | {fsecs[i][0] for i in skipped if 0 <= i < len(fsecs)})
    if broken:
        sys.exit('::error::SUSFS fix failed on: ' + ', '.join(broken))
    print('[+] SUSFS fix merged and applied.')


if __name__ == '__main__':
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
