globalThis.process ??= {}; globalThis.process.env ??= {};
import './chunks/astro-designed-error-pages_NWKxVtRP.mjs';
import './chunks/astro/server_KeCo5y3E.mjs';
import { s as sequence } from './chunks/render-context_DP6vVW70.mjs';

const onRequest$1 = (context, next) => {
  if (context.isPrerendered) {
    context.locals.runtime ??= {
      env: process.env
    };
  }
  return next();
};

const onRequest = sequence(
	onRequest$1,
	
	
);

export { onRequest };
