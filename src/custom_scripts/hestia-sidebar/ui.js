(() => {
	const app = document.querySelector('.app.hsb');
	if (!app) return;

	const $ = (sel) => app.querySelector(sel);
	const groups = [...app.querySelectorAll('.hsb-group')];
	const links = [...app.querySelectorAll('.hsb-link')];
	const nav = $('.hsb-nav');
	const search = $('.hsb-search-input');
	const toggle = $('.hsb-toggle');
	let filtering = false;
	let beforeFilter = null;

	// Remember which groups are open and the scroll position between pages
	function save() {
		if (filtering) return;
		try {
			const state = Object.fromEntries(groups.map((g) => [g.dataset.key, g.open]));
			localStorage.setItem('hsb.groups', JSON.stringify(state));
		} catch (e) {}
	}
	groups.forEach((g) => g.querySelector('summary').addEventListener('click', () => setTimeout(save)));
	window.addEventListener('pagehide', () => {
		try {
			sessionStorage.setItem('hsb.scroll', nav.scrollTop);
		} catch (e) {}
	});

	app.querySelectorAll('[data-hsb-fold]').forEach((btn) => {
		btn.addEventListener('click', () => {
			groups.forEach((g) => (g.open = btn.dataset.hsbFold === 'open'));
			save();
		});
	});

	// Filter the menu
	search.addEventListener('input', () => {
		const q = search.value.trim().toLocaleLowerCase();
		if (q && !filtering) {
			filtering = true;
			beforeFilter = groups.map((g) => g.open);
		}
		let found = 0;
		groups.forEach((group, i) => {
			const inTitle = group.querySelector('summary').textContent.toLocaleLowerCase().includes(q);
			let visible = 0;
			group.querySelectorAll('li').forEach((li) => {
				const match = !q || inTitle || li.textContent.toLocaleLowerCase().includes(q);
				li.hidden = !match;
				if (match) visible++;
			});
			group.hidden = visible === 0;
			found += visible;
			if (q) group.open = visible > 0;
			else if (beforeFilter) group.open = beforeFilter[i];
		});
		$('.hsb-empty').hidden = found > 0;
		if (!q) {
			filtering = false;
			beforeFilter = null;
		}
	});
	search.addEventListener('keydown', (evt) => {
		if (evt.key === 'Escape') {
			search.value = '';
			search.dispatchEvent(new Event('input'));
			search.blur();
		}
		if (evt.key === 'Enter') {
			const first = links.find((a) => a.offsetParent);
			if (first && search.value.trim()) location.href = first.href;
		}
		evt.stopPropagation(); // keep Hestia's single-key shortcuts out of the field
	});
	document.addEventListener('keydown', (evt) => {
		if (evt.key !== '/' || evt.ctrlKey || evt.metaKey || evt.altKey) return;
		if (/^(input|textarea|select)$/i.test(evt.target.tagName) || evt.target.isContentEditable) return;
		if (document.querySelector('dialog[open]')) return;
		evt.preventDefault();
		setOpen(true);
		search.focus();
	});

	// Off-canvas menu on small screens
	function setOpen(open) {
		app.classList.toggle('hsb-open', open);
		toggle.setAttribute('aria-expanded', String(open));
	}
	toggle.addEventListener('click', () => setOpen(!app.classList.contains('hsb-open')));
	$('.hsb-backdrop').addEventListener('click', () => setOpen(false));
	document.addEventListener('keydown', (evt) => evt.key === 'Escape' && setOpen(false));

	// Hestia's arrow-key navigation moves a focus mark over the (now hidden) top menu: mirror it
	const topMenu = document.querySelector('.main-menu');
	if (topMenu) {
		new MutationObserver(() => {
			const href = topMenu.querySelector('.main-menu-item.focus a')?.getAttribute('href');
			links.forEach((a) => {
				const on = a.getAttribute('href') === href;
				a.classList.toggle('is-focus', on);
				if (on) {
					a.closest('details').open = true;
					a.scrollIntoView({ block: 'nearest' });
				}
			});
		}).observe(topMenu, { subtree: true, attributeFilter: ['class'] });
	}
})();
