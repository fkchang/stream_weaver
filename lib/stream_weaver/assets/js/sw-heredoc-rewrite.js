// Rewrites Ruby heredocs into double-quoted string literals.
//
// Opal's self-hosted parser (opal-parser.js) cannot lex heredocs of any form,
// while the MRI-hosted compiler handles them fine. Doc DSL files lean on them
// heavily, so anything compiling Ruby in the browser has to get past this.
//
// Double-quoted output preserves #{} interpolation semantics, so the rewrite
// is transparent for the interpolating forms (<<~X, <<-X, <<X) -- only the
// single-quoted form <<~'X' is non-interpolating, and it is escaped as such.
function rewriteHeredocs(source) {
  const lines = source.split('\n');
  const out = [];
  let i = 0;

  const OPEN = /<<([-~]?)(['"]?)([A-Z_][A-Z_0-9]*)\2/;

  while (i < lines.length) {
    const line = lines[i];
    const m = line.match(OPEN);
    if (!m) { out.push(line); i++; continue; }

    const [token, squiggle, quote, delim] = m;
    const closeRe = new RegExp('^\\s*' + delim + '\\s*$');

    // Collect the body.
    const body = [];
    let j = i + 1;
    let closed = false;
    while (j < lines.length) {
      if (closeRe.test(lines[j])) { closed = true; break; }
      body.push(lines[j]);
      j++;
    }
    if (!closed) { out.push(line); i++; continue; }

    let text = body;
    if (squiggle === '~') {
      const indents = body.filter(l => l.trim() !== '').map(l => l.match(/^[ \t]*/)[0].length);
      const strip = indents.length ? Math.min(...indents) : 0;
      text = body.map(l => l.slice(strip));
    }

    const joined = text.join('\n') + (text.length ? '\n' : '');
    let literal;
    if (quote === "'") {
      literal = "'" + joined.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'";
    } else {
      // Escape backslashes and quotes, but leave #{...} intact so interpolation
      // keeps working exactly as the heredoc form would.
      literal = '"' + joined
        .replace(/\\/g, '\\\\')
        .replace(/"/g, '\\"')
        .replace(/\n/g, '\\n') + '"';
    }

    out.push(line.replace(token, literal));
    i = j + 1;
  }
  return out.join('\n');
}

// Usable as a CommonJS module (Node) or as a plain browser script, since the
// two consumers -- an npm renderer and a browser extension -- differ.
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { rewriteHeredocs };
} else if (typeof window !== 'undefined') {
  window.swRewriteHeredocs = rewriteHeredocs;
}
