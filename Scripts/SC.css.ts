// @ts-nocheck

export function containsClass(element: Element, className: string) {
	return !SC.util.isNullOrEmpty(element.className) && (' ' + element.className + ' ').indexOf(' ' + className + ' ') != -1;
}

export function toggleClass(element: Element, className: string) {
	if (containsClass(element, className)) {
		removeClass(element, className);
		return false;
	} else {
		addClass(element, className);
		return true;
	}
}

export function addClass(element: Element, className: string) {
	element.className = (element.className === '' ? className : element.className + ' ' + className);
}

export function removeClass(element: Element, className: string) {
	var paddedClassName = ' ' + element.className + ' ';
	var index = paddedClassName.indexOf(' ' + className + ' ');
	if (index > -1)
		element.className = (paddedClassName.substr(0, index) + ' ' + paddedClassName.substring(index + className.length + 1, paddedClassName.length)).trim();
}

export function ensureClass(element: Element, className: string, hasOrNot: boolean) {
	var previouslyContained = containsClass(element, className);

	if (hasOrNot && !previouslyContained) {
		addClass(element, className);
		return true;
	} else if (!hasOrNot && previouslyContained) {
		removeClass(element, className);
		return true;
	}

	return false;
}

export function getClassNameStringFromMap(map) {
	return Object.keys(map)
		.filter(function (k) { return map[k]; })
		.join(' ');
}

export function tryGetComputedStyle(element, psuedoElement) {
	return window.getComputedStyle ? window.getComputedStyle(element, psuedoElement) : null;
}

// non-raw values will be resolved to pixels, and we probably don't want that
export function tryGetCssPropertyRawString(element, cssProperty) {
	// HACKish - a side effect of using this function is that it triggers anything that reacts from changing display value
	// https://www.w3.org/TR/css-typed-om-1/ seems promising but is still in development by browsers
	// https://stackoverflow.com/questions/9730612/get-element-css-property-width-height-value-as-it-was-set-in-percent-em-px-et states that the above is in experimental chrome

	var computedStyle = tryGetComputedStyle(element);
	var value = null;

	if (computedStyle) {
		var parent = element.parentNode;
		parent.style.display = 'none';
		value = computedStyle.getPropertyValue(cssProperty);
		parent.style.removeProperty('display');
	}

	return value;
}

export function tryGetExtendedCssValueFromElement(element, property) {
	return tryGetExtendedCssValue(tryGetComputedStyle(element), property);
}

export function tryGetExtendedCssValue(computedStyle, property) {
	return computedStyle && computedStyle.getPropertyValue('--' + property).trim();
}

export function runElementAnimation(element, animationName) {
	element.setAttribute('animation', animationName);

	var animationEndHandler = function () {
		element.removeAttribute('animation');
		SC.event.removeHandler(element, animationEndHandler);
	};

	SC.event.addHandler(element, 'animationend', animationEndHandler);
}

export function tryGetUnitlessValues(stringValues: string[]) {
	let values: number[] = [];
	let unit: string | null = null;
	for (let i = 0; i < stringValues.length; i++) {
		const digitsMatch = /^(\d*\.?\d+)(\D*)$/.exec(stringValues[i].trim()); // handles 54px, 12.32%, etc.
		if (digitsMatch == null)
			return null;

		const value = parseFloat(digitsMatch[1]);
		if (Number.isNaN(value) || value < 0)
			return null;

		if (unit == null)
			unit = digitsMatch[2];
		else if (unit !== digitsMatch[2])
			return null;

		values.push(value);
	}

	return values;
}

export function getUnitlessValues(stringValues: string[]) {
	const values = tryGetUnitlessValues(stringValues);
	if (values == null)
		throw new Error('Invalid: ' + stringValues.join(' '));
	return values;
}

export function normalizeRelativeValues(values: number[]) {
	const sum = values.reduce(function (a, b) { return a + b; }, 0);
	return values.map(function (it) { return it / sum; });
}

export function setGridTemplateColumns(
	element: HTMLElement,
	desiredColumnWidths: string | null,
	desiredColumnEdgeShiftIndex: number | null,
	desiredColumnEdgeShiftPixels: number | null
) {
	const elementWidth = element.getBoundingClientRect().width;

	const resizeHandleBarElements: HTMLElement[] = $$(element, ':scope > .ResizeHandleBar');

	element.style.removeProperty('grid-template-columns');
	const baseValue = window.getComputedStyle(element).getPropertyValue('grid-template-columns');

	const desiredRelativeWidths: number[] = desiredColumnWidths && tryGetUnitlessValues(desiredColumnWidths.split(' ')) || getUnitlessValues(baseValue.split(' '));

	let columnPercentageWidths;
	if (elementWidth === 0) {
		columnPercentageWidths = normalizeRelativeValues(desiredRelativeWidths).map(function (it) { return 100 * it; })
	} else {
		const desiredWidthPixels = normalizeRelativeValues(desiredRelativeWidths)
			.map(function (it) { return elementWidth * it; })
			.map(function (it, i) {
				return desiredColumnEdgeShiftIndex == null || desiredColumnEdgeShiftPixels == null ? it :
					i === desiredColumnEdgeShiftIndex ? it + desiredColumnEdgeShiftPixels :
						i === desiredColumnEdgeShiftIndex + 1 ? it - desiredColumnEdgeShiftPixels :
							it;
			});

		const minColumnWidths = desiredWidthPixels.map(function (_, i) {
			return resizeHandleBarElements.reduce(function (result, it) {
				return it._edgeIndex === i ? Math.max(result, it._leftColumnMinWidthPixels)
					: it._edgeIndex === i - 1 ? Math.max(result, it._rightColumnMinWidthPixels)
						: result;
			}, 0);
		});

		const columnWidthPixels = desiredWidthPixels;

		function adjustWidthsPropagatingLeft() {
			for (let i = columnWidthPixels.length - 1; i >= 0; i--) {
				const shortage = minColumnWidths[i] - columnWidthPixels[i];
				if (shortage > 0 && i - 1 >= 0) {
					columnWidthPixels[i] += shortage;
					columnWidthPixels[i - 1] -= shortage;
				}
			}
		}

		function adjustWidthsPropagatingRight() {
			for (let i = 0; i < columnWidthPixels.length; i++) {
				const shortage = minColumnWidths[i] - columnWidthPixels[i];
				if (shortage > 0 && i + 1 < columnWidthPixels.length) {
					columnWidthPixels[i] += shortage;
					columnWidthPixels[i + 1] -= shortage;
				}
			}
		}

		if (desiredColumnEdgeShiftIndex == null || desiredColumnEdgeShiftPixels == null || desiredColumnEdgeShiftPixels === 0) {
			adjustWidthsPropagatingRight();
		} else if (desiredColumnEdgeShiftPixels > 0) {
			adjustWidthsPropagatingRight();
			adjustWidthsPropagatingLeft();
		} else {
			adjustWidthsPropagatingLeft();
			adjustWidthsPropagatingRight();
		}

		columnPercentageWidths = columnWidthPixels.map(function (it) { return 100 * it / elementWidth; });
	}

	const newGridColumnWidths = columnPercentageWidths.map(function (it) { return it.toFixed(2) + '%'; });
	const newValue = newGridColumnWidths.join(' ');
	element.style.gridTemplateColumns = newValue;

	if (window.getComputedStyle(element).getPropertyValue('grid-template-columns') === baseValue) {
		element.style.removeProperty('grid-template-columns');
	}

	for (var i = 0; i < resizeHandleBarElements.length; i++) {
		const handleBarElement = resizeHandleBarElements[i];
		// NOTE this `left` positioning depends the parent element having its own stacking context (e.g. MainPanel is `position: relative`)
		resizeHandleBarElements[i].style.left = 'calc(' + newGridColumnWidths.slice(0, handleBarElement._edgeIndex + 1).join(' + ') + ')';
		resizeHandleBarElements[i].style.width = 'calc(' + handleBarElement._handleRightOffset + ' - ' + handleBarElement._handleLeftOffset + ')';
		resizeHandleBarElements[i].style.marginLeft = handleBarElement._handleLeftOffset;
	}
}

export function handleGridResizableColumnEdgesDoubleClickEvent(eventArgs: MouseEvent) {
	const handleBarElement: HTMLElement = eventArgs.target;
	// reset applicable columns on handle bar double-click iff the dblclick event isn't immediately following the completion of a drag resize
	if (handleBarElement._shouldProcessDoubleClick) {
		eventArgs.preventDefault();
		const element: HTMLElement = handleBarElement.parentElement;

		const initialColumnWidths = window.getComputedStyle(element).getPropertyValue('grid-template-columns');
		const initialColumnPixelWidths = getUnitlessValues(initialColumnWidths.split(' '));
		setGridTemplateColumns(element, null);

		const baseColumnPixelWidths = getUnitlessValues(window.getComputedStyle(element).getPropertyValue('grid-template-columns').split(' '));
		const edgeDelta =
			baseColumnPixelWidths.reduce(function (result, it, i) { return i <= handleBarElement._edgeIndex ? (result + it) : result; }, 0)
			- initialColumnPixelWidths.reduce(function (result, it, i) { return i <= handleBarElement._edgeIndex ? (result + it) : result; }, 0);

		setGridTemplateColumns(element, initialColumnWidths, handleBarElement._edgeIndex, edgeDelta);
		element._setUserSettingProc(element.style.gridTemplateColumns);
	}
}

export function handleGridResizableColumnEdgesMouseDownEvent(eventArgs: MouseEvent) {
	eventArgs.preventDefault();
	const handleBarElement: HTMLElement = eventArgs.target;
	const element: HTMLElement = handleBarElement.parentElement;
	handleBarElement._shouldProcessDoubleClick = true;

	const initialX = eventArgs.clientX;
	const initialColumnWidths = window.getComputedStyle(element).getPropertyValue('grid-template-columns');

	const processDrag = function (eventArgs) {
		eventArgs.preventDefault();

		const delta = eventArgs.clientX - initialX;
		if (delta !== 0) {
			setGridTemplateColumns(element, initialColumnWidths, handleBarElement._edgeIndex, eventArgs.clientX - initialX);
			handleBarElement._shouldProcessDoubleClick = false;
		}
	};

	const endDrag = function (eventArgs) {
		eventArgs.preventDefault();
		element._setUserSettingProc(element.style.gridTemplateColumns);

		SC.event.removeHandler(window, 'mousemove', processDrag);
		SC.event.removeHandler(window, 'mouseup', endDrag);
	};

	SC.event.addHandler(window, 'mouseup', endDrag);
	SC.event.addHandler(window, 'mousemove', processDrag);
}

export function initializeExtendedCss(
	element: HTMLElement,
	getUserSettingValueFunc: (elementKey: string, settingKey: string) => string | null,
	setUserSettingValueProc: (elementKey: string, settingKey: string, settingValue: string | null) => void
) {
	const propertyProcessors = {
		// re-called whenever css property `--grid-resizable-column-edges` may have changed
		'grid-resizable-column-edges': function (element: HTMLElement, propertyValue: string) {
			const initialResizeHandleBarElements = $$(element, ':scope > .ResizeHandleBar');

			if (propertyValue === 'none') {
				element.style.removeProperty('grid-template-columns');
				initialResizeHandleBarElements.forEach(SC.ui.discardElement);
			} else {
				const propertyValueParts = propertyValue.trim().split('/').map(function (it) { return it.trim(); });
				const elementKey = propertyValueParts[0];
				const rawColumnEdgeGroups = propertyValueParts[1].split(',')

				for (let i = rawColumnEdgeGroups.length; i < initialResizeHandleBarElements.length; i++)
					SC.ui.discardElement(initialResizeHandleBarElements[i]);

				for (let i = 0; i < rawColumnEdgeGroups.length; i++) {
					const parts = rawColumnEdgeGroups[i].trim().split(' ').map(function (it) { return it.trim(); });
					const columnEdgeGroup = {
						columnIndex: parseInt(parts[0]),
						minColumnWidthPixels: parseFloat(parts[1].slice(0, -2)), // remove 'px', the only supported unit since we'd have to resolve other units to pixels for javascript
						isEdgeStartOrEnd: parts[2] === 'start',
						handleLeftOffset: parts[3],
						handleRightOffset: parts[4],
					};

					let handleBarElement = initialResizeHandleBarElements[i];
					if (!handleBarElement)
						element.appendChild(handleBarElement = $div({
							className: 'ResizeHandleBar',
							style: 'position: absolute; -ms-touch-action: none; touch-action: none; z-index: 100; cursor: ew-resize; top: 0; height: 100%;',
						}));

					handleBarElement._edgeIndex = columnEdgeGroup.columnIndex - (columnEdgeGroup.isEdgeStartOrEnd ? 1 : 0);
					handleBarElement._handleLeftOffset = columnEdgeGroup.handleLeftOffset || '-5px';
					handleBarElement._handleRightOffset = columnEdgeGroup.handleRightOffset || '5px';
					handleBarElement._leftColumnMinWidthPixels = !columnEdgeGroup.isEdgeStartOrEnd && columnEdgeGroup.minColumnWidthPixels || 40;
					handleBarElement._rightColumnMinWidthPixels = columnEdgeGroup.isEdgeStartOrEnd && columnEdgeGroup.minColumnWidthPixels || 40;

					// addEventListener will only add these non-capturing named functions once to a given element, so they're safe to "add" multiple times
					SC.event.addHandler(handleBarElement, 'mousedown', handleGridResizableColumnEdgesMouseDownEvent);
					SC.event.addHandler(handleBarElement, 'dblclick', handleGridResizableColumnEdgesDoubleClickEvent);
				}

				element._setUserSettingProc = function (value) { setUserSettingValueProc(elementKey, 'grid-resizable-column-edges', value); }
				setGridTemplateColumns(element, getUserSettingValueFunc(elementKey, 'grid-resizable-column-edges'));
			}
		},
	};

	var processProc = function () {
		var computedStyle = tryGetComputedStyle(element);
		propertyProcessors.forEachKeyValue(function (propertyName, handler) {
			var newPropertyValue = tryGetExtendedCssValue(computedStyle, propertyName);
			handler(element, newPropertyValue);
		});
	}

	// HACK needed because our computed styles are based on media queries that depend on window size
	// and HACK because since we support querying settings, we allow the idea that those settings can change on things, so if the URL has changes, we process that
	// so this works ... and anything else around this idea where we could need to reprocess should be handled similarly
	SC.event.addHandler(window, 'resize', processProc);
	SC.event.addHandler(window, 'hashchange', processProc);

	processProc();
}
