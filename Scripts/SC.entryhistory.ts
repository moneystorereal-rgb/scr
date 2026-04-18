// @ts-nocheck

export function createPanel(emptyImageUrl, emptyTitle, emptyMessage, placeholderText, buttonText, emptyWhoText, addCommandName, eventFilter, historyNavigateFilter) {
	let entryPanel, entryBox, button, historyListPanel;

	const entryHistoryPanel = $div({ _classNameMap: { EntryHistoryPanel: true, HasEntryBox: addCommandName }, _addCommandName: addCommandName, _eventFilter: eventFilter, _emptyWhoText: emptyWhoText }, [
		$div({ className: 'HistoryPanel' }, [
			$div({ className: 'EmptyPanel' }, [
				$p($img({ src: emptyImageUrl })),
				$h4(emptyTitle),
				$p(emptyMessage),
			]),
			historyListPanel = $div({ className: 'ListPanel' })
		]),
		addCommandName && (entryPanel = $div({ className: 'EntryPanel' }, [
			$div(
				entryBox = SC.ui.createTextBox({ _commandName: 'Default' }, true, false, placeholderText)
			),
			button = $input({ type: 'button', value: buttonText, _commandName: 'Default' }),
		])),
	])

	addCommandName && SC.event.addHandler(entryBox, 'keydown', function (eventArgs) {
		const isValidUp = eventArgs.keyCode == 33 || (eventArgs.keyCode == 38 && entryBox.value.lastIndexOf('\n', entryBox.selectionStart - 1) == -1);
		const isValidDown = eventArgs.keyCode == 34 || (eventArgs.keyCode == 40 && entryBox.value.indexOf('\n', entryBox.selectionEnd) == -1);

		if (historyNavigateFilter && entryBox.selectionStart === entryBox.selectionEnd && (isValidUp || isValidDown)) {
			const step = (isValidUp ? -1 : 1);
			const navigateItems = Array.prototype.filter.call(historyListPanel.childNodes, function (n) { return historyNavigateFilter(n._dataItem.event); });
			let index = Array.prototype.findIndex.call(navigateItems, function (n) { return n._dataItem.event.eventID == entryBox._historyEventID; });

			if (index == -1)
				index = navigateItems.length;

			while (navigateItems[index] && navigateItems[index + step] && navigateItems[index]._dataItem.event.data == navigateItems[index + step]._dataItem.event.data)
				index += step;

			index += step;

			if (navigateItems[index]) {
				entryBox._historyEventID = navigateItems[index]._dataItem.event.eventID;

				entryBox.value = navigateItems[index]._dataItem.event.data;

				const selectionIndex = (isValidUp ? 1000000 : 0);
				entryBox.setSelectionRange(selectionIndex, selectionIndex);

				eventArgs.preventDefault();
			}
		}
	});

	addCommandName && SC.event.addHandler(entryHistoryPanel, SC.event.ExecuteCommand, function (eventArgs) {
		if (eventArgs.commandName == 'Default') {
			const entryText = entryBox.value.trim();

			if (!SC.util.isNullOrEmpty(entryText)) {
				SC.command.dispatchExecuteCommand(entryPanel, button, entryHistoryPanel, entryHistoryPanel._addCommandName, entryText);
				entryBox._historyEventID = null;
				entryBox.value = '';
				SC.ui.scrollToBottom(entryHistoryPanel.firstChild);
			}

			entryBox.focus();
		}
	});

	return entryHistoryPanel;
}

export function getAddCommandName(entryHistoryPanel) {
	return entryHistoryPanel._addCommandName;
}

export function setEntryEnabled(entryHistoryPanel, entryEnabled) {
	SC.ui.findDescendant(entryHistoryPanel, function (e) {
		if (e.tagName === 'INPUT' || e.tagName === 'TEXTAREA')
			e.disabled = (entryEnabled ? '' : 'disabled');
	});
}

export function rebuildPanel(entryHistoryPanel, events, selectedEventID) {
	var filteredEvents = events.filter(entryHistoryPanel._eventFilter);
	var listPanel = entryHistoryPanel.querySelector('.ListPanel');
	var historyPanel = entryHistoryPanel.querySelector('.HistoryPanel');
	var wasAtBottom = historyPanel.scrollHeight - historyPanel.scrollTop - historyPanel.clientHeight < 50; // Set 50px as threshold

	function createSubEventElement(subEvent) {
		var eventTypeName = SC.util.getEnumValueName(SC.types.SessionEventType, subEvent.eventType);
		var eventText = SC.res['SessionEvent.' + SC.util.getEnumValueName(SC.types.SessionEventType, subEvent.eventType) + '.Text'];
		var title = eventText
			+ (subEvent.who ? SC.util.formatString(SC.res['SessionEventSubEvent.ByFormat'], subEvent.who) : '')
			+ ' ' + SC.util.formatDateTime(new Date(subEvent.time), { includeFullDate: true, includeRelativeDate: true, includeSeconds: true })
			+ (subEvent.data ? SC.util.formatString(SC.res['SessionEventSubEvent.DataFormat'], subEvent.data) : '');
		return $div({ className: eventTypeName, title: title }, $span(eventText));
	}

	SC.ui.setContents(listPanel, filteredEvents
		.map(function (event) {
			return {
				event: event,
				correlatedEvents: events.filter(function (it) { return it.correlationEventID === event.eventID; })
			};
		})
		.map(function (eventInfo) {
			return Object.assign({},
				eventInfo,
				{
					requestResolutionEvents: eventInfo.correlatedEvents.filter(function (it) { return SC.context.requestResolutionEventTypes.includes(it.eventType); }),
					acknowledgementEvents: eventInfo.correlatedEvents.filter(function (it) { return it.eventType === SC.types.SessionEventType.AcknowledgedEvent; }),
					processedEvents: eventInfo.correlatedEvents.filter(function (it) { return it.eventType === SC.types.SessionEventType.ProcessedEvent; }),
					annotatedEvents: eventInfo.correlatedEvents.filter(function (it) { return it.eventType === SC.types.SessionEventType.AnnotatedEvent; }),
				}
			);
		})
		.map(function (eventInfo) {
			return Object.assign({},
				eventInfo,
				SC.event.dispatchEvent(entryHistoryPanel, SC.event.QuerySessionEventRenderInfo, {
					eventInfo: eventInfo,
					renderInfo: {
						isTitleVisible: false,
						isRawDataVisible: true,
						isDataContentVisible: false,
						isDataFieldListVisible: false,
						isRequestResolutionListVisible: false,
						isResponseCommandListVisible: false,
						isWaitingToProcessVisible: true,
						isAcknowledgementListVisible: true,
						isProcessedListVisible: true,
						isAnnotatedListVisible: false,
					},
				}).renderInfo
			);
		})
		.map(function (eventAndRenderInfo) {
			return Object.assign({},
				eventAndRenderInfo,
				{ parsedEventData: eventAndRenderInfo.isDataFieldListVisible || eventAndRenderInfo.isDataContentVisible ? SC.util.parseEventData(eventAndRenderInfo.event.data) : null }
			);
		})
		.map(function (eventAndRenderInfo) {
			return $div(
				{
					_classNameMap: {
						[SC.util.getEnumValueName(SC.types.ProcessType, eventAndRenderInfo.event.processType)]: true,
						[SC.util.getEnumValueName(SC.types.SessionEventType, eventAndRenderInfo.event.eventType)]: true,
						SelectedEventIDElement: eventAndRenderInfo.event.eventID === selectedEventID,
					},
					_selected: eventAndRenderInfo.event.eventID === selectedEventID,
					_dataItem: eventAndRenderInfo,
				},
				[
					$div({ className: 'Header' }, [
						$div({ className: 'Info' }, [
							$p({ className: 'Who' }, SC.util.isNullOrEmpty(eventAndRenderInfo.event.who) ? entryHistoryPanel._emptyWhoText : eventAndRenderInfo.event.who),
							$p({ className: 'Time', title: SC.util.formatDateTime(new Date(eventAndRenderInfo.event.time), { includeFullDate: true, includeSeconds: true }) }, SC.util.formatDateTime(new Date(eventAndRenderInfo.event.time), { includeRelativeDate: true })),
							eventAndRenderInfo.isAcknowledgementListVisible && eventAndRenderInfo.acknowledgementEvents.map(createSubEventElement),
							eventAndRenderInfo.isProcessedListVisible && eventAndRenderInfo.processedEvents.map(createSubEventElement),
							eventAndRenderInfo.isAnnotatedListVisible && eventAndRenderInfo.annotatedEvents.map(createSubEventElement),
							eventAndRenderInfo.isWaitingToProcessVisible && $div({ className: 'Waiting', title: SC.res['SessionEventSubEvent.WaitingToProcessTitle'] }, $span()),
						]),
						$p({ className: 'Command' }, SC.command.queryAndCreateCommandButtons('EventHistoryItem', eventAndRenderInfo)),
					]),
					$div({ className: 'Body' }, [
						$div({ className: 'Info' }, [
							eventAndRenderInfo.isTitleVisible && $h4({ className: 'Title' }, SC.res['SessionEvent.' + SC.util.getEnumValueName(SC.types.SessionEventType, eventAndRenderInfo.event.eventType) + '.Title']),
							(eventAndRenderInfo.isRawDataVisible || eventAndRenderInfo.isDataContentVisible || eventAndRenderInfo.isDataFieldListVisible) && $div({ className: 'Content' }, [
								eventAndRenderInfo.isRawDataVisible && $p({ className: 'Data', _innerHTMLAlreadySanitized: SC.util.escapeHtmlAndLinkify(eventAndRenderInfo.event.data) }),
								eventAndRenderInfo.isDataContentVisible && $p({ className: 'DataContent', _innerHTMLAlreadySanitized: SC.util.escapeHtmlAndLinkify(eventAndRenderInfo.parsedEventData.content) }),
								eventAndRenderInfo.isDataFieldListVisible && $div({ className: 'DataFieldList' },
									[Object.entries(eventAndRenderInfo.parsedEventData.fields)]
										.concat(eventAndRenderInfo.annotatedEvents.map(function (it) { return Object.entries(SC.util.parseEventData(it.data).fields); }))
										.flat()
										.map(function (fieldNameValuePair) {
											return {
												labelText: SC.res['SessionEventDataField.' + fieldNameValuePair[0] + '.LabelText'],
												valueText: fieldNameValuePair[1],
											};
										})
										.filter(function (it) { return it.labelText !== undefined; })
										.map(function (it) {
											return [
												$dt(it.labelText),
												$dd({ _innerHTMLAlreadySanitized: SC.util.escapeHtmlAndLinkify(it.valueText) }),
											];
										})
								),
							]),
						]),
						(eventAndRenderInfo.isResponseCommandListVisible || eventAndRenderInfo.isRequestResolutionListVisible) && $div({ className: 'Response' }, [
							eventAndRenderInfo.isResponseCommandListVisible && $div({ className: 'EventHistoryItemResponse CommandList' }, SC.command.queryAndCreateCommandButtons('ResponseCommandList', eventAndRenderInfo)),
							eventAndRenderInfo.isRequestResolutionListVisible && $div({ className: 'RequestResolutionList' }, eventAndRenderInfo.requestResolutionEvents.map(createSubEventElement)),
						]),
					]),
				]
			);
		})
	);

	SC.css.ensureClass(entryHistoryPanel, 'Empty', !filteredEvents.length);

	if ($('.SelectedEventIDElement'))
		$('.SelectedEventIDElement').scrollIntoView();
	else if (wasAtBottom)
		SC.ui.scrollToBottom(historyPanel);
}
