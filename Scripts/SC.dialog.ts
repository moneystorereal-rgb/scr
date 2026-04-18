export function showModalActivityAndReload(
	operationKey = '',
	shouldWaitForRestart = true,
	reloadUrl = window.location.href.substr(0, window.location.href.indexOf('#')) // If there is a hash, it would not reload
) {
	var showProc = function () {
		showModalActivityBox(SC.res['ActivityPanel.Title'], SC.res['ActivityPanel.' + (operationKey ?? '') + 'ReloadingMessage']);
	};

	if (document.readyState === 'complete')
		showProc();
	else
		SC.event.addHandler(window, 'load', showProc);

	var checkProc = function () {
		SC.service.NotifyActivity(
			function () { window.location.href = reloadUrl; },
			function (error) { window.setTimeout(checkProc, 1000); }
		);
	};

	window.setTimeout(checkProc, shouldWaitForRestart ? SC.context.restartCheckIntervalMilliseconds as number : (SC.util.isNullOrEmpty(operationKey) ? 500 : 1000));
}

export function showModalActivityBox(title, message) {
	return showModalDialog('ActivityBox', {
		title: title,
		content: $h2({ className: 'LoadingHeading' }, message),
	});
}

export function showModalPromptCommandBox(commandName, isDataTextBoxVisible, isDataMultiLine, completeProc, optionalSubCommand) {
	var buttonAndTitleText = SC.res['Command.' + commandName + '.ButtonText'] || SC.res['Command.' + commandName + '.Text'];
	var textBox;

	return showModalDialog('Prompt ' + commandName, {
		title: buttonAndTitleText,
		buttonText: buttonAndTitleText,
		shouldFocusOnButton: !isDataTextBoxVisible,
		shouldFocusOnFirstInputElement: isDataTextBoxVisible,
		content: [
			$div({ className: commandName + 'Image CommandImage' }),
			$p({ _innerHTMLToBeSanitized: SC.res['Command.' + commandName + optionalSubCommand + '.Message'] || SC.res['Command.' + commandName + '.Message'] }),
			isDataTextBoxVisible ? $p(textBox = SC.ui.createTextBox({ className: 'PromptTextBox', _commandName: 'Default' }, isDataMultiLine, false, SC.res['Command.' + commandName + '.PlaceholderText'])) : null,
		],
		onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
			var data = isDataTextBoxVisible ? dialog.querySelector<ReturnType<typeof SC.ui.createTextBox>>('.PromptTextBox')?.value.trim() : '';

			completeProc(
				data,
				closeDialogProc,
				function (error) {
					setDialogErrorProc(error);
					if (isDataTextBoxVisible)
						textBox.focus();
				}
			);
		},
	});
}

export function showModalErrorBox(message) {
	return showModalDialog('MessageBox', { titleResourceName: 'ErrorPanel.Title', content: $pre(message) });
}

export function showModalMessageBox(title, message) {
	return showModalDialog('MessageBox', { title: title, message: message });
}

export function showModalPage(title, url, onHideProc) {
	return showModalDialog('Page', {
		title: title,
		content: $iframe({ src: url }),
		onHideProc: onHideProc,
	});
}

export function showConfirmationDialog(subClassName, title, message, buttonText, executeProc) {
	return showModalDialog(subClassName, {
		title: title,
		message: message,
		buttonText: buttonText,
		onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
			executeProc(closeDialogProc, setDialogErrorProc);
		},
	});
};

export function showModalButtonDialog(subClassName, title, buttonText, buttonCommandName, contentBuilderProc, onExecuteCommandProc, onQueryCommandButtonStateProc, referenceBuilderProc) {
	return showModalDialog(subClassName, {
		title: title,
		buttonText: buttonText,
		buttonCommandName: buttonCommandName,
		contentBuilderProc: contentBuilderProc,
		onExecuteCommandProc: onExecuteCommandProc,
		onQueryCommandButtonStateProc: onQueryCommandButtonStateProc,
		referenceBuilderProc: referenceBuilderProc,
	});
}

export function showModalDialog(
	subClassName: string,
	parameters: {
		title?: string;
		titleResourceName?: string;
		message?: string;
		content?: unknown;
		noBackdrop?: boolean;
		buttonText?: string;
		buttonTextResourceName?: string;
		buttonCommandName?: string;
		buttonPanelExtraContent?: HTMLElement;
		referencePanelTextResourceName?: string;
		contentBuilderProc?: (contentPanel: HTMLElement) => void;
		onExecuteCommandProc?: (eventArgs: unknown, dialog: Dialog, closeDialogProc: () => void, setDialogErrorProc: (error?: Error) => void) => void;
		onQueryCommandButtonStateProc?: (eventArgs: unknown, dialog: Dialog) => void;
		onHideProc?: () => void;
		shouldFocusOnFirstInputElement?: boolean;
		shouldFocusOnButton?: boolean;
		initializeProc?: (dialog: Dialog) => void;
		classNameMap?: { [key: string]: boolean };
		referenceBuilderProc?: (referencePanel: HTMLElement) => void;
		suppressEscapeKeyHandling?: boolean;
	}
): Dialog {
	if (typeof parameters === 'string')
		parameters = { title: arguments[1], content: arguments[2] }; // for backwards compatibility

	var titlePanel = createTitlePanel(
		parameters.title || (parameters.titleResourceName ? SC.res[parameters.titleResourceName] : '')
	);

	var contentPanel = createContentPanel([
		parameters.message ? $p(parameters.message) : null,
		parameters.content,
	]);

	if (parameters.noBackdrop)
		subClassName += ' NoBackdrop';

	if (parameters.contentBuilderProc)
		parameters.contentBuilderProc(contentPanel);

	var buttonPanel = createButtonPanel();

	if (parameters.buttonText || parameters.buttonTextResourceName)
		SC.ui.addContent(buttonPanel, createButtonPanelButton(parameters.buttonText || SC.res[parameters.buttonTextResourceName!], parameters.buttonCommandName))

	if (parameters.buttonPanelExtraContent)
		SC.ui.addContent(buttonPanel, parameters.buttonPanelExtraContent);

	var referencePanel = createContentPanel(
		{ _classNameMap: { 'ReferenceContentPanel': true } },
		parameters.referencePanelTextResourceName && $div({ _htmlResource: parameters.referencePanelTextResourceName })
	);

	if (parameters.referenceBuilderProc)
		parameters.referenceBuilderProc(referencePanel)

	if (parameters.classNameMap)
		subClassName = subClassName + ' ' + SC.css.getClassNameStringFromMap(parameters.classNameMap);

	var dialog = showModalDialogRaw(
		subClassName,
		(parameters.referencePanelTextResourceName || parameters.referenceBuilderProc) ? [titlePanel, contentPanel, buttonPanel, referencePanel] : [titlePanel, contentPanel, buttonPanel],
		parameters.onExecuteCommandProc,
		parameters.onQueryCommandButtonStateProc,
		parameters.onHideProc,
		parameters.suppressEscapeKeyHandling
	);

	if (parameters.shouldFocusOnFirstInputElement)
		dialog.querySelector<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>('input, textarea, select')?.focus();

	if (parameters.shouldFocusOnButton)
		getButtonPanelButtons(buttonPanel)[0].focus();
	
	if (parameters.initializeProc)
		parameters.initializeProc(dialog);

	return dialog;
};

export type Dialog = HTMLDivElement;

type DialogContainer = HTMLDivElement & { _onHideProc: () => void };

export function showModalDialogRaw(
	subClassName: string,
	dialogPanels: HTMLElement[],
	onExecuteCommandProc?: (eventArgs: unknown, dialog: Dialog, closeDialogProc: () => void, setDialogErrorProc: (error?: Error, isStillProcessing?: boolean) => void) => void,
	onQueryCommandButtonStateProc?: (eventArgs: unknown, dialog: Dialog) => void,
	onHideProc?: () => void,
	suppressEscapeKeyHandling = false, // would be better if this wasn't necessary because escape would not close a dialog that has changes, but not ready for that yet
): Dialog {
	const existingModalDialogContainer = getModalDialog()?.parentElement;
	if (existingModalDialogContainer != null)
		SC.ui.discardElement(existingModalDialogContainer);

	const dialogContainer = SC.ui.addElement(document.body, 'div', { id: 'dialogContainer', _classNameMap: { DialogContainer: true, NoBackdrop: subClassName.split(' ').indexOf('NoBackdrop') > -1 } }) as DialogContainer;
	const dialog: Dialog = SC.ui.addElement(dialogContainer, 'div', { className: 'ModalDialog ' + subClassName });

	Array.prototype.forEach.call(dialogPanels, dialogPanel => dialogPanel && dialog.appendChild(dialogPanel));

	function setDialogBoundedLocation(left: number, top: number, dialogWidth: number) {
		SC.ui.setLocation(
			dialog,
			SC.util.getBoundedValue(200 - dialogWidth, left, window.innerWidth - 200),
			SC.util.getBoundedValue(0, top, window.innerHeight - 100)
		);
	}

	let hasFixedPosition = false;

	function onUserInteraction() {
		if (!hasFixedPosition) {
			// manually center the dialog (without messing up its slide-in animation) so its position is fixed so it doesn't jump around if its content changes size
			// but only fix position on initial user interaction because the content might get filled in asynchronously based on service calls
			const { width, height } = dialog.getBoundingClientRect();
			setDialogBoundedLocation((window.innerWidth - width) / 2, (window.innerHeight - height) / 2, width);
			hasFixedPosition = true;
		}
	}

	SC.event.addHandler(dialog, 'keydown', onUserInteraction);
	SC.event.addHandler(dialog, 'mousedown', function (eventArgs) {
		onUserInteraction();

		const element = SC.event.getElement(eventArgs);
		const commandElement = SC.ui.findAncestor(element, it => it._commandName != undefined);
		let originalState: { dialogRect: DOMRect; mouseDownLocation: { x: number; y: number } } | undefined;

		if (commandElement == null && SC.ui.findAncestor(element, it => SC.css.containsClass(it, 'TitlePanel')) != null) {
			originalState = {
				dialogRect: dialog.getBoundingClientRect(),
				mouseDownLocation: SC.event.getMouseLocation(eventArgs),
			};

			SC.event.addGlobalHandler('mousemove', onMouseMove, { capture: true });
			SC.event.addGlobalHandler(
				'mouseup',
				function (eventArgs) {
					originalState = undefined;
					document.removeEventListener('mousemove', onMouseMove, { capture: true });
					eventArgs.stopPropagation();
				},
				{ capture: true, once: true }
			);

			eventArgs.preventDefault();
		}

		function onMouseMove(eventArgs: MouseEvent) {
			if (originalState) {
				eventArgs.stopPropagation();

				const mouseLocation = SC.event.getMouseLocation(eventArgs);
				setDialogBoundedLocation(
					originalState.dialogRect.left + mouseLocation.x - originalState.mouseDownLocation.x,
					originalState.dialogRect.top + mouseLocation.y - originalState.mouseDownLocation.y,
					originalState.dialogRect.width
				);
			}
		}
	});

	if (!suppressEscapeKeyHandling)
		SC.ui.pushEscapeKeyHandler(() => SC.dialog.hideModalDialog(dialog));

	dialogContainer._onHideProc = () => onHideProc?.();

	SC.event.addHandler(dialog, SC.event.ExecuteCommand, function (eventArgs: any) {
		if (eventArgs.commandName == 'Close') {
			SC.dialog.hideModalDialog(dialog);
		}
		else if (onExecuteCommandProc) {
			SC.css.ensureClass(eventArgs.clickedElement, 'Loading', true);

			onExecuteCommandProc(
				eventArgs,
				dialog,
				() => SC.dialog.hideModalDialog(dialog),
				function (error, isStillProcessing) {
					const buttonPanel = getButtonPanel(dialog);
					if (buttonPanel)
						setButtonPanelError(buttonPanel, error);

					if (!isStillProcessing)
						SC.css.ensureClass(eventArgs.clickedElement, 'Loading', false);
				}
			);
		}
	});

	const buttonPanel = getButtonPanel(dialog);
	if (!buttonPanel || !buttonPanel.hasChildNodes())
		SC.css.ensureClass(dialog, 'ButtonPanelHidden', true);

	SC.event.addHandler(dialog, SC.event.QueryCommandButtonState, eventArgs => onQueryCommandButtonStateProc?.(eventArgs, dialog));

	// HACK HACK HACK for iOS fixed position bug
	if (SC.util.isCapable(SC.util.Caps.iOS)) {
		SC.ui.findDescendant<HTMLTextAreaElement | HTMLInputElement>(dialog, function (e) {
			if (e.tagName == 'TEXTAREA' || (e.tagName == 'INPUT' && e.type == 'text')) {
				SC.event.addHandler(e, 'blur', function (event) {
					document.body.scrollTop = 0;
				});
			}

			return false;
		});
	}

	return dialog;
}

export function hideButtonPanel(dialog = getModalDialog()) {
	if (dialog)
		SC.css.ensureClass(dialog, 'ButtonPanelHidden', true);
}

export function getModalDialog(): Dialog | null {
	return $('.ModalDialog') as Dialog | null;
}

export function hideModalDialog(dialog = getModalDialog()): void {
	const dialogContainer = dialog?.parentElement as DialogContainer | null;
	if (dialogContainer) {
		SC.css.ensureClass(dialogContainer, 'Hidden', true);
		dialogContainer._onHideProc();
	}
}

export function createTitlePanel(title: string) {
	var panel = $div({ className: 'TitlePanel' });
	SC.ui.addElement(panel, 'a', { _commandName: 'Close' }, '×');
	SC.ui.addElement(panel, 'h2', title);
	return panel;
}

export function createContentPanel(...varargs) {
	var panel = $div({ className: 'ContentPanel' });
	SC.ui.initializeElement(panel, arguments, 0);
	return panel;
}

export function createButtonPanel(defaultButtonText?: string, ...varargs) {
	var panel = $div({ className: 'ButtonPanel' });

	if (!SC.util.isNullOrEmpty(defaultButtonText))
		SC.ui.addContent(panel, createButtonPanelButton(defaultButtonText));

	SC.ui.initializeElement(panel, arguments, 1);

	return panel;
}

export function getButtonPanel(dialog = getModalDialog()): HTMLElement | null {
	return dialog?.querySelector('.ButtonPanel') ?? null;
}

export function createButtonPanelButton(text: string, commandName?: string) {
	return $input({ type: 'button', _commandName: commandName || 'Default', value: text });
}

export function getButtonPanelButton(buttonPanel: HTMLElement, commandName) {
	return Array.from(buttonPanel.querySelectorAll('INPUT[type=button]')).find(it => it._commandName === commandName);
}

export function getButtonPanelButtons(buttonPanel: HTMLElement) {
	return buttonPanel.querySelectorAll<HTMLInputElement>('INPUT[type=button]');
}

export function enableOrDisableButtonPanelButtons(buttonPanel: HTMLElement, enableOrDisable) {
	Array.from(getButtonPanelButtons(buttonPanel)).forEach(function (button) {
		SC.css.ensureClass(button, 'Disabled', !enableOrDisable);
	});
}

export function setButtonPanelError(buttonPanel: HTMLElement, error?: Error) {
	var errorParagraph = Array.prototype.find.call(buttonPanel.childNodes, function (n) { return n.className == 'Failure' });

	if (errorParagraph == null)
		errorParagraph = SC.ui.addElement(buttonPanel, 'p', { className: 'Failure' });

	SC.ui.setInnerText(errorParagraph, error?.message);
}
