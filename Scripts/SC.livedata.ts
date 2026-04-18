// @ts-nocheck

export const ActionCenterInfo = 'ActionCenterInfo';
export const HostSessionInfo = 'HostSessionInfo';
export const GuestSessionInfo = 'GuestSessionInfo';

export function startLoop() {
	if (window._liveData === 'undefined')
		throw 'Live data loop can only be started once';

	window._liveData = null;

	var refreshTimeoutID = null;
	var lastFullRefreshTimeMilliseconds = 0;
	var pendingRequest = null;
	var errorWindowStartTimeMilliseconds = null;

	var innerLoopProc = function (isDirty) {
		if (!SC.ui.isWindowActive()) {
			refreshTimeoutID = window.setTimeout(function () {
				innerLoopProc(isDirty);
			}, 1000);
		} else {
			var requestVersion = (isDirty || !window._liveData || !lastFullRefreshTimeMilliseconds || SC.util.getMillisecondCount() - lastFullRefreshTimeMilliseconds > 3600000 ? 0 : window._liveData.Version);

			if (requestVersion === 0)
				lastFullRefreshTimeMilliseconds = SC.util.getMillisecondCount();

			let eventArgs = { requestInfoMap: {} };
			SC.event.dispatchGlobalEvent(SC.event.QueryLiveData, eventArgs);

			if (Object.keys(eventArgs.requestInfoMap).length === 0)
				refreshTimeoutID = window.setTimeout(function () {
					innerLoopProc(isDirty);
				}, 10000);
			else
				pendingRequest = SC.service.GetLiveData(
					eventArgs.requestInfoMap,
					requestVersion,
					function (result) {
						pendingRequest = null;
						errorWindowStartTimeMilliseconds = null;

						refreshTimeoutID = window.setTimeout(function () { innerLoopProc(false); }, 1000);

						if (result) {
							window._liveData = result;

							if (result.ProductVersion && result.ProductVersion !== SC.context.productVersion)
								window.location.reload(true);

							SC.event.dispatchGlobalEvent(SC.event.LiveDataRefreshed, { liveData: result, requestVersion: requestVersion })
						}
					},
					function (error) {
						pendingRequest = null;
						
						if (error.errorType !== 'TimeoutException') {
							// many subsequent long-polling timeouts are expected for some environments/configurations, so don't count them as errors
							refreshTimeoutID = window.setTimeout(function () { innerLoopProc(true); }, 1000);
						} else {
							var now = SC.util.getMillisecondCount();
							errorWindowStartTimeMilliseconds = errorWindowStartTimeMilliseconds || now;
							var millisecondsSinceErrorWindowStart = now - errorWindowStartTimeMilliseconds;

							// give web server 20 seconds to restart before alerting user
							var shouldShowError = millisecondsSinceErrorWindowStart > 20000

							if (shouldShowError)
								SC.dialog.showModalErrorBox(error.detail || error.message);

							refreshTimeoutID = window.setTimeout(function () {
								if (shouldShowError)
									SC.dialog.hideModalDialog();

								innerLoopProc(true);
							}, Math.max(500, Math.min(millisecondsSinceErrorWindowStart, 10000)));
						}
					}
				);
		}
	};

	SC.event.addGlobalHandler(SC.event.LiveDataDirtied, function () {
		window.clearTimeout(refreshTimeoutID);

		if (pendingRequest) {
			pendingRequest.abort();
			pendingRequest = null;
		}

		innerLoopProc(true);
	});

	notifyDirty();
}

export function setRequestInfo(eventArgs, key, value) {
	eventArgs.requestInfoMap[key] = value || {};
}

export function getResponseInfo(key) {
	return (window._liveData && window._liveData.ResponseInfoMap && window._liveData.ResponseInfoMap[key]) || {};
}

export function get() {
	return window._liveData;
}

export function notifyDirty(dirtyLevel) {
	SC.event.dispatchGlobalEvent(SC.event.LiveDataDirtied, { dirtyLevel: dirtyLevel, liveData: window._liveData });
}
