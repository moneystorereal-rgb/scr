// @ts-nocheck

export function queryCommandButtons(area, commandContext) {
	return SC.event.dispatchGlobalEvent(SC.event.QueryCommandButtons, { area: area, commandContext: commandContext, buttonDefinitions: [] }).buttonDefinitions
}

export function queryAndCreateCommandButtons(area, commandContext, createOptions) {
	var buttonDefinitions = queryCommandButtons(area, commandContext);
	return createCommandButtons(buttonDefinitions, createOptions);
}

export function queryAndAddCommandButtons(container, area, commandContext, createOptions) {
	queryAndCreateCommandButtons(area, commandContext, createOptions).forEach(function (it) { SC.ui.addContent(container, it); });
}

export const DescriptionRenderStyle = { Title: 0, Tooltip: 1, Element: 2 };

export interface CommandButtonDefinition {
	commandName: string;
	commandArgument?: unknown;
	text?: string;
	description?: string;
	imageUrl?: string;
	_dataItem?: unknown;
	/** @deprecated only here for extension backwards compatibility */
	className?: string;
}

export interface CommandButtonCreateOptions {
	tagName?: keyof HTMLElementTagNameMap;
	descriptionRenderStyle?: number;
}

export function createCommandButtons(
	buttonDefinitions: CommandButtonDefinition[],
	createOptions: CommandButtonCreateOptions | undefined
) {
	var resolvedCreateOptions = {
		tagName: (createOptions && createOptions.tagName) || 'A',
		descriptionRenderStyle: createOptions && createOptions.descriptionRenderStyle !== undefined ? createOptions.descriptionRenderStyle : DescriptionRenderStyle.Title,
	};
	
	return buttonDefinitions
		.filter(Boolean)
		.map(function (bd) {
			var text = bd.text
				|| (typeof bd.commandArgument === 'string' && SC.res['Command.' + bd.commandName + bd.commandArgument + '.Text'])
				|| SC.res['Command.' + bd.commandName + '.Text']
				|| '';

			var description = bd.description
				|| (typeof bd.commandArgument === 'string' && SC.res['Command.' + bd.commandName + bd.commandArgument + '.Description'])
				|| SC.res['Command.' + bd.commandName + '.Description']
				|| '';

			 var buttonClassNameMap = {};
			 buttonClassNameMap[bd.commandName] = true;
			 if (typeof bd.commandArgument === 'string') {
				buttonClassNameMap[bd.commandName + bd.commandArgument] = true;
				buttonClassNameMap[bd.commandArgument] = true;
			 }
			 if (typeof bd.className === 'string') {
			 	buttonClassNameMap[bd.className] = true; // backwards compatibility
			 }

			 buttonClassNameMap.HasImage = !!bd.imageUrl;
			 buttonClassNameMap.HasText = !!text;
			 buttonClassNameMap.HasDescription = !!description;

			var button = SC.ui.createElement(resolvedCreateOptions.tagName, {
				_commandName: bd.commandName,
				_commandArgument: bd.commandArgument,
				_dataItem: bd._dataItem,
				onmouseenter: resolvedCreateOptions.descriptionRenderStyle === DescriptionRenderStyle.Tooltip ? function () { SC.tooltip.showPanel(this, text); } : null,
				onmouseleave: resolvedCreateOptions.descriptionRenderStyle === DescriptionRenderStyle.Tooltip ? function () { SC.tooltip.hidePanel(); } : null,
				title: resolvedCreateOptions.descriptionRenderStyle === DescriptionRenderStyle.Title ? description : '',
				_classNameMap: buttonClassNameMap,
				_updateText: function (newText) {
					if (resolvedCreateOptions.descriptionRenderStyle === DescriptionRenderStyle.Title)
						button.title = newText;

					if (!button.querySelector('SPAN'))
						SC.ui.addElement(button, 'SPAN', newText);
					else
						SC.ui.setInnerText(button.querySelector('SPAN'), newText);
				},
			}, [
				bd.imageUrl && $img({ src: bd.imageUrl, alt: text }),
				text && $span(text),
				description && resolvedCreateOptions.descriptionRenderStyle === DescriptionRenderStyle.Element && $p(description),
			]);

			return button;
		});
}

export function getDataElements(element: HTMLElement) {
	var dataElements = [];
	SC.ui.findAncestor(element, function (e) { if (e._dataItem != undefined) dataElements.push(e); });
	return dataElements;
}

export function getDataElement(element: HTMLElement) {
	return SC.ui.findAncestor(element, function (e) { return e._dataItem != undefined });
}

export function getDataItems(element: HTMLElement) {
	return getDataElements(element).map(function (e) { return e._dataItem; });
}

export function getDataItem(element: HTMLElement) {
	var dataElement = getDataElement(element);
	return dataElement == null ? null : dataElement._dataItem;
}

export function getEventDataElements(eventArgs) {
	return getDataElements(eventArgs.commandElement);
}

export function getEventDataElement(eventArgs) {
	return getDataElement(eventArgs.commandElement);
}

export function getEventDataItem(eventArgs) {
	return getDataItem(eventArgs.commandElement);
}

export function getEventDataItems(eventArgs) {
	return getDataItems(eventArgs.commandElement);
}

export function queryCommandButtonState(targetElement, commandName, commandArgument, commandContext) {
	var properties = { commandElement: targetElement, commandName: commandName, commandArgument: commandArgument, commandContext: commandContext, isVisible: null, isEnabled: null };
	var eventArgs = SC.event.dispatchEvent(targetElement, SC.event.QueryCommandButtonState, properties);

	return {
		allowsUrlExecution: eventArgs.allowsUrlExecution === true,
		isVisible: eventArgs.isVisible === null || eventArgs.isVisible === true,
		isEnabled: eventArgs.isEnabled === null || eventArgs.isEnabled === true,
	};
}

export function updateCommandButtonsState(container, commandContext) {
	var parentsWithCommandChildrenVisibility: [HTMLElement, boolean][] = [];

	SC.ui.findDescendantBreadthFirst(container, function (e) {
		if (e._commandName) {
			var commandButtonState = queryCommandButtonState(e, e._commandName, e._commandArgument, commandContext);

			SC.ui.setVisible(e, commandButtonState.isVisible);

			if (commandButtonState.isVisible)
				SC.ui.setDisabled(e, !commandButtonState.isEnabled);

			if (!parentsWithCommandChildrenVisibility.length || parentsWithCommandChildrenVisibility[parentsWithCommandChildrenVisibility.length - 1][0] !== e.parentElement)
				parentsWithCommandChildrenVisibility.push([e.parentElement, commandButtonState.isVisible]);
			else
				parentsWithCommandChildrenVisibility[parentsWithCommandChildrenVisibility.length - 1][1] = parentsWithCommandChildrenVisibility[parentsWithCommandChildrenVisibility.length - 1][1] || commandButtonState.isVisible;
		}
	});
	
	parentsWithCommandChildrenVisibility.forEach(function (it) {
		SC.css.ensureClass(it[0], 'AllCommandChildrenInvisible', !it[1]);
	});
}

export function doesChangeDispatch(element: HTMLInputElement) {
	return element.tagName === 'SELECT'
		|| (element.tagName === 'INPUT' && element.type === 'checkbox');
}

export function doesClickDispatch(element: HTMLInputElement) {
	return element.tagName !== 'TEXTAREA'
		&& element.tagName !== 'SELECT'
		&& element.tagName !== 'FORM'
		&& (element.tagName !== 'INPUT' || element.type === 'button' || element.type === 'submit');
}

export function doesInputDispatch(element: HTMLInputElement) {
	return element.tagName === 'INPUT'
		&& (element.type === 'number' || (element.type === 'text' && element.pattern));
}

export function doesEnterKeyDispatch(element: HTMLInputElement) {
	return element.tagName !== 'FORM';
}

export function doesSubmitDispatch(element: HTMLInputElement) {
	return element.tagName === 'FORM';
}

export function dispatchExecuteCommand(element: HTMLElement | null, clickedElement: HTMLElement, commandElement: HTMLElement, commandName, commandArgument, isAdvanced, isIntense) {
	SC.event.dispatchEvent(element, SC.event.ExecuteCommand, {
		clickedElement: clickedElement,
		commandElement: commandElement,
		commandName: commandName,
		commandArgument: commandArgument,
		isAdvanced: isAdvanced,
		isIntense: isIntense,
	});
}

export function dispatchGlobalExecuteCommand(commandName, commandArgument, isAdvanced, isIntense) {
	dispatchExecuteCommand(null, window.document.body, window.document.body, commandName, commandArgument, isAdvanced, isIntense);
}

export function addCommandDispatcher(element) {
	var dispatchCommandProc = function (eventArgs, isIntense: boolean, clickedElement?: HTMLElement) {
		dispatchExecuteCommand(
			element,
			clickedElement || SC.event.getElement(eventArgs),
			element,
			element._commandName,
			element._commandArgument,
			eventArgs.shiftKey,
			isIntense
		);
	}

	if (doesEnterKeyDispatch(element))
		SC.event.addHandler(element, 'keydown', function (eventArgs) {
			if (SC.event.isEnterKey(eventArgs) && !eventArgs.shiftKey) {
				dispatchCommandProc(eventArgs, false);
				eventArgs.preventDefault();
				eventArgs.stopImmediatePropagation();
			}
		});

	if (doesChangeDispatch(element))
		SC.event.addHandler(element, 'change', function (eventArgs) {
			dispatchCommandProc(eventArgs, false);
			eventArgs.preventDefault();
			eventArgs.stopImmediatePropagation();
		});

	if (doesInputDispatch(element)) {
		SC.event.addHandler(element, 'input', function (eventArgs) {
			dispatchCommandProc(eventArgs, false);
			eventArgs.preventDefault();
			eventArgs.stopImmediatePropagation();
		});
	}

	if (doesSubmitDispatch(element)) {
		SC.event.addHandler(element, 'submit', function (eventArgs) {
			// NOTE: As of 2020, submitter isn't supported on Safari or Android Firefox, so on those, clickedElement will end up being the form element
			dispatchCommandProc(eventArgs, false, eventArgs.submitter);
			eventArgs.preventDefault();
			eventArgs.stopImmediatePropagation();
		});
	}

	if (doesClickDispatch(element)) {
		var updateCommandCoordinatesProc = function (eventArgs) {
			window._commandCoordinates = { x: eventArgs.clientX, y: eventArgs.clientY };
		};

		var isNearCommandCoordinatesFunc = function (eventArgs) {
			return window._commandCoordinates && Math.sqrt(Math.pow(Math.abs(window._commandCoordinates.x - eventArgs.clientX), 2) + Math.pow(Math.abs(window._commandCoordinates.y - eventArgs.clientY), 2)) < 10;
		};

		var downProc = function (eventArgs, activeClassName, intensiveActiveClassName) {
			if (window._cancelActiveProc) {
				if (!SC.css.containsClass(element, activeClassName))
					window._cancelActiveProc();

				window.clearTimeout(window._cancelActiveTimeout);
				window._cancelActiveProc = undefined;
			}

			var isDisabled = SC.ui.isDisabled(element);
			SC.css.ensureClass(element, activeClassName, !isDisabled);

			if (!isNearCommandCoordinatesFunc(eventArgs))
				SC.css.ensureClass(element, intensiveActiveClassName, false);

			updateCommandCoordinatesProc(eventArgs);
		};

		var upProc = function (eventArgs, activeClassName, intensiveActiveClassName) {
			if (SC.css.containsClass(element, activeClassName)) {
				if (isNearCommandCoordinatesFunc(eventArgs)) {
					dispatchCommandProc(eventArgs, SC.css.containsClass(element, intensiveActiveClassName));

					updateCommandCoordinatesProc(eventArgs);

					SC.css.ensureClass(element, intensiveActiveClassName, true);

					window._cancelActiveProc = function () {
						SC.css.ensureClass(element, intensiveActiveClassName, false);
						SC.css.ensureClass(element, activeClassName, false);
					};

					window._cancelActiveTimeout = window.setTimeout(function () {
						if (window._cancelActiveProc) {
							window._cancelActiveProc();
							window._cancelActiveProc = undefined;
						}
					}, 250);

					return true;
				} else {
					SC.css.ensureClass(element, intensiveActiveClassName, false);
					SC.css.ensureClass(element, activeClassName, false);
				}
			}

			return false;
		};

		SC.event.addHandler(element, 'mousedown', function (eventArgs) {
			if (SC.event.isLeftButton(eventArgs) && (!window._lastTouchEndMillis || window._lastTouchEndMillis < SC.util.getMillisecondCount() - 1000))
				downProc(eventArgs, 'ClickActive', 'ClickIntenseActive');
		});

		SC.event.addHandler(element, 'mouseup', function (eventArgs) {
			if (SC.event.isLeftButton(eventArgs) && (!window._lastTouchStartMillis || window._lastTouchStartMillis < SC.util.getMillisecondCount() - 1000)) {
				if (upProc(eventArgs, 'ClickActive', 'ClickIntenseActive')) {
					eventArgs.stopPropagation();
				}
			}
		});

		if (SC.util.isTouchEnabled()) {
			SC.event.addHandler(element, 'touchstart', function (eventArgs) {
				window._lastTouchStartMillis = SC.util.getMillisecondCount();
				downProc(eventArgs.changedTouches[0], 'TouchActive', 'TouchIntenseActive');
			});

			SC.event.addHandler(element, 'touchend', function (eventArgs) {
				window._lastTouchEndMillis = SC.util.getMillisecondCount();

				if (upProc(eventArgs.changedTouches[0], 'TouchActive', 'TouchIntenseActive')) {
					eventArgs.preventDefault();
					eventArgs.stopPropagation();
				}
			});
		}

		SC.event.addHandler(element, 'click', function (eventArgs) {
			if (SC.event.isLeftButton(eventArgs)) {
				eventArgs.preventDefault();
				eventArgs.stopPropagation();
			}
		});
	}
}
