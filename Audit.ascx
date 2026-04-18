<%@ Control %>

<dl class="AuditList"></dl>

<script>

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetAuditInfo(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
		window._sessionEventTypesFilterOptions = SC.util.combineObjects(SC.types.SessionEventType);
		delete window._sessionEventTypesFilterOptions.None; // 'None' is not really a session event type // TODO bad

		window._securityEventTypesFilterOptions = SC.util.combineObjects(SC.types.SecurityEventType);

		var auditInfo = SC.pagedata.get();
		SC.ui.setContents(document.querySelector('.AuditList'), [
			$dt({ _visible: auditInfo.HasExtendedAuditingCapability },
				$h3({ _textResource: 'AuditPanel.AuditLevelLabelText' })
			),
			$dd({ _visible: auditInfo.HasExtendedAuditingCapability }, [
				$button({ className: 'SecondaryButton', _commandName: 'ChangeAuditLevel', _textResource: SC.util.formatString('AuditPanel.{0}LevelTitle', SC.util.getEnumValueName(SC.types.AuditLevel, auditInfo.AuditLevel)) }),
			]),
			$dt(
				$h3({ _textResource: 'AuditPanel.QueryAuditLogLabelText' })
			),
			$dd([
				$dl([
					$dt({ _textResource: 'AuditPanel.TimeRangeBeginLabelText' }),
					$dd([
						SC.ui.createInputElement({ type: 'date', className: 'MinDateBox', value: SC.util.formatDateTimeToInputDate(SC.util.addDuration(new Date(), { months: -1 })) }),
						SC.ui.createInputElement({ type: 'time', className: 'MinTimeBox', value: SC.util.formatDateTimeToInputTime(new Date()), step: 1 }),
					]),
					$dt({ _textResource: 'AuditPanel.TimeRangeEndLabelText' }),
					$dd([
						SC.ui.createInputElement({ type: 'date', className: 'MaxDateBox', value: SC.util.formatDateTimeToInputDate(SC.util.addDuration(new Date(), { days: 1 })) }),
						SC.ui.createInputElement({ type: 'time', className: 'MaxTimeBox', value: SC.util.formatDateTimeToInputTime(new Date()), step: 1 }),
					]),
					$dt({ _textResource: 'AuditPanel.SessionNameLabelText' }),
					$dd($input({ type: 'text', id: 'sessionNameBox' })),
					$dt({ _textResource: 'AuditPanel.SessionEventTypeLabelText' }),
					$dd(SC.ui.createMultiselectBox('SessionEventTypes', false, [], window._sessionEventTypesFilterOptions, null, 'SessionEventMultiselectBox')),
					$dt({ _textResource: 'AuditPanel.SecurityEventTypeLabelText' }),
					$dd(SC.ui.createMultiselectBox('SecurityEventTypes', false, [], window._securityEventTypesFilterOptions, null, 'SecurityEventMultiselectBox', 0)),
				]),
				$input({ className: 'QueryAuditLogButton', type: 'submit', _commandName: 'QueryAuditLog', value: SC.res['AuditPanel.QueryButtonText'] }),
				$div({ id: 'queryResultPanel' }),
			]),
		]);
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		var auditInfo = SC.pagedata.get();

		switch (eventArgs.commandName) {
			case 'QueryAuditLog':
				var minTime = SC.util.fromDateAndTimeValueStrings($('.MinDateBox').value, $('.MinTimeBox').value);
				var maxTime = SC.util.fromDateAndTimeValueStrings($('.MaxDateBox').value, $('.MaxTimeBox').value);
				var sessionName = $('sessionNameBox').value;
				var sessionEventMultiselectBoxObject = SC.ui.getValuesFromMultiselectBox($('.SessionEventMultiselectBox'));
				var sessionEventTypes = sessionEventMultiselectBoxObject.includedOrExcluded ? sessionEventMultiselectBoxObject.includedOrExcludedValues : SC.util.difference(sessionEventMultiselectBoxObject.includedOrExcludedValues, Object.values(window._sessionEventTypesFilterOptions));
				var securityEventMultiselectBoxObject = SC.ui.getValuesFromMultiselectBox($('.SecurityEventMultiselectBox'));
				var securityEventTypes = securityEventMultiselectBoxObject.includedOrExcluded ? securityEventMultiselectBoxObject.includedOrExcludedValues : SC.util.difference(securityEventMultiselectBoxObject.includedOrExcludedValues, Object.values(window._securityEventTypesFilterOptions));

				SC.css.ensureClass($('.QueryAuditLogButton'), 'Loading', true);

				SC.service.QueryAuditLog(minTime, maxTime, sessionName, sessionEventTypes, securityEventTypes, function (auditEntries) {
					if (!auditEntries || !auditEntries.length)
						SC.ui.setContents($('queryResultPanel'), $p({ _textResource: 'AuditPanel.EmptyQueryMessage' }));
					else {
						SC.ui.setContents($('queryResultPanel'),
							$table({ className: 'DataTable AuditTable' }, [
								$thead(
									$tr([
										$th({ _textResource: 'AuditPanel.TimeHeaderText' }),
										$th({ _textResource: 'AuditPanel.SessionHeaderText' }),
										$th({ _textResource: 'AuditPanel.EventHeaderText' }),
										$th({ _textResource: 'AuditPanel.DetailHeaderText' }),
									])
								),
								$tbody(
									auditEntries.map(function (auditEntry) {
										return $tr([
											$td(SC.util.formatDateTime(SC.util.tryGetDateTime(auditEntry.Time), { includeFullDate: true, includeSeconds: true })),
											$td(auditEntry.SessionName),
											$td(auditEntry.EventType),
											$td(
												auditEntry.mapKeyValue(function (key, value) {
													const keyText = SC.res[`AuditPanel.AuditEntry${key}LabelText`];
													if (keyText == null || value == null || value === '')
														return null;
														
													if (key === 'ProcessType' && value === SC.types.ProcessType.Unknown)
														return null; 

													if (key === 'ProcessType')
														value = SC.util.getEnumValueName(SC.types.ProcessType, value);

													if (key === 'OperationResult')
														value = SC.util.getEnumValueName(SC.types.SecurityOperationResult, value);

													let valueElement = $span(value);

													if (key === 'DownloadUrl')
														valueElement = $a(SC.res['AuditPanel.AuditEntryDownloadUrlLinkText'], { href: value, target: '_blank' });

													return $p([
														$span({ className: 'AuditTableEntryLabel' }, keyText),
														$span({ className: 'AuditTableEntryValue' }, valueElement),
													]);
												})
											),
										]);
									})
								),
							])
						);
					}

					SC.css.ensureClass($('.QueryAuditLogButton'), 'Loading', false);
				});
				break;

			case 'ChangeAuditLevel':
				SC.dialog.showModalDialog('ChangeAuditLevel', {
					titleResourceName: 'ChangeAuditLevelPanel.Title',
					content: [
						Object.keys(SC.types.AuditLevel).map(function (_) {
							return $label([
								$input({ type: 'radio', name: 'AuditLevel', value: SC.types.AuditLevel[_], checked: auditInfo.AuditLevel === SC.types.AuditLevel[_] }),
								$h3({ _textResource: SC.util.formatString('AuditPanel.{0}LevelTitle', _) }),
								$p({ _textResource: SC.util.formatString('AuditPanel.{0}LevelDescription', _) }),
							]);
						}),
					],
					buttonTextResourceName: 'ChangeAuditLevelPanel.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.ApplyAuditLevel(
							SC.ui.getSelectedRadioButtonValue(dialog),
							function () { SC.dialog.showModalActivityAndReload('Save', true); },
							setDialogErrorProc
						);
					},
				});
				break;
		}
	});

</script>
