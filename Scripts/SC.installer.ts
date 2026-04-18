// @ts-nocheck

export function getSortedInstallerTypeInfos() {
	return Object.keys(SC.res)
		.filter(function (_) { return _.indexOf('BuildInstallerPanel.InstallerType.') === 0; })
		.orderBy()
		.map(function (_) { return { type: _.match(/[a-z]+$/)[0], text: SC.res[_] } });
}

export function getSessionNameFromEditFields(editFieldDefinitionList) {
	return SC.editfield.getOptionValue(editFieldDefinitionList, 'Name') === 'M' ? '' : SC.editfield.getTextValue(editFieldDefinitionList, 'Name');
}

export function getSessionCustomPropertyValuesFromEditFields(editFieldDefinitionList) {
	return SC.util.range(0, SC.context.customPropertyCount)
		.map(SC.util.getCustomPropertyName)
		.map(function (_) { return SC.editfield.getTextValue(editFieldDefinitionList, _); });
}

export function showDialog(className, resourcePrefix, extraContentPanelContent, defaultButtonTextUnprefixedResourceName, dialogProc, onChangeProc) {
	var installerValueList;
	var visibleCustomPropertyIndices = SC.util.getVisibleCustomPropertyIndices(SC.types.SessionType.Access);

	SC.dialog.showModalDialogRaw(className, [
		SC.dialog.createTitlePanel(SC.res[resourcePrefix + '.Title']),
		SC.dialog.createContentPanel([
			$p({ _textResource: resourcePrefix + '.Paragraph1Message' }),
			$p({ _textResource: resourcePrefix + '.Paragraph2Message' }),
			installerValueList = $dl({ className: 'InstallerValueList' }, [
				SC.editfield.createEditField('Name', 'MS', 'M', null, null, onChangeProc),
				visibleCustomPropertyIndices.map(SC.util.getCustomPropertyName).map(function (_) { return SC.editfield.createEditField(_, null, null, null, null, onChangeProc); }),
			]),
			extraContentPanelContent
		]),
		defaultButtonTextUnprefixedResourceName ? SC.dialog.createButtonPanel(SC.res[resourcePrefix + '.' + defaultButtonTextUnprefixedResourceName]) : null,
	], function (eventArgs, dialog) {
		if (dialogProc)
			dialogProc(
				eventArgs,
				dialog,
				getSessionNameFromEditFields(installerValueList),
				getSessionCustomPropertyValuesFromEditFields(installerValueList)
			);
	});

	SC.service.GetDistinctCustomPropertyValues(visibleCustomPropertyIndices, SC.types.SessionType.Access, function (values) {
		if (values === undefined || values.length == 0) // IE made an array of empty to be a empty array
			values = new Array(visibleCustomPropertyIndices.length).fill("");

		for (var i = 0; i < visibleCustomPropertyIndices.length; i++)
			SC.editfield.setEditFieldHintValues(
				installerValueList,
				SC.util.getCustomPropertyName(visibleCustomPropertyIndices[i]),
				values[i]
			);
	});
}

export function showBuildDialog() {
	var installerTypeList, customPropertyValues;

	showDialog(
		'BuildInstaller',
		'BuildInstallerPanel',
		[
			$dl([
				$dt(SC.res['BuildInstallerPanel.InstallerTypeLabelText']),
				$dd(installerTypeList = $select(getSortedInstallerTypeInfos().map(function (i) { return new Option(i.text, i.type); }))),
			]),
			SC.ui.createSharePanel(
				'BuildInstallerPanel',
				'SendInstallerEmail',
				'CopyInstallerURL',
				'DownloadInstaller',
				function (onSuccessProc) {
					onSuccessProc(SC.util.getInstallerUrl(
						installerTypeList.options[installerTypeList.selectedIndex].value,
						getSessionNameFromEditFields($('.InstallerValueList')),
						getSessionCustomPropertyValuesFromEditFields($('.InstallerValueList'))
					));
				},
				function (url) {
					return {
						resourceBaseNameFormat: 'BuildInstallerPanel.',
						resourceNameFormatArgs: [],
						resourceFormatArgs: [SC.context.userDisplayName, url],
					};
				}
			),
		]
	);
}

export function showInstallAccessDialog(onSubmit) {
	showDialog(
		'InstallAccess',
		'InstallAccessPanel',
		$p({ _textResource: 'InstallAccessPanel.Paragraph3Message' }),
		'ButtonText',
		function (eventArgs, dialog, name, customPropertyValues) {
			onSubmit(
				SC.util.getInstallerQueryString(name, customPropertyValues, SC.context.clp),
				function () { SC.dialog.hideModalDialog(); },
				function (error) {
					var buttonPanel = SC.dialog.getButtonPanel(dialog);
					SC.dialog.setButtonPanelError(buttonPanel, error);
				}
			);
		}
	);
}
