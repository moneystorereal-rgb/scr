<%@ Control Language="C#" %>

<dl class="DatabaseMaintenanceList"></dl>

<script>

	function doesActionTypeUseSessionOrSecurityEvents(actionType) {
		switch (actionType) {
			case SC.types.DatabaseMaintenanceActionType.PurgeSecurityActivity:
				return false;
			case SC.types.DatabaseMaintenanceActionType.PurgeSessionActivity:
			case SC.types.DatabaseMaintenanceActionType.PurgeDeletedSessions:
			case SC.types.DatabaseMaintenanceActionType.PurgeSessionCaptures:
			case SC.types.DatabaseMaintenanceActionType.PurgeSessionConnections:
				return true;
			default:
				return null;
		}
	}

	function setVisibilityOfParametersBasedOnActionType(actionType, parameterDefinitions) {
		Object.keys(parameterDefinitions).forEach(function (parameterName) {
			var isVisible = parameterName === 'ActionType' || parameterDefinitions[parameterName].AppliesToActionTypes.includes(actionType);
			var elements = document.querySelectorAll('.EditAction .' + parameterName);
			Array.from(elements).forEach(function (e) { SC.ui.setVisible(e, isVisible) });
		});
	}

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetConfiguration(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function (eventArgs) {
		SC.ui.setContents(document.querySelector('.DatabaseMaintenanceList'), [
			$dt(
				$h3({ _textResource: 'DatabasePanel.MaintenancePlanActionsText' }),
				$p({ className: 'CommandList' }, SC.command.createCommandButtons([{ commandName: 'CreateAction' }])),
			),
			$dd($table({ className: 'DataTable' },
				$tr($th(), $th({ _textResource: 'DatabasePanel.MaintenancePlanActionDescriptionText' })),
				eventArgs.pageData.MaintenancePlan.Actions.length === 0
					? $tr($td({ colSpan: 2, _textResource: 'DatabasePanel.EmptyText' }))
					: eventArgs.pageData.MaintenancePlan.Actions.map(function (action) {
						return $tr({ _dataItem: { action: action } },
							$td({ className: 'ActionCell' },
								SC.command.createCommandButtons([
									{ commandName: 'EditAction', _dataItem: { action: action } },
									{ commandName: 'DeleteAction', _dataItem: { action: action } }
								])
							),
							$td(SC.util.formatString(
								SC.res['DatabasePanel.ActionDescriptions.' + SC.util.getEnumValueName(SC.types.DatabaseMaintenanceActionType, action.ActionType)],
								SC.util.formatString(SC.res['DatabasePanel.' + (action.Parameters.DaysAgo === 1 ? 'OneDayAgoText' : 'ManyDaysAgoText')], action.Parameters.DaysAgo), // {0} days
								SC.util.getEnumValueName(SC.types.SessionType, action.Parameters.SessionType), // {1} session type
								!action.Parameters.ConnectionTypes ? '' : action.Parameters.ConnectionTypes
									.map(it => SC.util.getEnumValueName(SC.types.ProcessType, it))
									.join(SC.res['DatabasePanel.ActionDescriptions.PurgeSessionConnections.ConnectionTypesContraction']), // {2} connection types
								doesActionTypeUseSessionOrSecurityEvents(action.ActionType) == null
									? ''
									: doesActionTypeUseSessionOrSecurityEvents(action.ActionType)
										? SC.ui.getTextForOptions(action.Parameters.SessionEventTypesIncludedOrExcluded, action.Parameters.SessionEventTypes, 'SessionEventTypes', SC.types.SessionEventType)
										: SC.ui.getTextForOptions(action.Parameters.SecurityEventTypesIncludedOrExcluded, action.Parameters.SecurityEventTypes, 'SecurityEventTypes', SC.types.SecurityEventType) // {3} event types
							))
						);
					})
			)),

			$dt($h3({ _textResource: 'DatabasePanel.MaintenancePlanScheduleText' })),
			$dd(
				$span(SC.util.formatString(
					SC.res[
						(eventArgs.pageData.MaintenancePlan.Days.length === 0 && eventArgs.pageData.MaintenancePlan.DaysIncludedOrExcluded)
						|| (eventArgs.pageData.MaintenancePlan.Days.length === 7 && !eventArgs.pageData.MaintenancePlan.DaysIncludedOrExcluded)
							? 'DatabasePanel.Schedule.TextPlanDisabled'
							: 'DatabasePanel.Schedule.Text'
					],
					SC.ui.getTextForOptions(eventArgs.pageData.MaintenancePlan.DaysIncludedOrExcluded, eventArgs.pageData.MaintenancePlan.Days, 'RunFrequency', SC.types["DayOfWeek"]),
					SC.util.formatMinutesSinceMidnightUtcToTimeString(eventArgs.pageData.MaintenancePlan.RunAtUtcTimeMinutes, { utcOrLocal: true, showTimeZone: true }),
					SC.util.formatMinutesSinceMidnightUtcToTimeString(eventArgs.pageData.MaintenancePlan.RunAtUtcTimeMinutes, { utcOrLocal: false, showTimeZone: true }),
				)),
				SC.command.createCommandButtons([{ commandName: 'EditSchedule', _dataItem: { maintenancePlan: eventArgs.pageData.MaintenancePlan } }])
			)
		]);
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		var pageData = SC.pagedata.get();
		var dataItem = SC.command.getEventDataItem(eventArgs);
		var action = dataItem == null ? null : dataItem.action;

		switch (eventArgs.commandName) {
			case 'CreateAction':
			case 'EditAction':
				var createOrEdit = action == null;

				if (createOrEdit)
					action = { ActionType: SC.types.DatabaseMaintenanceActionType.PurgeDeletedSessions, Parameters: {} };

				// Fill in missing parameters' default values
				SC.util.difference(Object.keys(pageData.MaintenancePlanParameterDefinitions), Object.keys(action.Parameters)).forEach(function (parameterName) {
					action.Parameters[parameterName] = pageData.MaintenancePlanParameterDefinitions[parameterName].DefaultValue;
				});

				function createParameterInput(resourceKeyPrefix, parameterName, ddBodyFunc) {
					return [
						$dt({ className: parameterName, _textResource: resourceKeyPrefix + parameterName + 'LabelText' }),
						$dd({ className: parameterName }, ddBodyFunc(parameterName))
					];
				}

				function createParameterSelectElement(parameterName, parameterValue) {
					return $select({ _commandName: parameterName }, [
						pageData.MaintenancePlanParameterDefinitions[parameterName].SelectableValues.map(function (value) {
							return $option({
								value: value,
								_textResource: 'EditActionPanel.' + parameterName + SC.util.getEnumValueName(SC.types[pageData.MaintenancePlanParameterDefinitions[parameterName].EnumTypeIfApplicable], value) + 'Text',
								selected: value === parameterValue
							});
						}),
					]);
				}

				SC.dialog.showModalDialog('EditAction', {
					titleResourceName: createOrEdit ? 'EditActionPanel.CreateTitle' : 'EditActionPanel.EditTitle',
					content: $dl(
						createParameterInput('EditActionPanel.', 'ActionType', function (parameterName) {
							return createParameterSelectElement(parameterName, action[parameterName]);
						}),
						createParameterInput('EditActionPanel.', 'DaysAgo', function (parameterName) {
							return [
								$input({ type: 'number', min: '0', value: action.Parameters[parameterName], _commandName: parameterName }),
								$span({ _textResource: 'EditActionPanel.' + parameterName + 'Text' })
							];
						}),
						createParameterInput('EditActionPanel.', 'SessionType', function (parameterName) {
							return createParameterSelectElement(parameterName, action.Parameters[parameterName]);
						}),
						createParameterInput('EditActionPanel.', 'ConnectionTypes', function (parameterName) {
							return pageData.MaintenancePlanParameterDefinitions[parameterName].SelectableValues.map(function (value) {
								return $label([
									$input({
										type: 'checkbox', value: value, _commandName: parameterName + 'Toggle',
										checked: action.Parameters[parameterName].includes(value)
									}),
									$span(SC.util.getEnumValueName(SC.types.ProcessType, value)),
								]);
							});
						}),
						createParameterInput('EditActionPanel.', 'SessionEventTypes', function (parameterName) {
							return SC.ui.createMultiselectBox(
								parameterName,
								action.Parameters.SessionEventTypesIncludedOrExcluded,
								action.Parameters.SessionEventTypes,
								SC.types[pageData.MaintenancePlanParameterDefinitions.SessionEventTypes.EnumTypeIfApplicable],
								pageData.MaintenancePlanParameterDefinitions.SessionEventTypes.SelectableValues,
							);
						}),
						createParameterInput('EditActionPanel.', 'SecurityEventTypes', function (parameterName) {
							return SC.ui.createMultiselectBox(
								parameterName,
								action.Parameters.SecurityEventTypesIncludedOrExcluded,
								action.Parameters.SecurityEventTypes,
								SC.types[pageData.MaintenancePlanParameterDefinitions.SecurityEventTypes.EnumTypeIfApplicable],
								pageData.MaintenancePlanParameterDefinitions.SecurityEventTypes.SelectableValues,
							);
						}),
					),
					buttonTextResourceName: 'EditActionPanel.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						var element = dialogEventArgs.clickedElement;

						switch (dialogEventArgs.commandName) {
							case 'ActionType':
								setVisibilityOfParametersBasedOnActionType(parseInt(element.value), pageData.MaintenancePlanParameterDefinitions);
								break;

							case 'Default':
								action.ActionType = parseInt(dialog.querySelector('dd.ActionType select').value);
								action.Parameters.DaysAgo = parseInt(dialog.querySelector('dd.DaysAgo input').value);
								action.Parameters.SessionType = parseInt(dialog.querySelector('dd.SessionType select').value);
								action.Parameters.ConnectionTypes = Array.from(dialog.querySelectorAll('dd.ConnectionTypes input[type=checkbox]:checked')).map(function (_) { return _.value; });

								var actionTypeUsesSessionOrSecurityEvent = doesActionTypeUseSessionOrSecurityEvents(action.ActionType)

								if (actionTypeUsesSessionOrSecurityEvent != null) {
									var multiselectBoxValues = SC.ui.getValuesFromMultiselectBox(dialog.querySelector(`dd.${actionTypeUsesSessionOrSecurityEvent ? 'SessionEventTypes' : 'SecurityEventTypes'} .MultiselectBox`));

									if (actionTypeUsesSessionOrSecurityEvent) {
										action.Parameters.SessionEventTypes = multiselectBoxValues.includedOrExcludedValues;
										action.Parameters.SessionEventTypesIncludedOrExcluded = multiselectBoxValues.includedOrExcluded;
									} else {
										action.Parameters.SecurityEventTypes = multiselectBoxValues.includedOrExcludedValues;
										action.Parameters.SecurityEventTypesIncludedOrExcluded = multiselectBoxValues.includedOrExcluded;
									}
								}

								SC.service.SaveAction(
									action,
									function () { SC.dialog.showModalActivityAndReload('Save', true); },
									setDialogErrorProc
								);

								break;
						}
					},
				});
				setVisibilityOfParametersBasedOnActionType(action.ActionType, pageData.MaintenancePlanParameterDefinitions);
				break;
			case 'DeleteAction':
				SC.dialog.showConfirmationDialog(
					'DeleteAction',
					SC.res['DeleteActionPanel.Title'],
					$p({ _htmlResource: 'DeleteActionPanel.Text' }),
					SC.res['DeleteActionPanel.ButtonText'],
					function (onSuccess, onFailure) {
						SC.service.DeleteAction(
							action.ActionID,
							function () {
								onSuccess();
								SC.dialog.showModalActivityAndReload('Save', true);
							},
							onFailure
						);
					}
				);
				break;
			case 'EditSchedule':
				if (dataItem == null)
					break;
				var re24HourTime = /^([1-9]|[0-1][0-9]|2[0-3]):[0-5][0-9]$/;
				var maintenancePlan = dataItem.maintenancePlan;
				var selectableDays = Object.values(SC.types["DayOfWeek"]);
				var runAtUtcTimeMinutes = maintenancePlan.RunAtUtcTimeMinutes;
				var daysIncludedOrExcluded = maintenancePlan.DaysIncludedOrExcluded;
				var days = maintenancePlan.Days;

				SC.dialog.showModalDialog('EditSchedule', {
					titleResourceName: 'EditSchedulePanel.Title',
					content: [
						$dl(
							createParameterInput('EditSchedulePanel.', 'RunFrequency', function (parameterName) {
								return SC.ui.createMultiselectBox(
									parameterName,
									maintenancePlan.DaysIncludedOrExcluded,
									maintenancePlan.Days,
									SC.types["DayOfWeek"],
									selectableDays,
									null,
									2
								);
							}),
							createParameterInput('EditSchedulePanel.', 'RunAtTime', function(parameterName) {
								let runAtUtcTimeString = SC.util.formatMinutesSinceMidnightUtcToTimeString(maintenancePlan.RunAtUtcTimeMinutes, { utcOrLocal: true, showTimeZone: false });
								let timeZoneLabel = SC.util.getTimeZoneName(true);
								return [
									SC.ui.createEditableInput(
										'ChangeTime',
										{ type: 'text', className: 'RunAtTimeInput', pattern: re24HourTime.source, value: runAtUtcTimeString, _commandName: parameterName },
										null,
										null,
										true
									),
									$span(timeZoneLabel),
									$p({ className: 'LocalTimeText' }, SC.util.formatMinutesSinceMidnightUtcToTimeString(maintenancePlan.RunAtUtcTimeMinutes, { utcOrLocal: false, showTimeZone: true })),
								];
							}),
						)
					],
					buttonTextResourceName: 'EditSchedulePanel.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						var element = dialogEventArgs.clickedElement;
						var multiselectBoxValues = SC.ui.getValuesFromMultiselectBox(dialog.querySelector('dd.RunFrequency .MultiselectBox'));
						switch (dialogEventArgs.commandName) {
							case 'ToggleAll':
							case 'ToggleCheckbox':
								daysIncludedOrExcluded = multiselectBoxValues.includedOrExcluded;
								days = multiselectBoxValues.includedOrExcludedValues;
								break;
							case 'ChangeTime':
								let runAtUtcTimeString = element.value;

								if (re24HourTime.test(runAtUtcTimeString)) {
									var hoursAndMinutes = runAtUtcTimeString.split(':');
									runAtUtcTimeMinutes = Number(hoursAndMinutes[0]) * 60 + Number(hoursAndMinutes[1]);
									SC.ui.setContents($('.LocalTimeText'), SC.util.formatMinutesSinceMidnightUtcToTimeString(runAtUtcTimeMinutes, { utcOrLocal: false, showTimeZone: true }));
								} else
									runAtUtcTimeMinutes = NaN;
								break;
							case 'Default':
								if (isNaN(runAtUtcTimeMinutes))
									setDialogErrorProc({ message: SC.res['EditSchedulePanel.TimeFormatErrorMessage'] });
								else
									SC.service.SaveSchedule(
										runAtUtcTimeMinutes,
										daysIncludedOrExcluded,
										days,
										() => SC.dialog.showModalActivityAndReload('Save', true),
										setDialogErrorProc
									);
								break;
						}
					},
				});
				break;
		}
	});

</script>
