<%@ Control Language="C#" %>

<dl class="LicenseList" />

<script>

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetLicenseInfo(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
		var licenseInfo = SC.pagedata.get();
		SC.ui.setContents(document.querySelector('.LicenseList'), [
			$dt([
				$h3({ _textResource: 'LicensePanel.CurrentLicenseText' }),
				$p({ className: 'CommandList' },
					SC.command.createCommandButtons([
						{ commandName: 'AddLicense' },
					])
				),
			]),
			$dd([
				licenseInfo.LicenseRuntimeInfos.length ?
					licenseInfo.LicenseRuntimeInfos.map(function (l) {
						const millisecondsPerDay = 24 * 60 * 60 * 1000;
						var daysUntilValidForReleasesIssuedBeforeDate = l.ValidForReleasesIssuedBeforeDate ?
							Math.floor((new Date(l.ValidForReleasesIssuedBeforeDate) - new Date()) / millisecondsPerDay)
							: null;

						return $div({
							_dataItem: l,
							_classNameMap: {
								'LicensePanel': true,
								'Card': true,
								'Invalid': l.InitializationErrorMessage,
								'Valid': !l.InitializationErrorMessage,
								'ShowWarningMessage': daysUntilValidForReleasesIssuedBeforeDate && daysUntilValidForReleasesIssuedBeforeDate < 30,
							},
						}, [
							$img({ src: 'Images/LicenseIcon.png' }),
							$div({ className: 'CommandPanel' }, SC.command.queryAndCreateCommandButtons('LicensePanel')),
							$h3({ _textResource: 'LicensePanel.LicenseHeaderText' }),
							$p([
								$span({ _classNameMap: { 'ErrorText': l.InitializationErrorMessage } }, SC.util.formatString(SC.res['LicensePanel.ValidationStatusHeaderTextFormat'], l.InitializationErrorMessage || SC.res['LicensePanel.ValidationStatusNullDisplayText'])),
								$span(SC.util.formatString(SC.res['LicensePanel.UsageReportHeaderTextFormat'], l.UsageReport)),
							]),
							$p(l.LicenseDescription),
							daysUntilValidForReleasesIssuedBeforeDate ?
								$div({ className: 'Warning' }, [
									$span(daysUntilValidForReleasesIssuedBeforeDate <= 0 ? SC.res['LicensePanel.IsOutOfMaintenanceWarningMessage'] : SC.util.formatString(SC.res['LicensePanel.WillBeOutOfMaintenanceWarningMessageFormat'], daysUntilValidForReleasesIssuedBeforeDate)),
									$input({ type: 'button', value: SC.res['Command.UpgradeLicense.Text'], _commandName: 'UpgradeLicense' }),
								])
								: null,
						]);
					})
					: $div({ className: 'EmptyPanel' }, [
						$p($img({ src: 'images/EmptyLicense.svg' })),
						$h2({ _textResource: 'LicensePanel.EmptyHeader' }),
						$p({ _textResource: 'LicensePanel.EmptyText' }),
						$input({ type: 'button', value: SC.res['LicensePanel.PurchaseText'], _commandName: 'UpgradeLicense' }),
					]),
			]),
		]);
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'RemoveLicense':
				SC.dialog.showModalPromptCommandBox(eventArgs.commandName, false, false, function (data, onSuccess, onError) {
					SC.service.RemoveLicense(SC.command.getEventDataItem(eventArgs).LicenseID, function () {
						onSuccess();
						SC.pagedata.notifyDirty();
					}, onError);
				});
				break;
			case 'AddLicense':
				SC.dialog.showModalPromptCommandBox(eventArgs.commandName, true, true, function (data, onSuccess, onError) {
					if (data) {
						SC.service.AddLicense(data, function () {
							onSuccess();
							SC.pagedata.notifyDirty();
						}, onError);
					} else {
						onError(new Error(SC.res['ModalPromptCommandBox.Error.EmptyData']));
					}
				});
				break;
			case 'UpgradeLicense':
				SC.http.performWithServiceContext(true, function () {
					SC.service.GetUpgradeUrl(function (url) {
						window.open(SC.util.sanitizeUrl(url));
					})
				});
				break;
			case 'Options':
				SC.popout.showPanelFromCommand(eventArgs, { licenseInfo: SC.command.getEventDataItem(eventArgs) });
				break;
		}
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
		switch (eventArgs.area) {
			case 'OptionsPopoutPanel':
				eventArgs.buttonDefinitions.push(
					{ commandName: 'RemoveLicense' },
					{ commandName: 'UpgradeLicense' },
				);
				break;
			case 'LicensePanel':
				eventArgs.buttonDefinitions.push(
					{ commandName: 'Options' }
				);
				break;
		}
	});

</script>
