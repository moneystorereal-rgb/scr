import * as command from "./SC.command";
import * as css from "./SC.css";
import * as dashboard from "./SC.dashboard";
import * as dialog from "./SC.dialog";
import * as editfield from "./SC.editfield";
import * as entryhistory from "./SC.entryhistory";
import * as event from "./SC.event";
import * as extension from "./SC.extension";
import * as http from "./SC.http";
import * as installer from "./SC.installer";
import * as launch from "./SC.launch";
import * as livedata from "./SC.livedata";
import * as nav from "./SC.nav";
import * as pagedata from "./SC.pagedata";
import * as panellist from "./SC.panellist";
import * as popout from "./SC.popout";
import * as svg from "./SC.svg";
import * as toolbox from "./SC.toolbox";
import * as tooltip from "./SC.tooltip";
import * as ui from "./SC.ui";
import * as util from "./SC.util";

window.namespace = function (namespace) {
	const parts = namespace.split('.');
	let currentSection = window as any;

	for (let i = 0; i < parts.length; i++)
		currentSection = currentSection[parts[i]] ||= {};
};

// ensure always-available libraries are on the global SC object

namespace("SC");
window.SC = {
	...window.SC,
	command,
	css,
	dashboard,
	dialog,
	editfield,
	entryhistory,
	event,
	extension,
	http,
	installer,
	launch,
	livedata,
	nav,
	pagedata,
	panellist,
	popout,
	svg,
	toolbox,
	tooltip,
	ui,
	util,
};

// proprietary prototype extensions

declare global {
	interface Window {
		namespace: (namespace: string) => void;
	}

	interface Element {
		_commandName?: string;
		_commandArgument?: string;
	}

	interface Object {
		mapKeyValue<T>(selector: (key: string, value: unknown) => T): T[];
		forEachKeyValue(func: (key: string, value: unknown) => void): void;
	}

	interface Array<T> {
		groupBy(keySelector: (item: T) => any, optionalValueSelector?: (item: T) => any): any;
		firstOrDefault(selector: (item: T) => any): T | null;
		everyEqual(selector: (item: T) => any): boolean;
		interleave(interleaveFunc: (index: number) => any): Array<any>;
		orderBy(selector: (item: T) => any, reverse?: boolean): Array<T>;
		orderByDescending(selector: (item: T) => any): Array<T>;
	}
}

// proprietary object extensions won't be called under ie8
(function () {
	function defineFunction<T>(prototype: any, name: string, func: T) {
		try {
			Object.defineProperty(prototype, name, { enumerable: false, value: func });
		} catch (ex) {
			prototype[name] = func;
		}
	}

	defineFunction<typeof Object.mapKeyValue>(Object.prototype, 'mapKeyValue', function (this: any, selector) {
		const O = Object(this);
		return Object.keys(O).map((key) => selector(key, O[key]));
	});

	defineFunction<typeof Object.forEachKeyValue>(Object.prototype, 'forEachKeyValue', function (this: any, func) {
		const O = Object(this);
		return Object.keys(O).forEach((key) => { func(key, O[key]); });
	});
})();

// proprietary array extensions
Array.prototype.groupBy = function (keySelector, optionalValueSelector) {
	const groupObject: any = {};

	this.forEach((item) => {
		const groupKey = keySelector(item);
		let items = groupObject[groupKey];

		if (!items)
			items = groupObject[groupKey] = [];

		items.push(optionalValueSelector ? optionalValueSelector(item) : item);
	});

	return groupObject;
};

Array.prototype.firstOrDefault = function (selector) {
	const firstElement = SC.util.selectOrDefault(this[0], selector);

	if (firstElement === undefined)
		return null;

	return firstElement;
};

Array.prototype.everyEqual = function (selector) {
	const firstValue = SC.util.selectOrDefault(this[0], selector);

	for (let i = 1; this[i] != undefined; i++)
		if (SC.util.selectOrDefault(this[i], selector) != firstValue)
			return false;

	return true;
};

Array.prototype.interleave = function (interleaveFunc) {
	const newArray: unknown[] = [];

	for (let i = 0; i < this.length; i++) {
		if (i != 0)
			newArray.push(interleaveFunc(i));

		newArray.push(this[i]);
	}

	return newArray;
};

Array.prototype.orderBy = function (selector, reverse) {
	return this.map((_) => ({ sortKey: SC.util.selectOrDefault(_, selector), value: _ }))
		.sort((a, b) => (reverse ? -1 : 1) * (a.sortKey < b.sortKey ? -1 : a.sortKey > b.sortKey ? 1 : 0))
		.map((_) => _.value);
};

Array.prototype.orderByDescending = function (selector) {
	return this.orderBy(selector, true);
};
