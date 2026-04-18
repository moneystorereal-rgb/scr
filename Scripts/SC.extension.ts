// @ts-nocheck

export function initializeExtensions() {
	SC.extensions.forEachKeyValue(function (extensionID, extension) {
		var extensionContext = {
			baseUrl: SC.context.scriptBaseUrl + extension.virtualPath,
			settingValues: extension.settingValues,
			custom: extension.customContexts.reduce(function (accumulator, context) { return Object.assign(accumulator, context); }, {}),
		};

		extension.initializeProcs.forEach(function (ip) {
			try {
				ip(extensionContext)
			} catch (error) {
				console.log('Failed to initialize extension ' + extensionID + ': ' + error);
			}
		});
	});
}

export function addInitializeProc(extensionID, initializeProc) {
	var extension = SC.extensions[extensionID];

	if (extension)
		extension.initializeProcs.push(initializeProc);
}
