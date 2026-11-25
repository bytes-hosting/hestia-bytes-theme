(() => {
	const root = document.querySelector('.hsb-dash');
	if (!root) return;
	const text = root.dataset;

	function el(tag, props = {}, ...children) {
		const node = Object.assign(document.createElement(tag), props);
		node.append(...children);
		return node;
	}

	function message(box, msg) {
		box.replaceChildren(el('p', { className: 'hsb-muted', textContent: msg }));
	}

	async function getJson(url, options) {
		const response = await fetch(url, options);
		if (!response.ok) throw new Error(`HTTP ${response.status}`);
		return response.json();
	}

	// Services: stopped ones first
	async function loadServices(card) {
		const list = card.querySelector('.hsb-services');
		try {
			const services = await getJson(card.dataset.hsbServices);
			if (!services.length) return list.replaceChildren(el('li', { className: 'hsb-muted', textContent: text.noData }));
			services.sort((a, b) => a.running - b.running || a.name.localeCompare(b.name));
			const up = services.filter((s) => s.running).length;
			card.querySelector('.hsb-card-note').textContent = text.summary
				.replace('%s', up)
				.replace('%s', services.length);
			list.replaceChildren(
				...services.map((s) =>
					el(
						'li',
						{},
						el('span', { textContent: s.name }),
						el('small', { textContent: s.about }),
						el(
							'span',
							{ className: `hsb-state ${s.running ? 'is-ok' : 'is-bad'}` },
							el('i', { className: `fas ${s.running ? 'fa-circle-check' : 'fa-circle-exclamation'}` }),
							s.running ? text.running : text.stopped,
						),
					),
				),
			);
		} catch (e) {
			list.replaceChildren(el('li', { className: 'hsb-muted', textContent: text.failed }));
		}
	}

	// 24h line chart of the first series of an RRD export
	async function loadChart(card) {
		const box = card.querySelector('.hsb-chart');
		try {
			const rrd = await getJson('/list/rrd/ajax.php', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ service: card.dataset.hsbChart, period: 'daily' }),
			});
			// Hestia stores memory in MB and the load average multiplied by 100
			const scale = card.dataset.hsbChart === 'mem' ? 1 / 1024 : 1 / 100;
			const points = (rrd.data || [])
				.map((row, i) => ({
					t: (rrd.meta.start + i * rrd.meta.step) * 1000,
					v: typeof row[0] === 'number' ? row[0] * scale : null,
				}))
				.filter((p) => p.v !== null);
			if (points.length < 2) return message(box, text.noData);
			drawChart(card, box, points, card.dataset.unit, rrd.meta.step * 1500);
		} catch (e) {
			message(box, text.failed);
		}
	}

	function drawChart(card, box, points, unit, maxGap) {
		const NS = 'http://www.w3.org/2000/svg';
		const svgEl = (tag, attrs, content) => {
			const node = document.createElementNS(NS, tag);
			for (const key in attrs) node.setAttribute(key, attrs[key]);
			if (content !== undefined) node.textContent = content;
			return node;
		};
		const lang = document.documentElement.lang || undefined;
		const clock = (t) => new Date(t).toLocaleTimeString(lang, { hour: '2-digit', minute: '2-digit', hour12: false });
		const num = (v) => `${v.toFixed(v < 10 ? 2 : 1)}${unit ? ` ${unit}` : ''}`;

		// Round axis top: 1, 2, 2.5 or 5 times a power of ten
		const peak = Math.max(...points.map((p) => p.v)) || 1;
		const pow = 10 ** Math.floor(Math.log10(peak / 4));
		const tick = [1, 2, 2.5, 5, 10].map((m) => m * pow).find((s) => s * 4 >= peak);
		const ticks = [0, 1, 2, 3, 4].map((n) => n * tick);
		const decimals = tick < 0.1 ? 2 : tick < 1 || tick % 1 ? 1 : 0;

		const table = card.querySelector('.hsb-chart-table');
		table.querySelector('tbody').replaceChildren(
			...points.map((p) =>
				el('tr', {}, el('td', { textContent: clock(p.t) }), el('td', { textContent: num(p.v) })),
			),
		);
		table.hidden = false;

		function render() {
			const W = box.clientWidth;
			const H = 200;
			const pad = { l: 40, r: 10, t: 8, b: 24 };
			const t0 = points[0].t;
			const t1 = points[points.length - 1].t;
			const x = (t) => pad.l + ((t - t0) / (t1 - t0)) * (W - pad.l - pad.r);
			const y = (v) => H - pad.b - (v / ticks[4]) * (H - pad.t - pad.b);

			const svg = svgEl('svg', {
				viewBox: `0 0 ${W} ${H}`,
				role: 'img',
				tabindex: 0,
				'aria-label': `${card.querySelector('h2').textContent}: ${num(points[points.length - 1].v)}`,
			});
			ticks.forEach((v) => {
				svg.append(
					svgEl('line', { class: 'hsb-chart-grid', x1: pad.l, x2: W - pad.r, y1: y(v), y2: y(v) }),
					svgEl('text', { x: pad.l - 8, y: y(v) + 4, 'text-anchor': 'end' }, v.toFixed(decimals)),
				);
			});
			const marks = W < 480 ? 3 : 5;
			for (let n = 0; n < marks; n++) {
				const t = t0 + ((t1 - t0) * n) / (marks - 1);
				const anchor = n === 0 ? 'start' : n === marks - 1 ? 'end' : 'middle';
				svg.append(svgEl('text', { x: x(t), y: H - 4, 'text-anchor': anchor }, clock(t)));
			}
			svg.append(
				svgEl('path', {
					class: 'hsb-chart-line',
					// A hole in the data stays a hole: never draw a line across missing readings
					d: points
						.map((p, i) => {
							const joined = i > 0 && p.t - points[i - 1].t <= maxGap;
							return `${joined ? 'L' : 'M'}${x(p.t).toFixed(1)} ${y(p.v).toFixed(1)}`;
						})
						.join(''),
				}),
			);

			const cross = svgEl('line', { class: 'hsb-chart-cross', y1: pad.t, y2: H - pad.b, visibility: 'hidden' });
			const dot = svgEl('circle', { class: 'hsb-chart-dot', r: 5, visibility: 'hidden' });
			svg.append(cross, dot);
			const tip = el('div', { className: 'hsb-tip', hidden: true });
			let index = points.length - 1;

			function show(i) {
				index = Math.max(0, Math.min(points.length - 1, i));
				const p = points[index];
				cross.setAttribute('x1', x(p.t));
				cross.setAttribute('x2', x(p.t));
				dot.setAttribute('cx', x(p.t));
				dot.setAttribute('cy', y(p.v));
				[cross, dot].forEach((n) => n.setAttribute('visibility', 'visible'));
				tip.replaceChildren(el('b', { textContent: num(p.v) }), clock(p.t));
				tip.hidden = false;
				const left = x(p.t) + 12;
				tip.style.left = `${left + tip.offsetWidth > W ? x(p.t) - 12 - tip.offsetWidth : left}px`;
			}
			function hide() {
				[cross, dot].forEach((n) => n.setAttribute('visibility', 'hidden'));
				tip.hidden = true;
			}
			svg.addEventListener('pointermove', (evt) => {
				const t = t0 + ((evt.clientX - svg.getBoundingClientRect().left - pad.l) / (W - pad.l - pad.r)) * (t1 - t0);
				show(points.reduce((best, p, i) => (Math.abs(p.t - t) < Math.abs(points[best].t - t) ? i : best), 0));
			});
			svg.addEventListener('pointerleave', hide);
			svg.addEventListener('focus', () => show(index));
			svg.addEventListener('blur', hide);
			svg.addEventListener('keydown', (evt) => {
				const step = { ArrowLeft: -1, ArrowRight: 1 }[evt.key];
				if (!step) return;
				evt.preventDefault();
				evt.stopPropagation(); // Hestia uses the arrows to move through the menu
				show(index + step);
			});
			box.replaceChildren(svg, tip);
		}

		render();
		let width = box.clientWidth;
		new ResizeObserver(() => {
			if (box.clientWidth !== width) {
				width = box.clientWidth;
				render();
			}
		}).observe(box);
	}

	// One after another: requests of one session wait for each other anyway
	(async () => {
		for (const card of root.querySelectorAll('[data-hsb-chart]')) await loadChart(card);
	})();
	root.querySelectorAll('[data-hsb-services]').forEach(loadServices);
})();
