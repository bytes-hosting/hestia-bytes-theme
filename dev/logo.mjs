// Draws every logo file in src/images. Run after changing a shape or a color: node dev/logo.mjs
// Sizes are the ones Hestia asks for in its white-label settings. No dependencies.
import { writeFileSync } from "node:fs";
import { deflateSync } from "node:zlib";

const out = new URL("../src/images/", import.meta.url);
const A = "#21c8ee", B = "#4acfb6", C = "#38ccce", D = "#7cd671", F = "#b1de29";

// The bytes.ua mark on its own 36 x 40 grid: x, y, width, height, color, frame thickness (0 = solid)
const mark = [
	[0, 0, 11, 13, A, 2], [12, 0, 10, 6, A, 2], [23, 0, 13, 13, B, 2],
	[12, 7, 6, 6, C, 2], [19, 7, 3, 13, D, 0],
	[0, 14, 6, 6, D, 2], [7, 14, 4, 6, D, 0], [12, 14, 6, 10, A, 2], [23, 14, 13, 6, F, 2],
	[0, 21, 11, 6, F, 2], [12, 25, 6, 2, D, 0], [19, 21, 10, 6, C, 2], [30, 21, 6, 6, B, 2],
	[0, 28, 13, 12, A, 2], [14, 28, 10, 6, D, 2], [25, 28, 11, 12, A, 2],
	[14, 35, 2, 5, D, 0], [17, 35, 3, 5, D, 0], [21, 35, 3, 5, D, 0],
];

// The same composition with fewer blocks, pixel by pixel: 16 px is too small for all nineteen
const tiny = [
	[1, 0, 5, 5, A, 1], [7, 0, 2, 2, A, 0], [10, 0, 5, 5, B, 1],
	[7, 3, 2, 6, D, 0],
	[1, 6, 5, 2, D, 0], [10, 6, 5, 2, F, 0],
	[1, 9, 5, 1, F, 0], [10, 9, 5, 1, C, 0],
	[1, 11, 5, 5, A, 1], [7, 10, 2, 3, D, 0], [7, 14, 2, 2, D, 0], [10, 11, 5, 5, A, 1],
];

const fmt = (n) => String(Math.round(n * 1000) / 1000);

// One path per color; evenodd turns the inner rectangle into the hole of a frame
function paths(shapes, scale = 1, dx = 0, dy = 0) {
	const byColor = new Map();
	const rect = (x, y, w, h) => `M${fmt(dx + x * scale)} ${fmt(dy + y * scale)}h${fmt(w * scale)}v${fmt(h * scale)}h${fmt(-w * scale)}z`;
	for (const [x, y, w, h, color, t] of shapes) {
		const d = rect(x, y, w, h) + (t ? rect(x + t, y + t, w - 2 * t, h - 2 * t) : "");
		byColor.set(color, (byColor.get(color) ?? "") + d);
	}
	return [...byColor].map(([color, d]) => `<path fill="${color}" fill-rule="evenodd" d="${d}"/>`).join("\n\t");
}

// BYTES, 22 units tall and 84 wide, 5-unit strokes. Drawn as outlines, so no font is needed.
const word = `<path fill="none" stroke="url(#w)" stroke-width="5" d="M2.5 2.5H9.6a4.1 4.1 0 0 1 0 8.2H2.5M2.5 10.7H10a4.4 4.4 0 0 1 0 8.8H2.5M2.5 0V22"/>
		<path fill="url(#w)" d="M18 0h5.9l3.6 7.6L31.1 0H37L30 13.6V22h-5v-8.4zM38.5 0H54v5h-5.25v17h-5V5H38.5zM57 0h13v5h-8v3.6h7v4.8h-7V17h8v5H57z"/>
		<path fill="none" stroke="url(#w)" stroke-width="5" d="M86.3 5.4C85 3.4 83 2.5 80.5 2.5c-3 0-5.2 1.4-5.2 3.9 0 2.7 2.3 3.5 5.3 4.3 3.2.9 5.7 1.8 5.7 4.7 0 2.7-2.4 4.1-5.5 4.1-2.9 0-5.2-1-6.7-3.2"/>`;
const gradient = `<linearGradient id="w" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="22"><stop stop-color="#f1f6fc"/><stop offset="1" stop-color="#a9c4e0"/></linearGradient>`;

const svg = (w, h, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><title>BYTES</title>\n\t${body}\n</svg>\n`;
const lockup = (scale, dx, dy, wordScale, wx, wy) =>
	`${paths(mark, scale, dx, dy)}\n\t<defs>${gradient}</defs>\n\t<g transform="translate(${wx} ${wy}) scale(${wordScale})">\n\t\t${word}\n\t</g>`;

// Every shape is a rectangle, so the exact share of each pixel it covers is easy to compute
function raster(shapes, width, height, scale = 1, dx = 0, dy = 0) {
	const sum = new Float64Array(width * height * 4);
	const fill = (x0, y0, x1, y1, rgb, sign) => {
		for (let y = Math.max(0, Math.floor(y0)); y < Math.min(height, Math.ceil(y1)); y++) {
			for (let x = Math.max(0, Math.floor(x0)); x < Math.min(width, Math.ceil(x1)); x++) {
				const part = sign * (Math.min(x + 1, x1) - Math.max(x, x0)) * (Math.min(y + 1, y1) - Math.max(y, y0));
				const i = (y * width + x) * 4;
				for (let c = 0; c < 3; c++) sum[i + c] += rgb[c] * part;
				sum[i + 3] += part;
			}
		}
	};
	for (const [x, y, w, h, color, t] of shapes) {
		const rgb = [1, 3, 5].map((p) => parseInt(color.slice(p, p + 2), 16));
		const box = (k) => [dx + (x + k) * scale, dy + (y + k) * scale, dx + (x + w - k) * scale, dy + (y + h - k) * scale];
		fill(...box(0), rgb, 1);
		if (t) fill(...box(t), rgb, -1);
	}
	const px = Buffer.alloc(sum.length);
	for (let i = 0; i < sum.length; i += 4) {
		if (sum[i + 3] < 1e-6) continue;
		for (let c = 0; c < 3; c++) px[i + c] = Math.round(sum[i + c] / sum[i + 3]);
		px[i + 3] = Math.min(255, Math.round(sum[i + 3] * 255));
	}
	return px;
}

function crc32(buf) {
	let crc = ~0;
	for (const byte of buf) {
		crc ^= byte;
		for (let k = 0; k < 8; k++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
	}
	return ~crc >>> 0;
}

function png(px, width, height) {
	const chunk = (type, data) => {
		const body = Buffer.concat([Buffer.from(type), data]);
		const head = Buffer.alloc(4), tail = Buffer.alloc(4);
		head.writeUInt32BE(data.length);
		tail.writeUInt32BE(crc32(body));
		return Buffer.concat([head, body, tail]);
	};
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(width, 0);
	ihdr.writeUInt32BE(height, 4);
	ihdr.set([8, 6, 0, 0, 0], 8);
	const rows = [];
	for (let y = 0; y < height; y++) rows.push(Buffer.from([0]), px.subarray(y * width * 4, (y + 1) * width * 4));
	return Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk("IHDR", ihdr), chunk("IDAT", deflateSync(Buffer.concat(rows), { level: 9 })), chunk("IEND", Buffer.alloc(0)),
	]);
}

// One 32-bit bitmap. The format stores rows bottom-up as BGRA, then a 1-bit mask.
function ico(px, size) {
	const mask = Buffer.alloc(size * Math.ceil(size / 32) * 4);
	const dir = Buffer.alloc(22), info = Buffer.alloc(40), bits = Buffer.alloc(size * size * 4);
	for (let y = 0; y < size; y++) {
		for (let x = 0; x < size; x++) {
			const s = (y * size + x) * 4, d = ((size - 1 - y) * size + x) * 4;
			bits.set([px[s + 2], px[s + 1], px[s], px[s + 3]], d);
		}
	}
	dir.writeUInt16LE(1, 2);
	dir.writeUInt16LE(1, 4);
	dir.set([size, size], 6);
	dir.writeUInt16LE(1, 10);
	dir.writeUInt16LE(32, 12);
	dir.writeUInt32LE(40 + bits.length + mask.length, 14);
	dir.writeUInt32LE(22, 18);
	info.writeUInt32LE(40, 0);
	info.writeInt32LE(size, 4);
	info.writeInt32LE(size * 2, 8);
	info.writeUInt16LE(1, 12);
	info.writeUInt16LE(32, 14);
	info.writeUInt32LE(bits.length + mask.length, 20);
	return Buffer.concat([dir, info, bits, mask]);
}

const write = (name, data) => writeFileSync(new URL(name, out), data);
// Hestia also uses logo.svg as the tab icon, so it is the mark alone
write("logo.svg", svg(100, 120, paths(mark, 2.5, 5, 10)));
write("logo.png", png(raster(mark, 100, 120, 2.5, 5, 10), 100, 120));
write("logo-header.svg", svg(54, 29, lockup(0.5, 0, 4.5, 0.37, 21, 10.43)));
// Not a Hestia file: the wide version for our sidebar, like on bytes.ua
write("logo-sidebar.svg", svg(138, 40, lockup(0.9, 0, 2, 1, 44, 9)));
write("favicon.png", png(raster(mark, 64, 64, 1.5, 5, 2), 64, 64));
write("favicon.ico", ico(raster(tiny, 16, 16), 16));
