globalThis.process ??= {}; globalThis.process.env ??= {};
import { f as createComponent, k as renderComponent, r as renderTemplate, m as maybeRenderHead } from '../chunks/astro/server_KeCo5y3E.mjs';
import { $ as $$Layout } from '../chunks/Layout_bSTM8tTH.mjs';
export { renderers } from '../renderers.mjs';

const $$Methodology = createComponent(($$result, $$props, $$slots) => {
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": "Debt Manager methodology" }, { "default": ($$result2) => renderTemplate`${maybeRenderHead()}<main class="simple wrap"><a class="wordmark" href="/">↗ debt manager</a><p class="eyebrow">Methodology</p><h1>Forecasts built from visible assumptions.</h1><p class="lede">Debt Manager projects balances month by month using the balance, APR, minimum payment, payment cadence, and additional budget you provide. Strategies differ only in which eligible debt receives extra payments first.</p><h2>A note on limitations</h2><p class="lede">Illustrations are synthetic and estimates are not guarantees. Interest, fees, lender policies, and payment timing can change real outcomes. Debt Manager does not provide financial advice.</p><a class="back" href="/">← Back home</a></main>` })}`;
}, "/home/user/repos/debt-manager/apps/website/src/pages/methodology.astro", void 0);

const $$file = "/home/user/repos/debt-manager/apps/website/src/pages/methodology.astro";
const $$url = "/methodology";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
	__proto__: null,
	default: $$Methodology,
	file: $$file,
	url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
