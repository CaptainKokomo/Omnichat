import type { OmnichatAPI } from '../platform/omnichatApi';

declare global {
  interface Window {
    omnichat: OmnichatAPI;
  }
}

export {};
