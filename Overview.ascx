<%@ Control %>
<dl class="OverviewPanel"></dl>

<script>
	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetOverviewInfo(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function (eventArgs) {
		const overviewInfo = SC.pagedata.get();
		SC.ui.setContents($('.OverviewPanel'), [
			$div({ className: 'Dashboard' }, [
				$div({ className: 'MainColumn' }),
				$div({ className: 'SecondaryColumn' }),
			]),
		]);

		SC.dashboard.queryAndAddTiles($('.Dashboard .MainColumn'), 'MainColumn', overviewInfo);
		SC.dashboard.queryAndAddTiles($('.Dashboard .SecondaryColumn'), 'SecondaryColumn', overviewInfo);
	});

	SC.event.addGlobalHandler(SC.event.QueryPanels, function (eventArgs) {
		switch (eventArgs.area) {
			case 'MainColumn':
				let totalNumberOfInternalUsers;
				let numberOfInternalUsersWithPasswordQuestion;
				const internalUserSourceInfo = eventArgs.tileContext.UserSources.find(it => !it.IsExternal);
				if (internalUserSourceInfo) {
					totalNumberOfInternalUsers = internalUserSourceInfo.Users.length;
					numberOfInternalUsersWithPasswordQuestion = internalUserSourceInfo.Users.filter(it => Boolean(it.PasswordQuestion)).length;
				}
				const recentRevokedAccess = eventArgs.tileContext.AccessRevocationInfos.filter(revocationInfo => SC.util.tryGetDateTime(revocationInfo.EarliestValidIssueTime))
				const statusPanelDefinitions = [
					['Version', {
						'YourVersion': it => it.CheckedVersion,
						'LatestVersion': it => it.LatestVersion,
						'LatestEligibleVersion': it => it.LatestEligibleVersion,
						'DownloadLocation': it => $a({ href: it.DownloadLocation }, it.DownloadLocation),
					}],
					['WindowsFirewall', {
						'FirewallEnabled': it => it.IsFirewallEnabled.toString(),
						'WebServerAllowed': it => it.IsWebServerPortAllowed.toString(),
						'RelayAllowed': it => it.IsRelayPortAllowed.toString(),
					}],
					['ExternalAccessibility', {
						'WebServerTestUrl': it => it.WebServerUri,
						'WebServerError': it => it.WebServerErrorMessage,
						'RelayTestUrl': it => it.RelayUri,
						'RelayError': it => it.RelayErrorMessage,
					}],
					['BrowserUrl', {
						'Browsable': it => it.IsHostResolvable.toString(),
						'PossibleUrls': it => it.AlternateHosts.map(host => [
							$a({ href: window.location.href.replace(window.location.host.split(':')[0], host) }, host),
							$br()
						]),
					}],
					['WebServer', {
						'TestUrl': it => it,
					}],
					['Relay', {
						'TestUrl': it => it,
					}],
					['SessionManager', {
						'TestUrl': it => it,
					}],
				];

				eventArgs.tileDefinitions.push(
					{
						significance: 2,
						title: SC.res['OverviewPanel.StatusTile.Title'],
						fullSize: true,
						content: [
							SC.ui.createTabs('StatusTab', statusPanelDefinitions.map(definition => ({
								name: definition[0],
								link: $div({ className: 'Header', _dataItem: definition[0] }, [
									$span({ _textResource: `StatusPanel.${definition[0]}CheckHeading` }),
								]),
								content: $div([
									$p({ _htmlResource: `StatusPanel.${definition[0]}CheckMessage` }),
									$dl({ className: 'StatusTestPanel', _dataItem: definition[0] }, Object.keys(definition[1]).map(p => [
										$dt({ _textResource: `StatusPanel.${p}Text` }),
										$dd({ _dataItem: definition[1][p] }),
									])),
								]),
							}))),
						],
						initializeProc: function (statusTab) {
							const updateStatusTileProc = function (statusCheckName, result, data, errorMessage) {
								const statusTestPanel = SC.ui.findDescendent(statusTab, it => it.className && it.className.includes('StatusTestPanel') && it._dataItem === statusCheckName);
								const headerPanel = SC.ui.findDescendent(statusTab, it => it.className && it.className.includes('Header') && it._dataItem === statusCheckName);

								Object.keys(SC.types.TestResult).forEach(it => SC.css.ensureClass(statusTestPanel, it, result === SC.types.TestResult[it]));
								headerPanel.title = errorMessage || '';
								SC.css.ensureClass(headerPanel, SC.util.getEnumValueName(SC.types.TestResult, result), true);

								SC.ui.findDescendent(statusTestPanel, it => {
									if (it._dataItem && data)
										SC.ui.setContents(it, it._dataItem(data));
								});
							};

							statusPanelDefinitions.forEach(function (definition) {
								updateStatusTileProc(definition[0], SC.types.TestResult.Incomplete);

								SC.service.PerformStatusCheck(
									definition[0],
									result => updateStatusTileProc(definition[0], result.Result, result.Data, result.ErrorMessage),
									error => updateStatusTileProc(definition[0], SC.types.TestResult.Error, null, error.message)
								);
							});
						},
					},
					SC.context.tabKeys.includes('Security') ? {
						significance: 1,
						title: SC.res['OverviewPanel.SecurityTile.Title'],
						titlePanelExtra: $a({ href: '/Administration?Tab=Security', _textResource: 'OverviewPanel.EditSettings.ButtonText' }),
						content: [
							$dl([
								$dt({ _textResource: 'OverviewPanel.SecurityTile.UserSourcesLabel' }),
								$dd([
									eventArgs.tileContext.UserSources
										.filter(it => it.IsEnabled)
										.map(it => it.ResourceKey)
										.map(it => SC.res[`SecurityPanel.${it}.Heading`])
										.join(', '),
								]),
								internalUserSourceInfo
									? [
										$dt({ _textResource: 'OverviewPanel.SecurityTile.InternalUsersLabel' }),
										$dd([
											SC.ui.createBarGraph(100 * numberOfInternalUsersWithPasswordQuestion / totalNumberOfInternalUsers),
											SC.util.formatString(SC.res['OverviewPanel.SecurityTile.InternalUsersWith2FAFormat'], numberOfInternalUsersWithPasswordQuestion, totalNumberOfInternalUsers),
										]),
									]
									: null,
								$dt({ _textResource: 'OverviewPanel.SecurityTile.RevokedAccessLabel' }),
								$dd([
									recentRevokedAccess.length > 0
										? recentRevokedAccess.map(it => $p(SC.util.formatString(
											SC.res['OverviewPanel.SecurityTile.RevokedAccessFormat'],
											SC.res[`SecurityPanel.${it.Name}Label`],
											SC.util.formatDateTime(SC.util.tryGetDateTime(it.EarliestValidIssueTime), { includeFullDate: true, includeSeconds: true })
										)))
										: SC.res['SecurityPanel.EarliestValidIssueTimeNeverRevokedText'],
								]),
							]),
						],
					} : null
				);
				break;

			case 'SecondaryColumn':
				eventArgs.tileDefinitions.push({
					significance: 2,
					title: SC.res['OverviewPanel.DatabaseTile.Title'],
					titlePanelExtra: $a({ href: '/Administration?Tab=Database', _textResource: 'OverviewPanel.EditSettings.ButtonText' }),
					content: [
						$p({ _innerHTMLToBeSanitized: SC.util.formatString(SC.res['OverviewPanel.DatabaseTile.MaintenancePlanActionsFormat'], eventArgs.tileContext.MaintenancePlan.Actions.length.toString()) }),
						$p(SC.util.formatString(
							SC.res[
								(eventArgs.tileContext.MaintenancePlan.Days.length === 0 && eventArgs.tileContext.MaintenancePlan.DaysIncludedOrExcluded)
								|| (eventArgs.tileContext.MaintenancePlan.Days.length === 7 && !eventArgs.tileContext.MaintenancePlan.DaysIncludedOrExcluded)
									? 'DatabasePanel.Schedule.TextPlanDisabled'
									: 'DatabasePanel.Schedule.Text'
							],
							SC.ui.getTextForOptions(eventArgs.tileContext.MaintenancePlan.DaysIncludedOrExcluded, eventArgs.tileContext.MaintenancePlan.Days, 'RunFrequency', SC.types["DayOfWeek"]),
							SC.util.formatMinutesSinceMidnightUtcToTimeString(eventArgs.tileContext.MaintenancePlan.RunAtUtcTimeMinutes, { utcOrLocal: true, showTimeZone: true }),
							SC.util.formatMinutesSinceMidnightUtcToTimeString(eventArgs.tileContext.MaintenancePlan.RunAtUtcTimeMinutes, { utcOrLocal: false, showTimeZone: true }),
						)),
					],
				});
				break;
		}
	});
</script>
