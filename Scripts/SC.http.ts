// @ts-nocheck

export function performWithServiceContext(syncOrAsync, func) {
	try {
		window._inSyncServiceContext = syncOrAsync;
		return func();
	} finally {
		window._inSyncServiceContext = false;
	}
}

export function invokeService(serviceUrl, methodName, params, onSuccess, onFailure, userContext, userName, password) {
	var url = (serviceUrl.match(/\/\//) ? '' : SC.context.scriptBaseUrl) + serviceUrl + '/' + methodName;
	var paramsString = JSON.stringify(params);

	var xhr;

	var completeProc = function (isKnownError) {
		var result = SC.util.tryGet(function () { return JSON.parse(xhr.responseText); });

		if (isKnownError || (xhr.status !== undefined && xhr.status !== 200)) {
			result = result || {};
			// TimeoutException is mainly for long-polling timeouts, which should generally be handled the same as an empty succesful response
			result.errorType = result.errorType || ([
				0, // IE abort
				404, // Not Found - proxies can return on long poll
				408, // Request Timeout
				504, // Gateway Timeout - proxy timeout
				524, // A timeout occurred - Cloudflare reverse proxy during long-polling
				598, // Network Read Timeout - proxy timeout
				599, // Network Connect Timeout - proxy timeout
				12002, // IE abort
				12019 // saw it in IE after long polling for 16 seconds
			].indexOf(xhr.status) !== -1 ? 'TimeoutException' : 'UnknownException');
			result.message = result.message || (SC.util.isNullOrEmpty(xhr.statusText) ? 'Unknown error' : xhr.statusText);
			result.statusCode = result.statusCode || xhr.status;

			var handled = false;

			if (SC.context.prehandleServiceFailureProc)
				handled |= SC.context.prehandleServiceFailureProc(result, userContext) !== false;

			if (!handled && onFailure)
				handled |= onFailure(result, userContext) !== false;

			if (!handled && SC.context.unhandledServiceFailureProc)
				SC.context.unhandledServiceFailureProc(result, userContext);
		} else {
			if (onSuccess) onSuccess(result, userContext);
		}
	}

	var authorizationString = (userName && password ? 'Basic ' + SC.util.base64Encode(userName + ':' + password) : null);

	var sendProc = function () {
		var fullUrl = url;

		if (typeof xhr.onload !== 'undefined')
			xhr.onload = function () { completeProc(false); }

		if (typeof xhr.onerror !== 'undefined')
			xhr.onerror = function () { completeProc(true); }

		if (typeof xhr.onprogress !== 'undefined')
			xhr.onprogress = function () { }

		if (typeof xhr.setRequestHeader === 'undefined') {
			var urlParameters = {};
			urlParameters['__UnauthorizedStatusCode'] = 403;

			if (authorizationString != null)
				urlParameters['__Authorization'] = authorizationString;

			fullUrl += SC.util.getQueryString(urlParameters);
		}

		xhr.open('POST', fullUrl, !window._inSyncServiceContext);

		xhr.setRequestHeader('Content-Type', 'application/json');
		xhr.setRequestHeader('X-Anti-Forgery-Token', SC.context.antiForgeryToken);

		if (typeof xhr.onload === 'undefined')
			xhr.onreadystatechange = function () { if (xhr.readyState == 4) completeProc(false); }

		if (typeof xhr.withCredentials !== 'undefined')
			if (!window._inSyncServiceContext)
				xhr.withCredentials = true;

		if (typeof xhr.setRequestHeader !== 'undefined') {
			xhr.setRequestHeader('X-Unauthorized-Status-Code', 403);

			if (authorizationString != null)
				xhr.setRequestHeader('Authorization', authorizationString);
		}

		xhr.send(paramsString);
	}

	try {
		xhr = new XMLHttpRequest();
		sendProc(xhr);
	} catch (e) {
		if (typeof XDomainRequest === 'undefined')
			throw e;

		xhr = new XDomainRequest();
		sendProc(xhr);
	}

	return xhr;
}
