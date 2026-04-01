import sunset, { toggleSunset } from "./modules/sunset.js";

App.config({
    windows: [sunset],
});

globalThis.toggleSunset = toggleSunset;
