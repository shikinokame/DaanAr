const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const template = fs.readFileSync(path.join(__dirname, '../resources/views/ar/landmark.blade.php'), 'utf8');
const script = template.match(/<script>\s*([\s\S]*?)<\/script>/)[1];

function page(src) {
  const events = {};
  const clicks = {};
  const nodes = {};
  for (const id of ['loading-overlay', 'progress-fill', 'loading-status', 'hint-pill', 'ar-button', 'ar-diagnostics', 'ar-diagnostic-text']) {
    nodes[id] = {style: {}, classList: {add() {}}, addEventListener(type, callback) { clicks[type] = callback; }};
  }
  nodes['ar-diagnostics'].hidden = true;
  const viewer = {src, addEventListener(type, callback) { events[type] = callback; }};
  vm.runInNewContext(script, {
    URL, location: {href: 'https://example.com/ar/landmark/7'},
    console: {info() {}, log() {}, error() {}}, setTimeout() {},
    document: {
      querySelector(selector) { return selector === '#landmark-model' ? viewer : nodes[selector.slice(1)]; },
      getElementById(id) { return nodes[id]; },
    },
    window: {addEventListener(type, callback) { events[type] = callback; }},
  });
  return {nodes, events, click() {
    let blocked = false;
    clicks.click({preventDefault() { blocked = true; }, stopImmediatePropagation() {}});
    return blocked;
  }};
}

test('public HTTPS GLB with nested query is left intact for model-viewer', () => {
  const url = 'https://cdn.example.com/a%20b.glb?token=a%2Bb&sv=3';
  const p = page(url);
  assert.equal(p.click(), false);
  assert.ok(p.nodes['ar-diagnostic-text'].textContent.includes(url));
});

test('invalid model schemes and local URLs are blocked with visible details', () => {
  for (const url of ['blob:https://example.com/id', 'file:///a.glb', 'http://example.com/a.glb', 'https://localhost/a.glb', 'https://example.com/login']) {
    const p = page(url);
    assert.equal(p.click(), true, url);
    assert.equal(p.nodes['ar-diagnostics'].hidden, false);
    assert.ok(p.nodes['ar-diagnostic-text'].textContent.includes('error:'));
  }
});

test('native errors and activity results render exact details as text', () => {
  const p = page('https://example.com/a.glb');
  const detail = {status: 'returned', message: 'resultCode=0; <error>', modelUrl: 'https://example.com/a.glb?sv=3&x=4'};
  p.events['daanar-ar-diagnostic']({detail});
  assert.equal(p.nodes['ar-diagnostic-text'].textContent, 'returned: resultCode=0; <error>\nModel URL: https://example.com/a.glb?sv=3&x=4');
  assert.equal(p.nodes['ar-diagnostics'].hidden, false);
});

test('AR backend failure displays fallback advice', () => {
  const p = page('https://example.com/a.glb');
  p.events['ar-status']({detail: {status: 'failed'}});
  assert.ok(p.nodes['ar-diagnostic-text'].textContent.includes('Google viewer fallback'));
});
