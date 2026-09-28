#!/usr/bin/env node
// Usage: node probe-mcp-remote.js <config-dir> <mcp-remote-version> <server-url> [timeout-ms]
//
// Asks Webflow — through mcp-remote itself, the only thing that knows how to
// refresh and persist its own session — whether an org's saved login works
// right now. Prints exactly one JSON line:
//   {"status":"ok"}                       the session answered an MCP initialize
//   {"status":"needs_login","detail":..}  Webflow rejected it; mcp-remote wants a sign-in
//   {"status":"no_response","detail":..}  couldn't tell (offline, timeout, crash)
//
// Never opens a browser: a background check must not be able to spawn tabs,
// so every opener mcp-remote might call is replaced by a no-op for its
// lifetime. It never reads or prints token contents.

const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const [configDir, version, serverUrl, timeoutArg] = process.argv.slice(2);
if (!configDir || !version || !serverUrl) {
  console.log(JSON.stringify({ status: 'no_response', detail: 'usage: probe-mcp-remote.js <config-dir> <version> <url> [timeout-ms]' }));
  process.exit(0);
}
const timeoutMs = Number(timeoutArg) || 30000;

const shimDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flowmcp-noopen-'));
for (const name of ['open', 'xdg-open', 'gio', 'x-www-browser', 'sensible-browser']) {
  fs.writeFileSync(
    path.join(shimDir, name),
    '#!/bin/sh\n[ -n "$FLOWMCP_PROBE_LOG" ] && echo "$0 $*" >> "$FLOWMCP_PROBE_LOG"\nexit 0\n',
    { mode: 0o755 }
  );
}

const env = {
  ...process.env,
  MCP_REMOTE_CONFIG_DIR: configDir,
  PATH: shimDir + path.delimiter + (process.env.PATH || ''),
  BROWSER: 'true',
};
// Linux openers can bypass PATH (bundled/absolute xdg-open); with no display
// there is nothing for them to open.
delete env.DISPLAY;
delete env.WAYLAND_DISPLAY;
delete env.DBUS_SESSION_BUS_ADDRESS;

const child = spawn('npx', ['-y', `mcp-remote@${version}`, serverUrl, '--resource', serverUrl], {
  env,
  stdio: ['pipe', 'pipe', 'pipe'],
  detached: process.platform !== 'win32',
});

let finished = false;
let stderrTail = '';

function finish(status, detail) {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  try {
    if (process.platform === 'win32') child.kill();
    else process.kill(-child.pid, 'SIGTERM');
  } catch (_) { /* already gone */ }
  try { fs.rmSync(shimDir, { recursive: true, force: true }); } catch (_) { /* best effort */ }
  const out = { status };
  if (detail) out.detail = detail;
  console.log(JSON.stringify(out));
  process.exit(0);
}

const timer = setTimeout(() => finish('no_response', `no answer within ${Math.round(timeoutMs / 1000)}s`), timeoutMs);

child.on('error', (e) => finish('no_response', `could not start npx: ${e.message}`));
child.on('exit', (code) => finish('no_response', `mcp-remote exited (code ${code}) before answering`));

let stdoutBuf = '';
child.stdout.on('data', (chunk) => {
  stdoutBuf += chunk.toString();
  let nl;
  while ((nl = stdoutBuf.indexOf('\n')) !== -1) {
    const line = stdoutBuf.slice(0, nl).trim();
    stdoutBuf = stdoutBuf.slice(nl + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch (_) { continue; }
    if (msg && msg.id === 0) {
      if (msg.result) finish('ok');
      else finish('no_response', 'server replied with an error to initialize');
    }
  }
});

child.stderr.on('data', (chunk) => {
  stderrTail = (stderrTail + chunk.toString()).slice(-4000);
  if (/Please authorize this client|requires authorization|Authentication required|Waiting for authorization|Another instance is running the sign-in/.test(stderrTail)) {
    finish('needs_login', 'Webflow no longer accepts the saved session');
  }
});

child.stdin.write(JSON.stringify({
  jsonrpc: '2.0',
  id: 0,
  method: 'initialize',
  params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'flowmcp-check', version: '1' } },
}) + '\n');
