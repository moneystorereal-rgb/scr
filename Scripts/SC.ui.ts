// @ts-nocheck

export function isVisible(element: HTMLElement) {
	return element.style.display != 'none';
}

export function setVisible(element: HTMLElement, visible: boolean) {
	element.style.display = (visible ? '' : 'none');
}

export function findNextSibling<E extends Element = Element>(element: Node, predicate: (element: E) => boolean): E | null {
	for (var e = element.nextSibling; e != null; e = e.nextSibling)
		if (predicate(e))
			return e;

	return null;
}

export function findAncestor<E extends Element = Element>(element: Node | null, predicate: (element: E) => boolean): E | null {
	while (element && !predicate(element))
		element = element.parentNode;

	return element;
}

export function findDescendant<E extends Element = Element>(element: Node | null, predicate: (element: E) => boolean): E | null {
	if (element == null) return null;
	for (var childNode = element.firstChild; childNode; childNode = childNode.nextSibling) {
		if (predicate(childNode))
			return childNode;

		var foundNode = findDescendant(childNode, predicate);

		if (foundNode != null)
			return foundNode;
	}

	return null;
}

/** @deprecated misspelled but used all over */
export const findDescendent = findDescendant;
/** @deprecated misspelled but used all over */
export const findDescendentByTag = findDescendantByTag;

export function findDescendantBreadthFirst<E extends Element = Element>(element: Element | null, predicate: (element: E) => boolean, shouldReverseSearch = false): E | null {
	if (!element)
		return null;

	var elementQueue = [element];

	while (elementQueue.length > 0) {
		var node = elementQueue.shift();
		if (node != element && predicate(node))
			return node;

		if (node.children)
			elementQueue = elementQueue.concat(shouldReverseSearch ? Array.from(node.children).reverse() : Array.from(node.children));
	}

	return null;
}

export function findAncestorByTag<E extends Element = Element>(element: Element | null, tagName: string) {
	return findAncestor<E>(element, function (e) { return e.tagName === tagName; });
}

export function findDescendantByTag<E extends Element = Element>(element: Element | null, tagName: string) {
	return findDescendant<E>(element, function (e) { return e.tagName === tagName; });
}

export function setText(element: HTMLElement, text: string, options?: { shouldSetTitle?: boolean }) {
	var shouldSetTitle = (options != undefined && options.shouldSetTitle != undefined) ? options.shouldSetTitle : true;

	setInnerText(element, text);
	if (shouldSetTitle) {
		element.title = text || '';
	}
}

export function setInnerText(element: HTMLElement, content: string | null | undefined) {
	clear(element);

	if (!SC.util.isNullOrEmpty(content)) {
		var textNode = element.ownerDocument.createTextNode(content);
		element.title = content;
		element.appendChild(textNode);
	}
}

export function sanitizeAndSetInnerHtml(element: HTMLElement, htmlContent: string) {
	element.innerHTML = SC.util.sanitizeHtml(htmlContent);
}

export function discardElement(element: HTMLElement) {
	var leakBin = document.getElementById('leakBin');

	if (!leakBin)
		leakBin = addElement(document.body, 'DIV', { id: 'leakBin', _visible: false });

	leakBin.appendChild(element);
	clear(leakBin);
}

export function clear(element: HTMLElement) {
	element.title = '';
	element.innerHTML = '';
}

export function createTextBox(properties: unknown, isMultiLine?: boolean, isPassword?: boolean, placeholderText?: string): HTMLInputElement | HTMLTextAreaElement {
	let element: HTMLInputElement | HTMLTextAreaElement;

	if (isMultiLine)
		element = createElement('TEXTAREA', properties);
	else if (isPassword)
		element = createElement('INPUT', SC.util.combineObjects(properties, { type: 'password' }));
	else
		element = createElement('INPUT', SC.util.combineObjects(properties, { type: 'text' }));

	if (!SC.util.isNullOrEmpty(placeholderText))
		element.placeholder = placeholderText;

	return element;
}

export function createTabs(subClassName, tabDefinitions) {
	var tabLinksPanel;
	var tabContentsPanel;
	var tabContainer = $div({ className: 'TabContainer ' + subClassName }, [
		tabLinksPanel = $div({ className: 'TabLinks' }, [
			tabDefinitions.map(function (tabDefinition) {
				return $div({ _commandName: 'SelectTab', _commandArgument: tabDefinition.name }, tabDefinition.link);
			}),
		]),
		tabContentsPanel = $div({ className: 'TabContents' }, [
			tabDefinitions.map(function (tabDefinition) {
				return $div({ _tabName: tabDefinition.name }, tabDefinition.content);
			}),
		]),
	]);

	setSelected(tabLinksPanel.firstChild, true);
	setSelected(tabContentsPanel.firstChild, true);

	SC.event.addHandler(tabContainer, SC.event.ExecuteCommand, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'SelectTab':
				Array.from(tabLinksPanel.childNodes).forEach(function (_) { setSelected(_, _._commandArgument == eventArgs.commandArgument); });
				Array.from(tabContentsPanel.childNodes).forEach(function (_) { setSelected(_, _._tabName == eventArgs.commandArgument); });
		}
	});

	return tabContainer;
}

export function createSearchTextBox(properties, searchHandler) {
	var searchTextBox = createElement('INPUT', properties);

	try {
		searchTextBox.setAttribute('type', 'search');
		searchTextBox.incremental = true;
	} catch (ex) { }

	if (searchHandler)
		SC.event.addHandler(searchTextBox, typeof searchTextBox.onsearch !== 'undefined' ? 'search' : 'keyup', function (eventArgs) {
			// ignore duplicate searches caused by enter/keyup/keydown/etc.
			if (searchTextBox.value != searchTextBox._previousSearchText) {
				searchTextBox._previousSearchText = searchTextBox.value;
				searchHandler(eventArgs);
			}
		});

	return searchTextBox;
}

export function createFilterBox(properties, filterHandler) {
	var searchTextBox = createSearchTextBox(properties, filterHandler);
	SC.css.addClass(searchTextBox, 'FilterBox');

	return searchTextBox;
}

export function createInputElement(properties) {
	try {
		return $input(properties);
	} catch (ex) {
		properties.type = 'text';
		return $input(properties);
	}
}

export function getAbsoluteBounds(element) {
	var clientRect = element.getBoundingClientRect();

	var scrollTop = element.ownerDocument.documentElement.scrollTop || element.ownerDocument.body.scrollTop;
	var scrollLeft = element.ownerDocument.documentElement.scrollLeft || element.ownerDocument.body.scrollLeft;

	return {
		top: Math.round(clientRect.top) + scrollTop,
		bottom: Math.round(clientRect.bottom) + scrollTop,
		left: Math.round(clientRect.left) + scrollLeft,
		right: Math.round(clientRect.right) + scrollLeft,
		horizontalCenter: Math.round(clientRect.left + scrollLeft + 0.5 * clientRect.width),
		verticalCenter: Math.round(clientRect.top + scrollTop + 0.5 * clientRect.height),
	};
}

export function getLocation(element: HTMLElement) {
	var absoluteBounds = getAbsoluteBounds(element);

	return {
		x: absoluteBounds.left,
		y: absoluteBounds.top,
	};
}

export function setLocation(element: HTMLElement, x: number, y: number) {
	element.style.position = 'absolute';
	element.style.left = x + 'px';
	element.style.top = y + 'px';
}

export function addCell(row, ...varargs) {
	var cell = row.insertCell(-1);
	initializeElement(cell, arguments, 1);
	return cell;
}

export function createElement<K extends keyof HTMLElementTagNameMap>(tagName: K, ...varargs): HTMLElementTagNameMap[K] {
	var element = document.createElement(tagName);
	initializeElement(element, arguments, 1);
	return element;
}

export function createElementInternal<K extends keyof HTMLElementTagNameMap>(tagName: K, originalArguments): HTMLElementTagNameMap[K] {
	var element = document.createElement(tagName);
	initializeElement(element, originalArguments, 0);
	return element;
}

export function addElement<K extends keyof HTMLElementTagNameMap>(container: HTMLElement, tagName: K, ...varargs): HTMLElementTagNameMap[K] {
	var element = document.createElement(tagName);
	initializeElement(element, arguments, 2);
	container.appendChild(element);
	return element;
}

export function initializeElement(element: HTMLElement, args: IArguments | unknown[], argsStartIndex: number) {
	for (var i = argsStartIndex; i < args.length; i++) {
		if (typeof args[i] === 'string' || (args[i] && args[i].tagName)) {
			addContent(element, args[i]);
		} else if (args[i] instanceof Array) {
			args[i].forEach(function (c) { addContent(element, c); });
		} else if (args[i])
			args[i].forEachKeyValue(function (key, value) {
				switch (key) {
					case '_visible':
						setVisible(element, value);
						break;
					case '_selected':
						setSelected(element, value);
						break;
					case '_cssText':
						element.style.cssText = value;
						break;
					case '_classNameMap':
						SC.css.addClass(element, SC.css.getClassNameStringFromMap(value));
						break;
					case '_innerText': // DEPRECATED give the text as an argument instead
						setInnerText(element, value);
						break;
					case '_textResource':
						setInnerText(element, SC.res[value]);
						break;
					case '_htmlResource':
						sanitizeAndSetInnerHtml(element, SC.res[value]);
						break;
					case 'innerHTML': // HACK DO NOT USE innerHTML - we're overriding default behavior to make older extensions safer
					case '_innerHTMLToBeSanitized': // ..use _innerHTMLToBeSanitized instead
						sanitizeAndSetInnerHtml(element, value);
						break;
					case '_innerHTMLAlreadySanitized':
						element.innerHTML = value;
						break;
					case '_eventHandlerMap':
						Object.keys(value).forEach(function (_) { SC.event.addHandler(element, _, value[_]); });
						break;
					case '_dataMap':
						if (element.dataset)
							Object.keys(value).forEach(function (_) { element.dataset[_] = value[_]; });
						break;
					case '_attributeMap':
						Object.keys(value).forEach(function (_) { element.setAttribute(_, value[_]); });
						break;
					case '_commandName':
						SC.command.addCommandDispatcher(element);
						element[key] = value;
						break;
					default:
						element[key] = value;
						break;
				}
			});
	}

	if (element.tagName == 'A' && !element.href)
		element.href = '#';
}

export function replaceElement(element: HTMLElement, newElement: HTMLElement) {
	element.parentNode.replaceChild(newElement, element);
}

export function setContents(container: HTMLElement, contents: Content) {
	clear(container);
	addContent(container, contents);
}

type Content = string | HTMLElement | Content[];

export function addContent(container: Node, content: Content) {
	if (typeof content == 'string')
		addTextNode(container, content);
	else if (content instanceof Array) {
		var fragment = document.createDocumentFragment();
		var flattenedContent = content.flat(99);

		for (var i = 0; i < flattenedContent.length; i++)
			addContent(fragment, flattenedContent[i]);

		container.appendChild(fragment);
	}
	else if (content)
		container.appendChild(content);
}

export function addBarGraph(container: Node, percentage: number) {
	return container.appendChild(createBarGraph(percentage));
}

export function createBarGraph(percentage: number) {
	return $div({ className: 'PercentageBar' }, [
		$div({ className: 'PercentageBarFilled', style: "width:" + percentage.toFixed(2) + "%; ", title: percentage.toFixed(2) + "%" }),
		$div({ className: 'PercentageBarEmpty', style: "width:" + (100 - percentage).toFixed(2) + "%;", title: (100 - percentage).toFixed(2) + "%" }),
	]);
}

export function createInfoIcon(tooltipText?: string) {
	return tooltipText ? $span({
		className: 'InfoIcon',
		onmouseenter: function () { SC.tooltip.showPanel(this, tooltipText); },
		onmouseleave: function () { SC.tooltip.hidePanel(); },
	}) : null;
}

export function addTextNode(container: Node, text: string) {
	var textNode = document.createTextNode(text);
	container.appendChild(textNode);
}

export function addNonBreakingSpace(container: Node) {
	addTextNode(container, '\u00a0');
}

export function createRadioButtonOption<K extends keyof HTMLElementTagNameMap>(tagName: K, labelContent, groupName: string, value: string, checked: boolean, enabled: boolean, extraElement?: HTMLElement): HTMLElementTagNameMap[K] {
	var id = groupName + value;
	var panel = createElement(tagName);

	var radioButtonTagName = 'input' as const;

	if (SC.util.isCapable(SC.util.Caps.InternetExplorer, null, { major: 8 })) // awful, awful
		radioButtonTagName = SC.util.formatString('<{0} name=\'{1}\' />', radioButtonTagName, groupName);

	var radioButton = addElement(panel, radioButtonTagName, { id: id, type: 'radio', value: value, name: groupName, checked: checked, disabled: !enabled });

	addNonBreakingSpace(panel);

	addElement(panel, 'LABEL', { htmlFor: enabled ? id : null }, labelContent);

	if (extraElement) {
		addNonBreakingSpace(panel);
		panel.appendChild(extraElement);

		SC.event.addHandler(extraElement, 'click', function () { radioButton.checked = true; });

		var extraInputElement = extraElement.querySelector<HTMLInputElement | HTMLTextAreaElement>('input:enabled, textarea:enabled');
		if (extraInputElement) {
			SC.event.addHandler(radioButton, 'click', function () {
				extraInputElement.focus();
				selectText(extraInputElement);
			});

			SC.event.addHandler(extraInputElement, 'focus', function () { radioButton.checked = true; });
		}
	}

	return panel;
}

export function getSelectedRadioButtonValue(container: Element) {
	var checkedRadioButton = findDescendant<HTMLInputElement>(container, function (e) { return e.type === 'radio' && e.checked; });
	return (checkedRadioButton == null ? null : checkedRadioButton.value);
}

export function createDefaultCustomSelector(isOverridenInitially, defaultElement, overrideElement, getOverrideValueFromElement) {
	var groupName = 'DefaultCustomSelector' + Math.random();
	return $div({ className: 'DefaultCustomSelector', _getOverrideValue: function () { return getOverrideValueFromElement(overrideElement); } }, [
		createRadioButtonOption('DIV', SC.res['DefaultCustomSelector.DefaultLabelText'], groupName, 'Default', !isOverridenInitially, true, $div(defaultElement)),
		createRadioButtonOption('DIV', SC.res['DefaultCustomSelector.CustomLabelText'], groupName, 'Override', isOverridenInitially, true, $div(overrideElement)),
	]);
}

export function getCustomValueFromDefaultCustomSelector(container: Element) {
	var input = container.querySelector('.DefaultCustomSelector');
	var radioButtonValue = getSelectedRadioButtonValue(container);
	return radioButtonValue === 'Default' || radioButtonValue == null ? null : input._getOverrideValue();
}

export function extractFormState(formElement: HTMLFormElement, options?: { shouldTrimInputValues?: boolean }): Record<string, unknown> {
	var defaultOptions = { shouldTrimInputValues: true };
	options = Object.assign({}, options, defaultOptions);

	return Array.from(formElement.elements)
		.filter(function (inputElement) { return inputElement.name; })
		.reduce(function (result, inputElement) {
			result[inputElement.name] = inputElement.type === 'checkbox'
				? inputElement.checked
				: (options.shouldTrimInputValues ? inputElement.value.trim() : inputElement.value);
			return result;
		}, {});
}

export function applyFormState(formElement: HTMLFormElement, formState: Record<string, unknown>) {
	Array.from(formElement.elements)
		.filter(function (inputElement) { return inputElement.name; })
		.forEach(function (inputElement) {
			var value = formState[inputElement.name];
			if (value !== undefined) {
				if (inputElement.type === 'checkbox')
					inputElement.checked = value;
				else
					inputElement.value = value;
			}
		});
}

export function moveNodeUp(node: Node) {
	var parentNode = node.parentNode;
	var nodeBefore = node.previousSibling;
	parentNode.removeChild(node);
	parentNode.insertBefore(node, nodeBefore);
}

export function moveNodeDown(node: Node) {
	var parentNode = node.parentNode;
	var nodeAfterAfter = node.nextSibling.nextSibling;
	parentNode.removeChild(node);

	if (nodeAfterAfter)
		parentNode.insertBefore(node, nodeAfterAfter);
	else
		parentNode.appendChild(node);
}

export function insertChild(parentElement: Element, childElement: Element, index: number) {
	var beforeElement = parentElement.childNodes[index];

	if (beforeElement)
		parentElement.insertBefore(childElement, beforeElement);
	else
		parentElement.appendChild(childElement);
}

export function removeChildAt(parentElement: Element, index: number) {
	parentElement.removeChild(parentElement.childNodes[index]);
}

export function refreshTableRowsWithNewData(table, dataArray, dataKeySelector, dataRowUpdater, dataRowUpdaterUserData, rowUserData) {
	var dataRow = table.rows[0];

	for (var i = 0; dataArray[i]; i++) {
		var dataKey = dataKeySelector(dataArray[i]);

		while (true) {
			if (!dataRow)
				return;

			if (dataKeySelector(dataRow._dataItem) == dataKey)
				break;

			dataRow = dataRow.nextSibling;
		}

		var oldDataItem = dataRow._dataItem;
		dataRow._dataItem = dataArray[i];
		dataRow._userData = rowUserData;
		dataRowUpdater(dataRow, oldDataItem, dataRow._dataItem, dataRow._userData, dataRowUpdaterUserData);
	}
}

export function refreshTableRowsWithExistingData(table, dataRowUpdater, dataRowUpdaterUserData) {
	for (var dataRow = table.rows[0]; dataRow; dataRow = dataRow.nextSibling)
		dataRowUpdater(dataRow, dataRow._dataItem, dataRow._dataItem, dataRow._userData, dataRowUpdaterUserData);
}

export function rebuildList<TData, TTransientUserData, TStoredUserData>(
	list: HTMLUListElement,
	dataArray: TData[],
	dataKeySelector: (dataItem: TData) => string,
	dataListItemCreator: (dataItem: TData, transientUserData: TTransientUserData) => HTMLElement,
	dataListItemUpdater: (element: HTMLElement, oldDataItem: TData, newDataItem: TData, storedUserData: TStoredUserData, transientUserData: TTransientUserData, shouldAttemptToPreserveElementsAtExpenseOfPerformance: boolean) => void,
	transientUserData: TTransientUserData,
	storedUserData: TStoredUserData,
	shouldAttemptToPreserveElementsAtExpenseOfPerformance: boolean
) {
	if (!dataArray) {
		clear(list);
		return;
	}

	if (list.childNodes.length > 0 && shouldAttemptToPreserveElementsAtExpenseOfPerformance) {
		var deletedListItems: Map<string, HTMLElement> = new Map();

		var index;
		for (index = 0; index < dataArray.length; index++) {
			var dataKey = dataKeySelector(dataArray[index]);
			var dataListItem: HTMLElement | null = null;

			for (var potentialDataListItemIndex = index; potentialDataListItemIndex < list.childNodes.length; potentialDataListItemIndex++) {
				var node = list.childNodes[potentialDataListItemIndex];
				if (node._dataItem && dataKeySelector(node._dataItem) === dataKey) {
					dataListItem = node;
					// backtrack to remove intermediate items
					for (var deletedListItemIndex = potentialDataListItemIndex - 1; deletedListItemIndex >= index; deletedListItemIndex--) {
						var deletedListItem = list.removeChild(list.childNodes[deletedListItemIndex]);
						var deletedListItemKey = deletedListItem._dataItem && dataKeySelector(deletedListItem._dataItem);
						if (deletedListItemKey)
							deletedListItems.set(deletedListItemKey, deletedListItem);
					}
					break;
				}
			}

			if (!dataListItem) {
				dataListItem = deletedListItems.get(dataKey) || dataListItemCreator(dataArray[index], transientUserData);
				list.insertBefore(dataListItem, list.childNodes[index]);
			}

			var oldDataItem = dataListItem._dataItem;
			dataListItem._dataItem = dataArray[index];
			dataListItem._userData = storedUserData;
			dataListItemUpdater(dataListItem, oldDataItem, dataListItem._dataItem, storedUserData, transientUserData, shouldAttemptToPreserveElementsAtExpenseOfPerformance);
		}

		// remove extra tail-end items
		while (list.childNodes[index])
			list.removeChild(list.childNodes[index]);
	} else {
		var newList = list.cloneNode(false);
		for (var i = 0; i < dataArray.length; i++) {
			var newListItem = dataListItemCreator(dataArray[i], transientUserData);
			newListItem._dataItem = dataArray[i];
			newListItem._userData = storedUserData;
			dataListItemUpdater(newListItem, newListItem._dataItem, newListItem._dataItem, storedUserData, transientUserData, shouldAttemptToPreserveElementsAtExpenseOfPerformance);
			newList.appendChild(newListItem);
		}

		replaceElement(list, newList);
	}
}

// to be deleted in SCP-36856
export function rebuildTable(table, dataArray, dataKeySelector, dataRowInitializer, dataRowUpdater, dataRowUpdaterUserData, rowUserData, shouldAttemptToPreserveElementsAtExpenseOfPerformance) {
	if (shouldAttemptToPreserveElementsAtExpenseOfPerformance) {
		var tableRowIndex = 0;
		var deletedTableRows = [];
		for (var dataIndex = 0; dataIndex < dataArray.length; dataIndex++) {
			var dataKey = dataKeySelector(dataArray[dataIndex]);
			var dataRow = null;
			var potentialDataRowIndex = tableRowIndex;

			while (potentialDataRowIndex < table.rows.length) {
				if (table.rows[potentialDataRowIndex]._dataItem && dataKeySelector(table.rows[potentialDataRowIndex]._dataItem) === dataKey) {
					dataRow = table.rows[potentialDataRowIndex];
					break;
				}

				potentialDataRowIndex++;
			}

			if (dataRow) {
				while (potentialDataRowIndex > tableRowIndex) {
					deletedTableRows.push(table.tBodies[0].removeChild(table.rows[potentialDataRowIndex - 1]));
					potentialDataRowIndex--;
				}
			} else {
				dataRow = deletedTableRows.find(function (it) { return it._dataItem && dataKeySelector(it._dataItem) === dataKey; });

				if (dataRow)
					table.tBodies[0].insertBefore(dataRow, table.rows[tableRowIndex]);
				else {
					dataRow = table.insertRow(tableRowIndex);
					dataRowInitializer(dataRow, dataArray[dataIndex]);
				}
			}

			tableRowIndex++;

			var oldDataItem = dataRow._dataItem;
			dataRow._dataItem = dataArray[dataIndex];
			dataRow._userData = rowUserData;
			dataRowUpdater(dataRow, oldDataItem, dataRow._dataItem, dataRow._userData, dataRowUpdaterUserData);
		}

		while (table.rows[tableRowIndex])
			table.deleteRow(tableRowIndex);
	}
	else {
		var newTbody = $tbody();
		var dataRow = table.rows[0];

		for (var dataIndex = 0; dataIndex < dataArray.length; dataIndex++) {
			dataRow = newTbody.insertRow(dataIndex);
			dataRowInitializer(dataRow, dataArray[dataIndex]);

			var oldDataItem = dataRow._dataItem;
			dataRow._dataItem = dataArray[dataIndex];
			dataRow._userData = rowUserData;
			dataRowUpdater(dataRow, oldDataItem, dataRow._dataItem, dataRow._userData, dataRowUpdaterUserData);
		}

		if (table.tBodies.length == 0) {
			table.appendChild(newTbody);
		}
		else {
			replaceElement(table.tBodies[0], newTbody);
		}
	}
}

export function scrollToBottom(element) {
	element.scrollTop = element.scrollHeight;
}

export function scrollToFarRight(element) {
	element.scrollLeft = element.scrollWidth;
}

export function createDataUri(varargs) {
	var base64Content = arguments[arguments.length == 2 ? 1 : 0];
	var explicitContentType = arguments.length == 2 ? arguments[0] : null;

	return 'data:' +
		(explicitContentType ||
			(!base64Content ? ''
				: base64Content.startsWith('/9j/4') ? 'image/jpeg'
					: base64Content.startsWith('iVBOR') ? 'image/png'
						: base64Content.startsWith('PHN2Z') ? 'image/svg+xml' // <svg
							: base64Content.startsWith('PD') ? 'image/svg+xml' // <?
								: base64Content.startsWith('77u/PHN2Z') ? 'image/svg+xml' // <svg with BOM
									: base64Content.startsWith('77u/PD') ? 'image/svg+xml' // <? with BOM
										: base64Content.startsWith('UEsDB') ? 'application/zip'
											: '')
		) +
		';base64,' +
		(base64Content || '');
}

export function extractBase64ContentFromImageDeclaration(imageDeclaration) {
	return /data:[^;]*;base64,(.*)/.exec(imageDeclaration)[1];
}

export function createSimpleImageElement(base64Content) {
	return $img({ src: createDataUri(base64Content) });
}

export function isInBody(element) {
	return findAncestor(element, function (e) { return e == document.body; }) != null;
};

export function setHiddenFocusAndClearOthers(element) {
	$$('.HiddenFocus').forEach(function (_) { SC.css.removeClass(_, 'HiddenFocus'); });
	if (element)
		SC.css.addClass(element, 'HiddenFocus');
}

export function setSelected(element, isSelected) {
	return SC.css.ensureClass(element, 'Selected', isSelected);
}

export function setChecked(element, isChecked) {
	return SC.css.ensureClass(element, 'Checked', isChecked);
}

export function setDisabled(element, isDisabled) {
	return SC.css.ensureClass(element, 'Disabled', isDisabled);
}

export function setDisabledAttribute(element, isDisabled) {
	if (isDisabled)
		element.setAttribute('disabled', '');
	else
		element.removeAttribute('disabled');
}

export function isSelected(element) {
	return SC.css.containsClass(element, 'Selected');
}

export function isChecked(element) {
	return SC.css.containsClass(element, 'Checked');
}

export function isDisabled(element) {
	return SC.css.containsClass(element, 'Disabled');
}

export function pushEscapeKeyHandler(handler) {
	if (!window._escapeKeyStack) {
		window._escapeKeyStack = [];

		SC.event.addGlobalHandler('keydown', function (eventArgs) {
			if (eventArgs.keyCode == 27) {
				while (true) {
					var lastHandler = window._escapeKeyStack.pop();

					if (!lastHandler || lastHandler())
						return;
				}
			}
		});
	}

	var existingIndex = window._escapeKeyStack.indexOf(handler);

	if (existingIndex != -1)
		window._escapeKeyStack.splice(existingIndex, 1);

	window._escapeKeyStack.push(handler);
}

export function initializeWindowActivityTracking(activityHandler) {
	if (!SC.util.isCapable(SC.util.Caps.InternetExplorer, null, { major: 9 })) {
		SC.event.addHandler(window, 'blur', function () { window._blurTime = new Date().getTime(); });
		SC.event.addHandler(window, 'focus', function () { window._blurTime = null; });
		SC.event.addHandler(window.document.body, 'mousemove', function () { if (isWindowActive()) activityHandler(); });
	}
}

export function isWindowActive() {
	return !window._blurTime || new Date().getTime() - window._blurTime < 600000;
}

export function isDefinitelyNotTextEntryElement(element: HTMLElement) {
	switch (element.tagName) {
		case 'BODY':
		case 'A':
		case 'TR':
		case 'UL':
		case 'DIV':
			return !element.isContentEditable;
		default:
			return false;
	}
}

export function createImageSelector(initialImageData, readOnly) {
	var imageDisplayPanel;
	var imageDropDestinationPanel;
	var fileChooser;

	var imageSelectorPanel = $div({ className: 'ImageSelector' }, [
		imageDisplayPanel = $div({ className: 'ImageDisplay' },
			initialImageData ? createSimpleImageElement(initialImageData) : $span({ _htmlResource: 'ImageSelector.NoImage.Message' })
		),
		$div({ className: 'ImageInput' }, [
			imageDropDestinationPanel = $div({ className: 'ImageDropDestination', _textResource: 'ImageSelector.DropDestination.Message' }),
			$p({ _textResource: 'ImageSelector.JoinOr.Message' }),
			fileChooser = $input({ type: 'file', accept: 'image/*' }),
		]),
	]);

	SC.css.ensureClass(imageSelectorPanel, 'ReadOnly', readOnly);

	if (!readOnly) {
		var addFileHandlerProc = function (element, eventName, getFileSource) {
			SC.event.addHandler(element, eventName, function (eventArgs) {
				eventArgs.stopPropagation();
				eventArgs.preventDefault();

				imageSelectorPanel.click(); // gives focus

				var file = getFileSource(eventArgs).files[0];
				if (file) {
					var reader = new FileReader();
					reader.onload = function (e) {
						setContents(imageDisplayPanel, $img({ src: reader.result }));
					};
					reader.readAsDataURL(file);
				}
			});
		};

		addFileHandlerProc(imageDropDestinationPanel, 'drop', function (eventArgs) { return eventArgs.dataTransfer; });
		addFileHandlerProc(fileChooser, 'change', function () { return fileChooser; });

		SC.event.addHandler(imageDropDestinationPanel, 'dragover', function (eventArgs) {
			eventArgs.stopPropagation();
			eventArgs.preventDefault();
			eventArgs.dataTransfer.dropEffect = 'copy';
		});
	}

	return imageSelectorPanel;
}

export function createEditableInput(commandName, properties, cancelBlur, onFocus, shouldDispatchCommandOnKeyUp) {
	var field = $input(SC.util.combineObjects({
		type: 'text',
		_commandName: 'BlurField',
		_eventHandlerMap: {
			focus: function (eventArgs) {
				eventArgs.target._startValue = eventArgs.target.value;
				if (onFocus) onFocus(eventArgs);
			},
			blur: function (eventArgs) {
				if (eventArgs.target._startValue != eventArgs.target.value)
					SC.command.dispatchExecuteCommand(eventArgs.target, eventArgs.target, eventArgs.target, commandName, eventArgs.target.value.trim());
				else if (cancelBlur)
					cancelBlur(eventArgs);

				SC.css.ensureClass(field, 'Editing', false);
			},
			keyup: function (eventArgs) {
				if (eventArgs.keyCode == 27) { // esc
					eventArgs.target.value = eventArgs.target._startValue;
					field.blur();
				}

				if (shouldDispatchCommandOnKeyUp && eventArgs.target._startValue != eventArgs.target.value)
					SC.command.dispatchExecuteCommand(eventArgs.target, eventArgs.target, eventArgs.target, commandName, eventArgs.target.value.trim());
			},
		},
	}, properties));

	SC.event.addHandler(field, SC.event.ExecuteCommand, function (eventArgs) {
		if (eventArgs.commandName == 'BlurField')
			field.blur();
	});

	return field;
}

export function setInputHintValues(inputElement, hintValues) {
	var dataListID = SC.util.getRandomStringFromMask('AAAAAA');

	inputElement.parentElement.appendChild(createElement('DATALIST', { id: dataListID },
		Array.from(hintValues).map(function (_) { return $option({ value: _ }) })
	));

	inputElement.setAttribute('list', dataListID);
}

export function getImageDataFromSelector(imageSelector) {
	var image = imageSelector.querySelector('img');
	return image ? extractBase64ContentFromImageDeclaration(image.src) : "";
}

export function selectText(textBox) {
	if (SC.util.isCapable(SC.util.Caps.iOS)) {
		// hack requires ios 10+ https://stackoverflow.com/questions/34045777/copy-to-clipboard-using-javascript-in-ios
		var previousContentEditable = textBox.contentEditable,
			previousReadOnly = textBox.readOnly,
			range = document.createRange();

		textBox.contentEditable = true;
		textBox.readOnly = true; // this is needed to keep the keyboard from showing up
		range.selectNodeContents(textBox);

		var selection = window.getSelection();
		selection.removeAllRanges();
		selection.addRange(range);

		textBox.setSelectionRange(0, textBox.value.length);

		textBox.contentEditable = previousContentEditable;
		textBox.readOnly = previousReadOnly;
	} else {
		textBox.select();
	}
}

export function executeCopyToClipboard(textBox, resultElement) {
	selectText(textBox);

	SC.css.ensureClass(resultElement, 'Success', false);
	SC.css.ensureClass(resultElement, 'Failure', false);

	SC.util.copyToClipboard(function () {
		SC.css.ensureClass(resultElement, 'Success', true);
		setContents(resultElement, SC.res['Command.CopyToClipboard.SuccessMessage']);
	}, function (errorMessage) {
		SC.css.ensureClass(resultElement, 'Failure', true);
		setContents(resultElement, errorMessage || SC.res['Command.CopyToClipboard.FailureMessage']);
	});
	setTimeout(function () {
		SC.css.ensureClass(resultElement, 'Success', false);
	}, 3000);

	setTimeout(function () {
		SC.css.ensureClass(resultElement, 'Failure', false);
	}, 30000);
}

export function addDragAndDropHandlersToElement(element, onDropProc, onDragOverProc, onDragLeaveProc, shouldDisableInitially) {
	element._isDragAndDropTarget = true;

	element._activateDragAndDropHandlers = function () {
		SC.event.addHandler(element, 'dragover', onDragOverProc);
		SC.event.addHandler(element, 'drop', onDropProc);
		SC.event.addHandler(element, 'dragleave', onDragLeaveProc);
	};

	element._deactivateDragAndDropHandlers = function () {
		SC.event.removeHandler(element, 'dragover', onDragOverProc);
		SC.event.removeHandler(element, 'drop', onDropProc);
		SC.event.removeHandler(element, 'dragleave', onDragLeaveProc);
	};

	if (!shouldDisableInitially)
		element._activateDragAndDropHandlers();
}

export function promptUserUploadFile(onChangeProc) {
	// recycle the global file input so we can easily update its onchange handler
	var fileInput = $('globalFileInput');

	if (fileInput != null)
		discardElement(fileInput);

	fileInput = addElement(document.body, 'INPUT', { id: 'globalFileInput', type: 'file', multiple: 'multiple', _visible: false });

	SC.event.addHandler(fileInput, 'change', onChangeProc);

	fileInput.click();
}

export function createCollapsiblePanel(header, content, isCollapsedByDefault, name) {
	var isCollapsed = (SC.util.loadSettings().collapsedPanelMap || {})[name || header.innerHTML];

	if (isCollapsed == null)
		isCollapsed = isCollapsedByDefault;

	var collapsiblePanel = $div({ className: 'CollapsiblePanel' + (isCollapsed ? '' : ' Expanded') }, [
		$div({ className: 'Header', _commandName: 'ToggleExpanded' }, [
			header,
			$a({ className: 'ToggleButton' }),
		]),
		$div({ className: 'Content' }, content),
	]);

	SC.event.addHandler(collapsiblePanel, SC.event.ExecuteCommand, function (eventArgs) {
		if (eventArgs.commandName == 'ToggleExpanded') {
			var content = collapsiblePanel.querySelector('.Content');
			SC.css.toggleClass(collapsiblePanel, 'Expanded');
			content.style.maxHeight = SC.css.containsClass(collapsiblePanel, 'Expanded') ? content.scrollHeight + "px" : 0;

			SC.util.modifySettings(function (settings) {
				if (!settings.collapsedPanelMap)
					settings.collapsedPanelMap = {};

				settings.collapsedPanelMap[name || header.innerHTML] = !SC.css.containsClass(collapsiblePanel, 'Expanded');
			});
		}
	});

	return collapsiblePanel;
}

export function toggleFilterPopout(popoutFrom, filterOptions, activeFilterMap, updateFunc) {
	SC.popout.togglePanel(popoutFrom, function (popoutPanel) {
		SC.css.ensureClass(popoutPanel, 'FilterPopout', true);

		setContents(popoutPanel, [
			$div({ className: 'FilterHeader' }, [
				$h3({ _textResource: 'FilterPopout.Title' }),
				SC.command.createCommandButtons([{ commandName: 'ResetFilter' }]),
			]),

			Object.entries(filterOptions)
				.map(function (keyValuePair) {
					const enumTypeName = keyValuePair[0];
					const enumObject = keyValuePair[1];
					return $div([
						$div({ className: 'FilterSectionHeader' }, [
							$h4({ _textResource: 'FilterPopout.' + enumTypeName + '.HeaderText' }),
							createInfoIcon(SC.res['FilterPopout.' + enumTypeName + '.TooltipText']),
						]),
						Object.entries(enumObject).map(function (keyValuePair) {
							const key = keyValuePair[0];
							const value = keyValuePair[1];
							return $label([
								$span({ _textResource: 'FilterPopout.' + enumTypeName + '.' + key + 'LabelText' }),
								$input({
									type: 'radio',
									name: enumTypeName,
									value: value,
									checked: activeFilterMap[enumTypeName] === value,
									onchange: function (eventArgs) {
										activeFilterMap[eventArgs.target.name] = eventArgs.target.value;
										updateFunc();
									},
								}),
							]);
						}),
					]);
				}),
		]);
	});
}

export function createMultiselectBox(optionTypePrefix, includedOrExcluded, includedOrExcludedValuesParameter, optionNameValueMap, optionValuesParameter, multiselectBoxSubClassName, includeExcludeThreshold) {
	if (includeExcludeThreshold == undefined)
		includeExcludeThreshold = 4;

	var includedOrExcludedValues = includedOrExcludedValuesParameter.slice(); // TODO cmon ... but the parameters named *Parameter need to be reworked
	var optionValues = optionValuesParameter || Object.values(optionNameValueMap);
	var commandButton = SC.command.createCommandButtons([{ commandName: 'OpenPopup' }])[0];
	var multiselectPanel = $div({ className: 'MultiselectBox' + (multiselectBoxSubClassName ? ' ' + multiselectBoxSubClassName : '') }, commandButton);

	function updateMultiselectPanel(element) {
		element._updateText(getTextForOptions(includedOrExcluded, includedOrExcludedValues, optionTypePrefix, optionNameValueMap));

		multiselectPanel._includedOrExcluded = includedOrExcluded;
		multiselectPanel._includedOrExcludedValues = includedOrExcludedValues;
	};

	updateMultiselectPanel(commandButton);

	SC.event.addHandler(multiselectPanel, SC.event.ExecuteCommand, function (eventArgs) {
		var element = eventArgs.clickedElement;

		switch (eventArgs.commandName) {
			case 'OpenPopup':
				SC.popout.togglePanel(eventArgs.commandElement, function (container) {
					SC.css.ensureClass(container, optionTypePrefix + 'Popout', true);
					addContent(
						container,
						[
							$label({ className: 'SelectAll' }, [
								$input({
									type: 'checkbox', _commandName: 'ToggleAll',
									checked: !includedOrExcluded && includedOrExcludedValues.length === 0
								}),
								$span({ _textResource: 'SelectAllButtonText' }),
							]),
							optionValues.map(function (value) {
								var optionName = SC.util.getEnumValueName(optionNameValueMap, value);
								return $label({ className: optionTypePrefix + 'Label' }, [
									$input({
										type: 'checkbox', name: optionName, value: value, className: optionTypePrefix + 'Input', _commandName: 'ToggleCheckbox',
										checked: includedOrExcluded === includedOrExcludedValues.includes(value)
									}),
									$span(optionName),
								]);
							})
						]
					);
				}, null, true);
				break;

			case 'ToggleCheckbox':
				var elementValue = parseInt(element.value);

				if (includedOrExcluded === element.checked) {
					includedOrExcludedValues.push(elementValue);
					if (includedOrExcludedValues.length > (includedOrExcluded ? optionValues.length - includeExcludeThreshold - 1 : includeExcludeThreshold)) {
						includedOrExcluded = !includedOrExcluded;
						includedOrExcludedValues = SC.util.difference(includedOrExcludedValues, optionValues);
					}
				} else
					SC.util.removeElementFromArray(includedOrExcludedValues, elementValue);

				SC.util.handleToggle(element, SC.popout.getPanel().querySelector('.SelectAll > input'), SC.popout.getPanel().querySelectorAll('.' + optionTypePrefix + 'Input'));
				updateMultiselectPanel(eventArgs.commandElement);
				break;

			case 'ToggleAll':
				includedOrExcluded = !element.checked;
				includedOrExcludedValues = [];

				SC.util.handleToggleAll(SC.popout.getPanel().querySelector('.SelectAll > input'), SC.popout.getPanel().querySelectorAll('.' + optionTypePrefix + 'Input'));
				updateMultiselectPanel(eventArgs.commandElement);
				break;
		}
	});

	return multiselectPanel;
}

export function getTextForOptions(includedOrExcluded, includedOrExcludedValues, optionTypePrefix, optionNameValueMap) {
	if (!includedOrExcludedValues)
		return '';
	var listText = includedOrExcludedValues.map(function (e) { return SC.util.getEnumValueName(optionNameValueMap, e); }).join(', ');
	if (includedOrExcluded)
		return includedOrExcludedValues.length === 0
			? SC.res[optionTypePrefix + '.NoOptionsText']
			: listText;
	else
		return includedOrExcludedValues.length === 0
			? SC.res[optionTypePrefix + '.AllOptionsText']
			: SC.util.formatString(SC.res[optionTypePrefix + '.AllOptionsExceptText'], listText);
}

export function getValuesFromMultiselectBox(multiselectBox) {
	return {
		includedOrExcluded: multiselectBox._includedOrExcluded,
		includedOrExcludedValues: multiselectBox._includedOrExcludedValues,
	};
}

export function smartFocusFormField(fieldNamesByPriority: string[]) {
	var eligibleFields = fieldNamesByPriority
		.map(function (name) { return $('input[name="' + name + '"]'); })
		.filter(function (field) { return field && !field.disabled && !field.readOnly; });

	for (var i = 0; i < eligibleFields.length; i++) {
		var field = eligibleFields[i];
		if (!field.value) {
			field.focus();
			return;
		}
	}

	// if everything's filled out, the last field of interest is probably the correct thing to focus
	const lastField = eligibleFields[eligibleFields.length - 1];
	if (lastField) {
		lastField.focus();
		lastField.select();
	}
}

export function createSharePanel(resourceKeyPrefix, sendCommandName, copyCommandName, downloadCommandName, getUrlFunc, getEmailResourceInfoFunc) {
	var emailBox, urlBox, resultPanel, url, emailSubjectResourceInfo, emailBodyResourceInfo;

	var sharePanel = $div({ className: 'SharePanel' }, [
		$p({ className: 'ShareMessage', _textResource: resourceKeyPrefix + '.ShareMessage' }),
		$p({ className: 'CommandPanel' }, [
			SC.command.createCommandButtons([
				sendCommandName && { commandName: sendCommandName },
				copyCommandName && { commandName: copyCommandName },
				downloadCommandName && { commandName: downloadCommandName },
			])
		]),
		resultPanel = $p({ className: 'ResultPanel' }),
	]);

	SC.event.addHandler(sharePanel, SC.event.ExecuteCommand, function (eventArgs) {
		switch (eventArgs.commandName) {
			case sendCommandName:
			case copyCommandName:
				SC.css.ensureClass(resultPanel, 'Success', false);
				SC.css.ensureClass(resultPanel, 'Failure', false);
				setContents(resultPanel);

				getUrlFunc(function (result) {
					url = result;
					emailSubjectResourceInfo = getEmailResourceInfoFunc(url);
					SC.popout.togglePanel(eventArgs.commandElement, function (container) {
						addContent(container, $div({ className: 'SharePanel' }, eventArgs.commandName == sendCommandName ? [
							$p([
								emailBox = $input({ type: 'text', placeholder: SC.res['Command.SendEmail.PlaceholderText'], autofocus: true, _commandName: 'SendEmail' }),
								$input({ type: 'button', _commandName: 'SendEmail', value: SC.res['Command.SendEmail.Text'] }),
							]),
							$p(
								$button({ className: 'SecondaryButton', _commandName: 'OpenEmail', _textResource: 'Command.OpenEmail.Text' })
							)
						] : [
							$p([
								urlBox = $input({ type: 'text', value: url, title: url, readOnly: true, _commandName: 'CopyToClipboard' }),
								$input({ type: 'button', _commandName: 'CopyToClipboard', value: SC.res['Command.CopyToClipboard.Text'] }),
							]),
						]));
					});
				});
				break;

			case downloadCommandName:
				getUrlFunc(SC.util.launchUrl);
				break;

			case 'SendEmail':
				emailBodyResourceInfo = getEmailResourceInfoFunc(url);

				SC.service.SendEmail(
					emailBox.value.trim(),
					emailSubjectResourceInfo.resourceBaseNameFormat,
					emailSubjectResourceInfo.resourceNameFormatArgs,
					emailSubjectResourceInfo.resourceFormatArgs,
					emailBodyResourceInfo.resourceBaseNameFormat,
					emailBodyResourceInfo.resourceNameFormatArgs,
					emailBodyResourceInfo.resourceFormatArgs,
					true,
					function () {
						SC.css.ensureClass(resultPanel, 'Success', true);
						setContents(resultPanel, SC.res['Command.SendEmail.SuccessMessage']);
						setTimeout(function () {
							SC.css.ensureClass(resultPanel, 'Success', false);
						}, 3000);
					},
					function (error) {
						SC.css.ensureClass(resultPanel, 'Failure', true);
						setContents(resultPanel, error.message);
						setTimeout(function () {
							SC.css.ensureClass(resultPanel, 'Failure', false);
						}, 30000);
					}
				);
				break;

			case 'OpenEmail':
				emailBodyResourceInfo = getEmailResourceInfoFunc(url);

				SC.util.openClientEmail(
					null,
					SC.util.formatString(
						SC.util.getResourceWithFallback(
							emailSubjectResourceInfo.resourceBaseNameFormat + 'EmailSubjectFormat',
							emailSubjectResourceInfo.resourceNameFormatArgs
						),
						emailSubjectResourceInfo.resourceFormatArgs
					),
					SC.util.formatString(
						SC.util.getResourceWithFallback(
							emailBodyResourceInfo.resourceBaseNameFormat + 'TextEmailBodyFormat',
							emailBodyResourceInfo.resourceNameFormatArgs
						),
						emailBodyResourceInfo.resourceFormatArgs
					)
				);
				SC.css.ensureClass(resultPanel, 'Success', true);
				setContents(resultPanel, SC.res['Command.OpenEmail.SuccessMessage']);
				break;

			case 'CopyToClipboard':
				executeCopyToClipboard(urlBox, resultPanel);
				break;
		}
	});

	return sharePanel;
}

export function getPreviousOrNextElementSibling(currentElement, previousOrNext) {
	return previousOrNext ? currentElement.previousElementSibling : currentElement.nextElementSibling;
}

// vertical only
// this scrolls an element into view if it is not in complete view relative to its ancestor with the scroll bar
// the reason we use scrollTop vs scrollIntoView(true) is because it causes the entire page to shift up
// https://stackoverflow.com/questions/22062845/scrollintoview-shifting-the-complete-page
export function scrollIntoViewIfNotInView(element, upOrDown) {
	if (element) {
		var ancestorWithScrollBar = findAncestor(element, function (_) {
			if (_.nodeType == document.body.ELEMENT_NODE) {
				var elementOverflowValue = window.getComputedStyle(_).getPropertyValue('overflow-y');
				return (elementOverflowValue == 'scroll' || elementOverflowValue == 'auto') && _.scrollHeight > _.clientHeight;
			} else {
				return false;
			}
		});
		if (ancestorWithScrollBar) {
			var boundingClientRectForElement = element.getBoundingClientRect();
			var boundingClientRectForCompareElement = ancestorWithScrollBar.getBoundingClientRect();
			if (upOrDown ? boundingClientRectForElement.top < boundingClientRectForCompareElement.top : boundingClientRectForElement.bottom > boundingClientRectForCompareElement.bottom)
				if (upOrDown)
					ancestorWithScrollBar.scrollTop = element.offsetTop;
				else
					element.scrollIntoView(false);
		}
	}
}

// known uses: IE
export function getSelectedOptions(selectElement) {
	return Array.from(selectElement.options).filter(function (_) { return _.selected; });
}

window.$ = function (query) { return window.document.getElementById(query) || window.document.querySelector(query); }
window.$$ = function (elementOrGlobalQuery, elementQuery) {
	return Array.from(
		typeof elementOrGlobalQuery === 'string'
			? window.document.querySelectorAll(elementOrGlobalQuery)
			: elementOrGlobalQuery.querySelectorAll(elementQuery)
	);
}

window.$nbsp = function () { return document.createTextNode('\u00a0'); }

window.$a = function () { return createElementInternal('A', arguments); }
window.$br = function () { return createElementInternal('BR', arguments); }
window.$button = function () { return createElementInternal('BUTTON', arguments); }
window.$dd = function () { return createElementInternal('DD', arguments); }
window.$div = function () { return createElementInternal('DIV', arguments); }
window.$dl = function () { return createElementInternal('DL', arguments); }
window.$dt = function () { return createElementInternal('DT', arguments); }
window.$fieldset = function () { return createElementInternal('FIELDSET', arguments); }
window.$form = function () { return createElementInternal('FORM', arguments); }
window.$h1 = function () { return createElementInternal('H1', arguments); }
window.$h2 = function () { return createElementInternal('H2', arguments); }
window.$h3 = function () { return createElementInternal('H3', arguments); }
window.$h4 = function () { return createElementInternal('H4', arguments); }
window.$hr = function () { return createElementInternal('HR', arguments); }
window.$iframe = function () { return createElementInternal('IFRAME', arguments); }
window.$img = function () { return createElementInternal('IMG', arguments); }
window.$input = function () { return createElementInternal('INPUT', arguments); }
window.$label = function () { return createElementInternal('LABEL', arguments); }
window.$legend = function () { return createElementInternal('LEGEND', arguments); }
window.$li = function () { return createElementInternal('LI', arguments); }
window.$option = function () { return createElementInternal('OPTION', arguments); }
window.$p = function () { return createElementInternal('P', arguments); }
window.$script = function () { return createElementInternal('SCRIPT', arguments); }
window.$select = function () { return createElementInternal('SELECT', arguments); }
window.$span = function () { return createElementInternal('SPAN', arguments); }
window.$table = function () { return createElementInternal('TABLE', arguments); }
window.$tbody = function () { return createElementInternal('TBODY', arguments); }
window.$td = function () { return createElementInternal('TD', arguments); }
window.$textarea = function () { return createElementInternal('TEXTAREA', arguments); }
window.$th = function () { return createElementInternal('TH', arguments); }
window.$thead = function () { return createElementInternal('THEAD', arguments); }
window.$tr = function () { return createElementInternal('TR', arguments); }
window.$ul = function () { return createElementInternal('UL', arguments); }

// DEPRECATED: use CSS styling instead
window.$dfn = function () { return createElementInternal('DFN', arguments); }
window.$ins = function () { return createElementInternal('INS', arguments); }
window.$pre = function () { return createElementInternal('PRE', arguments); }
