// @ts-nocheck

export function set(data) {
	window._pageData = data;
	SC.event.dispatchGlobalEvent(SC.event.PageDataRefreshed, { pageData: data });
}

export function get() {
	return window._pageData;
}

export function notifyDirty() {
	SC.event.dispatchGlobalEvent(SC.event.PageDataDirtied, { pageData: window._pageData });
}
