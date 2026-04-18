// @ts-nocheck

export function createEditField(sessionPropertyName, selectableOptionString, trySelectedOption, textValue, enterCommandName, onChangeProc) {
	var selectableOptions = [
		{ value: 'K', text: SC.res['SessionPanel.PropertyKeepOption'], showTextBox: false },
		{ value: 'M', text: SC.res['SessionPanel.PropertyMachineNameOption'], showTextBox: false },
		{ value: 'S', text: SC.res['SessionPanel.PropertySpecifyOption'], showTextBox: true }
	];

	var docFragment = document.createDocumentFragment();
	docFragment.appendChild($dt({ _textResource: 'SessionProperty.' + sessionPropertyName + '.LabelText' }));
	var definitionElement = docFragment.appendChild($dd({ _sessionPropertyName: sessionPropertyName }));
	var selectBox, textBox;

	SC.ui.addContent(definitionElement, $div({ className: 'EditField' }, [
		selectBox = $select(),
		textBox = SC.ui.createTextBox({ value: textValue || '', _commandName: enterCommandName, _eventHandlerMap: { 'change': onChangeProc } }, false, false)
	]));

	selectableOptions.forEach(function (so) {
		if (!SC.util.isNullOrEmpty(selectableOptionString) && selectableOptionString.indexOf(so.value) !== -1) {
			var option = new Option(so.text, so.value);
			option._selectableOption = so;
			selectBox.add(option);

			if (so.value === trySelectedOption)
				selectBox.selectedIndex = selectBox.options.length - 1;
		}
	});

	var updateClassesProc = function () {
		SC.ui.setVisible(selectBox, selectBox.options.length > 0);
		SC.ui.setVisible(textBox, selectBox.options.length === 0 || selectBox.options[selectBox.selectedIndex]._selectableOption.showTextBox);
	};

	SC.event.addHandler(selectBox, 'change', function () {
		updateClassesProc();
		textBox.focus();
		if (onChangeProc)
			onChangeProc();
	});

	updateClassesProc();

	return docFragment;
}

export function addEditField(definitionList, sessionPropertyName, selectableOptionString, trySelectedOption, textValue, enterCommandName) {
	definitionList.appendChild(createEditField(sessionPropertyName, selectableOptionString, trySelectedOption, textValue, enterCommandName));
}

export function setEditFieldHintValues(definitionList, sessionPropertyName, hintValues) {
	var inputElement = getElement(definitionList, sessionPropertyName, function (e) { return e.tagName == 'INPUT' && e.type == 'text'; });
	SC.ui.setInputHintValues(inputElement, hintValues);
}

export function getElement(definitionList, sessionPropertyName, predicate) {
	var definitionElement = SC.ui.findDescendant(definitionList, function (e) { return e._sessionPropertyName == sessionPropertyName; });
	return !predicate ? definitionElement : SC.ui.findDescendant(definitionElement, predicate);
}

export function getOptionValue(definitionList, sessionPropertyName) {
	var selectBox = getElement(definitionList, sessionPropertyName, function (e) { return e.tagName == 'SELECT'; });

	if (selectBox != null)
		return (selectBox.options.length == 0 ? null : selectBox.options[selectBox.selectedIndex].value);

	var definitionElement = getElement(definitionList, sessionPropertyName);
	return SC.ui.getSelectedRadioButtonValue(definitionElement);
}

export function getTextValue(definitionList, sessionPropertyName) {
	var inputElement = getElement(definitionList, sessionPropertyName, function (e) { return e.tagName == 'INPUT' && e.type == 'text'; });
	if (inputElement)
		return inputElement.value.trim();

	var spanElement = getElement(definitionList, sessionPropertyName, function (e) { return e.tagName == 'SPAN'; });
	if (spanElement)
		return spanElement.innerHTML;

	return '';
}

export function focus(definitionList, sessionPropertyName) {
	getElement(definitionList, sessionPropertyName, function (e) { return e.tagName == 'INPUT'; }).focus();
}
