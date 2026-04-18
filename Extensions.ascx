<%@ Control %>

<div class="ExtensionsPanel"></div>

<script>

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetExtensionInfos(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
		var extensionInfos = SC.pagedata.get();
		var extensionButtonDefinitions = SC.command.queryCommandButtons('ExtensionsPanel');
		var allExtensionsButtonDefinitions = SC.command.queryCommandButtons('AllExtensionsPanel');

		SC.ui.setContents(document.querySelector('.ExtensionsPanel'),
			$dl([
				$dt([
					$h3({ _textResource: 'ExtensionsPanel.InstalledExtensionsText' }),
					$p({ className: 'CommandList' }, SC.command.createCommandButtons(allExtensionsButtonDefinitions)),
				]),
				$dd({ _classNameMap: { Empty: !extensionInfos.length } }, [
					$div({ className: 'EmptyPanel' }, [
						$p($img({ src: 'Images/EmptyExtension.svg' })),
						$div({ _htmlResource: 'ExtensionsPanel.EmptyMessage' }),
					]),
					Object.entries(extensionInfos.groupBy(function (extensionInfo) {
						return extensionInfo.Status == SC.types.ExtensionRuntimeStatus.Active;
					}))
						.map(function (_) {
							return {
								isActive: _[0] == 'true',
								matchingExtensionInfos: _[1],
							};
						})
						.sort((a, b) => a.isActive && !b.isActive ? -1 : 1)
						.map(function (_) {
							var panelName = _.isActive ? 'Active' : 'Inactive';
							return SC.ui.createCollapsiblePanel(
								$h3(SC.res['ExtensionsPanel.' + panelName + 'Text'] + ' (' + _.matchingExtensionInfos.length + ')'),
								_.matchingExtensionInfos.map(function (ei) {
									return $div({ _dataItem: ei, className: 'ExtensionPanel Card ' + SC.util.getEnumValueName(SC.types.ExtensionRuntimeStatus, ei.Status) }, [
										$img({ src: SC.ui.createDataUri(ei.PromotionalImageDataString) }),
										$div({ className: 'CommandPanel' }, SC.command.createCommandButtons(extensionButtonDefinitions)),
										$h3(ei.Name),
										$p([
											$span({ title: ei.LoadMessage || '' }, SC.util.formatString(SC.res['ExtensionsPanel.StatusLabelFormat'], SC.res['ExtensionsPanel.Status' + SC.util.getEnumValueName(SC.types.ExtensionRuntimeStatus, ei.Status) + 'Text'])),
											$span(SC.util.formatString(SC.res['ExtensionsPanel.VersionLabelFormat'], ei.Version)),
											$span(SC.util.formatString(SC.res['ExtensionsPanel.AuthorLabelFormat'], ei.Author)),
										]),
										$p({ title: ei.ShortDescription }, ei.ShortDescription),
									]);
								}),
								!_.isActive, // Collapse Inactive panel by default
								panelName
							);
						})
				]),
			])
		);

		Array.prototype.forEach.call(document.querySelectorAll('.ExtensionsPanel .CommandPanel'), function (cp) {
			SC.command.updateCommandButtonsState(cp, { extensionInfo: SC.command.getDataItem(cp) });
		});

		SC.command.updateCommandButtonsState(document.querySelector('.ExtensionsPanel .CommandList'));
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		var extensionInfo = SC.command.getEventDataItem(eventArgs);

		switch (eventArgs.commandName) {
			case 'DevelopExtension':
			case 'Options':
				SC.popout.showPanelFromCommand(eventArgs, { extensionInfo: SC.command.getEventDataItem(eventArgs) });
				break;
			case 'UninstallExtension':
				SC.dialog.showModalPromptCommandBox(eventArgs.commandName, false, false, function (data, onSuccess, onFailure) {
					SC.service.UninstallExtension(
						extensionInfo.ExtensionID,
						function () {
							onSuccess();
							SC.dialog.showModalActivityAndReload(null, false);
						},
						onFailure
					);
				});
				break;
			case 'Enable':
			case 'Disable':
				SC.service.SetExtensionEnabled(
					extensionInfo.ExtensionID,
					eventArgs.commandName === 'Enable',
					function () { SC.dialog.showModalActivityAndReload(null, false); },
				);
				break;
			case 'EditExtensionSettings':
				SC.dialog.showModalDialog('EditExtensionSettings', {
					titleResourceName: 'ExtensionsPanel.EditSettings.Title',
					content: [
						$div($p({ _textResource: 'ExtensionsPanel.EditSettings.Message' })),
						$table({ className: 'DataTable' }, [
							$thead(
								$tr([
									$th({ _textResource: 'ExtensionsPanel.EditSettings.KeyHeaderText' }),
									$th({ _textResource: 'ExtensionsPanel.EditSettings.DescriptionHeaderText' }),
									$th({ _textResource: 'ExtensionsPanel.EditSettings.ValueHeaderText' }),
								])
							),
							$tbody(
								extensionInfo.Settings.map(function (s) {
									function createValueDisplayTableCell() {
										switch (s.ValueUserInterfaceMode) {
											case 0: // Editable
												return $td([
													SC.ui.createDefaultCustomSelector(
														s.ConfigurationValue !== null,
														SC.ui.createTextBox({ value: s.DefaultValue, disabled: true }, true),
														SC.ui.createTextBox({ value: s.ConfigurationValue }, true),
														function (textBox) { return textBox.value.trim(); }
													),
												]);
											case 1: // Readonly
												return $td([
													$div(SC.util.isNullOrEmpty(s.ValueUserInterfaceModeDescription) ? $p({ className: 'SettingValueUserInterfaceModeDescriptionText', _textResource: 'ExtensionsPanel.EditSettings.ValueReadOnlyText' }) : $p({ className: 'SettingValueUserInterfaceModeDescriptionText' }, s.ValueUserInterfaceModeDescription)),
													SC.ui.createTextBox({ value: s.ConfigurationValue ? s.ConfigurationValue.trim() : null, disabled: true, readOnly: true }, true),
												]);
											case 2: // Hidden
												return $td([
													$div(SC.util.isNullOrEmpty(s.ValueUserInterfaceModeDescription) ? $p({ className: 'SettingValueUserInterfaceModeDescriptionText', _textResource: 'ExtensionsPanel.EditSettings.ValueHiddenText' }) : $p({ className: 'SettingValueUserInterfaceModeDescriptionText' }, s.ValueUserInterfaceModeDescription)),
												]);
										}
									}

									return $tr({ _dataItem: s }, [
										$td(s.Name),
										$td(s.Description),
										createValueDisplayTableCell(),
									]);
								})
							),
						]),
					],
					buttonTextResourceName: 'ExtensionsPanel.EditSettings.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.SaveExtensionSettingValues(
							extensionInfo.ExtensionID,
							Array.from(SC.ui.findDescendentByTag(dialog, 'TBODY').childNodes).reduce((settingValues, row) => {
								settingValues[row._dataItem.Name] = row._dataItem.ValueUserInterfaceMode === SC.types.ExtensionSettingValueUserInterfaceMode.Editable
									? SC.ui.getCustomValueFromDefaultCustomSelector(row)
									: row._dataItem.ConfigurationValue;
								return settingValues;
							}, {}),
							function () {
								closeDialogProc();
								SC.dialog.showModalActivityAndReload('Save', false);
							},
							setDialogErrorProc
						);
					},
				});
				break;
			case 'ShowExtensionBrowser':
				SC.dialog.showModalPage(
					SC.res['ExtensionsPanel.ExtensionBrowser.Title'],
					SC.res['ExtensionsPanel.BaseUrl'] + 'Extension-Browse' + SC.util.getQueryString({ Select: eventArgs.commandArgument }),
					function () {
						if (window._needsReloadOnExtensionBrowserExit) {
							SC.dialog.showModalActivityAndReload(null, false);
							return true; // stop propagation of escape key handling to prevent reload modal from immediately closing
						}
					}
				);
				break;
		}
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
		switch (eventArgs.area) {
			case 'OptionsPopoutPanel':
				eventArgs.buttonDefinitions.push(
					{ commandName: 'Enable' },
					{ commandName: 'Disable' },
					{ commandName: 'UninstallExtension' },
					{ commandName: 'EditExtensionSettings' }
				);
				break;
			case 'ExtensionsPanel':
				eventArgs.buttonDefinitions.push(
					{ commandName: 'DevelopExtension' },
					{ commandName: 'Options' }
				);
				break;
			case 'AllExtensionsPanel':
				eventArgs.buttonDefinitions.push(
					{ commandName: 'ShowExtensionBrowser' },
					{ commandName: 'ShowExtensionBrowser', commandArgument: 'Installed' }
				);
				break;
		}
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtonState, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'Options':
			case 'DevelopExtension':
				eventArgs.isVisible = SC.popout.computePopoutCommandsVisible(eventArgs);
				break;
			case 'Enable':
			case 'Disable':
				eventArgs.isVisible = !eventArgs.commandContext.extensionInfo.IsEnabled == (eventArgs.commandName == 'Enable');
				break;
			case 'EditExtensionSettings':
				eventArgs.isEnabled = eventArgs.commandContext.extensionInfo.Settings.length != 0;
				break;
			case 'ShowExtensionBrowser':
				eventArgs.allowsUrlExecution = true;
				if (eventArgs.commandArgument == 'Installed')
					eventArgs.isVisible = !!document.querySelector('.ExtensionsPanel .ExtensionPanel');
				break;
		}
	});

	SC.event.addHandler(window, 'message', function (eventArgs) {
		if ($$('iframe').some(function (_) { return _.src.startsWith(eventArgs.origin); })) {
			switch (eventArgs.data.commandName) {
				case 'QueryUrl':
					eventArgs.source.postMessage({
						commandName: 'ProcessUrl',
						commandArgument: window.location.href,
					}, '*');
					break;
				case 'QueryInstanceUserInfo':
					SC.service.GetInstanceUserInfo(function (instanceUserInfo) {
						eventArgs.source.postMessage({
							commandName: 'ProcessInstanceUserInfo',
							commandArgument: instanceUserInfo,
						}, '*');
					});
					break;
				case 'QueryReviewSignature':
					SC.service.SignReview(eventArgs.data.commandArgument.reviewComment, eventArgs.data.commandArgument.reviewerDisplayName, eventArgs.data.commandArgument.reviewRating, function (reviewSignature) {
						eventArgs.source.postMessage({
							commandName: 'ProcessReviewSignature',
							commandArgument: SC.util.combineObjects(eventArgs.data.commandArgument, { reviewSignature: reviewSignature }),
						}, '*');
					});
					break;
				case 'QueryCommandCapable':
					var queryEventArgs = SC.event.dispatchEvent(
						null,
						SC.event.QueryCommandButtonState,
						{ commandName: eventArgs.data.commandArgument, isEnabled: false }
					);

					eventArgs.source.postMessage({
						commandName: 'ProcessCommandCapable',
						commandArgument: {
							commandName: eventArgs.data.commandArgument,
							isCapable: queryEventArgs.isEnabled,
						}
					}, '*');
					break;
				case 'QueryExtensionContent': // TODO so, this calls a service method in an extension which is not correct, so remove from here once we can be sure that people have updated their extensions to have this handler
					SC.service.GetExtensionPackageContent(eventArgs.data.commandArgument, function (packageContent) {
						eventArgs.source.postMessage({
							commandName: 'ProcessExtensionContent',
							commandArgument: packageContent,
						}, '*');
					});
					break;
				case 'QueryBasicLicenseCapabilities':
					SC.service.GetBasicLicenseCapabilities(function (basicLicenseCapabilities) {
						eventArgs.source.postMessage({
							commandName: 'ProcessBasicLicenseCapabilities',
							commandArgument: basicLicenseCapabilities,
						}, '*');
					});
					break;
				case 'QueryInstalledExtensions':
					eventArgs.source.postMessage({
						commandName: 'ProcessInstalledExtensions',
						commandArgument: Array.prototype.map.call(document.querySelectorAll('.ExtensionsPanel .ExtensionPanel'), function (e) { return e._dataItem; }),
					}, '*');
					break;
				case 'InstallExtension':
					var populateExtensionInfosProc = function () {
						SC.service.GetExtensionInfos(
							function (extensionInfos) {
								eventArgs.source.postMessage({
									commandName: 'ProcessInstalledExtensions',
									commandArgument: extensionInfos,
								}, '*');
							},
							function (error) { window.setTimeout(populateExtensionInfosProc, 1000); }
						);
					}

					window._needsReloadOnExtensionBrowserExit = true;
					SC.service.InstallExtension(eventArgs.data.commandArgument, populateExtensionInfosProc);
					break;
			}
		}
	});

</script>
