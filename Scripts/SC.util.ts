// @ts-nocheck

export function formatString(format: string, ...args: unknown[] | [unknown[]]): string {
	const actualArguments = args[0] instanceof Array ? args[0] : args;

	return format.replace(/\{([0-9]+)(?:\:([^\}]+))?\}/g, (function (_, rawIndex, format) {
		const index = parseInt(rawIndex);
		const value = actualArguments[index];

		if (value == null)
			return '';

		if (format != null) {
			const numberMatch = format.match(/n([0-9]+)/);
			if (numberMatch)
				return value.toFixed(parseInt(numberMatch[1]));
		}

		return value.toString();
	}));
}

// TODO use this instead of manual bit checking on permissions
export function areFlagsSet(value: number, ...flags: number[]): boolean {
	for (let i = 0; i < flags.length; i++)
		if ((value & flags[i]) !== flags[i])
			return false;

	return true;
}

export function getVarArgs<T>(potentialVarArgs: T | T[], allArguments: unknown[], allArgumentsOffset: number): T[] {
	return potentialVarArgs instanceof Array
		? potentialVarArgs
		: Array.from(allArguments).slice(allArgumentsOffset) as T[];
}

export function getCookieValue(name: string): string | null {
	const cookieStrings = document.cookie.split(';');

	for (let i = 0; cookieStrings[i]; i++) {
		const cookieParts = cookieStrings[i].split('=');

		if (decodeURIComponent(cookieParts[0]).trim() == name)
			return decodeURIComponent(cookieParts[1]);
	}

	return null;
}

export function setCookieValue(name: string, value: Parameters<typeof encodeURIComponent>[0], lifetimeDays: number) {
	document.cookie = `${name}=${encodeURIComponent(value)}; expires=${SC.util.addDuration(new Date(), { days: lifetimeDays }).toUTCString()}`
}

export function loadSettings(): unknown {
	const stringValue = SC.util.getCookieValue('settings');

	try {
		if (!SC.util.isNullOrEmpty(stringValue))
			return JSON.parse(stringValue);
	} catch (ex) {
		// don't care
	}

	return {};
}

export function saveSettings(settings: unknown) {
	SC.util.setCookieValue('settings', JSON.stringify(settings), 3650);
}

export function modifySettings(settingsModifierFunc: (settings: unknown) => void) {
	const settings = SC.util.loadSettings();
	settingsModifierFunc(settings);
	SC.util.saveSettings(settings);
}

export function parseQueryString(queryString: string): Record<string, string> {
	const map: Record<string, string> = {};

	if (queryString.length != 0) {
		if (queryString.charAt(0) == '?')
			queryString = queryString.slice(1);

		queryString = queryString.replace(/\+/g, ' ');

		const parts = queryString.split('&');

		for (let i = 0; parts[i]; i++) {
			const subParts = parts[i].split('=');
			const name = decodeURIComponent(subParts[0]);
			const value = decodeURIComponent(subParts[1]);
			map[name] = value;
		}
	}

	return map;
}

export function getQueryString(map: Record<string, string>): string {
	let queryString = '';
	let first = true;

	map.forEachKeyValue(function (key, value) {
		let valueArray;

		if (value == undefined || value == null) {
			valueArray = [];
		} else if (value instanceof Array) {
			valueArray = value;
		} else {
			// watch out, in one JS version Array constructor with integer
			// will create that many elements
			valueArray = new Array();
			valueArray.push(value);
		}

		for (let i = 0; i < valueArray.length; i++) {
			queryString += (first ? '?' : '&') + encodeURIComponent(key) + '=' + encodeURIComponent(valueArray[i]);
			first = false;
		}
	});

	return queryString;
}

export function parseEventData(eventData: string): { processingInstruction: string; fields: Record<string, string>; content: string; } {
	// NOTE: keep in sync with ServerExtensions.TryParseEventData

	let processingInstruction = '';
	let fields: Record<string, string> = {};
	let lineStartIndex = 0;

	if (eventData.length > 0 && eventData.charAt(lineStartIndex) === '#') { // optimization
		for (let match of Array.from(eventData.matchAll(/\r?\n|$/g))) {
			if (match.index == undefined || lineStartIndex + 2 > match.index || eventData.charAt(lineStartIndex) !== '#')
				break;

			if (lineStartIndex === 0 && eventData.charAt(lineStartIndex + 1) === '!') {
				processingInstruction = eventData.slice(lineStartIndex + 2, match.index);
			} else {
				let equalsIndex = eventData.indexOf('=', lineStartIndex);
				fields[eventData.slice(lineStartIndex + 1, equalsIndex === -1 || equalsIndex > match.index ? match.index : equalsIndex)] = equalsIndex === -1 || equalsIndex > match.index ? '' : eventData.slice(equalsIndex + 1, match.index);
			}

			lineStartIndex = match.index + match[0].length;
		}
	}

	return {
		processingInstruction: processingInstruction,
		fields: fields,
		content: eventData.slice(lineStartIndex).trim(),
	};
}

export function launchUrl(url: string) {
	if (window.navigator.msLaunchUri != null && url.startsWith(SC.context.instanceUrlScheme))
		window.navigator.msLaunchUri(url, function () { }, function () { }); // need to fail silently
	else if (SC.util.isCapable(SC.util.Caps.Chrome) && (window.location.protocol === 'https:' || window.location.protocol === 'http:'))
		window.location.assign(url); // required to not be flagged when opening different scheme from https
	else if (SC.util.isCapable(SC.util.Caps.iOS) || SC.util.isCapable(SC.util.Caps.Android) || SC.util.isCapable(SC.util.Caps.WindowsModern))
		// Unfortunately, as of now, we are not aware of the reason behind making an exception for the
		// 3 capabilities mentioned in this if-condition. It would be nice to know that once we get a
		// chance. Also, please find below a couple of additional comments regarding the modification
		// of the window.location.href property:
		// a) Modifying this property instead of adding an IFRAME fixed the issue reported in SCP-36545.
		// However, when we reverted back to using an IFRAME, to prevent the unintentional, negative impact
		// that was caused by this change on Firefox (see SCP-36764 and SCP-36938 for more information), we
		// were unable to see the issue reported in SCP-36545 (20.11, 20.12, branch for SCP-36938, on
		// Chrome 88.0.4324.190). Therefore, no additional conditions have been added in order to allow
		// the modification of this property instead of adding an IFRAME when using Chrome.
		// b) Modifying this property instead of adding an IFRAME on Firefox caused the issue reported in
		// SCP-36764. We observed that after this property was modified, the refreshProc() defined in
		// SC.launch.js, which is responsible for closing the Join Session modal automatically after
		// successful connection, was not getting executed at all. Further investigation revealed that
		// Firefox was reporting that our web page has no sources at all (seen via the Debugger window) once
		// this property was modified. Unfortunately, as of now, we are still not aware of the reason why
		// modifying this property would prevent any further execution of our JavaScript code on Firefox until
		// the page is manually refreshed. It would be nice to know that once we get a chance.
		try {
			// In normal scenario with Install app (iPhone client), window.location.href works, but when inside iFrame, it is blocked.
			// For example: When launching url https://itunes.apple.com from Command Integration extension (inside iFrame), it is blocked.
			// It seems the iPhone is a bit more restrictive on the iFrame.
			// Although when using window.open() or window.top.location.href property, it works through inside iFrame as well as normal frame. 
			// 1) window.open() => Opening new tab allows it to navigate to app store url.
			// 2) window.top.location.href => window.top allows to update on outermost frame. This also avoids the new tab inconvenience of window.open().
			// Also, using try-catch block to avoid issues with non-supporting browsers. Though did not find any during unit testing.
			window.top.location.href = url;
		} catch (ex) {
			window.location.href = url;
		}
	else {
		const iframe = SC.ui.addElement(document.body, 'iframe', { src: url, _visible: false });

		// Ideally, we would want to subscribe to the 'load' event and remove the IFRAME from
		// the document body once that event is triggered. However, unfortunately, this event
		// does not seem to get triggered in Firefox when the url scheme is non-https
		// (for e.g.: - our instance url scheme - sc-<instance-fingerprint>: or mailto:).
		// Additionally, on Chrome, this event does not seem to get triggered even when we are
		// downloading a file from an https-site (for e.g.:- installers from any of our instances).
		// Therefore, we are removing this IFRAME from the document body after a timeout of a minute.
		window.setTimeout(function () { document.body.removeChild(iframe); }, 1 * 60 * 1000);
	}
}

export function selectOrDefault(item, selector) {
	if (selector instanceof Function)
		return selector(item);

	if (selector instanceof String)
		return item[selector];

	return item;
}

export function areArraysEqual<T>(x: Array<T>, y: Array<T>): boolean {
	if (!x || !y)
		return (!x == !y);

	if (x.length != y.length)
		return false;

	for (let i = 0; i < x.length; i++)
		if (x[i] != y[i])
			return false;

	return true;
}

export function createArray<T>(length: number, func: (index: number) => T): T[] {
	const array: T[] = [];
	for (let i = 0; i < length; i++)
		array[i] = func(i);

	return array;
}

export function createRangeArray(start: number, count: number): number[] {
	const array: number[] = [];
	for (let i = 0; i < count; i++)
		array.push(start + i);

	return array;
}

export function createEnum<T extends string>(names: T[]): { readonly [V in T]: V } {
	const enumObject = Object.create(null);
	Array.prototype.forEach.call(names, function (n) { enumObject[n] = n; });
	return Object.freeze(enumObject);
};

export function getTrimmedOrNull(text: string | null): string | null {
	if (SC.util.isNullOrEmpty(text))
		return null;

	const trimmed = text.trim();

	if (trimmed === '')
		return null;

	return trimmed;
}

export interface Version {
	major?: number;
	minor?: number;
	build?: number;
	revision?: number;
}

export function isVersion(minVersionInclusive: Version | undefined, maxVersionExclusive: Version | undefined, actualVersion: Version): boolean {
	if (actualVersion.major == 0)
		return false;

	if (minVersionInclusive != null && SC.util.compareVersion(actualVersion, minVersionInclusive) < 0)
		return false;

	return !(maxVersionExclusive != null && SC.util.compareVersion(actualVersion, maxVersionExclusive) >= 0);
}

export function compareVersion(x: Version, y: Version): number {
	const majorResult = (x.major ?? 0) - (y.major ?? 0);
	if (majorResult !== 0) return majorResult;

	const minorResult = (x.minor ?? 0) - (y.minor ?? 0);
	if (minorResult !== 0) return minorResult;

	const buildResult = (x.build ?? 0) - (y.build ?? 0)
	if (buildResult !== 0) return buildResult;
	
	return (x.revision ?? 0) - (y.revision ?? 0);
}

export function getVersionString(version: Version): string {
	if (version == null)
		return 'X';

	return '' + version.major + '.' + (version.minor || 0);
}

export const Caps = {
	WindowsModern: function () {
		const a = SC.util.getUserAgentVersion(/WindowsModern\/([0-9]+)\.([0-9]+)/);
		return a.major ? a : SC.util.getUserAgentVersion(/Windows Phone ([0-9]+)\.([0-9]+)/);
	},
	WindowsDesktop: function () {
		// mutually exclusive with modern
		if (SC.util.isCapable(SC.util.Caps.WindowsModern, { major: 1 }))
			return { major: 0, minor: 0 };

		return SC.util.getUserAgentVersion(/Windows (?:NT )?([0-9]+)\.([0-9]+)/);
	},
	MacOSX: function () {
		// iPad masquerades as MacOSX
		if (SC.util.isCapable(SC.util.Caps.iPad))
			return { major: 0, minor: 0 };

		return SC.util.getUserAgentVersion(/Mac OS X ([0-9]+)(?:_|\.)([0-9]+)(_|;|\))/);
	},
	LinuxDesktop: function () {
		if (SC.util.isCapable(SC.util.Caps.Android))
			return { major: 0, minor: 0 };

		return SC.util.getUserAgentVersion(/linux/i);
	},
	Android: function () { return SC.util.getUserAgentVersion(/android/i); },
	iOS: function () {
		// iPad masquerades as MacOSX
		if (SC.util.isCapable(SC.util.Caps.iPad)) {
			return SC.util.Caps.iPad();
		}

		return SC.util.getUserAgentVersion(/iphone|ipod|ios/i);
	},
	iPad: function () { return (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1) ? { major: 13, minor: 0 } : SC.util.getUserAgentVersion(/ipad/i); },
	InternetExplorer: function () { return SC.util.getUserAgentVersion(/(?:(?:Edge\/)|(?:MSIE\s)|(?:Trident[^\)]+rv:))([0-9]+)\.([0-9]+)/); },
	Chrome: function () {
		// Edge, etc, masquerades as chrome
		if (SC.util.isCapable(SC.util.Caps.InternetExplorer, { major: 12 }))
			return { major: 0, minor: 0 };

		// https://stackoverflow.com/questions/13807810/ios-chrome-detection
		return SC.util.getUserAgentVersion(/(Chrome|CriOS)\/([0-9]+)\.([0-9]+)/);
	},
	Firefox: function () { return SC.util.getUserAgentVersion(/(Firefox|FxiOS)\/([0-9]+)\.([0-9]+)/); },
	Safari: function () {
		// Chrome / Firefox masquerades as Safari
		if (SC.util.isCapable(SC.util.Caps.Chrome) || SC.util.isCapable(SC.util.Caps.Firefox))
			return { major: 0, minor: 0 };

		return SC.util.getUserAgentVersion(/Safari\/([0-9]+)\.([0-9]+)/);
	},
	WebKit: function () { return SC.util.getUserAgentVersion(/WebKit\/([0-9]+)\.([0-9]+)/); },
	NativeClient: function () { return SC.util.getUserAgentVersion(/ScreenConnect\/([0-9]+)\.([0-9]+)\./); },
	ClickOnce: function () {
		return (SC.util.getUserAgent().match(/\.NET/) ||
			SC.util.isCapable(SC.util.Caps.InternetExplorer, { major: 9 }) ||
			(SC.util.isCapable(SC.util.Caps.Chrome) && window.navigator.mimeTypes['application/x-ms-application'] != null)) ? { major: 1, minor: 0 } : { major: 0, minor: 0 };
	},
	WebStart: function () {
		// IE has new ActiveXObject('JavaWebStart.isInstalled'), but it prompts to run plugin, which is bad
		if (window.navigator.mimeTypes['application/x-java-jnlp-file'] != null || navigator.mimeTypes['application/x-java-applet;version=1.5'] != null)
			return { major: 1, minor: 0 };

		return { major: 0, minor: 0 };
	},
};

export function isCapable(capability: () => Version, minVersionInclusive?: Version, maxVersionExclusive?: Version): boolean {
	window._capabilities = window._capabilities || {};

	if (window._capabilities[capability] === undefined)
		window._capabilities[capability] = capability();

	return SC.util.isVersion(minVersionInclusive, maxVersionExclusive, window._capabilities[capability]);
}

export function getUserAgent(): string {
	return SC.context.userAgentOverride as string || navigator.userAgent;
}

export function getUserAgentVersion(pattern: RegExp): Version {
	const matches = SC.util.getUserAgent().match(pattern);
	if (matches === null) return { major: 0, minor: 0 };
	if (matches[1] === undefined) return { major: 1, minor: 0 };
	return { major: parseInt(matches[1]), minor: parseInt(matches[2]) };
}

export function doesBrowserNeedSyncServiceContextForLaunch(): boolean {
	return SC.util.isCapable(SC.util.Caps.InternetExplorer);
}

export function copyProperties(source: {} | null, destination: { [key: string]: any }) {
	if (source)
		source.forEachKeyValue(function (key, value) { destination[key] = value; });
}

export function combineObjects(...objects: Array<{} | null>) {
	const newObject = {};
	Array.prototype.forEach.call(arguments, function (a) { SC.util.copyProperties(a, newObject); });
	return newObject;
}

export function mergeIntoContext(properties: {} | null) {
	SC.util.copyProperties(properties, SC.context);
}

// TODO: The 3 lines of code within this method are used in a lot of Extensions as well.
// Therefore, it would be nice if we could use this method in Extensions as well, as and
// when we encounter these 3 lines of code in them.
export function simulateLinkClick(linkElement: HTMLAnchorElement) {
	document.body.appendChild(linkElement);
	linkElement.click();
	document.body.removeChild(linkElement);
}

export function openClientEmail(to: string | null, subject: string, body: string) {
	SC.util.simulateLinkClick($a({ target: '_blank', href: 'mailto:' + (to == null ? '' : to) + SC.util.getQueryString({ subject: subject, body: body }) }));
}

export function openClientEvent(to: string | null, subject: string, body: string, fileName: string) {
	const content = [
		'BEGIN:VCALENDAR',
		'VERSION:2.0',
		'PRODID:' + SC.res['Product.Name'],
		'BEGIN:VEVENT',
		'UID:' + Date.now(),
		'DTSTAMP:' + SC.util.formatDateTimeToIso(new Date()),
		'DTSTART:' + SC.util.formatDateTimeToIso(new Date()),
		'ORGANIZER;CN=default:MAILTO:default',
		'SUMMARY:' + subject,
		'DESCRIPTION:' + body.replace(/\n/g, '\\n').replace(/\r/g, ''),
		'END:VEVENT',
		'END:VCALENDAR',
	].join('\r\n');

	if ((window.navigator as any).msSaveOrOpenBlob) {
		(window.navigator as any).msSaveOrOpenBlob(new Blob([content]), fileName);
	} else if (SC.util.isCapable(SC.util.Caps.Safari) && !SC.util.isCapable(SC.util.Caps.Chrome) && !SC.util.isCapable(SC.util.Caps.Firefox)) {
		window.location.href = 'data:attachment/event,' + window.encodeURIComponent(content);
	} else {
		SC.util.simulateLinkClick($a({ download: fileName, href: 'data:attachment/event,' + window.encodeURIComponent(content) }));
	}
}

export function lazyImport<K extends keyof typeof SC.context.imports>(packageName: K): Promise<typeof SC.context.imports[K]> {
	// eval is used because `import` is a keyword and IE fails to parse the js
	return eval('import(SC.context.scriptBaseUrl + SC.context.imports[packageName])');
}

export function formatDomainMember(domain: string | null, member: string | null): string {
	const domainEmpty = SC.util.isNullOrEmpty(domain);
	const memberEmpty = SC.util.isNullOrEmpty(member);

	if (domainEmpty && memberEmpty)
		return '';
	else if (domainEmpty)
		return member!;
	else if (memberEmpty)
		return domain + '\\';
	else
		return domain + '\\' + member;
}

/** @deprecated as of 23.5 use formatDurationFromSeconds */
export function formatSecondsDuration(seconds: number): string {
	return SC.util.formatDurationFromSeconds(seconds);
}

export function formatDurationFromSeconds(seconds: number): string {
	if (seconds < 0)
		return '';
	
	const days = Math.floor(seconds / 86400); seconds %= 86400;
	const hours = Math.floor(seconds / 3600); seconds %= 3600;
	const minutes = Math.floor(seconds / 60); seconds %= 60;

	let string = '';

	if (days !== 0)
		string += days + 'd';

	if (hours !== 0)
		string += (string && ' ') + hours + 'h';

	if (days === 0)
		string += (string && ' ') + minutes + 'm';

	return string;
}

export type FormatDateTimeOptions = {
	includeFullDate?: boolean;
	includeRelativeDate?: boolean;
	includeSeconds?: boolean;
};

export function formatDateTimeFromSecondsAgo(secondsAgo: number, options?: FormatDateTimeOptions): string {
	if (secondsAgo < 0)
		return '';

	return SC.util.formatDateTime(new Date(new Date().getTime() - (secondsAgo * 1000)), options);
}

export function tryGetDateTime(value: number | string): Date | null {
	let dateTime = new Date(value);
	return dateTime.getTime() < new Date(0).getTime() ? null : dateTime; // compare default C# time with 1970/01/01
}

export function formatDateTime(dateTime: Date | number | string, options?: FormatDateTimeOptions): string {
	const actualDateTime = // TODO not sure of this
		typeof dateTime === 'object' ? dateTime
		: new Date(dateTime);

	const timeString = new Intl.DateTimeFormat(
		undefined,
		{
			hour: 'numeric',
			minute: 'numeric',
			second: options && options.includeSeconds ? 'numeric' : undefined,
		}
	).format(actualDateTime);

	function getRelativeDateString(): string {
		return new Intl.RelativeTimeFormat('default', { numeric: 'auto', style: 'narrow' })
			.format(SC.util.getDayCount(actualDateTime) - SC.util.getDayCount(new Date()), 'day');
	}

	function getFullDateString(): string {
		return new Intl.DateTimeFormat(
			undefined,
			{
				weekday: 'long',
				year: 'numeric',
				month: 'numeric',
				day: 'numeric',
			}
		).format(actualDateTime);
	}

	return options && options.includeFullDate && options.includeRelativeDate ? getRelativeDateString() + ' (' + getFullDateString() + ') ' + ('@ ' + timeString).replaceAll(' ', '\xa0')
		: options && options.includeRelativeDate ? getRelativeDateString() + ' ' + ('@ ' + timeString).replaceAll(' ', '\xa0')
			: options && options.includeFullDate ? getFullDateString() + ' ' + ('@ ' + timeString).replaceAll(' ', '\xa0')
				: timeString.replaceAll(' ', '\xa0');
}

export function getDayCount(dateTime: Date): number {
	return Math.floor((dateTime.getTime() - (dateTime.getTimezoneOffset() * 60000)) / 86400000);
}

export function formatDateTimeToIso(dateTime: Date): string {
	return dateTime.getUTCFullYear() +
		'' + SC.util.padToTwoDigits(dateTime.getUTCMonth() + 1) +
		'' + SC.util.padToTwoDigits(dateTime.getUTCDate()) +
		'T' + SC.util.padToTwoDigits(dateTime.getUTCHours()) +
		'' + SC.util.padToTwoDigits(dateTime.getUTCMinutes()) +
		'' + SC.util.padToTwoDigits(dateTime.getUTCSeconds()) +
		'Z';
}

export function formatDateTimeToInputDate(date: Date): string {
	const
		padToTwoDigits = function (i: number) {
			return (i < 10 ? '0' : '') + i;
		},
		YYYY = date.getFullYear(),
		MM = padToTwoDigits(date.getMonth() + 1),
		DD = padToTwoDigits(date.getDate());
	return YYYY + '-' + MM + '-' + DD;
}

export function formatDateTimeToInputTime(date: Date): string {
	const
		padToTwoDigits = function (i: number) {
			return (i < 10 ? '0' : '') + i;
		},
		HH = padToTwoDigits(date.getHours()),
		II = padToTwoDigits(date.getMinutes()),
		SS = padToTwoDigits(date.getSeconds());
	return HH + ':' + II + ':' + SS;
}

export function getMillisecondCount(): number {
	return new Date().getTime();
}

export function formatMinutesSinceMidnightUtcToTimeString(timeMinutes: number, options?: { utcOrLocal: boolean; showTimeZone: boolean; }): string {
	let date = new Date();
	let year = date.getUTCFullYear();
	let month = date.getUTCMonth();
	let day = date.getUTCDate();
	let utcDate = new Date(Date.UTC(year, month, day, 0, timeMinutes));
	return new Intl.DateTimeFormat(
		undefined,
		{
			hour: 'numeric',
			minute: 'numeric',
			hourCycle: 'h23', // need to do this because of bug in chrome: https://stackoverflow.com/questions/60886186/intl-datetimeformat-shows-time-being-2459
			timeZone: options?.utcOrLocal ? 'UTC' : undefined,
			timeZoneName: options?.showTimeZone ? 'shortGeneric' : undefined,
		}
	).format(utcDate);
}

export function getTimeZoneName(utcOrLocal: boolean): string {
	let dateTimeParts = new Intl.DateTimeFormat(
		undefined,
		{
			timeZone: utcOrLocal ? 'UTC' : undefined,
			timeZoneName: 'shortGeneric',
		}
	).formatToParts(new Date());
	return dateTimeParts.find(part => part.type === 'timeZoneName')!.value;
}

export function padToTwoDigits(number: number): string {
	return (number < 10) ? '0' + number : number.toString();
}

export function decodeSectionHashParameters(sectionHashString: string): string[] {
	return (sectionHashString.split('/') ?? []).map(decodeURIComponent);
}

export function decodeMultipleSectionsHashParameters(multipleSectionsHashString: string): string[][] {
	return multipleSectionsHashString.split('&').map(SC.util.decodeSectionHashParameters);
}

export function encodeHashParameters<T>(parameters: T[], delimiter: string, encodeFunc: (value: T) => string): string {
	if (!parameters || !parameters.length)
		return '';

	const parameterStrings = parameters.map(function (it) { return it == null ? it : encodeFunc(it); });
	while (parameterStrings.length && !parameterStrings[parameterStrings.length - 1])
		parameterStrings.pop();

	return parameterStrings.join(delimiter)
}

export function encodeSectionHashParameters(parameters: string[]): string {
	return SC.util.encodeHashParameters(parameters, '/', encodeURIComponent);
}

export function encodeMultipleSectionsHashParameters(sectionParametersList: string[][]): string {
	return SC.util.encodeHashParameters(sectionParametersList, '&', SC.util.encodeSectionHashParameters);
}

export function getWindowHashString(): string {
	// bug in firefox requires using different impl than window.location.hash
	// https://bugzilla.mozilla.org/show_bug.cgi?id=582361
	const hashIndex = window.location.href.indexOf('#');
	return (hashIndex == -1 ? '' : window.location.href.substring(hashIndex));
}

export function getWindowHashParametersSections(windowHashString: string) {
	return !windowHashString || windowHashString.length < 1 ? [] : SC.util.decodeMultipleSectionsHashParameters(windowHashString.substring(1));
}

export function getWindowHashParameters(sectionIndex: number) {
	return SC.util.getWindowHashParametersSections(SC.util.getWindowHashString())[sectionIndex] || [];
}

export function getWindowHashParameter(parameterIndex: number, sectionIndex = 0) {
	return SC.util.getWindowHashParameters(sectionIndex)[parameterIndex];
}

export function getWindowHashStringFromSectionParametersList(sectionParametersList) {
	return '#' + SC.util.encodeMultipleSectionsHashParameters(sectionParametersList)
}

export function setHashParameter(parameterIndex: number, value: string, sectionIndex = 0) {
	const existingHashString = SC.util.getWindowHashString();
	const parametersSections = SC.util.getWindowHashParametersSections(existingHashString);

	for (let i = 0; i < sectionIndex - parametersSections.length + 1; i++)
		parametersSections.push([]);

	for (let i = 0; i < parameterIndex - parametersSections[sectionIndex].length + 1; i++)
		parametersSections[sectionIndex].push('');

	parametersSections[sectionIndex][parameterIndex] = value;

	const newHashString = SC.util.getWindowHashStringFromSectionParametersList(parametersSections);
	const isDifferent = newHashString !== existingHashString;

	if (isDifferent)
		window.location.hash = newHashString;

	return isDifferent;
}

export function base64Encode(input: string): string {
	return window.btoa(unescape(encodeURIComponent(input)));
}

export function convertBase64ToUrlSafe(base64String: string): string {
	return base64String.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

export function convertBytesToBase64(byteArray: Iterable<number>): string {
	return btoa(Array.from(byteArray).reduce(function (result, byte) {
		return result + String.fromCharCode(byte);
	}, ''));
}

export function convertBytesToHex(byteArray: Iterable<number>): string {
	return Array.from(byteArray, function (byte) {
		return ('0' + byte.toString(16)).slice(-2);
	}).join('');
}

export function isNullOrEmpty(string: string | null | undefined): string is null | undefined {
	return (typeof string != 'string' || string == '');
}

export function getEnumValueName(enumType: Record<string, number>, value: number): string {
	window._enumMap ||= new WeakMap();

	let enumTypeMap: Record<number, string> | undefined = window._enumMap.get(enumType);

	if (!enumTypeMap) {
		enumTypeMap = Object.keys(enumType).reduce<Record<number, string>>(function (map, enumName) {
			map[enumType[enumName]] = enumName;
			return map;
		}, {});
		window._enumMap.set(enumType, enumTypeMap);
	}

	return enumTypeMap[value];
}

export function getEnumValueNames(enumType: Record<string, number>, value: number): string[] {
	return Object.keys(enumType).filter(function (_) { return (enumType[_] == 0 && value != 0) ? false : (enumType[_] & value) == enumType[_]; });
}

export function getRandomStringFromMask(mask: string) {
	let string = '';

	for (let i = 0; mask[i]; i++) {
		const maskChar = mask.charAt(i);

		if (maskChar == '#')
			string += SC.util.getRandomChar(48, 58);
		else if (maskChar == 'A')
			string += SC.util.getRandomChar(65, 91);
		else
			string += maskChar;
	}

	return string;
}

export function getRandomValues<T extends ArrayBufferView>(array: T) {
	return (window.crypto || window.msCrypto).getRandomValues(array);
}

export function getRandomHexString(length: number) {
	const byteLength = Math.ceil(length / 2);
	return SC.util.convertBytesToHex(SC.util.getRandomValues(new Uint8Array(byteLength))).slice(0, length);
}

export function getRandomBase64String(length: number) {
	const byteLength = Math.ceil(length * 3 / 4);
	return SC.util.convertBytesToBase64(SC.util.getRandomValues(new Uint8Array(byteLength))).slice(0, length);
}

export function getRandomAlphanumericString(approximateLength: number) {
	// 1.1 = heuristic to get closer to desired length while discarding unwanted characters
	return SC.util.getRandomBase64String(approximateLength * 1.1)
		.replace(/[=+/]/g, '')
		.slice(0, approximateLength);
}

// Cryptographically strong alternative to Math.random()
// From https://stackoverflow.com/a/34577886
export function getRandom() {
	const buffer = new ArrayBuffer(8);
	const array = new Int8Array(buffer);
	SC.util.getRandomValues(array);
	array[7] = 63;
	array[6] |= 0xf0;
	return new DataView(buffer).getFloat64(0, true) - 1;
}

export function getRandomChar(minCharCode: number, maxCharCode: number) {
	const charCode = minCharCode + Math.floor(SC.util.getRandom() * (maxCharCode - minCharCode));
	return String.fromCharCode(charCode);
}

export function stringToBoolean(string: string | null) {
	return string != null && string.toLowerCase() === 'true';
}

export function getCacheEntry(key, version) {
	window._cache = window._cache || {};

	const cacheEntry = window._cache[key];

	if (!cacheEntry || cacheEntry.version != version)
		return null;

	cacheEntry.lastUsedTime = SC.util.getMillisecondCount();
	return cacheEntry;
}

export function setCacheItem(key, version, item) {
	window._cache = window._cache || {};

	let cacheEntry = window._cache[key];

	if (!cacheEntry) {
		cacheEntry = {};
		window._cache[key] = cacheEntry;
	}

	cacheEntry.version = version;
	cacheEntry.firstUsedTime = cacheEntry.lastUsedTime = SC.util.getMillisecondCount();
	cacheEntry.item = item;

	// scavenge
	if (!window._cacheIntervalID) {
		window._cacheIntervalID = window.setInterval(function () {
			let hasEntries = false;
			const now = SC.util.getMillisecondCount();

			Object.keys(window._cache).forEach(function (cacheKey) {
				if (now - window._cache[cacheKey].lastUsedTime > 120000)
					delete window._cache[cacheKey];
				else
					hasEntries = true;
			});

			if (!hasEntries) {
				window.clearInterval(window._cacheIntervalID);
				window._cacheIntervalID = undefined;
			}
		}, 120000);
	}

	return cacheEntry;
}

export function tryGet<T>(getter: () => T): T | null {
	try {
		return getter();
	} catch (e) {
		return null;
	}
}

export function getParameterlessUrl(url: string): string {
	return url.split(/#|\?/)[0];
}

export function getBaseUrl(url: string): string {
	let newUrl = SC.util.getParameterlessUrl(url);
	const slashIndex = newUrl.lastIndexOf('/')

	if (slashIndex != -1)
		newUrl = newUrl.substring(0, slashIndex + 1);

	return newUrl;
}

export function getClientLaunchParameters(sessionID, sessionType, sessionTitle, participantName, logonSessionID, accessToken, processType, attributes) {
	return SC.util.combineObjects(
		SC.context.clp,
		{
			s: sessionID,
			i: sessionTitle,
			e: SC.util.getEnumValueName(SC.types.SessionType, sessionType),
			y: SC.util.getEnumValueName(SC.types.ProcessType, processType == undefined /* only for legacy; expect this now */ ? SC.context.processType : processType),
			r: participantName,
			l: logonSessionID,
			n: accessToken,
			a: SC.util.getEnumValueNames(SC.types.ClientLaunchAttributes, attributes)
		}
	);
}

export function getInstallerQueryString(nameCallbackFormat: string, customPropertyValueCallbackFormats, baseClientLaunchParameters) {
	const clientLaunchParameters = SC.util.combineObjects(baseClientLaunchParameters, {
		e: SC.util.getEnumValueName(SC.types.SessionType, SC.types.SessionType.Access),
		y: SC.util.getEnumValueName(SC.types.ProcessType, SC.types.ProcessType.Guest),
		// exclude unnecessary empty parameters from user-facing query string
		t: nameCallbackFormat || undefined,
		c: customPropertyValueCallbackFormats && customPropertyValueCallbackFormats.some(function (it) { return it; }) ? customPropertyValueCallbackFormats : undefined,
	});

	return SC.util.getQueryString(clientLaunchParameters);
}

export function getInstallerUrl(installerType, nameCallbackFormat: string, customPropertyValueCallbackFormats) {
	return SC.context.scriptBaseUrl
		+ SC.context.installerHandlerPath.replace('*', installerType)
		+ SC.util.getInstallerQueryString(nameCallbackFormat, customPropertyValueCallbackFormats);
}

export function getSessionTypeResource(resourceNameFormat: string, sessionType: number, varargs) {
	const argumentsCopy = Array.prototype.slice.call(arguments);
	argumentsCopy[1] = SC.util.getEnumValueName(SC.types.SessionType, sessionType);
	return SC.util.getResourceWithFallback.apply(this, argumentsCopy);
}

export function getSessionTypeBooleanResource(resourceNameFormat: string, sessionType: number, varargs) {
	const stringValue = SC.util.getSessionTypeResource.apply(this, arguments);
	return SC.util.stringToBoolean(stringValue);
}

export function getBooleanResource(resourceName: string) {
	return SC.util.stringToBoolean(SC.res[resourceName]);
}

// tries every permutation of set/unset resource name format arguments
export function getResourceWithFallback(resourceNameFormat: string, resourceNameFormatParametersVarArgs) {
	const resourceNameFormatArguments = SC.util.getVarArgs(resourceNameFormatParametersVarArgs, arguments, 1);
	for (let bitSet = 0; bitSet < (1 << resourceNameFormatArguments.length); bitSet++) {
		const candidateArguments = resourceNameFormatArguments.map(function (arg, argIndex) {
			return SC.util.areFlagsSet(bitSet, 1 << argIndex) ? '' : arg;
		});

		const value = SC.res[(SC.util.formatString(resourceNameFormat, candidateArguments))];
		if (value != undefined)
			return value;
	}

	return null;
}

export function generatePhoneticText(string: string) {
	const phoneticCodes = Array.prototype.map.call(string, function (codeChar) { return SC.res['PhoneticAlphabet.' + codeChar.toUpperCase()] || codeChar });
	return phoneticCodes.join('-');
}

export function getVisibleCustomPropertyIndices(sessionType: number) {
	return SC.util.createRangeArray(0, SC.context.customPropertyCount)
		.filter(function (_) { return SC.util.getSessionTypeBooleanResource('SessionProperty.Custom{1}.{0}Visible', sessionType, _ + 1); });
}

export function getVisibleCustomPropertyNames(sessionType: number) {
	return SC.util.getVisibleCustomPropertyIndices(sessionType)
		.map(SC.util.getCustomPropertyName);
}

export function forEachVisibleCustomProperty(sessionType: number, proc: (index: number, customPropertyName: string) => void) {
	SC.util.getVisibleCustomPropertyIndices(sessionType)
		.forEach(function (i) { proc(i, SC.util.getCustomPropertyName(i)); });
}

export function getCustomPropertyName(customPropertyIndex: number) {
	return 'Custom' + (customPropertyIndex + 1);
}

export function getCustomPropertyIndex(customPropertyName: string) {
	return customPropertyName.substring('Custom'.length) - 1;
}

export function includeStyleSheet(styleSheetUrl: string) {
	if (document.querySelector('head link[href=\'' + styleSheetUrl + '\']') == null)
		SC.ui.addElement(document.querySelector('head'), 'LINK', { rel: 'stylesheet', type: 'text/css', href: styleSheetUrl });
}

export function includeScript(scriptUrl: string, checkLoadedFunc, runWhenLoadedProc) {
	let headScript = document.querySelector('head script[src=\'' + scriptUrl + '\']');

	if (headScript === null)
		headScript = SC.ui.addElement(document.querySelector('head'), 'SCRIPT', { src: scriptUrl });

	if (checkLoadedFunc && runWhenLoadedProc) {
		const proc = function () {
			if (checkLoadedFunc())
				runWhenLoadedProc();
			else
				window.setTimeout(proc, 50);
		};

		proc();
	}
}

export function sendToLogin(loginReason: string | number, shouldReturn: boolean) {
	const newQueryStringMap = {};

	if (shouldReturn)
		newQueryStringMap[SC.context.loginReturnUrlParameterName] = SC.util.parseQueryString(window.location.search)[SC.context.loginReturnUrlParameterName] || window.location.href.substring(0, window.location.href.length - window.location.hash.length);

	newQueryStringMap[SC.context.loginReasonParameterName] = loginReason;

	window.location.href = SC.context.loginUrl + SC.util.getQueryString(newQueryStringMap) + window.location.hash;
}

export function copyToClipboard(successProc?: () => void, failureProc?: (ex: unknown) => void) {
	try {
		if (!document.execCommand('copy')) throw '';
		if (successProc) successProc();
	} catch (ex) {
		if (failureProc) failureProc(ex);
	}
}

/** @deprecated use SC.util.createRangeArray */
export const range = createRangeArray;

/** @deprecated use groupBy Array extension */
export function groupBy(array: unknown[], groupByFunc) {
	return array.groupBy(groupByFunc);
}

export function difference<T>(array1: T[], array2: T[]) {
	return array1.concat(array2).filter((it) => !array1.includes(it) || !array2.includes(it));
}

export function removeElementFromArray<T>(array: T[], element: T) {
	const index = array.indexOf(element);
	if (index > -1) {
		array.splice(index, 1);
	}
}

export function handleToggleAll(toggleAllCheckbox: HTMLInputElement, checkboxes: Iterable<HTMLInputElement>) {
	Array.from(checkboxes).forEach((it) => (it.checked = toggleAllCheckbox.checked));
}

export function handleToggle(toggleCheckbox: HTMLInputElement, toggleAllCheckbox: HTMLInputElement, otherCheckboxes: Iterable<HTMLInputElement>) {
	if (!toggleCheckbox.checked)
		toggleAllCheckbox.checked = false;
	else
		toggleAllCheckbox.checked = Array.from(otherCheckboxes).every((it) => it.checked);
}

export function moveElement(array: unknown[], oldIndex: number, newIndex: number) {
	newIndex = (newIndex > oldIndex) ? newIndex - 1 : newIndex;
	if (oldIndex != newIndex)
		array.splice(newIndex, 0, array.splice(oldIndex, 1)[0]);
}

export function isTouchEnabled() {
	if (window._isTouchEnabled == null)
		window._isTouchEnabled = document.documentElement.ontouchstart != null;
	return window._isTouchEnabled;
}

export function combinePath(path1: string, path2: string) {
	return Array.prototype.concat(path1, path2).join("/");
}

export function setValueAtPath(object, path: string[], value) {
	let current = object;

	for (let i = 0; i < path.length - 1; i++) {
		const next = current[path[i]];
		current = next && typeof next === 'object' ? next : (current[path[i]] = {});
	}

	current[path[path.length - 1]] = value;
}

export function parseTsvIntoJaggedArray(tsvContent: string) {
	return tsvContent
		.split(/\r?\n/)
		.map(function (_) { return _.split('\t'); });
}

export function tryNavigateToElementUsingCommand(element: HTMLElement, upOrDown: boolean, isAdvanced: boolean) {
	if (element && element._commandName) {
		SC.ui.scrollIntoViewIfNotInView(element, upOrDown);
		SC.command.dispatchExecuteCommand(element, element, element, element._commandName, element._commandArgument, isAdvanced);
	}
}

export function fromDateAndTimeValueStrings(dateString: string, timeString: string) {
	return new Date(dateString + 'T' + timeString);
}

export function addDuration(
	date: Date,
	duration: {
		milliseconds?: number,
		seconds?: number,
		minutes?: number,
		hours?: number,
		days?: number,
		months?: number,
		years?: number,
	}
) {
	return new Date(
		date.valueOf()
		+ (duration.milliseconds || 0)
		+ (duration.seconds || 0) * 1000
		+ (duration.minutes || 0) * 60 * 1000
		+ (duration.hours || 0) * 60 * 60 * 1000
		+ (duration.days || 0) * 24 * 60 * 60 * 1000
		+ (duration.months || 0) * 30 * 24 * 60 * 60 * 1000
		+ (duration.years || 0) * 365 * 24 * 60 * 60 * 1000
	);
}

export function clearAndSetInterval(intervalID: number, proc: TimerHandler, intervalTime: number) {
	window.clearInterval(intervalID);
	return window.setInterval(proc, intervalTime);
}

export function recordLifeCycleEvent(eventName: string) {
	(window._lifeCycleEvents || (window._lifeCycleEvents = [])).push(eventName);
}

export function addOrRunLifeCycleEventHandler(eventName: string, handler: () => void) {
	if (window._lifeCycleEvents && window._lifeCycleEvents.indexOf(eventName) != -1)
		handler();
	else
		SC.event.addGlobalHandler(eventName, handler);
}

export function getBoundedValue(min: number, value: number, max: number): number {
	if (value < min)
		return min;

	if (value > max)
		return max;

	return value;
}

export interface ElementTagOptions {
	attributes?: ElementAttributes;
	validators?: ElementValidators;
}
export type ElementTags = {
	[tagName in keyof HTMLElementTagNameMap | 'rb']?: ElementTagOptions;
};

export interface ElementAttributeOptions {
	validators?: string[];
}
export interface ElementAttributes {
	[attribute: string]: ElementAttributeOptions;
}

export interface ElementValidatorOptions {}
export interface ElementValidators {
	[validator: string]: ElementValidatorOptions;
}

// inspired by https://stackoverflow.com/a/28533511
export const sanitizeHtml: (value: string) => string = (function () {
	const globallyAllowedAttributes = { 'class': {}, dir: {}, id: {}, lang: {}, title: {} } satisfies ElementAttributes;

	const allowedHtmlTags = {
		// Sections mirror https://developer.mozilla.org/en-US/docs/Web/HTML/Element
		// Sectioning root //
		body: {},

		// Content sectioning //
		address: {}, article: {}, aside: {}, footer: {}, header: {}, h1: {}, h2: {},
		h3: {}, h4: {}, h5: {}, h6: {}, hgroup: {}, main: {}, nav: {}, section: {},

		// Text content //
		blockquote: {}, dd: {}, div: {}, dl: {}, dt: {}, figcaption: {}, figure: {}, hr: {},
		li: { attributes: { value: {} } },
		ol: { attributes: { reversed: {}, start: {}, type: {} } },
		p: {}, pre: {}, ul: {},

		// Inline text semantics //
		a: {
			attributes: {
				href: { validators: ['safeUrlValidator'] },
				referrerpolicy: {}, rel: {}, target: {},
			},
		},
		abbr: {}, b: {}, bdi: {}, bdo: {}, br: {}, cite: {}, code: {},
		data: { attributes: { value: {} } },
		dfn: {}, em: {}, i: {}, kbd: {}, mark: {}, q: {}, rb: {},
		rp: {}, rt: {}, rtc: {}, ruby: {}, s: {}, samp: {}, small: {}, span: {},
		strong: {}, sub: {}, sup: {},
		time: { attributes: { datetime: {} } },
		u: {}, var: {}, wbr: {},

		// Image and multimedia //
		img: {
			attributes: {
				alt: {}, crossorigin: {}, decoding: {}, height: {},
				importance: {}, intrinsicsize: {}, loading: {}, referrerpolicy: {},
				src: { validators: ['safeUrlValidator'] },
				width: {},
			},
		},

		// Embedded content //

		// Scripting //
		// apparently, chrome's html parser works differently when parsing noscript tags between javascript-enabled (normal) and javascript-disabled (sandboxed iframe) environments
		// so, disallow noscript tags to protect against this class of mutation XSS vulnerabilities
		// noscript: {},

		// Demarcating edits //
		del: { attributes: { datetime: {} } },
		ins: { attributes: { datetime: {} } },

		// Table content //
		caption: {},
		col: { attributes: { span: {} } },
		colgroup: { attributes: { span: {} } },
		table: {},
		tbody: {},
		td: { attributes: { colspan: {}, headers: {}, rowspan: {} } },
		tfoot: {},
		th: { attributes: { abbr: {}, colspan: {}, headers: {}, rowspan: {}, scope: {} } },
		thead: {},
		tr: {},

		// Forms //

		// Interactive elements //
		details: { attributes: { open: {} } },
		summary: {},

		// Web Components //

		// Obsolete and deprecated elements //
		center: {},
	} satisfies ElementTags;

	const iframe = document.createElement('iframe');
	if (iframe.sandbox == null)
		return function () { return ''; }; // unsupported browser => refuse to render

	iframe.style.display = 'none';
	iframe.setAttribute('sandbox', 'allow-same-origin'); // so we can access contentDocument

	return function (input): string {
		try {
			document.body.appendChild(iframe);
			iframe.contentDocument.body.innerHTML = input;
			const resultElement = makeSanitizedCopy(iframe.contentDocument.body);
			return resultElement.innerHTML;
		} catch (ex) {
			console.log("Error sanitizing input:", ex);
			return '';
		} finally {
			// removing from body deletes contentDocument from iframe
			document.body.removeChild(iframe);
		}

		function makeSanitizedCopy(node: HTMLElement): HTMLElement {
			if (node.nodeType === Node.TEXT_NODE)
				return node.cloneNode(true);

			const tagName = node.tagName.toLowerCase();
			if (node.nodeType !== Node.ELEMENT_NODE || allowedHtmlTags[tagName] == null)
				return document.createDocumentFragment();

			const newNode = iframe.contentDocument.createElement(node.tagName);

			Array.from(node.attributes)
				.map(function (it) {
					const globalConfig = globallyAllowedAttributes[it.name];
					const tagAttributeConfig: ElementAttributeOptions | undefined = allowedHtmlTags[tagName].attributes && allowedHtmlTags[tagName].attributes[it.name];

					return {
						name: it.name.toLowerCase(),
						value: it.value,
						config: (globalConfig || tagAttributeConfig) ? Object.assign({}, globalConfig, tagAttributeConfig) : null,
					};
				})
				.filter(function (it) {
					if (it.config == null)
						return false;

					if (it.config.validators) {
						if (it.config.validators.includes('safeUrlValidator')) {
							// mainly for filtering out javascript urls
							// tested against https://owasp.org/www-community/xss-filter-evasion-cheatsheet
							if (!SC.util.sanitizeUrl(it.value))
								return false;
						}
					}

					return true;
				})
				.forEach(function (it) {
					newNode.setAttribute(it.name, it.value);
				});

			Array.from(node.childNodes).forEach(function (it) {
				newNode.appendChild(makeSanitizedCopy(it));
			});

			return newNode;
		}
	}
})();

export function sanitizeUrl(urlString: string) {
	// anchor element's href getter parses url so we don't have to
	const url = $a({ href: urlString }).href;
	if (!['http', 'https', 'ftp', 'mailto', 'tel'].includes(url.split(':', 1)[0]))
		return "";
	return url;
}

export function escapeHtml(htmlString: string) {
	return $div(htmlString).innerHTML;
}

export function escapeHtmlAndLinkify(htmlString: string) {
	// restricted character set should be safe against XSS
	const urlRegex = /\b(?:https?|ftp):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|]/ig;

	const urls = htmlString.match(urlRegex);
	if (urls == null)
		return SC.util.escapeHtml(htmlString);

	const htmlLinks = urls.map(function (it) {
		return $a({ href: it, target: '_blank', rel: "noreferrer", title: it }, it).outerHTML;
	});

	// remove urls, escape html, add back linkified urls
	return htmlString
		.split(urlRegex)
		.map(SC.util.escapeHtml)
		.reduce<string[]>((result, it, i) => result.concat(it, htmlLinks[i]), [])
		.join('');
}

export const equalsCaseInsensitive = (function () {
	try {
		'foo'.localeCompare('bar', 'i'); // check for browser support
	} catch (e: Error) {
		if (e.name === 'RangeError') // supports extended arguments
			return function (referenceString: string, compareString: string) {
				return referenceString.localeCompare(compareString, 'en', { sensitivity: 'base' }) === 0;
			};
	}
	return function (referenceString: string, compareString: string) {
		return referenceString.toLowerCase() === compareString.toLowerCase();
	};
})();

export function containsText(inputTexts: string | (string | null)[], searchText: string, options?: { isCaseSensitive?: boolean }): boolean {
	const isCaseSensitive = (options && options.isCaseSensitive);
	const transformedSearchText = isCaseSensitive ? searchText : searchText.toLowerCase();
	function matches(itemText: string | null) {
		return itemText != null && (isCaseSensitive ? itemText : itemText.toLowerCase()).indexOf(transformedSearchText) !== -1;
	}

	if (typeof inputTexts === 'string')
		return matches(inputTexts);
	else {
		return inputTexts.some(function (it) { return matches(it) });
	}
};

export function any(array: unknown[]): boolean {
	return array && array.length > 0;
};
