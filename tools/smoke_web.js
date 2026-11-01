#!/usr/bin/env node
// Smoke test de la version Web (M15 lot W, D-216, docs/WEB.md §4) — après
// `bash tools/export_web.sh`.
//
// Sert build/web/ comme le ferait l'hébergement réel (en-têtes COOP/COEP,
// types MIME, fichiers .gz précompressés), ouvre la page dans Chromium
// (Playwright) et joue le chemin réel d'un joueur :
//   1. chargement → écran titre (détecté à l'image) ; capture m15_web_title.png
//   2. NOUVELLE PARTIE à la **manette** (bouton A d'une manette standard simulée)
//   3. emplacement 1 puis difficulté « Dur » au **clavier** (Entrée)
//   4. briefing du J1 (détecté) ; capture m15_web_briefing.png
//   5. PRENDRE SON POSTE à la **souris** → guichet 3D du J1 (détecté) ;
//      capture m15_web_j1.png ; mesures (images/s, thread principal, audio,
//      mémoire) ; intercom (N) ; capture m15_web_j1_passenger.png
//   6. rechargement de la page : la sauvegarde du J1 est relue depuis IndexedDB
//      (user://demo/saves) et l'écran titre revient.
// Échoue (code 1) sur : délai dépassé à une étape, exception JS, ligne
// « ERROR » / « SCRIPT ERROR » de Godot dans la console, page non isolée
// (threads), AudioContext arrêté, audio muet, sous-alimentation audio > 20 %
// (build à threads), sauvegarde absente d'IndexedDB après rechargement.
//
// Usage : node tools/smoke_web.js [options]
//   --dir=build/web        dossier exporté
//   --gl=swiftshader       rendu WebGL logiciel de Chromium, headless (défaut ;
//                          ≈ 1 image/s au guichet : seul l'ordre de grandeur CPU compte)
//   --gl=angle-gl          Chromium avec fenêtre sur ANGLE/OpenGL (sous xvfb-run :
//                          Mesa llvmpipe, ≈ 3 images/s) — comparable au natif opengl3
//   --size=1280x720        taille de la fenêtre
//   --no-shots             pas de captures dans docs/mockups/
//   --throttle=MBPS        bande passante simulée (CDP) pour mesurer le démarrage réseau
//   --startup-only         s'arrête à l'écran titre (mesure du démarrage, avec --throttle)
//   --locale=fr-FR         langue du navigateur (le jeu suit la langue du système :
//                          en-* → anglais, sinon français ; captures m15_web_*_en.png en anglais)
// Playwright : préinstallé (NODE_PATH=/opt/node-tools/node_modules si besoin).
// Sorties : build/web_smoke/metrics.json, captures de chaque étape dans
// build/web_smoke/, captures de référence dans docs/mockups/m15_web_*.png.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

let chromium;
try {
	({ chromium } = require('playwright'));
} catch (e) {
	try {
		({ chromium } = require('/opt/node-tools/node_modules/playwright'));
	} catch (e2) {
		console.error('smoke_web: ERREUR : Playwright introuvable (npm i playwright, ou NODE_PATH)');
		process.exit(2);
	}
}

const ROOT = path.resolve(__dirname, '..');
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
	const m = a.replace(/^--/, '').split('=');
	return [m[0], m.length > 1 ? m.slice(1).join('=') : true];
}));
const DIR = path.resolve(ROOT, args.dir || 'build/web');
const GL = args.gl || 'swiftshader';
const [W, H] = (args.size || '1280x720').split('x').map((v) => parseInt(v, 10));
const SHOTS = !args['no-shots'];
const OUT = path.join(ROOT, 'build', 'web_smoke');
const MOCKUPS = path.join(ROOT, 'docs', 'mockups');
const THROTTLE = args.throttle ? parseFloat(args.throttle) : 0;
const LOCALE = args.locale || 'fr-FR';
const SUFFIX = /^en/i.test(LOCALE) ? '_en' : '';

const metrics = { dir: path.relative(ROOT, DIR), gl: GL, viewport: `${W}x${H}`, locale: LOCALE, steps: {} };
const errors = [];
const log = (...a) => console.log('  ', ...a);
const fail = (msg) => { errors.push(msg); console.error(`smoke_web: ÉCHEC : ${msg}`); };

if (!fs.existsSync(path.join(DIR, 'index.html'))) {
	console.error(`smoke_web: ERREUR : ${DIR}/index.html absent : lancer d'abord bash tools/export_web.sh`);
	process.exit(2);
}
fs.mkdirSync(OUT, { recursive: true });

// --- Serveur statique (comportement de web/nginx-clearance-web.conf) ----------
const MIME = {
	'.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png', '.txt': 'text/plain',
};
// Instrumentation de test seulement (jamais dans build/web) : le worklet audio
// de Godot compte ses blocs de 128 échantillons et ceux qu'il n'a pas pu
// remplir (sous-alimentation = craquement), et les poste à la page.
function instrumentWorklet(src) {
	const under = "// this.port.postMessage('Output buffer has not enough frames! Skipping output frame.');";
	const tail = 'this.process_notify();\n\t\treturn true;';
	if (!src.includes(under) || !src.includes(tail)) return src;
	return src.replace(under, 'globalThis.__u = (globalThis.__u || 0) + 1;')
		.replace(tail, "globalThis.__b = (globalThis.__b || 0) + 1; if (globalThis.__b % 344 === 0) { this.port.postMessage({ cmd: 'clearance_stat', b: globalThis.__b, u: globalThis.__u || 0 }); }\n\t\t" + tail);
}
const server = http.createServer((req, res) => {
	let p = decodeURIComponent(req.url.split('?')[0]);
	if (p === '/') p = '/index.html';
	const file = path.join(DIR, path.normalize(p).replace(/^(\.\.[/\\])+/, ''));
	if (!file.startsWith(DIR) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
		res.writeHead(404); res.end(); return;
	}
	const headers = {
		'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
		'Cross-Origin-Opener-Policy': 'same-origin',
		'Cross-Origin-Embedder-Policy': 'require-corp',
		'Cross-Origin-Resource-Policy': 'same-origin',
		'Cache-Control': 'no-cache',
	};
	if (file.endsWith('.audio.worklet.js')) {
		res.writeHead(200, headers);
		res.end(instrumentWorklet(fs.readFileSync(file, 'utf8')));
		return;
	}
	const gz = `${file}.gz`;
	if (/\bgzip\b/.test(req.headers['accept-encoding'] || '') && fs.existsSync(gz)) {
		headers['Content-Encoding'] = 'gzip';
		res.writeHead(200, headers);
		fs.createReadStream(gz).pipe(res);
		return;
	}
	res.writeHead(200, headers);
	fs.createReadStream(file).pipe(res);
});

// --- Analyse d'image (dans la page : décodage PNG natif du navigateur) ---------
// Proportions de pixels jaunes (accent DS), cyan (titre), luminance et contraste
// de zones relatives de l'image (x0, y0, x1, y1 en 0..1).
async function analyze(page, png) {
	return page.evaluate(async (b64) => {
		const blob = await (await fetch(`data:image/png;base64,${b64}`)).blob();
		const bmp = await createImageBitmap(blob);
		const c = new OffscreenCanvas(bmp.width, bmp.height);
		const g = c.getContext('2d');
		g.drawImage(bmp, 0, 0);
		const { data, width, height } = g.getImageData(0, 0, bmp.width, bmp.height);
		const zone = (x0, y0, x1, y1) => {
			let n = 0, yellow = 0, cyan = 0, sum = 0, sq = 0, ysum = 0;
			for (let y = Math.floor(y0 * height); y < Math.floor(y1 * height); y += 2) {
				for (let x = Math.floor(x0 * width); x < Math.floor(x1 * width); x += 2) {
					const i = (y * width + x) * 4;
					const r = data[i], gg = data[i + 1], b = data[i + 2];
					const l = 0.2126 * r + 0.7152 * gg + 0.0722 * b;
					n++; sum += l; sq += l * l;
					if (r > 200 && gg > 190 && b < 90) { yellow++; ysum += y / height; }
					if (r < 90 && gg > 170 && b > 190) cyan++;
				}
			}
			const mean = sum / n;
			return { yellow: yellow / n, cyan: cyan / n, mean, std: Math.sqrt(Math.max(0, sq / n - mean * mean)), yellow_y: yellow ? ysum / yellow : -1 };
		};
		return {
			title_panel: zone(0.33, 0.12, 0.67, 0.92),
			title_logo: zone(0.33, 0.15, 0.67, 0.32),
			brief_day: zone(0.04, 0.125, 0.15, 0.185),
			brief_button: zone(0.79, 0.87, 0.94, 0.93),
			booth_scene: zone(0.0, 0.07, 1.0, 0.38),
			booth_next: zone(0.29, 0.92, 0.36, 0.97),
			booth_bar: zone(0.0, 0.0, 1.0, 0.045),
			all: zone(0, 0, 1, 1),
		};
	}, png.toString('base64'));
}
const STOP = Symbol('arrêt demandé');
const isTitle = (a) => a.title_panel.yellow > 0.008 && a.title_logo.cyan > 0.004 && a.brief_button.yellow < 0.2;
const isBriefing = (a) => a.brief_day.yellow > 0.04 && a.brief_button.yellow > 0.35;
const isBooth = (a) => a.booth_scene.std > 25 && a.booth_scene.mean > 15 && a.booth_next.yellow > 0.25;

// --- Scénario ----------------------------------------------------------------------
(async () => {
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	const url = `http://127.0.0.1:${server.address().port}/`;
	const launchArgs = ['--autoplay-policy=no-user-gesture-required'];
	let headless = true;
	if (GL === 'angle-gl') {
		headless = false;
		launchArgs.push('--use-gl=angle', '--use-angle=gl', '--ignore-gpu-blocklist', '--enable-gpu');
	} else {
		launchArgs.push('--enable-unsafe-swiftshader', '--use-angle=swiftshader');
	}
	const browser = await chromium.launch({ headless, args: launchArgs });
	const context = await browser.newContext({ viewport: { width: W, height: H }, locale: LOCALE });
	const page = await context.newPage();
	const cdp = await context.newCDPSession(page);
	await cdp.send('Performance.enable');
	if (THROTTLE > 0) {
		await cdp.send('Network.enable');
		await cdp.send('Network.emulateNetworkConditions', {
			offline: false, latency: 20, uploadThroughput: 10e6 / 8,
			downloadThroughput: (THROTTLE * 1e6) / 8,
		});
		metrics.throttle_mbps = THROTTLE;
	}

	const t0 = Date.now();
	const secs = () => (Date.now() - t0) / 1000;
	const consoleLines = [];
	page.on('console', (m) => {
		const text = m.text();
		if (text.includes('clearance_stat')) return; // instrumentation (le build à threads journalise tout message du worklet)
		consoleLines.push(`[${secs().toFixed(1)}s] ${m.type()}: ${text}`);
		if (/^(SCRIPT |USER )?ERROR/.test(text)) fail(`console Godot : ${text.split('\n')[0]}`);
	});
	page.on('pageerror', (e) => fail(`exception JS : ${e.message}`));

	// Avant le moteur : compteur d'images (rAF), manette standard simulée, prises
	// sur la sortie audio (niveau) et sur le worklet (sous-alimentation).
	await page.addInitScript(() => {
		window.__frames = 0;
		const tick = () => { window.__frames++; requestAnimationFrame(tick); };
		requestAnimationFrame(tick);
		const buttons = Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 }));
		const pad = {
			id: 'Xbox 360 Controller (XInput STANDARD GAMEPAD)', index: 0, connected: true,
			mapping: 'standard', timestamp: 0, axes: [0, 0, 0, 0], buttons,
		};
		navigator.getGamepads = () => [pad, null, null, null];
		window.__pad = (i, down) => {
			buttons[i].pressed = down; buttons[i].touched = down; buttons[i].value = down ? 1 : 0;
			pad.timestamp = performance.now();
		};
		window.__astat = { b: 0, u: 0 };
		const OrigWorklet = window.AudioWorkletNode;
		if (OrigWorklet) {
			window.AudioWorkletNode = function (...a) {
				const node = new OrigWorklet(...a);
				node.port.addEventListener('message', (e) => {
					if (e.data && e.data.cmd === 'clearance_stat') window.__astat = { b: e.data.b, u: e.data.u };
				});
				return node;
			};
			window.AudioWorkletNode.prototype = OrigWorklet.prototype;
		}
		window.__analysers = [];
		const connect = AudioNode.prototype.connect;
		AudioNode.prototype.connect = function (dst, ...rest) {
			const r = connect.call(this, dst, ...rest);
			try {
				if (dst instanceof AudioDestinationNode && !this.__tap) {
					this.__tap = true;
					const an = this.context.createAnalyser();
					an.fftSize = 2048;
					connect.call(this, an);
					window.__analysers.push(an);
				}
			} catch (e) { /* prise facultative */ }
			return r;
		};
		window.__audio = () => {
			let rms = 0;
			for (const an of window.__analysers) {
				const buf = new Float32Array(an.fftSize);
				an.getFloatTimeDomainData(buf);
				let s = 0;
				for (const v of buf) s += v * v;
				rms = Math.max(rms, Math.sqrt(s / buf.length));
			}
			const ctx = window.__analysers.length ? window.__analysers[0].context : null;
			return { rms, state: ctx ? ctx.state : 'none', rate: ctx ? ctx.sampleRate : 0 };
		};
	});

	const shot = async (name) => {
		const png = await page.screenshot();
		fs.writeFileSync(path.join(OUT, `${name}.png`), png);
		return png;
	};
	// Attend une image qui satisfait `pred` (une capture par seconde environ).
	const waitFor = async (label, pred, timeoutS) => {
		const start = secs();
		while (secs() - start < timeoutS) {
			const png = await shot(`_${label}`);
			const a = await analyze(page, png);
			if (pred(a)) {
				metrics.steps[label] = +secs().toFixed(1);
				fs.renameSync(path.join(OUT, `_${label}.png`), path.join(OUT, `${label}.png`));
				log(`${label} atteint à ${secs().toFixed(1)} s`);
				return png;
			}
			await page.waitForTimeout(1000);
		}
		fail(`${label} : non atteint en ${timeoutS} s (dernière capture : build/web_smoke/_${label}.png)`);
		return null;
	};
	const keep = (png, name) => {
		if (SHOTS && png) fs.writeFileSync(path.join(MOCKUPS, `${name}${SUFFIX}.png`), png);
	};
	const measure = async (label, ms) => {
		const perf = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((m) => [m.name, m.value]));
		const a0 = await page.evaluate(() => window.__astat);
		const p0 = await perf();
		const f0 = await page.evaluate(() => window.__frames);
		const s0 = Date.now();
		let rms = 0, audioState = 'none', rate = 0;
		for (let i = 0; i < ms / 500; i++) {
			await page.waitForTimeout(500);
			const au = await page.evaluate(() => window.__audio());
			rms = Math.max(rms, au.rms); audioState = au.state; rate = au.rate;
		}
		const f1 = await page.evaluate(() => window.__frames);
		const p1 = await perf();
		const a1 = await page.evaluate(() => window.__astat);
		const dt = (Date.now() - s0) / 1000;
		const frames = Math.max(1, f1 - f0);
		const wasm = await page.evaluate(() => {
			try { return engine.rtenv.HEAP8.buffer.byteLength; } catch (e) { return 0; }
		});
		const m = {
			fps: +((f1 - f0) / dt).toFixed(1),
			main_thread_ms_per_frame: +(((p1.TaskDuration - p0.TaskDuration) * 1000) / frames).toFixed(1),
			main_thread_busy_pct: Math.round(((p1.TaskDuration - p0.TaskDuration) / dt) * 100),
			audio_state: audioState,
			audio_rate: rate,
			audio_rms_max: +rms.toFixed(4),
			audio_blocks: a1.b - a0.b,
			audio_underrun_ratio: a1.b - a0.b > 0 ? +((a1.u - a0.u) / (a1.b - a0.b)).toFixed(3) : null,
			wasm_heap_mb: Math.round(wasm / 1048576),
			js_heap_mb: Math.round(p1.JSHeapUsedSize / 1048576),
		};
		metrics[label] = m;
		log(`${label} : ${JSON.stringify(m)}`);
		return m;
	};

	try {
		log(`${url} — Chromium ${browser.version()} — WebGL ${GL} — ${W}×${H}`);
		await page.goto(url);
		// 1. Écran titre
		const title = await waitFor('title', isTitle, 120);
		if (!title) throw new Error('titre');
		metrics.cross_origin_isolated = await page.evaluate(() => window.crossOriginIsolated);
		const threaded = consoleLines.some((l) => /multi-threaded/.test(l));
		metrics.threads = threaded;
		if (threaded && !metrics.cross_origin_isolated) fail('build à threads sans isolation inter-origines (COOP/COEP)');
		metrics.demo = consoleLines.some((l) => /démo J1/.test(l));
		keep(title, 'm15_web_title');
		// Le contexte audio démarre au premier geste de l'utilisateur.
		await page.mouse.click(5, 5);
		await measure('title_metrics', 6000);
		if (args['startup-only']) throw STOP;

		// 2. Manette : bouton A (0) sur NOUVELLE PARTIE (focus par défaut).
		const before = await analyze(page, await shot('_pad'));
		await page.evaluate(() => window.__pad(0, true));
		await page.waitForTimeout(1200);
		await page.evaluate(() => window.__pad(0, false));
		await waitFor('slot_screen', (a) => !isTitle(a) && Math.abs(a.all.mean - before.all.mean) > 0.5, 30);
		// 3. Clavier : emplacement 1 puis « Jouer en Dur ».
		await page.keyboard.press('Enter');
		await page.waitForTimeout(2500);
		await page.keyboard.press('Enter');
		// 4. Briefing du J1.
		const brief = await waitFor('briefing', isBriefing, 180);
		if (!brief) throw new Error('briefing');
		keep(brief, 'm15_web_briefing');
		// 5. Souris : PRENDRE SON POSTE (bas droit).
		await page.waitForTimeout(1500);
		await page.mouse.click(Math.round(W * 0.865), Math.round(H * 0.904));
		const booth = await waitFor('booth_j1', isBooth, 240);
		if (!booth) throw new Error('guichet');
		await page.waitForTimeout(3000);
		keep(await shot('booth_j1_settled'), 'm15_web_j1');
		const m = await measure('booth_j1_metrics', 10000);
		if (m.audio_state !== 'running') fail(`AudioContext « ${m.audio_state} » au guichet`);
		if (!(m.audio_rms_max > 1e-4)) fail('audio muet au guichet');
		if (threaded && m.audio_underrun_ratio !== null && m.audio_underrun_ratio > 0.2) {
			fail(`sous-alimentation audio ${(m.audio_underrun_ratio * 100).toFixed(0)} % au guichet`);
		}
		// Intercom (N) : le premier passager s'avance.
		await page.keyboard.press('KeyN');
		await page.waitForTimeout(GL === 'swiftshader' ? 45000 : 20000);
		keep(await shot('booth_j1_passenger'), 'm15_web_j1_passenger');

		// 6. Persistance : la sauvegarde du J1 est dans IndexedDB et survit au rechargement.
		const idb = () => page.evaluate(() => new Promise((resolve) => {
			const req = indexedDB.open('/userfs');
			req.onerror = () => resolve([]);
			req.onsuccess = () => {
				const keys = [];
				const store = req.result.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA');
				store.openCursor().onsuccess = (e) => {
					const c = e.target.result;
					if (c) { if (/\/saves\//.test(String(c.key))) keys.push(String(c.key)); c.continue(); } else resolve(keys);
				};
			};
		}));
		await page.reload();
		const again = await waitFor('title_after_reload', isTitle, 120);
		const saves = await idb();
		metrics.indexeddb_saves = saves.map((k) => k.replace(/^.*app_userdata\/[^/]+\//, 'user://'));
		if (!saves.some((k) => /slot_1\/.*\.json$/.test(k))) fail('aucune sauvegarde slot_1 dans IndexedDB après rechargement');
		if (again) {
			// Sauvegarde relue par le jeu : le focus passe de NOUVELLE PARTIE à
			// CONTINUER (bouton jaune plus haut dans le panneau).
			const a = await analyze(page, again);
			const b = await analyze(page, title);
			metrics.continue_focused_after_reload = a.title_panel.yellow_y < b.title_panel.yellow_y - 0.03;
			if (!metrics.continue_focused_after_reload) fail('après rechargement, CONTINUER n\'a pas le focus (sauvegarde non relue ?)');
		}
	} catch (e) {
		if (e !== STOP && !errors.length) fail(String(e && e.message ? e.message : e));
	} finally {
		metrics.errors = errors;
		fs.writeFileSync(path.join(OUT, 'metrics.json'), `${JSON.stringify(metrics, null, 2)}\n`);
		fs.writeFileSync(path.join(OUT, 'console.log'), `${consoleLines.join('\n')}\n`);
		await browser.close();
		server.close();
	}
	if (errors.length) {
		console.error(`smoke_web: ${errors.length} échec(s) (build/web_smoke/metrics.json, console.log)`);
		process.exit(1);
	}
	console.log('== smoke Web OK (build/web_smoke/metrics.json)');
})();
