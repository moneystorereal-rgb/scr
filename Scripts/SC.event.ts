// @ts-nocheck

export const ExecuteCommand = 'executecommand';
export const QueryCommandButtons = 'querycommandbuttons';
export const QueryCommandButtonState = 'querycommandbuttonstate';
export const QueryParticipantJoinedCount = 'queryparticipantjoinedcount';
export const QueryNavigationLinks = 'querynavigationlinks';
export const QueryPanels = 'querypanels';
export const QueryTextEntryElement = 'querytextentryelement';
export const QueryJoinInfo = 'queryjoininfo';
export const QuerySessionEventRenderInfo = 'querysessioneventrenderinfo';
export const QueryLiveData = 'querylivedata';
export const LiveDataRefreshed = 'livedatarefreshed';
export const LiveDataDirtied = 'livedatadirtied';
export const JoinPromptCompleted = 'joinpromptcompleted';
export const JoinSessionCompleted = 'joinsessioncompleted';
export const PageDataDirtied = 'pagedatadirtied';
export const PageDataRefreshed = 'pagedatarefreshed';
export const PreRender = 'prerender';
export const PostRender = 'postrender';
export const InitializeTab = 'initializetab';
export const RefreshTab = 'refreshtab';
export const QueryTabContainsRelativeTimes = 'querytabcontainsrelativetimes';
export const KeyNavigation = 'keynavigation';

export function getElement(eventArgs) {
	return eventArgs.target ? eventArgs.target : eventArgs.srcElement;
}

export function isLeftButton(eventArgs: MouseEvent) {
	return eventArgs.which === 1 || eventArgs.button === 1 || eventArgs.button === 0;
}

export function getMouseLocation(eventArgs: MouseEvent): { x: number; y: number; } {
	if (eventArgs.pageX || eventArgs.pageY)
		return { x: eventArgs.pageX, y: eventArgs.pageY };

	return {
		x: eventArgs.clientX + document.body.scrollLeft - document.body.clientLeft,
		y: eventArgs.clientY + document.body.scrollTop - document.body.clientTop
	};
}

export function isEnterKey(eventArgs: KeyboardEvent) {
	return eventArgs && eventArgs.keyCode == 13;
}

export function getArrowKeyInfo(eventArgs: KeyboardEvent) {
	if (eventArgs.keyCode >= 37 && eventArgs.keyCode <= 40)
		return {
			isLeft: eventArgs.keyCode == 37,
			isRight: eventArgs.keyCode == 39,
			isUp: eventArgs.keyCode == 38,
			isDown: eventArgs.keyCode == 40,
		};

	return null;
}

export function doesKeyEventIndicateTextEntryOrArrowKeyNavigation(eventArgs: KeyboardEvent) {
	if (eventArgs.ctrlKey || eventArgs.altKey || eventArgs.metaKey)
		return false;

	if (eventArgs.keyCode == 8)
		return true;

	if (eventArgs.keyCode < 33)
		return false;

	if (eventArgs.keyCode >= 91 && eventArgs.keyCode <= 93)
		return false;

	if (eventArgs.keyCode >= 112 && eventArgs.keyCode <= 145)
		return false;

	return true;
}

export function doesKeyEventIndicateTextEntryNavigation(eventArgs: KeyboardEvent) {
	if (eventArgs.keyCode >= 33 && eventArgs.keyCode <= 46)
		return true;

	if (eventArgs.keyCode == 8)
		return true;

	return false;
}

export function dispatchEvent(targetElement: HTMLElement | null, eventName: string, properties?: any) {
	var eventArgs;
	var dispatchTargetElement = SC.ui.findAncestor(targetElement, function (_) { return _.tagName == 'BODY'; }) ? targetElement : window.document.body;
	var dispatchEventName = eventName;
	var customEventName = null;

	if (SC.util.isCapable(SC.util.Caps.InternetExplorer)) {
		// ie 8 and such don't even support custom event names
		// ie 10 and 11 have bugs that will misroute custom events
		dispatchEventName = 'dataavailable';
		customEventName = eventName;
	}

	if (typeof Event === "function") {
		eventArgs = new Event(eventName, { bubbles: true, cancelable: false });
		SC.util.copyProperties(properties, eventArgs);
		dispatchTargetElement.dispatchEvent(eventArgs);
	} else if (document.createEvent) {
		eventArgs = document.createEvent('Event');
		eventArgs.initEvent(dispatchEventName, true, false);
		SC.util.copyProperties(properties, eventArgs);
		eventArgs._customEventName = customEventName;
		dispatchTargetElement.dispatchEvent(eventArgs);
	} else {
		eventArgs = document.createEventObject();
		eventArgs._customEventName = eventName;
		SC.util.copyProperties(properties, eventArgs);
		dispatchTargetElement.fireEvent('on' + dispatchEventName, eventArgs);
	}

	return eventArgs;
}

export function dispatchGlobalEvent(eventName: string, properties: any) {
	return dispatchEvent(null, eventName, properties);
}


export function addHandler<K extends keyof GlobalEventHandlersEventMap, T extends GlobalEventHandlersEventMap[K]>(element: HTMLElement | Window | Document, eventName: K, func: (eventArgs: T) => any, options?: AddEventListenerOptions): void;
export function addHandler<T extends Event>(element: HTMLElement | Window | Document, eventName: string, func: (eventArgs: T) => any, options?: AddEventListenerOptions): void;
export function addHandler(element: HTMLElement | Window | Document, eventName: string, func: (eventArgs: Event) => any, options?: AddEventListenerOptions): void
{
	if (!func) return;

	if (typeof element.addEventListener !== 'undefined')
		element.addEventListener(eventName, func, options ?? false);
	else if (typeof element.attachEvent !== 'undefined')
		element.attachEvent('on' + eventName, func);
	else
		element['on' + eventName] = func;

	if (eventName !== 'dataavailable' && SC.util.isCapable(SC.util.Caps.InternetExplorer)) {
		func._dataavailableHandler = function (eventArgs) {
			if (eventArgs._customEventName === eventName)
				func(eventArgs);
		};

		addHandler(element, 'dataavailable', func._dataavailableHandler);
	}
}

export function removeHandler<K extends keyof GlobalEventHandlersEventMap>(element: HTMLElement | Window | Document, eventName: K, func: (eventArgs: GlobalEventHandlersEventMap[K]) => any, options?: AddEventListenerOptions): void;
export function removeHandler<T extends Event>(element: HTMLElement | Window | Document, eventName: string, func: (eventArgs: T) => any, options?: AddEventListenerOptions): void;
export function removeHandler(element: HTMLElement | Window | Document, eventName: string, func: (eventArgs: Event) => any, options?: AddEventListenerOptions): void {
	if (!func) return;

	if (typeof element.removeEventListener !== 'undefined')
		element.removeEventListener(eventName, func, options ?? false);
	else if (typeof element.detachEvent !== 'undefined')
		element.detachEvent('on' + eventName, func);
	else
		element['on' + eventName] = null;

	if (func._dataavailableHandler && eventName !== 'dataavailable' && SC.util.isCapable(SC.util.Caps.InternetExplorer))
		removeHandler(element, 'dataavailable', func._dataavailableHandler);
}

export function addGlobalHandler<K extends keyof DocumentEventMap>(eventName: K, func: (eventArgs: DocumentEventMap[K]) => any, options?: AddEventListenerOptions): void;
export function addGlobalHandler<T extends Event>(eventName: string, func: (eventArgs: T) => any, options?: AddEventListenerOptions): void;
export function addGlobalHandler(eventName: string, func: (eventArgs: Event) => any, options?: AddEventListenerOptions): void {
	addHandler(window.document, eventName, func, options);
}

export function removeGlobalHandler<K extends keyof DocumentEventMap>(eventName: K, func: (eventArgs: DocumentEventMap[K]) => any, options?: AddEventListenerOptions): void;
export function removeGlobalHandler<T extends Event>(eventName: string, func: (eventArgs: T) => any, options?: AddEventListenerOptions): void;
export function removeGlobalHandler(eventName: string, func: (eventArgs: Event) => any, options?: AddEventListenerOptions): void {
	removeHandler(window.document, eventName, func, options);
}
