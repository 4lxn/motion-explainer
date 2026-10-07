#!/bin/bash
# Build every example (lint must pass), then run the player control, resource and voice tests.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/motion-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0

for s in "$ROOT"/examples/*.scene.js; do
  name=$(basename "$s" .scene.js)
  if "$ROOT/bin/motion" build "$s" "$tmp/$name.html" > "$tmp/$name.log" 2>&1; then
    echo "ok   lint $name ($(grep -c '^warn' "$tmp/$name.log" || true) warnings)"
  else
    echo "FAIL lint $name"; sed 's/^/     /' "$tmp/$name.log"; fail=1
  fi
done

cat "$ROOT/examples/binary-search.scene.js" "$ROOT/test/controls.test.js" > "$tmp/controls.scene.js"
if out=$("$ROOT/bin/motion" build "$tmp/controls.scene.js" 2>&1) && printf '%s\n' "$out" | grep -q '^test-pass'; then
  echo "ok   controls ($(printf '%s\n' "$out" | awk '/^test-pass/ { print $2 }') checks)"
else
  echo "FAIL controls"; printf '%s\n' "$out" | grep -E '^(error|test-pass|FAIL)' | sed 's/^/     /'; fail=1
fi
cat "$ROOT/examples/showcase.scene.js" "$ROOT/test/resources.test.js" > "$tmp/resources.scene.js"
if out=$("$ROOT/bin/motion" build "$tmp/resources.scene.js" 2>&1) && printf '%s\n' "$out" | grep -q '^test-pass'; then
  echo "ok   resources ($(printf '%s\n' "$out" | awk '/^test-pass/ { print $2 }') checks)"
else
  echo "FAIL resources"; printf '%s\n' "$out" | grep -E '^(error|test-pass|FAIL)' | sed 's/^/     /'; fail=1
fi
# Voice: a fake voice.js beside the scene, so the separate <script> block and its CSP hash are tested too.
node "$ROOT/tools/narration.mjs" "$ROOT/examples/binary-search.scene.js" > "$tmp/narration.json"
fake() {
  node -e 'const s = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const v = [{ dur: 30, say: s[0].say }, { dur: 1, say: s[1].say }].map(c => ({ ...c, src: "data:audio/wav;base64," }));
    if (process.argv[2] === "stale") v[1].say += " (edited)";
    console.log("Motion.voice = " + JSON.stringify(v) + ";");' "$tmp/narration.json" "$1"
}
mkdir -p "$tmp/voice.voice" "$tmp/stale.voice"
cat "$ROOT/examples/binary-search.scene.js" "$ROOT/test/voice.test.js" > "$tmp/voice.scene.js"
fake fresh > "$tmp/voice.voice/voice.js"
if out=$("$ROOT/bin/motion" build "$tmp/voice.scene.js" 2>&1) && printf '%s\n' "$out" | grep -q '^test-pass'; then
  echo "ok   voice ($(printf '%s\n' "$out" | awk '/^test-pass/ { print $2 }') checks)"
else
  echo "FAIL voice"; printf '%s\n' "$out" | grep -E '^(error|test-pass|FAIL)' | sed 's/^/     /'; fail=1
fi
cp "$ROOT/examples/binary-search.scene.js" "$tmp/stale.scene.js"
fake stale > "$tmp/stale.voice/voice.js"
out=$("$ROOT/bin/motion" build "$tmp/stale.scene.js" 2>&1 || true)
if printf '%s\n' "$out" | grep -q 'step 2: voice clip is out of date' && printf '%s\n' "$out" | grep -q '^voice 1 clips 30.0'; then
  echo "ok   voice: stale clip dropped"
else
  echo "FAIL voice: stale clip"; printf '%s\n' "$out" | sed 's/^/     /'; fail=1
fi

if PYTHONDONTWRITEBYTECODE=1 python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import voice
b = voice.js_block([{"dur": 1, "say": "a </script> b", "src": "data:,"}, None])
sys.exit(0 if "</" not in b and "<\\/script>" in b else 1)' "$ROOT/tools"; then
  echo "ok   voice.js escapes </"
else
  echo "FAIL voice.js escaping"; fail=1
fi
printf 'Motion.voice = [{"dur": 1, "say": "</script>", "src": "data:,"}];\n' > "$tmp/stale.voice/voice.js"
if out=$("$ROOT/bin/motion" build "$tmp/stale.scene.js" 2>&1); then
  echo "FAIL voice.js with </script was embedded"; fail=1
elif printf '%s\n' "$out" | grep -q "contains '</script'"; then
  echo "ok   voice.js with </script is refused"
else
  echo "FAIL voice.js guard message"; printf '%s\n' "$out" | sed 's/^/     /'; fail=1
fi

out=$("$ROOT/bin/motion" build "$ROOT/test/note-title.scene.js" "$tmp/note-title.html" 2>&1 || true)
if printf '%s\n' "$out" | grep -q '^test-pass' && printf '%s\n' "$out" | grep -q "a word in the title of note 'wide'"; then
  echo "ok   note titles wrap and wide words are flagged"
else
  echo "FAIL note titles"; printf '%s\n' "$out" | sed 's/^/     /'; fail=1
fi
exit $fail
