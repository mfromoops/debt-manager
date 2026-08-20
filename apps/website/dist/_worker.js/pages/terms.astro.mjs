globalThis.process ??= {}; globalThis.process.env ??= {};
import { f as createComponent, k as renderComponent, r as renderTemplate, m as maybeRenderHead } from '../chunks/astro/server_KeCo5y3E.mjs';
import { $ as $$Layout } from '../chunks/Layout_bSTM8tTH.mjs';
export { renderers } from '../renderers.mjs';

const $$Terms = createComponent(($$result, $$props, $$slots) => {
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": "Debt Manager terms" }, { "default": ($$result2) => renderTemplate`${maybeRenderHead()}<main class="simple wrap"><a class="wordmark" href="/">↗ debt manager</a><p class="eyebrow">Terms of use</p><h1>Use the forecast as a tool, not a promise.</h1><p class="lede">Debt Manager provides educational illustrations and planning tools. Nothing on this site is financial, legal, or lending advice. Review your lender terms and consult a qualified professional for decisions about your finances.</p><a class="back" href="/">← Back home</a></main>` })}`;
}, "/home/user/repos/debt-manager/apps/website/src/pages/terms.astro", void 0);

const $$file = "/home/user/repos/debt-manager/apps/website/src/pages/terms.astro";
const $$url = "/terms";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
	__proto__: null,
	default: $$Terms,
	file: $$file,
	url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
