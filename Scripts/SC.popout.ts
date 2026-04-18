// @ts-nocheck

import type { CommandButtonCreateOptions } from './SC.command';

export function getPanel() {
	return $('popoutPanel');
};

export function hidePanel() {
	var popoutPanel = getPanel();

	if (!popoutPanel)
		return false;

	SC.ui.discardElement(popoutPanel);
	return true;
};

export function togglePanel(popoutFrom, buildProc, showProc, stayOpenOnExecuteCommand) {
	if (!hidePanel()) {
		var popoutPanel = SC.ui.addElement(document.body, 'DIV', { id: 'popoutPanel', className: 'PopoutPanel' });

		SC.event.addHandler(popoutPanel, SC.event.ExecuteCommand, function (eventArgs) {
			if (popoutFrom && popoutFrom.tagName) {
				SC.command.dispatchExecuteCommand(popoutFrom, eventArgs.clickedElement, popoutFrom, eventArgs.commandName, eventArgs.commandArgument, eventArgs.isAdvanced, eventArgs.isIntense);
				eventArgs.stopPropagation();
			}

			if (!stayOpenOnExecuteCommand)
				SC.ui.discardElement(popoutPanel);
		});

		buildProc(popoutPanel);

		var popoutPanelBounds = popoutPanel.getBoundingClientRect();
		var scrollTop = document.body.scrollTop || document.documentElement.scrollTop;
		var scrollLeft = document.body.scrollLeft || document.documentElement.scrollLeft;

		if (popoutFrom.nodeType == document.body.ELEMENT_NODE) {
			var popoutFromBounds = popoutFrom.getBoundingClientRect();
			var popoutFromDirection = SC.css.tryGetExtendedCssValueFromElement(popoutFrom, 'popout-from');
			var popoutFromAbsoluteBounds = SC.ui.getAbsoluteBounds(popoutFrom);

			if (popoutFromDirection == 'right-down') {
				SC.ui.setLocation(popoutPanel, popoutFromAbsoluteBounds.right, popoutFromAbsoluteBounds.top);
				SC.css.ensureClass(popoutPanel, 'PopoutFromRightDown', true);
			} else if (popoutFromDirection == 'right-up') {
				SC.ui.setLocation(popoutPanel, popoutFromAbsoluteBounds.right, popoutFromAbsoluteBounds.bottom - popoutPanelBounds.height);
				SC.css.ensureClass(popoutPanel, 'PopoutFromRightUp', true);
			} else if (popoutFromDirection == 'down-left' || popoutFromBounds.left + popoutPanel.offsetWidth > document.body.offsetWidth) {
				SC.ui.setLocation(popoutPanel, popoutFromAbsoluteBounds.right - popoutPanelBounds.width, popoutFromAbsoluteBounds.bottom);
				SC.css.ensureClass(popoutPanel, 'PopoutFromDownLeft', true);
			} else if (popoutFromDirection == 'up-right' || popoutFromBounds.bottom + popoutPanel.offsetHeight > document.body.offsetHeight) {
				SC.ui.setLocation(popoutPanel, popoutFromAbsoluteBounds.left, popoutFromAbsoluteBounds.top - popoutPanelBounds.height);
				SC.css.ensureClass(popoutPanel, 'PopoutFromUpRight', true);
			} else { // down-right
				SC.ui.setLocation(popoutPanel, popoutFromAbsoluteBounds.left, popoutFromAbsoluteBounds.bottom);
				SC.css.ensureClass(popoutPanel, 'PopoutFromDownRight', true);
			}
		} else if (popoutFrom.x != undefined && popoutFrom.y != undefined) {
			var classNameForDirection = 'PopoutFrom';

			if (popoutFrom.y + popoutPanelBounds.height > document.body.offsetHeight) {
				classNameForDirection += 'Up';
				popoutPanel.style.top = (popoutFrom.y - popoutPanelBounds.height) + 'px';
			} else {
				classNameForDirection += 'Down';
				popoutPanel.style.top = popoutFrom.y + 'px';
			}

			if (popoutFrom.x + popoutPanelBounds.width > document.body.offsetWidth) {
				classNameForDirection += 'Left';
				popoutPanel.style.left = (popoutFrom.x - popoutPanelBounds.width) + 'px';
			} else {
				classNameForDirection += 'Right';
				popoutPanel.style.left = popoutFrom.x + 'px';
			}

			SC.css.ensureClass(popoutPanel, classNameForDirection, true);
		}

		var modifiedPopoutPanelBounds = popoutPanel.getBoundingClientRect();
		var popoutPanelMargin = 8;

		var innerMarginBottom = window.innerHeight - popoutPanelMargin;
		if (popoutPanelBounds.height > window.innerHeight - 2 * popoutPanelMargin) {
			popoutPanel.style.top = popoutPanelMargin + 'px';
			popoutPanel.style.bottom = popoutPanelMargin + 'px';
		}
		else if (modifiedPopoutPanelBounds.bottom > innerMarginBottom) {
			popoutPanel.style.top = modifiedPopoutPanelBounds.top - (modifiedPopoutPanelBounds.bottom - innerMarginBottom) + 'px';
		}
		else if (modifiedPopoutPanelBounds.top < popoutPanelMargin) {
			popoutPanel.style.top = popoutPanelMargin + 'px';
		}

		var innerMarginRight = window.innerWidth - popoutPanelMargin;
		if (popoutPanelBounds.width > window.innerWidth - 2 * popoutPanelMargin) {
			popoutPanel.style.left = popoutPanelMargin + 'px';
			popoutPanel.style.right = popoutPanelMargin + 'px';
		}
		else if (modifiedPopoutPanelBounds.right > innerMarginRight) {
			popoutPanel.style.left = modifiedPopoutPanelBounds.left - (modifiedPopoutPanelBounds.right - innerMarginRight) + 'px';
		}
		else if (modifiedPopoutPanelBounds.left < popoutPanelMargin) {
			popoutPanel.style.left = popoutPanelMargin + 'px';
		}

		SC.css.runElementAnimation(popoutPanel, 'PopoutScaleUp');

		var bodyHandler = function (eventArgs) {
			var element = SC.event.getElement(eventArgs);

			if (SC.ui.findAncestor(element, function (e) { return e == popoutPanel || e == popoutFrom; }) == null) {
				SC.event.removeHandler(document.body, 'touchstart', bodyHandler);
				SC.event.removeHandler(document.body, 'mousedown', bodyHandler);
				SC.ui.discardElement(popoutPanel);
			}
		};

		SC.ui.pushEscapeKeyHandler(hidePanel);

		var popoutHandler = function (eventArgs) {
			eventArgs.stopPropagation();
		};

		if (SC.util.isTouchEnabled()) {
			SC.event.addHandler(document.body, 'touchstart', bodyHandler);
			SC.event.addHandler(popoutPanel, 'touchstart', popoutHandler);
		}

		SC.event.addHandler(document.body, 'mousedown', bodyHandler);
		SC.event.addHandler(popoutPanel, 'mousedown', popoutHandler);

		if (showProc)
			showProc(popoutPanel);
	}
}

export function computePopoutCommandsVisible(baseEventArgs, subAreas) {
	var element = SC.event.getElement(baseEventArgs);

	return (subAreas ? subAreas : [''])
		.flatMap(function (subArea) { return SC.command.queryCommandButtons(baseEventArgs.commandName + subArea + 'PopoutPanel'); })
		.filter(function (cb) { return SC.command.queryCommandButtonState(element, cb.commandName, cb.commandArgument, baseEventArgs.commandContext).isVisible; })
		.length !== 0;
}

export function showPanelFromCommand(
	baseEventArgs,
	commandContext,
	options: {
		subAreas?: string[];
		buildProc?: (popoutPanel: HTMLElement) => void;
		getCreateOptionsFunc?: (subArea: string) => CommandButtonCreateOptions;
	} | null
) {
	options = options || {};
	togglePanel(baseEventArgs.commandElement, function (popoutPanel) {
		SC.css.ensureClass(popoutPanel, baseEventArgs.commandName + 'Popout', true);

		if (options.buildProc != null)
			options.buildProc(popoutPanel);
		else
			SC.ui.setContents(popoutPanel, (options.subAreas ? options.subAreas : ['']).map(function(subArea) {
				let createOptions = options.getCreateOptionsFunc != null ? options.getCreateOptionsFunc(subArea) : undefined;
				let buttons = SC.command.queryAndCreateCommandButtons(baseEventArgs.commandName + subArea + 'PopoutPanel', commandContext, createOptions);
				return $div({ className: 'CommandList' + (subArea ? ' ' + subArea : '')}, buttons);
			}));

		SC.command.updateCommandButtonsState(popoutPanel, commandContext);
	});
}

export function showConfirmationDialog(popoutFrom, message, yesText, noText, yesProc, noProc) {
	hidePanel();
	togglePanel(
		popoutFrom,
		function (popoutPanel) {
			SC.event.addHandler(popoutPanel, SC.event.ExecuteCommand, function (eventArgs) {
				switch (eventArgs.commandName) {
					case 'YesConfirmation':
						if (yesProc) yesProc();
						break;
					case 'NoConfirmation':
						if (noProc) noProc();
						break;
				}
			});

			SC.css.ensureClass(popoutPanel, 'ConfirmationDialog', true);

			SC.ui.setContents(popoutPanel, [
				$p(message),
				$div({ className: 'ButtonPanel' }, [
					$input({ type: 'button', _commandName: 'NoConfirmation', value: noText }),
					$input({ type: 'button', _commandName: 'YesConfirmation', value: yesText }),
				])
			]);
		}
	);
}
