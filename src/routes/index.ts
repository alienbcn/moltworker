export { publicRoutes } from './public';
export { api } from './api';
export { adminUi } from './admin-ui';
export { debug } from './debug';

/**
 * Lazy load CDP route to avoid loading Puppeteer at Worker startup.
 * CDP uses @cloudflare/puppeteer which is heavy and should only load when needed.
 */
export async function getCdp() {
  const { cdp } = await import('./cdp');
  return cdp;
}
