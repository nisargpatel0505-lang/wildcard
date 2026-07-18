'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const ROOT = path.resolve(__dirname, '..');
const SW_PATH = path.join(ROOT, 'www', 'sw.js');
const ORIGIN = 'https://wildcard.test';
const CINEMATIC_PATH = '/assets/video/sly-single-tear.mp4';
const OTHER_MEDIA_PATH = '/assets/audio/bit-shift-kevin-macleod-115bpm.mp3';
const CINEMATIC_BYTES = Uint8Array.from([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

function createHarness() {
  const listeners = new Map();
  const cacheMatchCalls = [];
  const fetchCalls = [];

  const caches = {
    async match(request) {
      cacheMatchCalls.push(request);
      const pathname = typeof request === 'string'
        ? request
        : new URL(request.url).pathname;
      if (pathname !== CINEMATIC_PATH) return undefined;
      return new Response(CINEMATIC_BYTES, {
        status: 200,
        headers: { 'Content-Type': 'video/mp4' }
      });
    },
    async open() {
      return {
        async addAll() {},
        async put() {}
      };
    },
    async keys() {
      return [];
    },
    async delete() {
      return true;
    }
  };

  async function mockedFetch(request) {
    const normalized = request instanceof Request ? request : new Request(request);
    fetchCalls.push(normalized);
    return new Response(Uint8Array.from([90, 91]), {
      status: 206,
      headers: {
        'Content-Range': 'bytes 0-1/2',
        'X-Mock-Network': 'true'
      }
    });
  }

  const self = {
    location: { origin: ORIGIN },
    clients: { async claim() {} },
    async skipWaiting() {},
    addEventListener(type, handler) {
      listeners.set(type, handler);
    }
  };

  const context = vm.createContext({
    URL,
    Request,
    Response,
    Headers,
    Promise,
    Uint8Array,
    ArrayBuffer,
    console,
    caches,
    fetch: mockedFetch,
    self
  });

  const source = fs.readFileSync(SW_PATH, 'utf8');
  new vm.Script(source, { filename: SW_PATH }).runInContext(context);

  const fetchHandler = listeners.get('fetch');
  assert.equal(typeof fetchHandler, 'function', 'service worker must register a fetch handler');

  async function dispatchFetch(pathname, range) {
    const request = new Request(`${ORIGIN}${pathname}`, {
      method: 'GET',
      headers: range ? { Range: range } : undefined
    });
    let responsePromise;
    const event = {
      request,
      respondWith(value) {
        assert.equal(responsePromise, undefined, 'respondWith must only be called once');
        responsePromise = Promise.resolve(value);
      }
    };

    fetchHandler(event);

    // A fetch event without respondWith() is handled by the browser's normal
    // network path. Mirror that behavior so bypasses exercise mocked fetch.
    if (responsePromise === undefined) {
      return {
        intercepted: false,
        response: await mockedFetch(request)
      };
    }
    return {
      intercepted: true,
      response: await responsePromise
    };
  }

  return { cacheMatchCalls, dispatchFetch, fetchCalls };
}

async function main() {
  const harness = createHarness();

  const valid = await harness.dispatchFetch(CINEMATIC_PATH, 'bytes=2-5');
  assert.equal(valid.intercepted, true, 'cinematic Range request must be intercepted');
  assert.equal(valid.response.status, 206);
  assert.equal(valid.response.headers.get('Content-Range'), 'bytes 2-5/10');
  assert.equal(valid.response.headers.get('Accept-Ranges'), 'bytes');
  assert.equal(valid.response.headers.get('Content-Length'), '4');
  assert.deepEqual(
    [...new Uint8Array(await valid.response.arrayBuffer())],
    [2, 3, 4, 5],
    '206 body must contain exactly the requested byte slice'
  );

  const invalid = await harness.dispatchFetch(CINEMATIC_PATH, 'bytes=99-');
  assert.equal(invalid.intercepted, true, 'invalid cinematic Range must still be handled');
  assert.equal(invalid.response.status, 416);
  assert.equal(invalid.response.headers.get('Content-Range'), 'bytes */10');
  assert.equal((await invalid.response.arrayBuffer()).byteLength, 0);

  const unrelated = await harness.dispatchFetch(OTHER_MEDIA_PATH, 'bytes=0-1');
  assert.equal(
    unrelated.intercepted,
    false,
    'unrelated Range request must bypass the cinematic cache interception'
  );
  assert.equal(unrelated.response.headers.get('X-Mock-Network'), 'true');
  assert.equal(harness.fetchCalls.length, 1, 'unrelated Range request must reach mocked fetch');
  assert.equal(new URL(harness.fetchCalls[0].url).pathname, OTHER_MEDIA_PATH);
  assert.equal(harness.fetchCalls[0].headers.get('Range'), 'bytes=0-1');
  assert.deepEqual(
    harness.cacheMatchCalls,
    [CINEMATIC_PATH, CINEMATIC_PATH],
    'only cinematic Range requests may consult CacheStorage'
  );

  console.log('Service-worker MP4 Range behavior tests passed.');
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
