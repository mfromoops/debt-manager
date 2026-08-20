globalThis.process ??= {}; globalThis.process.env ??= {};
import { f as createComponent, k as renderComponent, r as renderTemplate, m as maybeRenderHead } from '../chunks/astro/server_KeCo5y3E.mjs';
import { $ as $$Layout } from '../chunks/Layout_bSTM8tTH.mjs';
export { renderers } from '../renderers.mjs';

const $$Privacy = createComponent(($$result, $$props, $$slots) => {
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": "Debt Manager privacy" }, { "default": ($$result2) => renderTemplate`${maybeRenderHead()}<main class="simple wrap"><a class="wordmark" href="/">↗ debt manager</a><p class="eyebrow">Privacy</p><h1>Your debt details stay yours.</h1><p class="lede">The public scenario on this site uses synthetic data. We do not ask for or collect real debt details in the marketing demo. The app handles account data according to its own privacy controls.</p><a class="back" href="/">← Back home</a></main>` })}`;
}, "/home/user/repos/debt-manager/apps/website/src/pages/privacy.astro", void 0);

const $$file = "/home/user/repos/debt-manager/apps/website/src/pages/privacy.astro";
const $$url = "/privacy";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
	__proto__: null,
	default: $$Privacy,
	file: $$file,
	url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
