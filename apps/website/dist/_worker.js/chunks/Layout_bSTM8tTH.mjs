globalThis.process ??= {}; globalThis.process.env ??= {};
import { e as createAstro, f as createComponent, n as renderHead, o as renderSlot, r as renderTemplate } from './astro/server_KeCo5y3E.mjs';
/* empty css                          */

const $$Astro = createAstro("https://debt-manager.app");
const $$Layout = createComponent(($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$Layout;
  const { title = "Debt Manager" } = Astro2.props;
  return renderTemplate`<html lang="en" data-astro-cid-sckkx6r4><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width"><meta name="description" content="See what your debt decisions change before you make them."><title>${title}</title>${renderHead()}</head><body data-astro-cid-sckkx6r4>${renderSlot($$result, $$slots["default"])} </body></html>`;
}, "/home/user/repos/debt-manager/apps/website/src/layouts/Layout.astro", void 0);

export { $$Layout as $ };
