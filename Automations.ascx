<%@ Control %>

<dl class="TriggersPanel"></dl>

<script>

	const TriggerTypeFilter = SC.util.createEnum(['All', 'Session', 'Security']);
	const SortingOption = SC.util.createEnum(['RecentlyModified', 'AscendingName', 'DescendingName', 'Enabled']);

	let filterText = '';
	let sortingOption = SortingOption.RecentlyModified;
	let activeFilterMap = { AutomationTypeFilter: TriggerTypeFilter.All };
	let sortingOptionLink, filterPanelLink, triggerPanel, triggerList;

	function updateTriggerTable() {
		const triggersInfo = SC.pagedata.get();

		const filteredTriggers = triggersInfo
			.filter(trigger =>
				activeFilterMap.AutomationTypeFilter === TriggerTypeFilter.All
				|| (activeFilterMap.AutomationTypeFilter === trigger.Type)
			)
			.filter(trigger => !filterText
				|| SC.util.containsText([
					...Object.values(trigger),
					...(trigger.Actions?.flatMap(Object.values) || [])
				].filter(it => typeof it === 'string'),
					filterText));

		const activeFilterDisplayString = activeFilterMap.AutomationTypeFilter !== TriggerTypeFilter.All && SC.res[`FilterPopout.AutomationTypeFilter.${activeFilterMap.AutomationTypeFilter}LabelText`] || SC.res['FilterPopout.AllAutomationsLabelText'];

		SC.ui.setContents(sortingOptionLink, SC.res[`Command.${sortingOption}.Text`]);
		SC.ui.setContents(filterPanelLink, activeFilterDisplayString);
		SC.css.ensureClass(triggerPanel, 'Empty', filteredTriggers.length === 0);
		SC.ui.setContents(triggerList, [
			filteredTriggers
				.sort((a, b) => {
					if (sortingOption === SortingOption.RecentlyModified) {
						return b.ModifiedDate.localeCompare(a.ModifiedDate)
					} else if (sortingOption === SortingOption.Enabled) {
						return (a.IsDisabled === b.IsDisabled) ? 0 : a.IsDisabled ? 1 : -1;
					} else {
						const result = a.Name.localeCompare(b.Name);
						return sortingOption === SortingOption.DescendingName ? -result : result;
					}
				})
				.map(trigger => $div({ className: 'TriggerCard ' + trigger.Type, _dataItem: trigger }, [
					$div({ className: 'TriggerCardHeader' }, [
						$img({ src: `../Images/${trigger.Type}EventTrigger.svg`, title: SC.res[`AutomationsPanel.${trigger.Type}EventAutomationIcon.LabelText`] }),
						$div([
							$h4({ title: trigger.Name }, trigger.Name),
							SC.util.tryGetDateTime(trigger.ModifiedDate)
								? $p({ title: SC.util.formatDateTime(SC.util.tryGetDateTime(trigger.ModifiedDate), { includeFullDate: true, includeSeconds: true }) },
									SC.util.formatString(SC.res['AutomationsPanel.ModifiedDateTextFormat'], SC.util.formatDateTime(new Date(trigger.ModifiedDate), { includeRelativeDate: true }))
								)
								: null,
						]),
					]),
					$div({ className: 'TriggerCardFooter' }, [
						$label({ className: 'ToggleButton', _commandName: 'ToggleEnabled', _commandArgument: trigger.Type, title: !trigger.IsDisabled ? SC.res['ToggleIcon.EnabledLabelText'] : SC.res['ToggleIcon.DisabledLabelText'] }, [
							$input({ type: 'checkbox', checked: !trigger.IsDisabled }),
							$span({ className: 'Slider' }),
						]),
						$a({ _commandName: 'MoreTriggerOptions', className: 'MoreOptionsButton' }),
					]),
				])),
		]);
	};

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetEventTriggers(triggersInfo => {
			SC.pagedata.set(
				['Session', 'Security'].map(triggerType =>
					triggersInfo[`${triggerType}EventTriggers`].map(trigger => {
						trigger.Type = triggerType;
						return trigger;
					})
				).flat()
			);
		});
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
		SC.ui.setContents($('.TriggersPanel'), [
			$dt([
				$h3({ _textResource: 'AutomationsPanel.AutomationsTitle' }),
				$div({ className: 'FlexSpacer' }),
				$div([
					$span({ className: 'LabelText', _textResource: 'SortPanel.LabelText' }),
					sortingOptionLink = $a({ _commandName: 'OpenSortingPopup' }),
				]),
				$div([
					$span({ className: 'LabelText', _textResource: 'FilterPanel.LabelText' }),
					filterPanelLink = $a({ _commandName: 'OpenFilterPopup' }),
				]),
				$div({ className: 'FilterBoxPanel' },
					SC.ui.createFilterBox({ placeholder: SC.res['AutomationsFilterBox.PlaceholderText'], value: filterText }, eventArgs => {
						filterText = eventArgs.target.value;
						window.updateTriggerTable();
					}),
				),
				$p({ className: 'CommandList' }, SC.command.createCommandButtons([{ commandName: 'CreateAutomation' }])),
			]),
			triggerPanel = $dd({ className: 'TriggerPanel' }, [
				$div({ className: 'EmptyPanel' }, [
					$p($img({ src: '../Images/Search.svg' })),
					$h2({ _textResource: 'AutomationPanel.AutomationsTable.EmptyTitle' }),
					$p({ _textResource: 'AutomationPanel.AutomationsTable.EmptyMessage' }),
				]),
				triggerList = $div(),
			]),
		]);

		window.updateTriggerTable();
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'OpenSortingPopup':
				SC.popout.showPanelFromCommand(eventArgs, { sortingOption });
				break;

			case SortingOption.Enabled:
			case SortingOption.AscendingName:
			case SortingOption.DescendingName:
			case SortingOption.RecentlyModified:
				sortingOption = eventArgs.commandName;
				window.updateTriggerTable();
				break;

			case 'OpenFilterPopup':
				SC.ui.toggleFilterPopout(eventArgs.commandElement, { AutomationTypeFilter: TriggerTypeFilter }, activeFilterMap, window.updateTriggerTable);
				break;

			case 'ResetFilter':
				activeFilterMap = {
					AutomationTypeFilter: TriggerTypeFilter.All,
				};
				window.updateTriggerTable();
				break;

			case 'MoreTriggerOptions':
				SC.popout.showPanelFromCommand(eventArgs, { triggerType: SC.command.getEventDataItem(eventArgs).Type });
				break;

			case 'CreateAutomation':
				SC.popout.showPanelFromCommand(eventArgs, null, { getCreateOptionsFunc: () => ({ descriptionRenderStyle: SC.command.DescriptionRenderStyle.Element }) });
				break;

			case 'CloneAutomation':
			case 'EditAutomation':
			case 'CreateSessionEventAutomation':
			case 'CreateSecurityEventAutomation':
				var triggerType = eventArgs.commandArgument;
				var isClone = (eventArgs.commandName == 'CloneAutomation');
				var trigger = SC.command.getEventDataItem(eventArgs) || {};
				var triggerName = trigger.Name || '';
				var triggerEventFilter = trigger.EventFilter || '';
				var triggerActions = trigger.Actions || [];

				var actionTypeToFieldToTagNameMap = {
					MailAction: {
						From: 'input',
						To: 'input',
						Subject: 'input',
						IsBodyHtml: 'select',
						Body: 'textarea',
					},
					HttpAction: {
						Uri: 'input',
						HttpMethod: 'input',
						ContentType: 'input',
						Body: 'textarea',
					},
				};

				if (triggerType === 'Session')
					actionTypeToFieldToTagNameMap.SessionEventAction = {
						EventType: 'select',
						HostName: 'input',
						CorrelationEventID: 'input',
						Data: 'textarea',
					};

				var fieldSelectOptionMap = {
					EventType: SC.types.SessionEventType,
					IsBodyHtml: { true: true, false: false },
				};

				var buttonPanel;

				var createElementBasedOnFieldFunc = function (actionType, field, value) {
					var elementType = actionTypeToFieldToTagNameMap[actionType][field];
					var selectOptions = fieldSelectOptionMap[field];

					if (elementType == 'input' || elementType == 'textarea') {
						return SC.ui.createTextBox({ className: field, value: value || '' }, elementType == 'textarea', false, SC.res['AutomationsPanel.' + actionType + field + 'PlaceHolder'] || '');
					} else if (elementType == 'select') {
						return $select({ className: field }, [
							Object.keys(selectOptions).map(function (_) {
								return $option({
									value: selectOptions[_],
									selected: selectOptions[_] == value,
								}, _);
							}),
						]);
					}
				};

				var createTriggerActionPanelFunc = function (actionType, action) {
					return $div({ className: 'TriggerAction ' + actionType }, [
						$div([
							$div({ className: 'TriggerActionHeader ' + actionType }, [
								$h4({ _textResource: 'AutomationsPanel.' + actionType + 'TitleText' }),
							]),
							$a({ className: 'DeleteTriggerActionButton', title: SC.res['AutomationsPanel.DeleteAutomationActionButtonTooltip'], _commandName: 'DeleteTriggerAction' }, 'Delete'),
						]),
						$dl(
							Object.keys(actionTypeToFieldToTagNameMap[actionType]).map(function (field) {
								return [
									$dt({ _textResource: 'AutomationsPanel.' + actionType + field + 'LabelText' }),
									$dd(createElementBasedOnFieldFunc(actionType, field, action[field])),
								];
							})
						),
					]);
				};

				var getTriggerActionTypeFunc = function (action) {
					if (typeof action.Subject !== 'undefined') { // Email Service
						return 'MailAction';
					} else if (typeof action.HttpMethod !== 'undefined') { // Web Service
						return 'HttpAction';
					} else if (typeof action.EventType !== 'undefined') { // Session Event Service
						return 'SessionEventAction';
					}
				};

				var filterExpressionEditor;

				SC.util.lazyImport('SC.editor').then((Editor) => SC.service.GetEventTriggerExpressionMetadata(
						triggerType === 'Session',
						triggerMetadata => SC.dialog.showModalDialog('EditTrigger', {
							suppressEscapeKeyHandling: true,
							initializeProc(dialog) {
								Editor.setExpressionEditorText(filterExpressionEditor, triggerEventFilter.trim());
								SC.command.updateCommandButtonsState(dialog);
							},
							titleResourceName: `Edit${triggerType}EventAutomationPanel.` + (Object.keys(trigger).length == 0 ? 'Create' : isClone ? 'Clone' : 'Edit') + 'Title',
							content: [
								$p({ _textResource: `Command.Create${triggerType}EventAutomation.Description` }),
								$dl([
									$dt({ _textResource: 'AutomationsPanel.AutomationNameLabelText' }),
									$dd($input({ className: 'TriggerName', type: 'text', value: isClone ? triggerName + ' (Clone)' : triggerName })),
								]),
								$h2({ _textResource: 'AutomationsPanel.IfLabelText' }),
								$dl([
									$dt({ _textResource: 'AutomationsPanel.AutomationEventFilterLabelText' }),
									$dd([
										filterExpressionEditor = Editor.createExpressionEditor({
											propertyInfos: triggerMetadata.PropertyInfos,
											variableInfos: {}, // don't need
											stringTable: {
												PlaceholderText: SC.res["EditSessionGroupPanel.SessionFilterPlaceholder"]
											},
										}),
										$a({ className: 'SyntaxHelperButton', _commandName: 'ShowEventFilterSyntaxHelper' }),
									]),
								]),
								$h2({ _textResource: 'AutomationsPanel.ThenLabelText' }),
								$dl([
									$dt({ _textResource: 'AutomationsPanel.AutomationActionLabelText' }),
									$dd([
										$div({ className: 'TriggerActionList' }, [
											triggerActions.map(function (action) {
												return createTriggerActionPanelFunc(getTriggerActionTypeFunc(action), action);
											}),
										]),
										$div({ className: 'AddTriggerAction' }, [
											Object.keys(actionTypeToFieldToTagNameMap).map(function (actionType) {
												return $div({ className: 'AddActionButton ' + actionType, _commandName: 'CreateTriggerAction', _commandArgument: actionType }, [
													$span({ _textResource: 'AutomationsPanel.New' + actionType + 'ButtonText' }),
												]);
											}),
										]),
									]),
								]),
							],
							buttonTextResourceName: 'EditAutomationPanel.ButtonText',
							buttonPanelExtraContent: [
								SC.command.createCommandButtons([
									{ commandName: 'ToggleReference', commandArgument: 'Hide' },
									{ commandName: 'ToggleReference', commandArgument: 'Show' },
								]),
							],
							referencePanelTextResourceName: `AdministrationPanel.${triggerType}EventAutomationsExtraMessage`,
							onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
								switch (dialogEventArgs.commandName) {
									case 'Default':
										var originalTriggerName = isClone ? '' : triggerName;
										var newTriggerName = dialog.querySelector('.TriggerName').value;
										var smtpTriggerActions = [];
										var httpTriggerActions = [];
										var sessionEventTriggerActions = [];

										triggerEventFilter = Editor.getExpressionEditorInfo(filterExpressionEditor).text;

										Object.keys(actionTypeToFieldToTagNameMap).map(function (actionType) {
											dialog.querySelectorAll('.TriggerAction.' + actionType).forEach(function (actionElement) {
												var action = {};
												Object.keys(actionTypeToFieldToTagNameMap[actionType]).map(function (field) {
													var elementType = actionTypeToFieldToTagNameMap[actionType][field];
													action[field] = actionElement.querySelector(elementType + '.' + field).value;
												});

												if (actionType == 'MailAction') {
													smtpTriggerActions.push(action);
												} else if (actionType == 'HttpAction') {
													httpTriggerActions.push(action);
												} else if (actionType == 'SessionEventAction') {
													sessionEventTriggerActions.push(action);
												}
											});
										});

										const onSuccessFunc = () => {
											closeDialogProc();
											SC.pagedata.notifyDirty();
										};

										if (triggerType === 'Session')
											SC.service.SaveSessionEventTrigger(originalTriggerName, newTriggerName, trigger.CreationDate, trigger.IsDisabled, triggerEventFilter, smtpTriggerActions, httpTriggerActions, sessionEventTriggerActions, onSuccessFunc, setDialogErrorProc);
										else
											SC.service.SaveSecurityEventTrigger(originalTriggerName, newTriggerName, trigger.CreationDate, trigger.IsDisabled, triggerEventFilter, smtpTriggerActions, httpTriggerActions, onSuccessFunc, setDialogErrorProc);
										break;

									case 'ToggleReference':
										SC.css.toggleClass(dialog, 'Expanded');
										break;

									case 'DeleteTriggerAction':
										SC.ui.discardElement(SC.ui.findAncestor(dialogEventArgs.target, function (_) { return SC.css.containsClass(_, 'TriggerAction'); }), false);
										break;

									case 'CreateTriggerAction':
										SC.ui.addContent($('.TriggerActionList'), createTriggerActionPanelFunc(dialogEventArgs.commandArgument, {}));
										break;

									case 'ShowEventFilterSyntaxHelper':
										SC.popout.togglePanel(dialogEventArgs.commandElement, function (popoutPanel) {
											SC.ui.setContents(
												popoutPanel,
												SC.util.parseTsvIntoJaggedArray(SC.res[`Edit${triggerType}EventAutomationPanel.EventFilterSyntaxItems`])
													.groupBy(function (_) { return _[2]; }, function (_) { return { buttonText: _[0], definition: _[1] }; })
													.mapKeyValue(function (categoryName, items) {
														return [
															$div({ className: 'CommandList' }, [
																$h4(categoryName),
																items.map(function (item) {
																	return SC.command.createCommandButtons([{
																		commandName: 'InsertEventFilterExample',
																		description: item.definition,
																		text: item.buttonText,
																		commandArgument: { exampleText: item.buttonText },
																	}]);
																}),
															]),
														];
													})
											);
										});
										break;

									case 'InsertEventFilterExample':
										const text = Editor.getExpressionEditorInfo(filterExpressionEditor).text + (Editor.getExpressionEditorInfo(filterExpressionEditor).text != '' ? ' AND ' : '') + dialogEventArgs.commandArgument.exampleText;
										Editor.setExpressionEditorText(dialog, text);
										break;
								}

								SC.command.updateCommandButtonsState(dialog);
							},
							onQueryCommandButtonStateProc: function (dialogEventArgs, dialog) {
								switch (dialogEventArgs.commandName) {
									case 'ToggleReference':
										dialogEventArgs.isVisible = (dialogEventArgs.commandArgument == 'Show') != SC.css.containsClass(dialog, 'Expanded');
										break;
								}
							},
						})
					)
				);
				break;

			case 'DeleteAutomation':
				var triggerType = eventArgs.commandArgument;
				SC.dialog.showConfirmationDialog(
					'DeleteAutomation',
					SC.res['DeleteAutomationPanel.Title'],
					$p({ _htmlResource: 'DeleteAutomationPanel.Text' }),
					SC.res['DeleteAutomationPanel.ButtonText'],
					function (onSuccess, onFailure) {
						SC.service[`Delete${triggerType}EventTrigger`](
							SC.command.getEventDataItem(eventArgs).Name,
							function () { onSuccess(); SC.pagedata.notifyDirty(); },
							onFailure
						);
					}
				);
				break;

			case 'ToggleEnabled':
				var triggerType = eventArgs.commandArgument;
				SC.service[`Toggle${triggerType}EventTriggerEnabled`](
					SC.command.getEventDataItem(eventArgs).Name,
					SC.pagedata.notifyDirty
				);
				break;
		}
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
		switch (eventArgs.area) {
			case "OpenSortingPopupPopoutPanel":
				Object.keys(SortingOption).forEach((option) => {
					eventArgs.buttonDefinitions.push({
						commandName: option,
						commandArgument: eventArgs.commandContext.sortingOption === option ? "Selected" : undefined,
					});
				});
				break;

			case 'MoreTriggerOptionsPopoutPanel':
				eventArgs.buttonDefinitions.push({ commandName: 'EditAutomation', commandArgument: eventArgs.commandContext.triggerType });
				eventArgs.buttonDefinitions.push({ commandName: 'DeleteAutomation', commandArgument: eventArgs.commandContext.triggerType });
				eventArgs.buttonDefinitions.push({ commandName: 'CloneAutomation', commandArgument: eventArgs.commandContext.triggerType });
				break;

			case 'CreateAutomationPopoutPanel':
				eventArgs.buttonDefinitions.push({ commandName: 'CreateSessionEventAutomation', commandArgument: 'Session', imageUrl: '../Images/SessionEventTrigger.svg' });
				eventArgs.buttonDefinitions.push({ commandName: 'CreateSecurityEventAutomation', commandArgument: 'Security', imageUrl: '../Images/SecurityEventTrigger.svg' });
				break;
		}
	});

</script>
