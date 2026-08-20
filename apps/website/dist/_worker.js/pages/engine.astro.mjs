globalThis.process ??= {}; globalThis.process.env ??= {};
import { f as createComponent, k as renderComponent, r as renderTemplate, m as maybeRenderHead } from '../chunks/astro/server_KeCo5y3E.mjs';
import { $ as $$Layout } from '../chunks/Layout_bSTM8tTH.mjs';
export { renderers } from '../renderers.mjs';

const $$Engine = createComponent(($$result, $$props, $$slots) => {
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": "The Debt Manager engine" }, { "default": ($$result2) => renderTemplate`${maybeRenderHead()}<main class="simple wrap"><a class="wordmark" href="/">↗ debt manager</a><p class="eyebrow">For financial institutions</p><h1>A deterministic engine for clearer debt decisions.</h1><p class="lede">Model, simulate, compare, and explain payoff outcomes with a transparent monthly forecast. Bring a calmer, more useful debt experience to your customers.</p><a class="button" href="mailto:hello@debtmanager.app">Talk about licensing ↗</a><a class="back" href="/">← Back home</a></main>` })}`;
}, "/home/user/repos/debt-manager/apps/website/src/pages/engine.astro", void 0);

const $$file = "/home/user/repos/debt-manager/apps/website/src/pages/engine.astro";
const $$url = "/engine";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
	__proto__: null,
	default: $$Engine,
	file: $$file,
	url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
