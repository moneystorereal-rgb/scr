<%@ Page Language="C#" MasterPageFile="~/Default.master" ClassName="ScreenConnect.HostPage" Async="true" %>

<script runat="server">

	protected override void OnLoad(EventArgs e)
	{
		base.OnLoad(e);

		this.RegisterAsyncTask(async () =>
		{
			var permissions = await Permissions.GetForUserAsync(this.Context.User);
			Permissions.AssertAnyPermission(permissions);

			this.Page.AddFormlessScriptContent("SC.util.mergeIntoContext({0:json});", new
			{
				guestUrl = this.Context.Request.GetRealUrl(false, false).AbsoluteUri,
				canAdminister = Permissions.HasPermission(PermissionInfo.AdministerPermission, permissions),
				canManageSessionGroups = Permissions.HasPermission(PermissionInfo.ManageSessionGroupsPermission, permissions),
				canRunCommand = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.RunCommand),
				canRunToolboxItem = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.RunToolboxItem),
				canHostChat = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.HostChat),
				canAddNote = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.AddNote),
				canWake = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.Wake),
				canGetHostPass = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.HostPass),
				canSwitchLogonSession = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.LogonSessionSwitching),
				sessionDisplayLimit = ConfigurationCache.HostSessionDisplayLimit,
			});
		});
	}

</script>
<asp:Content runat="server" ContentPlaceHolderID="Main">
	<div class="MasterPanel">
		<h2></h2>
		<p class="Instruction"></p>
		<p class="Create"></p>
		<div class="MasterListContainer ArrowNavigation" tabindex="20">
			<ul></ul>
		</div>
		<p class="Ambient"></p>
		<div class="InfoPanel"></div>
	</div>
	<div class="MainDetailHeaderPanel">
		<div class="CommandPanel"></div>
		<h2></h2>
	</div>
	<div class="MainDetailPanel">
		<div class="InfoPanel"></div>
		<div class="DetailSelectionPanel">
			<div class="DetailTableHeaderPanel"></div>
			<div class="DetailTablePanel">
				<div class="NotificationPanel"></div>
				<div class="DetailTableContainer ArrowNavigation" tabindex="30">
					<div class="EmptyPanel"></div>
					<table class="DetailTable"></table>
				</div>
			</div>
		</div>
		<div class="InfoPanel"></div>
	</div>
	<div class="SubDetailHeaderPanel">
		<div class="CommandPanel"></div>
		<h3></h3>
	</div>
	<div class="SubDetailPanel">
		<div class="MultiSelectionPanel"></div>
		<div class="SingleSelectionPanel">
			<div class="DetailTabList ArrowNavigation" tabindex="40"></div>
			<div class="DetailTabContent"></div>
			<div class="InfoPanel"></div>
		</div>
	</div>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="DeclareScript">
	<script>

		function onLiveDataRefreshed(eventArgs) {
			var sessionInfo = eventArgs.liveData.ResponseInfoMap?.['HostSessionInfo'];
			var sessionGroupSummary = window.tryGetSessionGroupSummary(sessionInfo);
			var shouldRebuildSessionTable = true;
			var pathSessionGroupSummaries = (sessionInfo && sessionInfo.PathSessionGroupSummaries) || [];

			SC.ui.rebuildList(
				$('.MasterListContainer ul'),
				pathSessionGroupSummaries[0],
				function (it) { return it.Name; },
				window.createSessionGroupListItem,
				window.updateSessionGroupListItem,
				{ sessionInfo: sessionInfo, level: 0, wasSelectedGroupCollapsed: $('.MasterListContainer ul *.Selected.Collapsed') != null },
				null,
				pathSessionGroupSummaries[0] && pathSessionGroupSummaries[0][0] && window.getSessionTypeUrlPart() == sessionInfo.PathSessionGroupSummaries[0][0].SessionType
			);

			SC.command.updateCommandButtonsState($('.MasterListContainer ul'));

			if (sessionGroupSummary) {
				var sessionGroupPathChanged = !SC.util.areArraysEqual(window.getSessionGroupUrlPart(), sessionInfo.SessionGroupPath);
				window.setSessionGroupUrlPart(sessionInfo.SessionGroupPath);
				window.updateDetailHeaderPanel(sessionInfo.SessionGroupPath);
				window.selectSessionGroupElement(sessionInfo.SessionGroupPath, sessionGroupPathChanged);
				shouldRebuildSessionTable = (sessionGroupPathChanged || sessionGroupSummary.LastSetAlteredVersion > eventArgs.requestVersion);

				if (shouldRebuildSessionTable)
					SC.ui.setContents($('.DetailTableContainer .EmptyPanel'), [
						$p($img({ src: SC.util.formatString('Images/Empty{0}.svg', SC.util.getEnumValueName(SC.types.SessionType, sessionGroupSummary.SessionType)) })),
						$h2(SC.util.formatString(
							SC.util.getSessionTypeResource('HostPanel.{0}Empty{1}Heading', sessionGroupSummary.SessionType, SC.util.isNullOrEmpty(sessionInfo.Filter) ? '' : 'Filtered', sessionInfo.Filter),
							sessionGroupSummary.Name,
							sessionInfo.Filter
						)),
						$p(SC.util.formatString(
							SC.util.getSessionTypeResource('HostPanel.{0}Empty{1}Message', sessionGroupSummary.SessionType, SC.util.isNullOrEmpty(sessionInfo.Filter) ? '' : 'Filtered'),
							sessionGroupSummary.Name,
							sessionInfo.Filter
						)),
						(sessionInfo.AlternateSessionGroupSummaries || [])
							.map(function (_) {
								return $p($a(
									{ href: SC.util.getWindowHashStringFromSectionParametersList([[SC.util.getEnumValueName(SC.types.SessionType, _.SessionType), _.Name, sessionInfo.Filter]]) },
									SC.util.formatString(SC.res['HostPanel.EmptyLinkFormat'], _.SessionCount, _.Name, SC.util.getEnumValueName(SC.types.SessionType, _.SessionType))
								));
							}),
					]);
			} else {
				SC.ui.clear($('.MainDetailHeaderPanel h2'));
				SC.ui.clear($('.DetailTableContainer .EmptyPanel'));
			}

			if (shouldRebuildSessionTable) {
				SC.css.ensureClass($('.DetailTableContainer'), 'Empty', sessionInfo.Sessions.length == 0);
				SC.css.ensureClass($('.NotificationPanel'), 'Notifying', sessionInfo.Sessions.length != sessionInfo.UntruncatedSessionCount);

				SC.ui.setContents($('.NotificationPanel'), [
					SC.util.formatString(SC.res['HostPanel.SessionTruncatedMessageFormat'], sessionInfo.Sessions.length, sessionInfo.UntruncatedSessionCount),
					$nbsp(),
					SC.command.createCommandButtons([{ commandName: 'ShowAll' }]),
				]);

				SC.ui.rebuildTable(
					$('.DetailTableContainer table'),
					sessionInfo.Sessions,
					function (session) { return session.SessionID; },
					window.initializeSessionRow,
					window.updateSessionRow,
					SC.util.getMillisecondCount(),
					SC.util.getMillisecondCount(),
					!sessionGroupPathChanged
				);
			} else {
				SC.ui.refreshTableRowsWithNewData(
					$('.DetailTableContainer table'),
					sessionInfo.Sessions,
					function (session) { return session.SessionID; },
					window.updateSessionRow,
					SC.util.getMillisecondCount(),
					SC.util.getMillisecondCount()
				);
			}

			window._refreshSessionTableIntervalID = SC.util.clearAndSetInterval(
				window._refreshSessionTableIntervalID,
				function () {
					SC.ui.refreshTableRowsWithExistingData(
						$('.DetailTableContainer table'),
						window.updateSessionRow,
						SC.util.getMillisecondCount()
					);
				},
				60000
			);

			var urlSessionID = window.getSessionUrlPart();
			var urlCommandDetails = window.extractCommandNameAndArgumentFromUrl();
			var urlSelectedSession = sessionInfo.Sessions.find(function (_) { return _.SessionID == urlSessionID });
			var urlCommandContext = urlSelectedSession ? {
				sessions: [urlSelectedSession],
				permissions: urlSelectedSession.Permissions,
			} : null;

			if (!SC.util.isNullOrEmpty(urlSessionID))
				if (window.selectSessionRow(urlSessionID, true) == null)
					window.setSessionUrlPart(null);

			if (Array.from($('.DetailTableContainer table').rows).find(function (r) { return SC.ui.isSelected(r) || SC.ui.isChecked(r); }) == null) {
				if (!SC.util.isNullOrEmpty(urlCommandDetails.commandName)) {
					Array.prototype.forEach.call($('.DetailTableContainer table').rows, function (r) {
						SC.ui.setChecked(r, true);
					});
				} else {
					var sessionID = sessionInfo.Sessions.length ? sessionInfo.Sessions[0].SessionID : null;
					window.setSessionUrlPart(sessionID);
					window.selectSessionRow(sessionID, true);
				}
			}

			if (SC.command.queryCommandButtonState(null, urlCommandDetails.commandName, urlCommandDetails.commandArgument, urlCommandContext).allowsUrlExecution)
				SC.command.dispatchGlobalExecuteCommand(urlCommandDetails.commandName, urlCommandDetails.commandArgument);

			window.updateDetailPanels();

			window.setLoadingComplete(window._dirtyLevels.SessionGroupList);
			window.setLoadingComplete(window._dirtyLevels.SessionList);
		}

		function createSessionGroupListItem(sessionGroupSummary, additionalData) {
			var sessionInfo = additionalData.sessionInfo;
			var level = additionalData.level;
			var wasSelectedGroupCollapsed = additionalData.wasSelectedGroupCollapsed;

			return $li(
				{
					_commandName: 'Select',
					_dataItem: sessionGroupSummary,
					_classNameMap: {
						HasChildren: sessionGroupSummary.SessionCount && sessionGroupSummary.HasSubgroupExpression,
						InPath: sessionGroupSummary.Name === sessionInfo.SessionGroupPath[level],
						Collapsed: wasSelectedGroupCollapsed && sessionGroupSummary.Name == sessionInfo.SessionGroupPath[level] && level == sessionInfo.SessionGroupPath.length - 1,
						Unacknowledged: sessionGroupSummary.UnacknowledgedSessionCount,
					},
				},
				[
					$div([
						$p({ title: sessionGroupSummary.Name }, sessionGroupSummary.Name || SC.res['HostPanel.EmptyGroupText']),
						level == 0 ? SC.command.createCommandButtons([{ commandName: 'ShowSessionGroupPopupMenu' }]) : null,
						$span(sessionGroupSummary.SessionCount.toString()),
					]),
					$ul([
						((sessionGroupSummary.Name == sessionInfo.SessionGroupPath[level] && sessionInfo.PathSessionGroupSummaries[level + 1]) || [])
							.map(function (subSessionGroupSummary) {
								return createSessionGroupListItem(
									subSessionGroupSummary,
									{ sessionInfo: sessionInfo, level: level + 1, wasSelectedGroupCollapsed: wasSelectedGroupCollapsed }
								);
							}),
					]),
				]
			);
		}

		function updateSessionGroupListItem(listItem, oldSessionGroupSummaryUnused, sessionGroupSummary, persistentAdditionalDataUnused, transientAdditionalData, shouldAttemptToPreserveElementsAtExpenseOfPerformance) {
			var sessionInfo = transientAdditionalData.sessionInfo;
			var level = transientAdditionalData.level;
			var wasSelectedGroupCollapsed = transientAdditionalData.wasSelectedGroupCollapsed;

			listItem._dataItem = sessionGroupSummary;
			SC.css.ensureClass(listItem, 'HasChildren', sessionGroupSummary.SessionCount && sessionGroupSummary.HasSubgroupExpression);
			SC.css.ensureClass(listItem, 'InPath', sessionGroupSummary.Name === sessionInfo.SessionGroupPath[level]);
			SC.css.ensureClass(listItem, 'Collapsed', wasSelectedGroupCollapsed && sessionGroupSummary.Name == sessionInfo.SessionGroupPath[level] && level == sessionInfo.SessionGroupPath.length - 1);
			SC.css.ensureClass(listItem, 'Unacknowledged', sessionGroupSummary.UnacknowledgedSessionCount);

			SC.ui.setContents(listItem.querySelector('span'), sessionGroupSummary.SessionCount.toString());

			if (sessionGroupSummary.Name == sessionInfo.SessionGroupPath[level] && sessionGroupSummary.HasSubgroupExpression) {
				SC.ui.rebuildList(
					listItem.querySelector('ul'),
					sessionInfo.PathSessionGroupSummaries[level + 1],
					function (sessionGroupSummary) { return sessionGroupSummary.Name; },
					window.createSessionGroupListItem,
					window.updateSessionGroupListItem,
					{ sessionInfo: sessionInfo, level: level + 1, wasSelectedGroupCollapsed: wasSelectedGroupCollapsed },
					null,
					shouldAttemptToPreserveElementsAtExpenseOfPerformance
				);
			} else {
				SC.ui.clear(listItem.querySelector('ul'));
			}
		}

		function initializeSessionRow(row, session) {
			row._commandName = 'Select';
			SC.command.addCommandDispatcher(row);

			SC.ui.addCell(row, { className: 'CheckBox', _commandName: 'Check' });
			SC.ui.addCell(row, { className: 'SessionInfo' }, $div({ className: 'SessionInfoPanel' }));
			SC.ui.addCell(row, { className: 'StatusDiagram' }, $div({ className: 'StatusDiagramPanel ' + SC.util.getEnumValueName(SC.types.SessionType, session.SessionType) }));
		}

		function updateSessionRow(row, oldSession, currentSession, sessionTime, currentTime) {
			var ageSeconds = (currentTime - sessionTime) / 1000;
			if (ageSeconds > 1 || !oldSession || currentSession.LastAlteredVersion > oldSession.LastAlteredVersion) {
				SC.css.ensureClass(row, 'Unacknowledged', currentSession.UnacknowledgedEvents.length);

				var isGuestClientVersionUpToDate = (currentSession.GuestClientVersion == SC.context.productVersion);

				var createSessionInfoElementFunc = (className, content) =>
					$p({ title: content, className: className || '' }, content);

				SC.ui.setContents(row.querySelector('.SessionInfoPanel'), [
					!SC.util.isNullOrEmpty(currentSession.Name)
						? $h3({ className: 'SessionTitle', title: currentSession.Name }, currentSession.Name)
						: null,
					SC.util.getVisibleCustomPropertyIndices(currentSession.SessionType)
						.filter(it => !SC.util.isNullOrEmpty(currentSession.CustomPropertyValues[it]))
						.map(visibleCustomPropertyIndex => createSessionInfoElementFunc(null,
							SC.util.formatString(SC.res['SessionInfoPanel.CustomPropertyLabelFormat'],
								SC.util.getSessionTypeResource('SessionProperty.{1}.{0}LabelText', currentSession.SessionType, SC.util.getCustomPropertyName(visibleCustomPropertyIndex)),
								currentSession.CustomPropertyValues[visibleCustomPropertyIndex]
							)
						)),
					!SC.util.isNullOrEmpty(currentSession.Host) && currentSession.SessionType != SC.types.SessionType.Access
						? createSessionInfoElementFunc(null, SC.util.formatString(SC.res['SessionInfoPanel.HostLabelFormat'], currentSession.Host))
						: null,
					currentSession.SessionType != SC.types.SessionType.Access && SC.util.getBooleanResource('SessionInfoPanel.JoinModeVisible')
						? createSessionInfoElementFunc(null, SC.util.formatString(SC.res['SessionInfoPanel.JoinModeLabelFormat'], window.getJoinModeText(currentSession)))
						: null,
					!SC.util.isNullOrEmpty(currentSession.GuestOperatingSystemName) && SC.util.getBooleanResource('SessionInfoPanel.GuestOperatingSystemVisibleIfPresent')
						? createSessionInfoElementFunc(null, SC.util.formatString(SC.res['SessionInfoPanel.GuestOperatingSystemLabelFormat'], currentSession.GuestOperatingSystemName, currentSession.GuestOperatingSystemVersion))
						: null,
					!SC.util.isNullOrEmpty(currentSession.GuestClientVersion)
						&& (
							SC.util.getBooleanResource('SessionInfoPanel.GuestClientVersionVisibleIfPresent')
							|| (
								!isGuestClientVersionUpToDate
								&& SC.util.areFlagsSet(currentSession.Attributes, SC.types.SessionAttributes.CanReinstallGuestClient)
								&& SC.util.getBooleanResource('SessionInfoPanel.GuestClientVersionVisibleIfOutOfDateAndReinstallable')
							)
						)
						? createSessionInfoElementFunc(isGuestClientVersionUpToDate ? null : 'Failure', SC.util.formatString(SC.res['SessionInfoPanel.GuestClientVersionLabelFormat'], currentSession.GuestClientVersion))
						: null,
					!SC.util.isNullOrEmpty(currentSession.GuestLoggedOnUserName) && SC.util.getBooleanResource('SessionInfoPanel.GuestLoggedOnUserVisibleIfPresent')
						? createSessionInfoElementFunc(null, SC.util.formatString(
							SC.res[
							currentSession.GuestIdleTime > parseInt(SC.res['SessionInfoPanel.GuestLoggedOnUserIdleThresholdSeconds']) ? 'SessionInfoPanel.GuestLoggedOnUserIdleLabelFormat' :
								currentSession.GuestIdleTime >= 0 ? 'SessionInfoPanel.GuestLoggedOnUserActiveLabelFormat' :
									'SessionInfoPanel.GuestLoggedOnUserIdleUnknownLabelFormat'
							],
							currentSession.GuestLoggedOnUserDomain,
							currentSession.GuestLoggedOnUserName,
							SC.util.formatDurationFromSeconds(currentSession.GuestIdleTime + ageSeconds)
						))
						: null,
					currentSession.AddedNoteEvents.length > 0 && SC.util.getBooleanResource('SessionInfoPanel.NotesVisibleIfPresent')
						? createSessionInfoElementFunc(null, SC.util.formatString(SC.res['SessionInfoPanel.NotesLabelFormat'], currentSession.AddedNoteEvents.map(_ => _.Data).join('; ')))
						: null,
				]);

				SC.ui.setContents(row.querySelector('.StatusDiagramPanel'), [
					[SC.types.ProcessType.Host, SC.types.ProcessType.Guest].map(processType => {
						var connectedTimeSeconds = -1;
						var connectedCount = 0;
						var participantName = '';
						Array.prototype.forEach.call(currentSession.ActiveConnections, function (ac) {
							if (ac.ProcessType == processType) {
								connectedCount++;
								connectedTimeSeconds = Math.max(connectedTimeSeconds, ac.ConnectedTime);
								participantName = SC.util.isNullOrEmpty(ac.ParticipantName) ? SC.res['HostPanel.GuestAnonymousName'] : ac.ParticipantName;
							}
						});

						var processTypeName = SC.util.getEnumValueName(SC.types.ProcessType, processType);

						var description =
							connectedCount > 1 ? SC.util.formatString('({0} {1}s) {2}', connectedCount, processTypeName, SC.util.formatDurationFromSeconds(connectedTimeSeconds + ageSeconds)) :
							connectedCount > 0 ? SC.util.formatString('{0} - {1}', participantName, SC.util.formatDurationFromSeconds(connectedTimeSeconds + ageSeconds)) :
							'';

						var latestStatus = null;

						if (processType === SC.types.ProcessType.Guest) {
							var statuses = currentSession.QueuedEvents
								.map(function (queuedEvent) {
									return {
										time: queuedEvent.Time,
										description: SC.util.getEnumValueName(SC.types.SessionEventType, queuedEvent.EventType),
									};
								});

							if (
								currentSession.LastInitiatedJoinEventTime >= 0 &&
								(currentSession.LastConnectedEventTime < 0 || currentSession.LastInitiatedJoinEventTime < currentSession.LastConnectedEventTime) &&
								!currentSession.ActiveConnections.some(function (_) { return _.ProcessType == SC.types.ProcessType.Guest; }) &&
								!currentSession.LastInitiatedJoinEventHost
							)
								statuses.push({
									time: currentSession.LastInitiatedJoinEventTime,
									description: SC.res['SessionInfoPanel.GuestJoinedMessage'],
								});

							latestStatus = statuses.reduce(function (previousStatus, currentStatus) {
								return previousStatus.time < currentStatus.time ? previousStatus : currentStatus;
							}, {
								time: Infinity,
								description: '',
							});
						}

						return $div({ _classNameMap: { [processTypeName]: true, Connected: connectedCount > 0 } }, [
							$div({ className: 'ConnectionBar' }),
							$p({ className: 'Description', title: description }, description),
							latestStatus && latestStatus.time + ageSeconds < 60
								? $p({ className: 'Latest', title: latestStatus.description }, latestStatus.description)
								: null,
						]);
					}),
				]);
			}
		}

		function updateDetailHeaderPanel(sessionGroupPath) {
			var sessionGroupPathText = sessionGroupPath.map(function (_) { return _ || SC.res['HostPanel.EmptyGroupText']; }).map(function (path) { return path.replace(/\//g, '//')}).join(' / ');
			SC.ui.setText($('.MainDetailHeaderPanel h2'), sessionGroupPathText);

			$('filterBox').setAttribute('placeholder', SC.util.formatString(SC.res['HostPanel.FilterBoxPlaceholderFormat'], sessionGroupPathText));
			$('filterBox').setAttribute('title', SC.res['HostPanel.FilterBoxTitle']);
		}

		function getSelectedSessionsContext(overrideRows) {
			var rowCheckedCount = 0;
			var checkedOrSelectedSessions = [];
			var permissions = null;
			var lastSessionTime = 0;
			var rows = overrideRows || $('.DetailTableContainer table').rows;

			Array.prototype.find.call(rows, function (row) {
				if (row._dataItem) {
					var isChecked = SC.ui.isChecked(row);
					var isSelected = SC.ui.isSelected(row);

					if (isChecked)
						rowCheckedCount++;

					if (isChecked || isSelected) {
						permissions = (permissions == null ? row._dataItem.Permissions : permissions & row._dataItem.Permissions);
						lastSessionTime = Math.max(lastSessionTime, row._userData);
						checkedOrSelectedSessions.push(row._dataItem);
					}
				}
			});

			return {
				rowCount: rows.length,
				rowCheckedCount,
				sessions: checkedOrSelectedSessions,
				permissions,
				lastSessionTime,
				sessionType: window.getSessionTypeUrlPartAndSetIfInvalid(),
			};
		}

		function updateDetailPanels() {
			var context = window.getSelectedSessionsContext();

			var sessionInfo = SC.livedata.get()?.ResponseInfoMap?.['HostSessionInfo'];

			SC.css.ensureClass($('.SubDetailPanel'), 'SingleSelection', context.sessions.length == 1);
			SC.css.ensureClass($('.SubDetailPanel'), 'MultiSelection', context.sessions.length > 1);

			SC.css.ensureClass($('.DetailTableHeaderPanel'), 'HalfChecked', context.rowCheckedCount > 0 && context.rowCheckedCount < context.rowCount);
			SC.css.ensureClass($('.DetailTableHeaderPanel'), 'Checked', context.rowCheckedCount > 0 && context.rowCheckedCount == context.rowCount);

			SC.ui.setText($('.SubDetailHeaderPanel h3'), context.sessions.map(function (session) { return session.Name; }).join(', '));

			SC.ui.setContents($('.MainDetailHeaderPanel .CommandPanel'), SC.command.createCommandButtons([
				...SC.command.queryCommandButtons('HostCommandListPanel', context),
				...SC.command.queryCommandButtons('HostDetailPanel'), // for extension backward compatibility
			]));

			SC.ui.setContents($('.SubDetailPanel .MultiSelectionPanel'), [
				$img({ src: 'Images/Multiselect.svg' }),
				$h2(SC.util.formatString(SC.res['HostPanel.MultiSelectionHeading'], context.rowCheckedCount)),
				$div(SC.command.createCommandButtons([
					...SC.command.queryCommandButtons('HostMultiSelectionPanel', context),
					...SC.command.queryCommandButtons('HostDetailPanel'), // for extension backward compatibility
				])),
			]);

			[
				$('.MainDetailHeaderPanel .CommandPanel'),
				$('.DetailTabList'),
				$('.SubDetailPanel .MultiSelectionPanel'),
				SC.popout.getPanel(),
			].forEach(function (c) {
				if (c != null)
					SC.command.updateCommandButtonsState(c, context);
			});

			var detailSession = (context.sessions.length === 1 ? context.sessions[0] : null);
			$('.SubDetailPanel .SingleSelectionPanel')._dataItem = detailSession;

			var tabElements = Array.from($('.DetailTabList').childNodes);
			var selectedTabName = null;

			// NOTE: context.sessions is empty before the session list is loaded, so also check URL for specified session
			if (context.sessions.length === 1 || window.getSessionUrlPart()) {
				function getValidTabName(tabName) {
					if (
						!SC.util.isNullOrEmpty(tabName)
						&& Array.from($('.DetailTabList').childNodes).find(function (tabElement) {
							return tabElement._commandArgument === tabName && SC.ui.isVisible(tabElement);
						}) != null
					)
						return tabName;

					return null;
				}

				// backwards compatibility for old command format in URL
				if (SC.command.queryCommandButtonState(null, window.getLocationHashParameter(4), window.getLocationHashParameter(5)).allowsUrlExecution) {
					const commandName = window.getLocationHashParameter(4);
					const commandArgument = window.getLocationHashParameter(5);

					if (commandName === 'Select')
						selectedTabName = getValidTabName(commandArgument);
					else
						window.setCommandHashParameters(commandName, commandArgument);
				}

				const tabNameFromUrl = window.getTabNameUrlPart();

				if (!selectedTabName)
					selectedTabName = getValidTabName(tabNameFromUrl);

				if (!selectedTabName)
					selectedTabName = getValidTabName((SC.util.loadSettings().selectedTabBySessionTypeMap || {})[window.getSessionTypeUrlPart()]);

				if (!selectedTabName)
					for (let tabElement of Array.from($('.DetailTabList').childNodes))
						if (selectedTabName = getValidTabName(tabElement._commandArgument))
							break;

				window.setTabNameUrlPart(selectedTabName);
				if (selectedTabName !== tabNameFromUrl)
					window.setTabContextUrlPart(null);

				SC.util.modifySettings(function (settings) {
					(settings.selectedTabBySessionTypeMap || (settings.selectedTabBySessionTypeMap = {}))[window.getSessionTypeUrlPart()] = selectedTabName;
				});
			} else {
				window.setTabNameUrlPart(null);
				window.setTabContextUrlPart(null);
			}

			var selectedTabElement = tabElements.find(function (tabElement) { return tabElement._commandArgument === selectedTabName; })

			var eventsToAcknowledge = null;

			tabElements.forEach(function (tabElement) {
				SC.ui.setSelected(tabElement, tabElement === selectedTabElement);

				var tabUnacknowledgedEvents = detailSession?.UnacknowledgedEvents
					.filter(e => SC.nav.getHostTabName(e.EventType) === tabElement._commandArgument)
					.filter(e => detailSession.Permissions & (
						e.EventType === SC.types.SessionEventType.RequestedElevation ? SC.types.SessionPermissions.RespondToElevationRequest
							: e.EventType === SC.types.SessionEventType.RequestedAdministrativeLogon ? SC.types.SessionPermissions.RespondToAdministrativeLogonRequest
								: SC.types.SessionPermissions.ViewSessionGroup
					) !== 0);

				SC.css.ensureClass(tabElement, 'Unacknowledged', tabUnacknowledgedEvents?.length);

				if (tabElement === selectedTabElement)
					eventsToAcknowledge = tabUnacknowledgedEvents;
			});

			if (window._acknowledgeSessionID !== detailSession?.SessionID || !SC.util.areArraysEqual(window._eventsToAcknowledge?.map(it => it.EventID), eventsToAcknowledge?.map(it => it.EventID))) {
				window.clearTimeout(window._acknowledgeTimeoutID);

				window._acknowledgeSessionID = detailSession?.SessionID;
				window._eventsToAcknowledge = eventsToAcknowledge;

				if (eventsToAcknowledge?.length && detailSession?.SessionID)
					window._acknowledgeTimeoutID = window.setTimeout(function () {
						SC.service.AddSessionEvents(
							sessionInfo.SessionGroupPath,
							eventsToAcknowledge.map(it => ({ SessionID: detailSession.SessionID, EventType: SC.types.SessionEventType.AcknowledgedEvent, ConnectionID: it.ConnectionID, CorrelationEventID: it.EventID })),
							null,
							function (e) { } // just eat any errors - SCP-33448
						);
					}, 3000);
			}

			if (window._currentTabName != selectedTabName || window._currentTabSessionID != (detailSession == null ? null : detailSession.SessionID)) {
				var tabContainer = $div({ className: selectedTabName });
				SC.ui.setContents($('.DetailTabContent'), tabContainer);
				SC.event.dispatchGlobalEvent(SC.event.InitializeTab, { container: tabContainer, tabName: selectedTabName, sessionType: context.sessionType });
				window._currentTabName = selectedTabName;
				window._currentTabSessionID = null;
				window._currentTabVersion = null;
				window.clearInterval(window._refreshTabContentIntervalID);
			}

			if (sessionInfo != null && context.sessions.length == 0)
				window.setLoadingComplete(window._dirtyLevels.SessionDetails);

			if (detailSession == null && window._pendingSessionDetailsRequest != undefined) {
				window._pendingSessionDetailsRequest.abort();
				window._pendingSessionDetailsRequest = undefined;
			} else if (detailSession != null) {
				var tabContext = window.getTabContextUrlPart();
				
				if (window._currentTabSessionID === detailSession.SessionID && window._currentTabVersion === detailSession.LastAlteredVersion && window._currentTabName === selectedTabName && window._currentTabContext === tabContext) {
					window.setLoadingComplete(window._dirtyLevels.SessionDetails);
				} else {
					var sessionDetailsEntry = SC.util.getCacheEntry(sessionInfo.SessionGroupPath[0] + ':' + detailSession.SessionID + 'SessionDetails', detailSession.LastAlteredVersion);

					if (sessionDetailsEntry) {
						window._currentTabSessionID = detailSession.SessionID;
						window._currentTabVersion = detailSession.LastAlteredVersion;
						window._currentTabContext = tabContext;

						var sortedEventsEntry = SC.util.getCacheEntry(detailSession.SessionID + 'SortedEvents', detailSession.LastAlteredVersion);

						if (!sortedEventsEntry) {
							var sortedEvents = window.getSortedEvents(sessionDetailsEntry.item);
							sortedEventsEntry = SC.util.setCacheItem(detailSession.SessionID + 'SortedEvents', detailSession.LastAlteredVersion, sortedEvents);
						}

						var refreshTabContentProc = function () {
							var nowTime = SC.util.getMillisecondCount();
							var sessionAgeSeconds = (nowTime - context.lastSessionTime) / 1000;
							var sessionDetailsAgeSeconds = (nowTime - sessionDetailsEntry.firstUsedTime) / 1000;

							SC.event.dispatchGlobalEvent(SC.event.RefreshTab, {
								container: $('.DetailTabContent > *'),
								tabName: selectedTabName,
								tabContext: tabContext,
								session: detailSession,
								sessionDetails: sessionDetailsEntry.item,
								sortedEvents: sortedEventsEntry.item,
								sessionAgeSeconds: sessionAgeSeconds,
								sessionDetailsAgeSeconds: sessionDetailsAgeSeconds,
							});

							$('.DetailTabContent')._dataItem = sessionDetailsEntry.item;
							SC.command.updateCommandButtonsState($('.DetailTabContent'), { sessions: [detailSession], permissions: detailSession.Permissions });
						};

						refreshTabContentProc();

						var queryRelativeTimeEventArgs = SC.event.dispatchGlobalEvent(SC.event.QueryTabContainsRelativeTimes, { tabName: selectedTabName, hasRelativeTimes: false });

						if (queryRelativeTimeEventArgs.hasRelativeTimes)
							window._refreshTabContentIntervalID = SC.util.clearAndSetInterval(window._refreshTabContentIntervalID, refreshTabContentProc, 60000);

						window.setLoadingComplete(window._dirtyLevels.SessionDetails);
					} else if (window._pendingSessionDetailsRequest == undefined || window._pendingSessionDetailsSessionID != detailSession.SessionID || window._pendingSessionDetailsVersion != detailSession.LastAlteredVersion) {
						window._pendingSessionDetailsSessionID = detailSession.SessionID;
						window._pendingSessionDetailsVersion = detailSession.LastAlteredVersion;

						if (window._pendingSessionDetailsRequest != undefined)
							window._pendingSessionDetailsRequest.abort();

						window._pendingSessionDetailsRequest = SC.service.GetSessionDetails(
							sessionInfo.SessionGroupPath,
							detailSession.SessionID,
							function (sessionDetails) {
								window._pendingSessionDetailsRequest = undefined;

								if (sessionDetails) {
									SC.util.setCacheItem(sessionInfo.SessionGroupPath[0] + ':' + detailSession.SessionID + 'SessionDetails', detailSession.LastAlteredVersion, sessionDetails);
									window.updateDetailPanels();
								} else {
									window.setTimeout(function () { window.updateDetailPanels(); }, 1000);
								}
							},
							function (error) {
								window._pendingSessionDetailsRequest = undefined;
								SC.dialog.showModalErrorBox(error.detail || error.message);
							}
						);
					}
				}
			}
		}

		function createAndSelectSession(sessionType) {
			SC.service.CreateSession(
				sessionType,
				SC.res['SessionPanel.New' + SC.util.getEnumValueName(SC.types.SessionType, sessionType) + 'SessionName'],
				false,
				SC.util.getRandomStringFromMask(SC.res['SessionPanel.GenerateCodeMask']),
				null,
				function (sessionID) {
					window.setSearchUrlPart(null);
					window.setSessionUrlPart(sessionID);
					window.setTabNameUrlPart('Start');
					window.setTabContextUrlPart(null);
					window.setCommandHashParameters('ProcessSessionCreated', null);
					window.updateHashBasedElements(true);
					SC.dialog.hideModalDialog();
					SC.livedata.notifyDirty(window._dirtyLevels.SessionDetails);
				}
			);
		}

		function navigateToSessionGroup(sessionGroupPath) {
			window.setSessionGroupUrlPart(sessionGroupPath);
			window.updateDetailHeaderPanel(sessionGroupPath);
			window.setSearchUrlPart(null);
			window.setSessionUrlPart(null);
			window.setTabNameUrlPart(null);
			window.setTabContextUrlPart(null);
			window.updateHashBasedElements(false);
			window._currentSessionDisplayLimit = SC.context.sessionDisplayLimit;
		}

		function showEditSessionsDialog(sessionGroupPath, sessions) {
			var definitionList = $dl();

			var sessionType = sessions[0].SessionType;
			var visibleCustomPropertyIndices = SC.util.getVisibleCustomPropertyIndices(sessionType);
			var areAllNamesEqual = sessions.everyEqual(function (session) { return session.Name; });
			var areAllNamesMachineBased = sessions.every(function (session) { return (session.Attributes & SC.types.SessionAttributes.MachineBasedName) !== 0; });
			var nameOptionString = '';
			var initialNameOption = null;

			if (!areAllNamesEqual && !areAllNamesMachineBased) {
				nameOptionString += 'K';
				initialNameOption = 'K';
			}

			if (sessionType == SC.types.SessionType.Access)
				nameOptionString += 'M';

			if (nameOptionString.length != 0)
				nameOptionString += 'S';

			initialNameOption = initialNameOption || (areAllNamesMachineBased ? 'M' : 'S');

			SC.editfield.addEditField(definitionList, 'Name', nameOptionString, initialNameOption, areAllNamesMachineBased ? null : sessions[0].Name);

			visibleCustomPropertyIndices.forEach(function (_) {
				var areAllValuesEqual = sessions.everyEqual(function (session) { return session.CustomPropertyValues[_]; });
				SC.editfield.addEditField(definitionList, SC.util.getCustomPropertyName(_), areAllValuesEqual ? null : 'KS', null, areAllValuesEqual ? sessions[0].CustomPropertyValues[_] : null);
			});

			SC.dialog.showModalDialog('EditSessions', {
				titleResourceName: 'EditSessionsPanel.Title',
				content: definitionList,
				buttonTextResourceName: 'EditSessionsPanel.ButtonText',
				onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
					var sessionIDs = Array.prototype.map.call(sessions, function (session) { return session.SessionID; });
					var names = Array.prototype.map.call(sessions, function (session) { return session.Name; });

					var customPropertyValues = Array.prototype.map.call(sessions, function (session) { return session.CustomPropertyValues; });

					var nameOptionValue = SC.editfield.getOptionValue(definitionList, 'Name');

					if (nameOptionValue != 'K') {
						var value = (nameOptionValue == 'M' ? '' : SC.editfield.getTextValue(definitionList, 'Name'));
						names = SC.util.createArray(sessions.length, function () { return value; });
					}

					visibleCustomPropertyIndices.forEach(function (_) {
						if (SC.editfield.getOptionValue(definitionList, SC.util.getCustomPropertyName(_)) != 'K') {
							var value = SC.editfield.getTextValue(definitionList, SC.util.getCustomPropertyName(_));
							for (var j = 0; j < sessions.length; j++)
								customPropertyValues[j][_] = value;
						}
					});

					SC.service.UpdateSessions(sessionGroupPath, sessionIDs, names, customPropertyValues, closeDialogProc, setDialogErrorProc);
				},
			});

			SC.service.GetDistinctCustomPropertyValues(visibleCustomPropertyIndices, sessionType, function (values) {
				for (var i = 0; i < visibleCustomPropertyIndices.length; i++)
					SC.editfield.setEditFieldHintValues(
						definitionList,
						SC.util.getCustomPropertyName(visibleCustomPropertyIndices[i]),
						values[i]
					);
			});
		}

		function shouldCommandAllowUrlExecution(commandName, commandArgument) {
			switch (commandName) {
				case 'Join':
				case 'JoinWithOptions':
				case 'ProcessSessionCreated':
				case 'Select':
					return true;
				default:
					return false;
			}
		}

		function isCommandVisible(commandName, commandArgument, commandContext) {
			const sessions = commandContext?.sessions ?? [];
			const sessionType = commandContext?.sessionType ?? (sessions.length > 0 ? sessions[0].SessionType : window.getSessionTypeUrlPart());

			switch (commandName) {
				case 'Transfer':
				case 'Invite':
					return sessionType !== SC.types.SessionType.Access;
				case 'Reinstall':
				case 'Uninstall':
					return sessionType === SC.types.SessionType.Access;
				case 'InstallAccess': return sessionType === SC.types.SessionType.Support;
				case 'Wake': return sessionType === SC.types.SessionType.Access && SC.context.canWake;
				case 'RunCommand': return sessionType !== SC.types.SessionType.Meeting && SC.context.canRunCommand;
				case 'RunTool': return sessionType !== SC.types.SessionType.Meeting && SC.context.canRunToolboxItem;
				case 'AddNote': return SC.context.canAddNote;
				case 'SendMessage': return SC.context.canHostChat;
				case 'GetHostPass': return SC.context.canGetHostPass;
				case 'Select':
					if (commandArgument === 'Commands' && (sessionType === SC.types.SessionType.Meeting || !SC.context.canRunCommand))
						return false;

					if (commandArgument === 'Messages' && !SC.context.canHostChat)
						return false;

					if (commandArgument === 'Notes' && !SC.context.canAddNote)
						return false;

					if (commandArgument === 'AccessManagement' && sessionType !== SC.types.SessionType.Access)
						return false;

					var invitationPanelResourceKey = 'InvitationPanel.' + commandArgument + 'TabVisible';
					if (SC.res[invitationPanelResourceKey])
						return SC.util.getBooleanResource(invitationPanelResourceKey);

					return sessionType !== SC.types.SessionType.Meeting || commandArgument !== 'Commands';
				case 'ShowSessionGroupPopupMenu':
				case 'CreateSessionGroup':
					return SC.context.canManageSessionGroups;
				case 'CreateSession': return SC.context.sessionTypeInfos.find((it) => it.sessionType == window.getSessionTypeUrlPartAndSetIfInvalid())?.isButtonVisible;
				case 'MakeSessionPublic': return SC.util.getBooleanResource('SessionInfoPanel.MakeSessionPublicVisible');
				case 'MakeSessionPrivate': return SC.util.getBooleanResource('SessionInfoPanel.MakeSessionPrivateVisible');
				case 'ViewRawData': return sessions.length === 1 && !commandArgument.isRawDataVisible && commandArgument.event.data;
				case 'DeleteEvent':
					if (sessions.length !== 1 || !SC.context.eventTypesAllowingDeletion.includes(commandArgument.event.eventType))
						return false;

					if (commandArgument.event.eventType === SC.types.SessionEventType.AddedNote
						|| commandArgument.event.eventType === SC.types.SessionEventType.QueuedCommand
						|| commandArgument.event.eventType === SC.types.SessionEventType.RanCommand)
						return true;

					return SC.context.canAdminister && commandArgument.processedEvents.length === 0; // allow admins to delete all types of pending activity
				default:
					return true;
			}
		}

		function isCommandEnabled(commandName, commandArgument, commandContext) {
			const sessions = commandContext?.sessions ?? [];
			const sessionType = commandContext?.sessionType ?? (sessions.length > 0 ? sessions[0].SessionType : null);
			const permissions = commandContext?.permissions ?? 0;

			switch (commandName) {
				case 'Wake':
				case 'SendMessage':
					return sessions.length > 0 && (permissions & SC.types.SessionPermissions.Join) !== 0;
				case 'Join':
				case 'JoinWithOptions':
					return sessions.length === 1 && (permissions & SC.types.SessionPermissions.Join) !== 0;
				case 'GetHostPass': return sessions.length === 1 && (permissions & SC.types.SessionPermissions.CreateDelegatedAccessToken) !== 0;
				case 'RunCommand': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.RunCommandOutside) !== 0;
				case 'RunTool':
					return sessions.length > 0 && (permissions & (SC.types.SessionPermissions.RunSharedTool | SC.types.SessionPermissions.RunSharedToolAsSystemSilently | SC.types.SessionPermissions.ManageSharedToolbox)) !== 0;
				case 'UpdateGuestInfo': return sessions.length === 1 && (permissions & SC.types.SessionPermissions.Join) !== 0 && window.isProcessTypeConnected(sessions[0], SC.types.ProcessType.Guest);
				case 'Edit': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.Edit) !== 0;
				case 'Delete': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.Delete) !== 0;
				case 'Transfer': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.Transfer) !== 0;
				case 'Reinstall': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.Reinstall) !== 0 && sessions.some(function (it) { return SC.util.areFlagsSet(it.Attributes, SC.types.SessionAttributes.CanReinstallGuestClient) });
				case 'Uninstall': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.Uninstall) !== 0 && sessions.some(function (it) { return SC.util.areFlagsSet(it.Attributes, SC.types.SessionAttributes.CanUninstallGuestClient) });
				case 'AddNote': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.AddNote) !== 0;
				case 'ForceDisconnect': return sessions.length === 1 && (permissions & SC.types.SessionPermissions.Delete) !== 0 && !(sessionType === SC.types.SessionType.Access && commandArgument.ProcessType === SC.types.ProcessType.Guest);
				case 'DeleteEvent': return commandArgument.event.eventType === SC.types.SessionEventType.AddedNote ? (permissions & SC.types.SessionPermissions.RemoveNote) !== 0
					: (commandArgument.event.eventType === SC.types.SessionEventType.QueuedCommand || commandArgument.event.eventType === SC.types.SessionEventType.RanCommand) ? (permissions & SC.types.SessionPermissions.RemoveCommand) !== 0
						: SC.context.canAdminister
				case 'RespondToElevationRequest': return sessions.length === 1 && (permissions & SC.types.SessionPermissions.RespondToElevationRequest) !== 0;
				case 'RespondToAdministrativeLogonRequest': return sessions.length === 1 && (permissions & SC.types.SessionPermissions.RespondToAdministrativeLogonRequest) !== 0;
				case 'InstallAccess': return sessions.length > 0 && (permissions & SC.types.SessionPermissions.RunCommandOutside) !== 0;
				case 'More': return sessions.length > 0;
				case 'MakeSessionPublic':
				case 'ChangeCodeToName':
					return !sessions[0].IsPublic;
				case 'MakeSessionPrivate': return sessions[0].IsPublic;
				default: return true;
			}
		}

		function shouldCheckSession(session, checkModeType) {
			switch (checkModeType) {
				case 'All': return true;
				case 'None': return false;
				case 'Neither': return !window.isProcessTypeConnected(session, SC.types.ProcessType.Host) && !window.isProcessTypeConnected(session, SC.types.ProcessType.Guest);
				case 'Both': return window.isProcessTypeConnected(session, SC.types.ProcessType.Host) && window.isProcessTypeConnected(session, SC.types.ProcessType.Guest);
				case 'OnlyHost': return window.isProcessTypeConnected(session, SC.types.ProcessType.Host) && !window.isProcessTypeConnected(session, SC.types.ProcessType.Guest);
				case 'OnlyGuest': return !window.isProcessTypeConnected(session, SC.types.ProcessType.Host) && window.isProcessTypeConnected(session, SC.types.ProcessType.Guest);
			}
		}

		function isProcessTypeConnected(session, processType) {
			return session.ActiveConnections.find(function (ac) { return ac.ProcessType == processType; }) !== undefined;
		}

		function onQueryCommandButtonState(eventArgs) {
			if (!window.isCommandVisible(eventArgs.commandName, eventArgs.commandArgument, eventArgs.commandContext))
				eventArgs.isVisible = false;
			else if (!window.isCommandEnabled(eventArgs.commandName, eventArgs.commandArgument, eventArgs.commandContext))
				eventArgs.isEnabled = false;

			if (window.shouldCommandAllowUrlExecution(eventArgs.commandName, eventArgs.commandArgument))
				eventArgs.allowsUrlExecution = true;
		}

		function onExecuteCommand(eventArgs) {
			var dataElement = SC.command.getEventDataElement(eventArgs);
			var commandSessionGroupPath = SC.command.getEventDataItems(eventArgs).reverse().map(function (_) { return _.Name; });

			if (eventArgs.commandName == 'Check') {
				if (dataElement != null || eventArgs.commandArgument != null) {
					var selectedSessionIDs = [];

					Array.prototype.forEach.call($('.DetailTableContainer table').rows, function (r) {
						var isRowChecked = SC.ui.isChecked(r);

						if (dataElement != null) {
							if (r == dataElement)
								isRowChecked = !isRowChecked;
						} else {
							isRowChecked = window.shouldCheckSession(r._dataItem, eventArgs.commandArgument);
						}

						SC.ui.setChecked(r, isRowChecked);
						SC.ui.setSelected(r, isRowChecked);

						if (isRowChecked)
							selectedSessionIDs.push(r._dataItem.SessionID);
					});

					if (selectedSessionIDs.length == 1)
						window.setSessionUrlPart(selectedSessionIDs[0]);
					else {
						window.setSessionUrlPart(null);
						window.setTabNameUrlPart(null);
						window.setTabContextUrlPart(null);
					}

					window.updateDetailPanels();
				} else {
					SC.popout.togglePanel(eventArgs.commandElement, function (popoutPanel) {
						SC.ui.setContents(popoutPanel, [
							$div({ className: 'CommandList' }, [
								$h4({ _textResource: 'Command.Check.CheckText' }),
								SC.command.createCommandButtons([
									{ commandName: 'Check', commandArgument: 'All' },
									{ commandName: 'Check', commandArgument: 'None' }
								]),
							]),
							$div({ className: 'CommandList' }, [
								$h4({ _textResource: 'Command.Check.WhereText' }),
								SC.command.createCommandButtons([
									{ commandName: 'Check', commandArgument: 'Neither' },
									{ commandName: 'Check', commandArgument: 'Both' },
									{ commandName: 'Check', commandArgument: 'OnlyHost' },
									{ commandName: 'Check', commandArgument: 'OnlyGuest' }
								]),
							]),
						]);
					});
				}
			} else if (eventArgs.commandName == 'Select') {
				if (eventArgs.commandArgument) {
					if (SC.ui.findAncestor(eventArgs.commandElement, function (_) { return SC.css.containsClass(_, 'InvitationPanel'); })) {
						Array.from($('.InvitationTabList').childNodes).forEach(function (_) { SC.ui.setSelected(_, _._commandArgument == eventArgs.commandArgument); });
						Array.from($('.InvitationTabContent').childNodes).forEach(function (_) { SC.ui.setSelected(_, _._tabName == eventArgs.commandArgument); });
					} else if (SC.ui.findAncestor(eventArgs.commandElement, function (_) { return SC.css.containsClass(_, 'DetailTabList'); })) {
						window.setTabNameUrlPart(eventArgs.commandArgument);
						window.setTabContextUrlPart(null);
						window.updateDetailPanels();
					}
				} else if (dataElement._dataItem.SessionID) {
					if (eventArgs.isIntense) {
						if ((dataElement._dataItem.Permissions & SC.types.SessionPermissions.Join) != 0)
							processSessionCommand('Join', null, eventArgs.commandElement, eventArgs.isAdvanced, [dataElement._dataItem]);
					} else if (eventArgs.isAdvanced) {
						if (!SC.ui.isSelected(dataElement)) {
							var isBeforeSelection = (SC.ui.findNextSibling(dataElement, function (e) { return SC.ui.isSelected(e); }) != null);
							var reachedSelection = false;

							for (var e = dataElement; e != null && !reachedSelection; e = (isBeforeSelection ? e.nextSibling : e.previousSibling)) {
								reachedSelection = SC.ui.isSelected(e);
								SC.ui.setChecked(e, true);
								SC.ui.setSelected(e, true);
							}

							window.setSessionUrlPart(null);
							window.updateDetailPanels();
						}
					} else {
						window.selectSessionRow(dataElement._dataItem.SessionID, false);
						window.setSessionUrlPart(dataElement._dataItem.SessionID);
						window.updateDetailPanels();
					}
				} else if (SC.css.containsClass(dataElement, 'HasChildren') && SC.css.containsClass(dataElement, 'Selected')) {
					SC.css.toggleClass(dataElement, 'Collapsed');
				} else {
					window.navigateToSessionGroup(commandSessionGroupPath);

					if (!SC.css.containsClass(dataElement, 'HasChildren'))
						SC.css.ensureClass(document.documentElement, 'ShowMenu', false);

					SC.livedata.notifyDirty(window._dirtyLevels.SessionList);
				}
			} else if (eventArgs.commandName === 'More') {
				SC.popout.togglePanel(
					eventArgs.commandElement,
					function (popoutPanel) {
						let context = window.getSelectedSessionsContext();
						SC.ui.setContents(popoutPanel, $div({ className: 'CommandList Overflow' }, [
							SC.command.queryAndCreateCommandButtons(eventArgs.commandArgument, context),
							SC.command.queryAndCreateCommandButtons('HostDetailPopoutPanel'), // for extension backward compatibility
						]));
						SC.command.updateCommandButtonsState(popoutPanel, context);
					}
				);
			} else if (eventArgs.commandName == 'MoreInvitationOptions') {
				SC.popout.showPanelFromCommand(eventArgs, window.getSelectedSessionsContext());
			} else if (eventArgs.commandName == 'ShowSessionGroupPopupMenu') {
				SC.popout.showPanelFromCommand(eventArgs);
			} else if (eventArgs.commandName == 'CreateSession') {
				if (eventArgs.commandArgument == SC.types.SessionType.Access)
					SC.installer.showBuildDialog();
				else
					window.createAndSelectSession(eventArgs.commandArgument);
			} else if (eventArgs.commandName == 'EditSessionGroup' && dataElement || eventArgs.commandName == 'CloneSessionGroup' && dataElement || eventArgs.commandName == 'CreateSessionGroup') {
				SC.util.lazyImport('SC.editor').then((Editor) => {
					SC.service.GetSessionGroups(function (sessionGroups) {
						var sessionGroupNameBox, subgroupExpressionsBox, sessionGroupIndex, filterExpressionEditor;
						var isNewSessionGroup = (eventArgs.commandName == 'CreateSessionGroup');
						var isCloneSessionGroup = (eventArgs.commandName == 'CloneSessionGroup');

						if (!isNewSessionGroup)
							sessionGroupIndex = sessionGroups.map(function (_) { return _.Name; }).indexOf(dataElement._dataItem.Name);

						SC.service.GetSessionExpressionMetadata(function (expressionMetadata) {
							SC.dialog.showModalDialog(
								'EditSessionGroup',
								{
									suppressEscapeKeyHandling: true,
									initializeProc: function (dialog) {
										function startRefreshResults(editorViewInfo) {
											SC.service.GetSessionExpressionResults(
												window.getSessionTypeUrlPart(),
												editorViewInfo.filters,
												editorViewInfo.subExpressions,
												expressionInfo => Editor.setExpressionEditorResults(
													filterExpressionEditor,
													expressionInfo.FilterInfos,
													expressionInfo.SubExpressionInfos,
													expressionInfo.TotalResultCount,
												),
												_error => Editor.setExpressionEditorResults(filterExpressionEditor),
											);
										}

										SC.event.addHandler(filterExpressionEditor, 'changed', startRefreshResults);

										if (!isNewSessionGroup)
											Editor.setExpressionEditorText(filterExpressionEditor, sessionGroups[sessionGroupIndex].SessionFilter.trim());

										startRefreshResults(Editor.getExpressionEditorInfo(filterExpressionEditor));
									},
									titleResourceName: isNewSessionGroup ? 'EditSessionGroupPanel.CreateTitle' : isCloneSessionGroup ? 'EditSessionGroupPanel.CloneTitle' : 'EditSessionGroupPanel.Title',
									content: [
										$p({ _textResource: 'EditSessionGroupPanel.Message' }),
										$dl([
											$dt({ _textResource: 'EditSessionGroupPanel.NameLabel' }),
											$dd(sessionGroupNameBox = $input({ type: 'text', value: isNewSessionGroup ? '' : isCloneSessionGroup ? SC.util.formatString(SC.res['CloneSessionGroup.NameFormat'], sessionGroups[sessionGroupIndex].Name) : sessionGroups[sessionGroupIndex].Name })),
											$dt({ _textResource: 'EditSessionGroupPanel.SessionFilterLabel' }),
											$dd([
												filterExpressionEditor = Editor.createExpressionEditor({
													propertyInfos: expressionMetadata.PropertyInfos,
													variableInfos: expressionMetadata.VariableInfos,
													stringTable: {
														PlaceholderText: SC.res["EditSessionGroupPanel.SessionFilterPlaceholder"],
														TotalResultsTextFormat: SC.res["EditSessionGroupPanel.TotalResultsTextFormat"],
														SubExpressionResultsTextFormat: SC.res["EditSessionGroupPanel.SubExpressionResultsTextFormat"],
													}
												}),
												$a({ className: 'SyntaxHelperButton', _commandName: 'ShowSessionGroupsSyntaxHelper', _commandArgument: 'SessionFilter' }),
											]),
											$dt({ _textResource: 'EditSessionGroupPanel.SubgroupExpressionsLabel' }),
											$dd([
												subgroupExpressionsBox = $input({
													className: 'SubgroupExpressionsBox',
													type: 'text',
													value: isNewSessionGroup ? '' : sessionGroups[sessionGroupIndex].SubgroupExpressions,
													placeholder: SC.res['EditSessionGroupPanel.SubgroupExpressionsPlaceholder'],
												}),
												$a({ className: 'SyntaxHelperButton', _commandName: 'ShowSessionGroupsSyntaxHelper', _commandArgument: 'SubgroupExpressions' }),
											]),
										]),
									],
									buttonTextResourceName: isNewSessionGroup ? 'EditSessionGroupPanel.CreateButtonText' : isCloneSessionGroup ? 'EditSessionGroupPanel.CloneButtonText' : 'EditSessionGroupPanel.ButtonText',
									buttonPanelExtraContent: [
										SC.command.createCommandButtons([
											{ commandName: 'ToggleReference', commandArgument: 'Hide' },
											{ commandName: 'ToggleReference', commandArgument: 'Show' },
										]),
										isNewSessionGroup ? $label([
											$input({ className: 'CreateAnotherBox', type: 'checkbox', checked: false }),
											$span({ _textResource: 'EditSessionGroupPanel.CreateAnotherBoxText' }),
										]) : '',
									],
									referencePanelTextResourceName: 'EditSessionGroupPanel.Instructions',
									onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
										switch (dialogEventArgs.commandName) {
											case 'ShowSessionGroupsSyntaxHelper':
												SC.popout.togglePanel(dialogEventArgs.commandElement, function (popoutPanel) {
													SC.css.ensureClass(popoutPanel, 'SessionGroupsSyntaxHelperPanel', true);

													SC.ui.setContents(
														popoutPanel,
														SC.util.parseTsvIntoJaggedArray(SC.res['EditSessionGroupPanel.' + dialogEventArgs.commandArgument + 'SyntaxItems'])
															.groupBy(function (_) { return _[2]; }, function (_) { return { buttonText: _[0], definition: _[1] }; })
															.mapKeyValue(function (categoryName, items) {
																return [
																	$div({ className: 'CommandList' }, [
																		$h4(categoryName),
																		items.map(function (item) {
																			return SC.command.createCommandButtons([{
																				commandName: 'InsertSessionGroupExample',
																				description: item.definition,
																				text: item.buttonText,
																				commandArgument: { exampleText: item.buttonText, type: dialogEventArgs.commandArgument },
																			}]);
																		}),
																	]),
																];
															})
													);
												});

												break;
											case 'InsertSessionGroupExample':
												if (dialogEventArgs.commandArgument.type == 'SessionFilter') {
													const text = Editor.getExpressionEditorInfo(filterExpressionEditor).text + (Editor.getExpressionEditorInfo(filterExpressionEditor).text != '' ? ' AND ' : '') + dialogEventArgs.commandArgument.exampleText;
													Editor.setExpressionEditorText(dialog, text);
												}
												else {
													subgroupExpressionsBox.value += (subgroupExpressionsBox.value != '' ? ', ' : '') + dialogEventArgs.commandArgument.exampleText;
													subgroupExpressionsBox.focus();
													subgroupExpressionsBox.setSelectionRange(subgroupExpressionsBox.value.length, subgroupExpressionsBox.value.length);
												}

												break;
											case 'ToggleReference':
												SC.css.toggleClass(dialog, 'Expanded');
												break;
											case 'Default':
												var newSessionGroup = {
													Name: sessionGroupNameBox.value.trim(),
													SessionFilter: Editor.getExpressionEditorInfo(filterExpressionEditor).text,
													SessionType: window.getSessionTypeUrlPart(),
													SubgroupExpressions: subgroupExpressionsBox.value.trim(),
													CreationDate: isNewSessionGroup || isCloneSessionGroup ? new Date().toISOString() : sessionGroups[sessionGroupIndex].CreationDate
												};

												if (isNewSessionGroup || isCloneSessionGroup) {
													sessionGroups.push(newSessionGroup);
													SC.service.SaveSessionGroups(
														sessionGroups,
														function () {
															if ($('.CreateAnotherBox') && $('.CreateAnotherBox').checked)
																SC.command.dispatchExecuteCommand(window.document.body, window.document.body, window.document.body, 'CreateSessionGroup');
															else
																closeDialogProc();

															window.navigateToSessionGroup([newSessionGroup.Name]);
															SC.livedata.notifyDirty();
														},
														function (error) {
															setDialogErrorProc(error);
															sessionGroups.pop();
														}
													);
												} else {
													var originalSessionGroup = sessionGroups[sessionGroupIndex];
													sessionGroups[sessionGroupIndex] = newSessionGroup;
													SC.service.UpdateSessionGroup(
														originalSessionGroup,
														newSessionGroup,
														function () {
															closeDialogProc();
															window.navigateToSessionGroup([newSessionGroup.Name]);
															SC.livedata.notifyDirty();
														},
														function (error) {
															setDialogErrorProc(error);
															sessionGroups[sessionGroupIndex] = originalSessionGroup;
														}
													);
												}
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
								}
							);

							SC.command.updateCommandButtonsState(SC.dialog.getModalDialog());
						});
					});
				});
			} else if (eventArgs.commandName == 'DeleteSessionGroup') {
				SC.dialog.showConfirmationDialog(
					'DeleteSessionGroup',
					SC.res['DeleteSessionGroupPanel.Title'],
					$p({
						_innerHTMLToBeSanitized: SC.util.formatString(
							SC.res['DeleteSessionGroupPanel.DeleteSessionGroupFormat'],
							SC.util.escapeHtml(dataElement._dataItem.Name)
						)
					}),
					SC.res['DeleteSessionGroupPanel.ButtonText'],
					function (closeDialogProc, setDialogErrorProc) {
						SC.service.GetSessionGroups(function (sessionGroups) {
							var sessionGroupIndex = sessionGroups.map(function (_) { return _.Name; }).indexOf(dataElement._dataItem.Name);
							sessionGroups.splice(sessionGroupIndex, 1);
							SC.service.SaveSessionGroups(
								sessionGroups,
								function () {
									closeDialogProc();
									SC.livedata.notifyDirty();
								},
								setDialogErrorProc
							);
						});

					}
				);
			} else if (eventArgs.commandName == 'MoveSessionGroupToPosition') {
				SC.service.GetSessionGroups(function (sessionGroups) {
					var newIndexSelectBox;
					var sessionGroupIndex = sessionGroups.map(function (_) { return _.Name; }).indexOf(dataElement._dataItem.Name);
					SC.dialog.showModalDialog('MoveSessionGroup', {
						titleResourceName: 'MoveSessionGroupPanel.Title',
						content: [
							$p(SC.util.formatString(SC.res['MoveSessionGroupPanel.MessageFormat'], dataElement._dataItem.Name)),
							$p(newIndexSelectBox = $select(
								sessionGroups
									.filter(function (_) { return _.SessionType == sessionGroups[sessionGroupIndex].SessionType; })
									.filter(function (_) { return _.Name != dataElement._dataItem.Name; })
									.map(function (_) { return $option({ value: _.Name }, _.Name) })
							)),
						],
						buttonTextResourceName: 'MoveSessionGroupPanel.ButtonText',
						onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
							SC.util.moveElement(sessionGroups, sessionGroupIndex, sessionGroups.map(function (_) { return _.Name; }).indexOf(newIndexSelectBox[newIndexSelectBox.selectedIndex].value));

							SC.service.SaveSessionGroups(
								sessionGroups,
								function () {
									closeDialogProc();
									window.navigateToSessionGroup(commandSessionGroupPath);
									SC.livedata.notifyDirty();
								},
								setDialogErrorProc
							);
						},
					});
				});
			} else if (eventArgs.commandName == 'MoveSessionGroupToTop' || eventArgs.commandName == 'MoveSessionGroupToBottom') {
				SC.service.GetSessionGroups(function (sessionGroups) {
					var sessionGroupIndex = sessionGroups.map(function (_) { return _.Name; }).indexOf(dataElement._dataItem.Name);
					var sameTypeSessionGroups = sessionGroups.filter(function (_) { return _.SessionType == sessionGroups[sessionGroupIndex].SessionType });
					var newIndexName = (eventArgs.commandName == 'MoveSessionGroupToTop') ? sameTypeSessionGroups[0].Name : sameTypeSessionGroups[sameTypeSessionGroups.length - 1].Name;
					SC.util.moveElement(sessionGroups, sessionGroupIndex, sessionGroups.map(function (_) { return _.Name; }).indexOf(newIndexName) + (eventArgs.commandName == 'MoveSessionGroupToTop' ? 0 : 1));

					SC.service.SaveSessionGroups(
						sessionGroups,
						function () {
							window.navigateToSessionGroup(commandSessionGroupPath);
							SC.livedata.notifyDirty();
						}
					);
				});
			} else if (eventArgs.commandName == 'ToggleDetailPanel') {
				SC.css.toggleClass($('.MainPanel'), 'ShowDetailPanel');
			} else if (eventArgs.commandName == 'ShowAll') {
				window._currentSessionDisplayLimit = 0;
				SC.livedata.notifyDirty(window._dirtyLevels.SessionList);
			} else if (eventArgs.commandName == 'ShowImage') {
				SC.dialog.showModalDialog('ShowImage', eventArgs.commandArgument.dialogTitle, $p($img({ src: eventArgs.commandArgument.src })));
			} else if (dataElement && dataElement._dataItem.SessionID) { // came from row in table
				window.processSessionCommand(eventArgs.commandName, eventArgs.commandArgument, eventArgs.commandElement, eventArgs.isAdvanced, [dataElement._dataItem]);
			} else {
				var commandRows = Array.prototype.filter.call($('.DetailTableContainer table').rows, function (r) { return SC.ui.isChecked(r) || SC.ui.isSelected(r); });

				if (commandRows.length) {
					var sessions = Array.prototype.map.call(commandRows, function (r) { return r._dataItem; });
					window.processSessionCommand(eventArgs.commandName, eventArgs.commandArgument, eventArgs.commandElement, eventArgs.isAdvanced, sessions);
				}
			}
		}

		function processSessionCommand(commandName, commandArgument, commandElement, isAdvanced, sessions) {
			var sessionIDs = Array.prototype.map.call(sessions, function (session) { return session.SessionID; });
			var sessionInfo = SC.livedata.get()?.ResponseInfoMap?.['HostSessionInfo'];

			var addEventToSessionsFunc = function (eventType, data, requiresData, requiresConfirmation) {
				window.addEventToSessions(
					sessionInfo.SessionGroupPath,
					sessions[0].SessionType,
					sessionIDs,
					eventType,
					commandName,
					data,
					requiresData,
					requiresConfirmation,
					isAdvanced
				);
			};

			var findSessionRowFunc = function (sessionID) {
				return Array.from($('.DetailTableContainer table').rows).find(function (_) { return _._dataItem.SessionID == sessionID });
			};

			if (commandName == 'ProcessSessionCreated') {
				SC.css.runElementAnimation(findSessionRowFunc(sessionIDs[0]), 'NewSessionSlideInHighlight');
			} else if (commandName == 'SendMessage') {
				addEventToSessionsFunc(SC.types.SessionEventType.QueuedMessage, commandArgument, true, false);
			} else if (commandName == 'RunCommand') {
				addEventToSessionsFunc(SC.types.SessionEventType.QueuedCommand, commandArgument, true, false);
			} else if (commandName == 'AddNote') {
				addEventToSessionsFunc(SC.types.SessionEventType.AddedNote, commandArgument, true, false);
			} else if (commandName == 'Reinstall') {
				addEventToSessionsFunc(SC.types.SessionEventType.QueuedReinstall, commandArgument, false, true);
			} else if (commandName == 'Wake') {
				addEventToSessionsFunc(SC.types.SessionEventType.QueuedWake, commandArgument, false, true);
			} else if (commandName == 'UpdateGuestInfo') {
				SC.css.ensureClass($('.ScreenshotPanel'), 'Loading', true);
				addEventToSessionsFunc(SC.types.SessionEventType.QueuedGuestInfoUpdate, commandArgument, false, false);
			} else if (commandName === 'RespondToElevationRequest' || commandName === 'RespondToAdministrativeLogonRequest') {
				SC.css.ensureClass(commandElement, 'Loading', true);
				SC.service.AddSessionEvents(
					sessionInfo.SessionGroupPath,
					sessionIDs.map(it => ({
						SessionID: it,
						EventType: SC.types.ResponseType[commandArgument] == SC.types.ResponseType.Approve ? SC.types.SessionEventType.ApprovedRequest : SC.types.SessionEventType.DeniedRequest,
						CorrelationEventID: SC.command.getDataItem(commandElement).event.eventID,
					}))
				);
			} else if (commandName == 'Delete' && sessions[0].SessionType != SC.types.SessionType.Access) {
				addEventToSessionsFunc(SC.types.SessionEventType.DeletedSession, null, false, true);
			} else if (commandName == 'Delete' || commandName == 'Uninstall') {
				SC.dialog.showModalDialog('DeleteUninstallSession', {
					titleResourceName: 'DeleteUninstallSessionPanel.Title',
					content: [
						$p({ _htmlResource: 'DeleteUninstallSessionPanel.Description' }),
						['UninstallAndDelete', 'Delete', 'Uninstall'].map(function (_) {
							return $label({ _eventHandlerMap: { 'change': function (eventArgs) { SC.command.dispatchExecuteCommand(eventArgs.target, eventArgs.target, eventArgs.target, 'Unconfirm'); } } }, [
								$h4([$input({ type: 'radio', name: 'DeleteUninstall', checked: commandName == _, value: _ }), $span(SC.res['DeleteUninstallSessionPanel.' + _ + 'Title'])]),
								$p({ _htmlResource: 'DeleteUninstallSessionPanel.' + _ + 'Description' }),
							]);
						}),
						$p({ className: 'ResultPanel', _visible: false }),
					],
					buttonPanelExtraContent: SC.dialog.createButtonPanelButton(SC.res['DeleteUninstallSessionPanel.ConfirmButtonText'], 'Confirm'),
					buttonTextResourceName: 'DeleteUninstallSessionPanel.ButtonText',
					initializeProc: function(dialog) {
						SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Confirm'), false);
						SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Default'), true);
					},
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						if (dialogEventArgs.commandName == 'Default') {
							window.setTimeout(() => SC.command.dispatchExecuteCommand(dialogEventArgs.target, dialogEventArgs.target, dialogEventArgs.target, 'Proceed'), 1000);
							setDialogErrorProc({ message: SC.res['DeleteUninstallSessionPanel.WarningMessage'] }, true);
						} else if (dialogEventArgs.commandName == 'Proceed') {
							SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Confirm'), true);
							SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Default'), false);
							setDialogErrorProc({ message: SC.res['DeleteUninstallSessionPanel.WarningMessage'] });
						} else if (dialogEventArgs.commandName == 'Unconfirm') {
							SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Confirm'), false);
							SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Default'), true);
							setDialogErrorProc({});
						} else if (dialogEventArgs.commandName == 'Confirm') {
							var eventType;
							switch (SC.ui.getSelectedRadioButtonValue($('.ContentPanel'))) {
								case 'UninstallAndDelete':
									eventType = SC.types.SessionEventType.QueuedUninstallAndDelete;
									break;
								case 'Delete':
									eventType = SC.types.SessionEventType.DeletedSession;
									break;
								case 'Uninstall':
									eventType = SC.types.SessionEventType.QueuedUninstall;
									break;
							}
							SC.service.AddSessionEvents(sessionInfo.SessionGroupPath, sessionIDs.map(it => ({ SessionID: it, EventType: eventType })), closeDialogProc, setDialogErrorProc);
						}
					},
				});
			} else if (commandName == 'Edit') {
				window.showEditSessionsDialog(sessionInfo.SessionGroupPath, sessions);
			} else if (commandName == 'Join' || commandName == 'JoinWithOptions') {
				var joinProc = function (shouldSuspendInput, logonSessionID) {
					SC.launch.startJoinSession(
						{ session: sessions[0] },
						function (joinInfo, _, onSuccess, onFailure) {
							return SC.http.performWithServiceContext(SC.util.doesBrowserNeedSyncServiceContextForLaunch(), function () {
								return SC.service.GetAccessToken(
									sessionInfo.SessionGroupPath,
									joinInfo.session.SessionID,
									function (accessTokenString) {
										onSuccess(
											SC.util.getClientLaunchParameters(
												joinInfo.session.SessionID,
												joinInfo.session.SessionType,
												joinInfo.session.Name,
												null,
												logonSessionID,
												accessTokenString,
												joinInfo.processType,
												(shouldSuspendInput ? SC.types.ClientLaunchAttributes.SuspendedInput : SC.types.ClientLaunchAttributes.None)
											)
										);
									},
									onFailure
								);
							});
						}
					);
				};

				if (commandName == 'Join' && !isAdvanced)
					joinProc(false, null);
				else {
					let hasConnectedHost = sessions[0].ActiveConnections.findIndex(ac => ac.ProcessType === 1) > -1;

					SC.dialog.showModalDialog('JoinSessionWithOptions', {
						titleResourceName: 'JoinWithOptionsPanel.Title',
						content: [
							function () {
								if (!(sessions[0].Permissions & SC.types.SessionPermissions.SwitchLogonSession) || !SC.context.canSwitchLogonSession || hasConnectedHost)
									return null;

								var validLogonSessions = (sessions[0].LogonSessions || [])
									.filter(function (logonSession) {
										return !(logonSession.LogonSessionAttributes & SC.types.LogonSessionAttributes.BackstageLogonSession)
											|| (sessions[0].Permissions & SC.types.SessionPermissions.EnableBackstageLogonSession);
									});

								return $dl([
									$dt({ _textResource: 'JoinWithOptionsPanel.LogonSessionLabelText' }),
									$dd(
										validLogonSessions.length
											? validLogonSessions.map(function (logonSession, index) {
												return $p($label([
													$input({ type: 'radio', name: 'LogonSession', value: logonSession.LogonSessionID, checked: index == 0 ? 'checked' : '' }),
													$span(logonSession.DisplayName),
												]));
											})
											: $p({ className: 'DefaultLogonSession', _textResource: 'JoinWithOptionsPanel.LogonSessionDefaultText' })
									),
								]);
							}(),
							$dl([
								$dt({ _textResource: 'JoinWithOptionsPanel.OtherOptionsLabelText' }),
								$dd([
									$p($label([
										$input({ type: 'checkbox' }),
										$span({ _textResource: 'JoinWithOptionsPanel.SuspendMyInputText' }),
									])),
								]),
							]),
						],
						buttonTextResourceName: 'JoinWithOptionsPanel.ButtonText',
						onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
							joinProc(
								dialog.querySelector('input[type=checkbox]').checked,
								(dialog.querySelector('input[type=radio]:checked') || {}).value
							);
						},
						buttonPanelExtraContent: [
							hasConnectedHost ? $p({ className: 'Success', _textResource: 'JoinWithOptionsPanel.HasConnectedHostText' }) : null,
						]
					});
				}
			} else if (commandName == 'InstallAccess') {
				SC.installer.showInstallAccessDialog(function (eventData, onSuccess, onFailure) {
					SC.service.AddSessionEvents(
						sessionInfo.SessionGroupPath,
						sessionIDs.map(it => ({ SessionID: it, EventType: SC.types.SessionEventType.QueuedInstallAccess, Data: eventData })),
						onSuccess,
						onFailure
					);
				});
			} else if (commandName == 'ForceDisconnect') {
				SC.service.AddSessionEvents(
					sessionInfo.SessionGroupPath,
					[{ SessionID: sessionIDs[0], EventType: SC.types.SessionEventType.QueuedForceDisconnect, ConnectionID: commandArgument.ConnectionID }]
				);
			} else if (commandName == 'DeleteEvent') {
				SC.service.AddSessionEvents(
					sessionInfo.SessionGroupPath,
					[{ SessionID: sessionIDs[0], EventType: SC.types.SessionEventType.DeletedEvent, CorrelationEventID: commandArgument.event.eventID }]
				);
			} else if (commandName == 'ViewRawData') {
				SC.dialog.showModalDialog('ViewRawData', {
					titleResourceName: 'ViewRawDataPanel.Title',
					content: [commandArgument.event]
						.concat(commandArgument.correlatedEvents)
						.map(it => SC.util.getEnumValueName(SC.types.SessionEventType, it.eventType) + ':\n\n' + it.data)
						.join('\n\n'),
				});
			} else if (commandName == 'RunTool') {
				SC.toolbox.showToolboxDialog(
					commandName,
					function (path, sessionEventType, onSuccess, onError) {
						SC.service.AddSessionEvents(
							sessionInfo.SessionGroupPath,
							sessionIDs.map(it => ({ SessionID: it, EventType: sessionEventType, Data: path })),
							onSuccess,
							onError
						);
					}
				);
			} else if (commandName == 'Transfer') {
				var titleAndButtonText = SC.res['Command.Transfer.ButtonText'];
				var selectBox = SC.ui.createElement('SELECT');

				SC.service.GetEligibleHosts(function (hosts) {
					Array.prototype.forEach.call(hosts, function (h) {
						selectBox.add(new Option(h));
					});
				});

				SC.dialog.showModalButtonDialog(
					'Prompt',
					titleAndButtonText,
					titleAndButtonText,
					'Default',
					function (container) {
						SC.ui.addElement(container, 'P', SC.res['Command.Transfer.Message']);
						SC.ui.addElement(container, 'P', selectBox);
					},
					function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.TransferSessions(
							sessionInfo.SessionGroupPath,
							sessionIDs,
							selectBox.options[selectBox.selectedIndex].value,
							closeDialogProc,
							setDialogErrorProc
						);
					}
				);
			} else if (commandName == 'Compose') {
				var url = SC.context.guestUrl + SC.util.getQueryString({ Session: sessions[0].SessionID });
				var emailSubject = SC.util.formatString(SC.util.getSessionTypeResource('InvitationPanel.{0}EmailSubjectFormat', sessions[0].SessionType), SC.context.userDisplayName, url, sessions[0].Name);
				var emailBody = SC.util.formatString(SC.util.getSessionTypeResource('InvitationPanel.{0}TextEmailBodyFormat', sessions[0].SessionType), SC.context.userDisplayName, url, sessions[0].Name);
				SC.util['openClient' + commandArgument](null, emailSubject, emailBody, SC.res['InvitationPanel.SendClient' + commandArgument + 'FileName']);

			} else if (commandName == 'SendInvitationEmail') {
				var url = SC.context.guestUrl + SC.util.getQueryString({ Session: sessions[0].SessionID });
				var sessionTypeName = SC.util.getEnumValueName(SC.types.SessionType, sessions[0].SessionType);

				SC.service.SendEmail(
					$('.GuestEmailBox').value.trim(),
					'InvitationPanel.{0}',
					[sessionTypeName],
					[SC.context.userDisplayName, url],
					'InvitationPanel.{0}',
					[sessionTypeName],
					[SC.context.userDisplayName, url],
					true,
					function () {
						SC.css.ensureClass($('.EmailTab .ResultPanel'), 'Success', true);
						SC.css.ensureClass($('.EmailTab .ResultPanel'), 'Failure', false);
						SC.ui.setContents($('.EmailTab .ResultPanel'), SC.res['Command.SendEmail.SuccessMessage']);
					},
					function (error) {
						SC.css.ensureClass($('.EmailTab .ResultPanel'), 'Success', false);
						SC.css.ensureClass($('.EmailTab .ResultPanel'), 'Failure', true);
						SC.ui.setContents($('.EmailTab .ResultPanel'), error.message);
					}
				);
			} else if (commandName == 'UpdateSession') {
				var dataItem = SC.command.getDataItem(commandElement);
				if (dataItem.propertyName == 'Name') {
					SC.service.UpdateSessionName(sessionInfo.SessionGroupPath, sessions[0].SessionID, commandArgument);
					findSessionRowFunc(sessionIDs[0])._sessionNameChangedSinceLastSelected = true;
				} else {
					SC.service.UpdateSessionCustomPropertyValue(sessionInfo.SessionGroupPath, sessions[0].SessionID, SC.util.getCustomPropertyIndex(dataItem.propertyName), commandArgument);
				}
			} else if (commandName == 'ChangeCodeToName') {
				SC.service.UpdateSessionCode(sessionInfo.SessionGroupPath, sessions[0].SessionID, sessions[0].Name);
			} else if (commandName == 'MakeSessionPublic') {
				SC.service.UpdateSessionIsPublicAndCode(sessionInfo.SessionGroupPath, sessions[0].SessionID, true, '');
			} else if (commandName == 'SaveInvitationCode') {
				SC.service.UpdateSessionCode(sessionInfo.SessionGroupPath, sessions[0].SessionID, commandArgument);
			} else if (commandName == 'MakeSessionPrivate') {
				SC.service.UpdateSessionIsPublicAndCode(sessionInfo.SessionGroupPath, sessions[0].SessionID, false, SC.util.getRandomStringFromMask(SC.res['SessionPanel.GenerateCodeMask']));
			} else if (commandName == 'GetHostPass') {
				var permissionsBox, timeBox, url, emailSubject, emailBody, memoBox;

				SC.dialog.showModalButtonDialog(
					'HostPass',
					SC.res['HostPassPanel.Title'],
					SC.res['HostPassPanel.DoneButtonText'],
					'Close',
					function (container) {
						SC.ui.addContent(container, [
							$p({ _htmlResource: 'HostPassPanel.Message' }),
							$dl([
								$dt({ _textResource: 'HostPassPanel.PermissionsLabelText' }),
								$dd($div({ className: 'EditField' },
									permissionsBox = $select([
										$option({
											value: SC.types.SessionPermissions.All,
											_textResource: 'HostPassPanel.PermissionsMyPermissionsText',
										}),
										[SC.types.SessionPermissions.TransferFiles, SC.types.SessionPermissions.Print, SC.types.SessionPermissions.SwitchLogonSession, SC.types.SessionPermissions.HostWithoutRemoteConsent]
											.map(function (permission) {
												return sessions[0].Permissions & permission ? $option({
													value: sessions[0].Permissions & ~permission,
													_textResource: SC.util.formatString('HostPassPanel.PermissionsAllExcept{0}Text', SC.util.getEnumValueName(SC.types.SessionPermissions, permission)),
												}) : null;
											}),
										$option({
											value: SC.types.SessionPermissions.Join | SC.types.SessionPermissions.ViewWithoutRemoteConsent,
											_textResource: 'HostPassPanel.PermissionsViewOnlyText',
										}),
									])
								)),
								$dt({ _textResource: 'HostPassPanel.LifetimeLabelText' }),
								$dd($div({ className: 'EditField' },
									timeBox = $select(
										SC.util.parseTsvIntoJaggedArray(SC.res['HostPassPanel.LifetimeItems'])
											.filter(function (_) { return _.length == 2 && parseInt(_[0]) != NaN && parseInt(_[0]) <= SC.context.accessTokenExpireSeconds; })
											.map(function (_) {
												return $option({ value: parseInt(_[0]) }, _[1]);
											})
									)
								)),
								$dt({ _textResource: 'HostPassPanel.MemoLabelText' }),
								$dd($div({ className: 'EditField' }, memoBox = $input({ type: 'text' }))),
							]),
							SC.ui.createSharePanel(
								'HostPassPanel',
								'SendHostPass',
								'CopyHostPass',
								null,
								function (onSuccessProc) {
									SC.service.GetDelegatedAccessToken(
										sessionInfo.SessionGroupPath,
										sessionIDs[0],
										permissionsBox.value,
										timeBox.value,
										memoBox.value,
										function (accessTokenString) {
											onSuccessProc(SC.context.guestUrl + SC.util.getQueryString({ Session: sessionIDs[0], HostAccessToken: accessTokenString }));
										}
									);
								},
								function (url) {
									return {
										resourceBaseNameFormat: 'HostPassPanel.{0}',
										resourceNameFormatArgs: [SC.util.getEnumValueName(SC.types.SessionType, sessions[0].SessionType)],
										resourceFormatArgs: [SC.context.userDisplayName, url, sessions[0].Name],
									};
								}
							),
						]);
					}
				);
			}
		}

		function addEventToSessions(sessionGroupPath, sessionType, sessionIDs, eventType, commandName, data, requiresData, requiresConfirmation, isAdvanced) {
			if ((!requiresConfirmation || isAdvanced) && (!requiresData || !SC.util.isNullOrEmpty(data))) {
				SC.service.AddSessionEvents(sessionGroupPath, sessionIDs.map(it => ({ SessionID: it, EventType: eventType, Data: data })));
			} else {
				SC.dialog.showModalPromptCommandBox(commandName, requiresData, true, function (enteredData, closeModalProc, onFailure) {
					if (!requiresData || !SC.util.isNullOrEmpty(enteredData)) {
						SC.service.AddSessionEvents(sessionGroupPath, sessionIDs.map(it => ({ SessionID: it, EventType: eventType, Data: enteredData })), closeModalProc, onFailure);
					} else {
						onFailure(new Error(SC.res['ModalPromptCommandBox.Error.EmptyData']));
					}
				}, SC.util.getEnumValueName(SC.types.SessionType, sessionType))
			}
		}

		function buildTimeline(container, sessionDetails, sortedEvents) {
			var computedStyle = SC.css.tryGetComputedStyle(container);
			var getExtendedCssValue = function (property) {
				return parseFloat(SC.css.tryGetExtendedCssValue(computedStyle, property));
			};

			var topPadding = getExtendedCssValue('top-padding');
			var bottomPadding = getExtendedCssValue('bottom-padding');
			var leftPadding = getExtendedCssValue('left-padding');
			var rightPadding = getExtendedCssValue('right-padding');
			var timestampPadding = getExtendedCssValue('timestamp-padding');
			var minTimelineWidth = getExtendedCssValue('min-timeline-width');
			var minTimelineHeight = getExtendedCssValue('min-timeline-height');
			var minGap = getExtendedCssValue('min-gap');
			var eventDotSideLength = getExtendedCssValue('event-dot-side-length');
			var connectionLineThickness = getExtendedCssValue('connection-line-thickness');
			var timeDivisionTextLineOffset = getExtendedCssValue('time-division-text-line-offset');
			var timeDifferenceDivisorPreLog = getExtendedCssValue('time-difference-divisor-pre-log');
			var timeDifferentMultiplierPostLog = getExtendedCssValue('time-different-multiplier-post-log');
			var connectionTextTopPadding = getExtendedCssValue('connection-text-top-padding');
			var connectionTextBottomPadding = getExtendedCssValue('connection-text-bottom-padding');
			var connectionTextLeftPadding = getExtendedCssValue('connection-text-left-padding');
			var connectionTextRightPadding = getExtendedCssValue('connection-text-right-padding');
			var positionPanelStep = getExtendedCssValue('position-panel-step');
			var spanTime = getExtendedCssValue('span-time');

			var eventDataMap = {};
			var uniqueTimeDatas = [];
			var positionedPanelBoundingBoxes = [];
			var maxPositionedPanelX = 0;
			var maxPositionedPanelY = 0;
			var currentEventTime = sessionDetails.BaseTime;
			var currentEventPosition = topPadding;
			var firstEventIndex = 0;

			if (sortedEvents.length != 0) {
				var minTime = sortedEvents[sortedEvents.length - 1].time - spanTime;
				var lowIndex = 0;
				var highIndex = sortedEvents.length - 1;

				while (lowIndex < highIndex) {
					firstEventIndex = Math.floor((lowIndex + highIndex) / 2);

					if (firstEventIndex == 0)
						break;
					else if (sortedEvents[firstEventIndex].time < minTime)
						lowIndex = firstEventIndex + 1;
					else if (sortedEvents[firstEventIndex - 1].time < minTime)
						break;
					else
						highIndex = firstEventIndex;
				}
			}

			uniqueTimeDatas.push({ time: currentEventTime, position: currentEventPosition });

			for (var i = sortedEvents.length - 1; i >= firstEventIndex; i--) {
				var previousEventTime = currentEventTime;
				currentEventTime = sortedEvents[i].time;

				if (currentEventTime > sessionDetails.BaseTime)
					currentEventTime = sessionDetails.BaseTime;

				if (currentEventTime != previousEventTime) {
					currentEventPosition += Math.max(minGap, Math.log((previousEventTime - currentEventTime) / timeDifferenceDivisorPreLog) * timeDifferentMultiplierPostLog);

					uniqueTimeDatas.push({ time: currentEventTime, position: currentEventPosition });
				}

				eventDataMap[sortedEvents[i].eventID] = { time: currentEventTime, position: currentEventPosition };
			}

			var timelineDiagram = SC.svg.addElement(container, 'svg');
			var timeDivisionContainer = SC.svg.addElement(timelineDiagram, 'g', { 'class': 'TimeDivision' });
			var positionedPanelContainer = SC.svg.addElement(timelineDiagram, 'g', { 'class': 'PositionedPanel' });

			var computedContainerStyle = SC.css.tryGetComputedStyle(container);
			var center = computedContainerStyle ? computedContainerStyle.width.replace('px', '') / 2 : 0;

			var positionPanelProc = function (panel) {
				var minX = Math.min(-center + timestampPadding + leftPadding, 0);
				var i = 0;
				var originalBoundingBox = panel.getBBox();
				var newBoundingBox = {
					x: originalBoundingBox.x,
					y: originalBoundingBox.y,
					width: originalBoundingBox.width,
					height: originalBoundingBox.height,
				};

				if (newBoundingBox.x < minX)
					newBoundingBox.x = minX;

				while (positionedPanelBoundingBoxes[i]) {
					if (SC.svg.areRectsIntersecting(newBoundingBox, positionedPanelBoundingBoxes[i])) {
						if (newBoundingBox.x <= Math.abs(minX))
							newBoundingBox.x *= -1;

						if (newBoundingBox.x >= 0)
							newBoundingBox.x += positionPanelStep;

						i = 0;
					} else {
						i++;
					}
				}

				maxPositionedPanelX = Math.max(maxPositionedPanelX, newBoundingBox.x + newBoundingBox.width);
				maxPositionedPanelY = Math.max(maxPositionedPanelY, newBoundingBox.y + newBoundingBox.height);

				SC.svg.setTransform(panel, newBoundingBox.x - originalBoundingBox.x, 0, 0);
				positionedPanelBoundingBoxes.push(newBoundingBox);

				// debugging:
				//SC.svg.addElement(timelineDiagram, 'rect', { x: newBoundingBox.x, y: newBoundingBox.y, width: newBoundingBox.width, height: newBoundingBox.height, stroke: stroke, fill: 'transparent' });
			};

			for (var i = 0; sessionDetails.Connections[i]; i++) {
				var connectionEvents = sessionDetails.Events.filter(it => it.ConnectionID == sessionDetails.Connections[i].ConnectionID);

				if (connectionEvents.length > 0) {
					var connectionPanel = null;
					var linePanel = null;
					var currentPosition = 0;
					var positionIndex = 0;
					var minPosition = Number.MAX_VALUE;
					var maxPosition = 0;
					var minTime = Number.MAX_VALUE;
					var maxTime = 0;
					var connectionStartElementInfo = null;
					var connectionEndElementInfo = null;
					var hasConnectedEvent = false;
					var hasDisconnectedEvent = false;
					var processTypeName = SC.util.getEnumValueName(SC.types.ProcessType, sessionDetails.Connections[i].ProcessType);

					Array.prototype.forEach.call(connectionEvents, function (e) {
						var eventData = eventDataMap[e.EventID];

						if (eventData) {
							if (eventData.position != currentPosition) {
								minPosition = Math.min(minPosition, eventData.position);
								maxPosition = Math.max(maxPosition, eventData.position);
								minTime = Math.min(minTime, eventData.time);
								maxTime = Math.max(maxTime, eventData.time);
								currentPosition = eventData.position;
								positionIndex = 0;
							} else {
								positionIndex++;
							}

							if (connectionPanel == null) {
								connectionPanel = SC.svg.addElement(positionedPanelContainer, 'g')
								linePanel = SC.svg.addElement(connectionPanel, 'g')
							}

							var eventElementAttributes = {
								'class': processTypeName,
								x: (positionIndex - 0.5) * eventDotSideLength,
								y: eventData.position - eventDotSideLength / 2,
								width: eventDotSideLength,
								height: eventDotSideLength,
								rx: eventDotSideLength / 2,
							};

							var eventElementTitle = SC.util.formatString(
								SC.res['Timeline.ConnectionEventTitleFormat'],
								SC.util.getEnumValueName(SC.types.SessionEventType, e.EventType),
								e.Data
							);

							var eventElement = SC.svg.addElement(
								connectionPanel,
								'rect',
								eventElementAttributes,
								null,
								null,
								eventElementTitle
							);

							eventElementAttributes['class'] = 'Overlay';

							var eventElementOverlay = SC.svg.addElement(
								connectionPanel,
								eventElement.tagName,
								eventElementAttributes,
								null,
								null,
								eventElementTitle
							);

							var eventElementInfo = {
								element: eventElement,
								title: eventElementTitle,
								overlay: eventElementOverlay,
							};

							if (eventData.position == maxPosition && positionIndex == 0)
								connectionStartElementInfo = eventElementInfo;

							if (eventData.position == minPosition)
								connectionEndElementInfo = eventElementInfo;

							hasConnectedEvent = (hasConnectedEvent || e.EventType == SC.types.SessionEventType.Connected);
							hasDisconnectedEvent = (hasDisconnectedEvent || e.EventType == SC.types.SessionEventType.Disconnected);
						}
					});

					var getDiamondVerticesString = function (centerX, centerY, width, height) {
						return [
							[centerX, centerY - height / 2],
							[centerX - width / 2, centerY],
							[centerX, centerY + height / 2],
							[centerX + width / 2, centerY],
						]
							.map(function (_) { return _.join(','); })
							.join(' ');
					};

					if (connectionPanel != null) {
						var continuationDiamondAxisLength = eventDotSideLength * Math.sqrt(2);

						if (!hasConnectedEvent) {
							maxPosition += continuationDiamondAxisLength;

							var startDiamondPoints = getDiamondVerticesString(
								0,
								maxPosition,
								continuationDiamondAxisLength,
								continuationDiamondAxisLength
							);

							connectionStartElementInfo = {
								element: SC.svg.addElement(
									connectionPanel,
									'polygon',
									{
										'class': processTypeName,
										points: startDiamondPoints,
									}
								),
								overlay: SC.svg.addElement(
									connectionPanel,
									'polygon',
									{
										'class': 'Overlay',
										points: startDiamondPoints,
									}
								),
							};
						}

						if (!hasDisconnectedEvent) {
							if (hasConnectedEvent) {
								minPosition = topPadding;
								maxTime = sessionDetails.BaseTime;
							}

							var endDiamondPoints = getDiamondVerticesString(
								0,
								minPosition,
								continuationDiamondAxisLength,
								continuationDiamondAxisLength
							);

							connectionEndElementInfo = {
								element: SC.svg.addElement(
									connectionPanel,
									'polygon',
									{
										'class': processTypeName,
										points: endDiamondPoints,
									}
								),
								overlay: SC.svg.addElement(
									connectionPanel,
									'polygon',
									{
										'class': 'Overlay',
										points: endDiamondPoints,
									}
								),
							};
						}
					}

					if (minPosition != Number.MAX_VALUE) {
						var connectionFormatArguments = [
							SC.util.getEnumValueName(SC.types.ProcessType, sessionDetails.Connections[i].ProcessType),
							sessionDetails.Connections[i].ParticipantName || SC.res['HostPanel.GuestAnonymousName'],
							sessionDetails.Connections[i].NetworkAddress,
							SC.util.getEnumValueName(SC.types.ClientType, sessionDetails.Connections[i].ClientType),
							sessionDetails.Connections[i].ClientVersion,
							SC.util.formatDurationFromSeconds((maxTime - minTime) / 1000),
						];

						SC.svg.setTitle(connectionPanel, SC.util.formatString(SC.res['Timeline.ConnectionTitleFormat'], connectionFormatArguments));

						var addTextAndAdjustSurroundingElementProc = function (text, position, surroundingElementInfo) {
							var textElement = SC.svg.addElement(
								connectionPanel,
								'text',
								{
									x: surroundingElementInfo.element.getBBox().x + surroundingElementInfo.element.getBBox().width / 2,
									y: position,
								},
								null,
								SC.util.formatString(text, connectionFormatArguments),
								surroundingElementInfo.title
							);

							SC.svg.setAttributes(textElement, {
								x: textElement.getBBox().x - textElement.getBBox().width / 2,
								y: position + position - textElement.getBBox().y - textElement.getBBox().height / 2,
							});

							var surroundingElementDimensionAttributes = null;
							if (surroundingElementInfo.element.tagName == 'rect') {
								surroundingElementDimensionAttributes = {
									x: textElement.getBBox().x - connectionTextLeftPadding,
									y: textElement.getBBox().y - connectionTextTopPadding,
									width: textElement.getBBox().width + connectionTextLeftPadding + connectionTextRightPadding,
									height: textElement.getBBox().height + connectionTextTopPadding + connectionTextBottomPadding,
								};
							} else if (surroundingElementInfo.element.tagName == 'polygon') {
								var height = eventDotSideLength * Math.sqrt(2);
								surroundingElementDimensionAttributes = {
									points: getDiamondVerticesString(
										textElement.getBBox().x + textElement.getBBox().width / 2,
										textElement.getBBox().y + textElement.getBBox().height / 2,
										textElement.getBBox().width / (height - textElement.getBBox().height) * height,
										height
									),
								};
							}

							SC.svg.setAttributes(surroundingElementInfo.element, surroundingElementDimensionAttributes);
							SC.svg.setAttributes(surroundingElementInfo.overlay, surroundingElementDimensionAttributes);
						};

						addTextAndAdjustSurroundingElementProc(SC.res['Timeline.ConnectionStartTextFormat'], maxPosition, connectionStartElementInfo);
						addTextAndAdjustSurroundingElementProc(SC.res['Timeline.ConnectionEndTextFormat'], minPosition, connectionEndElementInfo);
					}

					if (maxPosition > minPosition)
						SC.svg.addElement(
							linePanel,
							'rect',
							{
								'class': processTypeName,
								x: -connectionLineThickness / 2,
								y: minPosition,
								width: connectionLineThickness,
								height: maxPosition - minPosition,
							}
						);

					if (connectionPanel != null)
						positionPanelProc(connectionPanel);
				}
			}

			Array.prototype.forEach.call(sessionDetails.Events, function (e) {
				var eventData = eventDataMap[e.EventID];

				if (eventData && e.ConnectionID == null) {
					var eventPanel = SC.svg.addElement(positionedPanelContainer, 'g');

					SC.svg.addElement(
						eventPanel,
						'rect',
						{
							'class': 'Event',
							x: -eventDotSideLength / 2,
							y: eventData.position - eventDotSideLength / 2,
							width: eventDotSideLength,
							height: eventDotSideLength,
							rx: eventDotSideLength / 2,
						},
						null,
						null,
						SC.util.formatString(
							SC.res['Timeline.EventTitleFormat'],
							SC.util.getEnumValueName(SC.types.SessionEventType, e.EventType),
							e.Host,
							e.Data
						)
					);

					positionPanelProc(eventPanel);
				}
			});

			var timelineHeight = Math.max(
				minTimelineHeight,
				maxPositionedPanelY + bottomPadding
			);

			SC.svg.setAttributes(timelineDiagram, { height: timelineHeight, });

			// needs to be calculated after height is set because clientWidth depends on scrollbar
			var timelineWidth = Math.max(
				minTimelineWidth,
				center + maxPositionedPanelX + rightPadding,
				container.clientWidth
			);

			SC.svg.setAttributes(timelineDiagram, { width: timelineWidth });

			SC.svg.setTransform(positionedPanelContainer, center);

			Array.prototype.forEach.call(uniqueTimeDatas, function (td) {
				var timeLabel = SC.svg.addElement(timeDivisionContainer, 'g');
				SC.svg.addElement(
					timeLabel,
					'line',
					{
						x1: 0,
						y1: td.position,
						x2: timelineWidth,
						y2: td.position,
					}
				);

				SC.svg.addElement(
					timeLabel,
					'text',
					{
						x: leftPadding,
						y: td.position + timeDivisionTextLineOffset,
					},
					null,
					td.time == sessionDetails.BaseTime ? SC.res['Timeline.NowLabel'] : SC.util.formatDateTime(new Date(td.time), { includeRelativeDate: true, includeSeconds: true }),
					SC.util.formatDateTime(new Date(td.time), { includeFullDate: true, includeSeconds: true })
				);
			});
		}

		function getJoinModeText(session) {
			var joinModeTextResourceKey = (session.IsPublic ? 'SessionProperty.JoinMode.PublishedFormat' : (!SC.util.isNullOrEmpty(session.Code) ? 'SessionProperty.JoinMode.CodeFormat' : 'SessionProperty.JoinMode.InvitationOnlyFormat'));
			return SC.util.formatString(SC.res[joinModeTextResourceKey], session.Name, session.Code);
		}

		function selectSessionGroupElement(sessionGroupPath, shouldScrollIntoViewIfApplicable) {
			Array.prototype.find.call($('.MasterPanel').getElementsByTagName('LI'), function (e) {
				var elementSessionGroupPath = SC.command.getDataItems(e).reverse().map(function (_) { return _.Name; });
				var isSelected = SC.util.areArraysEqual(sessionGroupPath, elementSessionGroupPath);

				if (SC.ui.setSelected(e, isSelected) && isSelected && shouldScrollIntoViewIfApplicable)
					e.scrollIntoView(true);
			});
		}

		function selectSessionRow(sessionID, shouldScrollIntoViewIfApplicable, overrideRows) {
			var session = null;

			Array.prototype.forEach.call(overrideRows || $('.DetailTableContainer table').rows, function (r) {
				var isSessionRow = (r._dataItem.SessionID == sessionID);

				if (isSessionRow)
					session = r._dataItem;

				if (!isSessionRow)
					SC.ui.setChecked(r, false);

				if ((SC.ui.setSelected(r, isSessionRow) || r._sessionNameChangedSinceLastSelected) && isSessionRow && shouldScrollIntoViewIfApplicable)
					r.scrollIntoView(false);

				r._sessionNameChangedSinceLastSelected = false;
			});

			return session;
		}

		function tryGetSessionGroupSummary(sessionInfo) {
			if (!sessionInfo || !sessionInfo.SessionGroupPath || !sessionInfo.SessionGroupPath.length)
				return null;

			var sessionGroupSummaries = sessionInfo.PathSessionGroupSummaries[sessionInfo.SessionGroupPath.length - 1];
			var lastPathElement = sessionInfo.SessionGroupPath[sessionInfo.SessionGroupPath.length - 1];
			return sessionGroupSummaries.find(function (sgs) { return sgs.Name == lastPathElement; });
		}

		function getSortedEvents(sessionDetails) {
			var connectionMap = {};

			var getConnectionFunc = function (connectionID) {
				var connection = connectionMap[connectionID];

				if (connection === undefined) {
					connection = sessionDetails.Connections.filter(it => it.ConnectionID === connectionID)[0] || null;
					connectionMap[connectionID] = connection;
				}

				return connection;
			};

			return sessionDetails.Events
				.map(it => ({
					eventID: it.EventID,
					correlationEventID: it.CorrelationEventID,
					eventType: it.EventType,
					time: sessionDetails.BaseTime - it.Time,
					data: it.Data,
					who: it.Host || getConnectionFunc(it.ConnectionID)?.ParticipantName,
					processType: getConnectionFunc(it.ConnectionID)?.ProcessType ?? (it.Host ? SC.types.ProcessType.Host : SC.types.ProcessType.Guest),
				}))
				.sort((e1, e2) => e1.time - e2.time);
		}

		function onFilterBoxSearch(eventArgs) {
			var element = SC.event.getElement(eventArgs);
			window.setSearchUrlPart(element.value);
			SC.livedata.notifyDirty(window._dirtyLevels.SessionList);
			return true;
		}

		function setLoadingComplete(dirtyLevel) {
			setAnimationAttributeForLoadingState(dirtyLevel, false);
		}

		function setAnimationAttributeForLoadingState(dirtyLevel, isLoading) {
			var dirtyLevelName = SC.util.getEnumValueName(window._dirtyLevels, dirtyLevel);

			if (SC.css.ensureClass(window.document.body, dirtyLevelName + 'Loading', isLoading)) {
				var attributeName = dirtyLevelName + (isLoading ? 'BeginLoading' : 'EndLoading');
				var attributeNameToKeep = (isLoading ? '' : dirtyLevelName + 'BeginLoading');
				Array.from(window.document.body.attributes).forEach(function (_) {
					if (_.value === 'animation' && !SC.util.equalsCaseInsensitive(_.name, attributeNameToKeep))
						window.document.body.removeAttribute(_.name);
				});
				window.document.body.setAttribute(attributeName, 'animation');
			}
		}

		function getSessionTypeUrlPartAndSetIfInvalid() {
			var sessionType = window.getSessionTypeUrlPart();

			if (sessionType == null) {
				sessionType = SC.context.sessionTypeInfos.map(function (_) { return _.sessionType; })[0];
				window.setSessionTypeUrlPart(sessionType);
			}

			return sessionType;
		}

		function setHashParameter(parameterIndex, value, sectionIndex = 0) {
			if (SC.util.setHashParameter(parameterIndex, value, sectionIndex))
				window._ignoreHashChangeCount = (window._ignoreHashChangeCount || 0) + 1;
		}

		function getLocationHashParameter(parameterIndex) { return SC.util.getWindowHashParameter(parameterIndex, 0); }
		function setLocationHashParameter(parameterIndex, value) { return window.setHashParameter(parameterIndex, value, 0); }

		function getCommandHashParameters() { return SC.util.getWindowHashParameters(1); }
		function setCommandHashParameters(commandName, commandArgument) {
			window.setHashParameter(0, commandName, 1);
			window.setHashParameter(1, commandArgument, 1);
		}

		function getSessionTypeUrlPart() { return SC.types.SessionType[window.getLocationHashParameter(0)]; }
		function getSessionGroupUrlPart() { var p = window.getLocationHashParameter(1); return (p ? p.split('\x1f') : []); }
		function getSearchUrlPart() { return window.getLocationHashParameter(2); }
		function getSessionUrlPart() { return window.getLocationHashParameter(3); }
		function getTabNameUrlPart() { return window.getLocationHashParameter(4); }
		function getTabContextUrlPart() { return window.getLocationHashParameter(5); }

		function setSessionTypeUrlPart(value) { window.setLocationHashParameter(0, SC.util.getEnumValueName(SC.types.SessionType, value)); }
		function setSessionGroupUrlPart(value) { window.setLocationHashParameter(1, value.join('\x1f')); }
		function setSearchUrlPart(value) { window.setLocationHashParameter(2, value); }
		function setSessionUrlPart(value) { window.setLocationHashParameter(3, value); }
		function setTabNameUrlPart(value) { window.setLocationHashParameter(4, value); }
		function setTabContextUrlPart(value) { window.setLocationHashParameter(5, value); }

		function extractCommandNameAndArgumentFromUrl() {
			var commandDetails = window.getCommandHashParameters();
			if (commandDetails.length > 0)
				window.setCommandHashParameters(null, null);

			return { commandName: commandDetails[0], commandArgument: commandDetails[1] };
		}

		function updateHashBasedElements(shouldScrollIntoViewIfApplicable) {
			var sessionType = window.getSessionTypeUrlPartAndSetIfInvalid();
			SC.ui.setContents($('.MasterPanel h2'), SC.util.getSessionTypeResource('HostPanel.{0}Heading', sessionType));
			SC.ui.setContents($('.MasterPanel p'), SC.util.getSessionTypeResource('HostPanel.{0}HelpText', sessionType));
			SC.ui.setContents($('.MasterPanel p.Create'), $a({ _commandName: 'CreateSession', _commandArgument: sessionType }, SC.util.getSessionTypeResource('HostPanel.{0}ButtonText', sessionType)));
			SC.ui.setContents($('.MasterPanel p.Ambient'), SC.command.queryAndCreateCommandButtons('HostCreateSessionGroupPanel'));

			window.selectSessionGroupElement(window.getSessionGroupUrlPart(), shouldScrollIntoViewIfApplicable);
			window.selectSessionRow(window.getSessionUrlPart(), shouldScrollIntoViewIfApplicable);
			$('filterBox').value = window.getSearchUrlPart() || '';

			SC.command.updateCommandButtonsState($('.MasterPanel'));

			window.updateDetailPanels();
		}

		function onHashChange() {
			if (!window._ignoreHashChangeCount) {
				window.updateHashBasedElements(true);
				window._currentSessionDisplayLimit = SC.context.sessionDisplayLimit;
				SC.livedata.notifyDirty();
			} else {
				window._ignoreHashChangeCount--;
			}
		}

	</script>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="RunScript">
	<script>

		SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
			function createCommonMainButtonDefinitions() {
				return [
					{ commandName: 'Join', imageUrl: 'Images/CommandJoin.svg' },
					{ commandName: 'Edit', imageUrl: 'Images/CommandEdit.svg' },
				];
			}
			function createCommonExtendedButtonDefinitions() {
				return [
					{ commandName: 'JoinWithOptions' },
					{ commandName: 'InstallAccess' },
					{ commandName: 'Transfer' },
					{ commandName: 'Reinstall' },
					{ commandName: 'Uninstall' },
					{ commandName: 'Wake' },
					{ commandName: 'SendMessage' },
					{ commandName: 'RunCommand' },
					{ commandName: 'AddNote' },
					{ commandName: 'GetHostPass' },
				];
			}

			switch (eventArgs.area) {
				case 'HostCreateSessionGroupPanel':
					eventArgs.buttonDefinitions.push(
						{ commandName: 'CreateSessionGroup' },
					);
					break;
				case 'ShowSessionGroupPopupMenuPopoutPanel':
					eventArgs.buttonDefinitions.push(
						{ commandName: 'EditSessionGroup' },
						{ commandName: 'DeleteSessionGroup' },
						{ commandName: 'MoveSessionGroupToPosition' },
						{ commandName: 'MoveSessionGroupToTop' },
						{ commandName: 'MoveSessionGroupToBottom' },
						{ commandName: 'CloneSessionGroup' },
					);
					break;
				case 'HostCommandListPanel':
				case 'SubDetailHeaderCommandListPanel':
					eventArgs.buttonDefinitions.push(...createCommonMainButtonDefinitions());
					if (eventArgs.commandContext.sessionType === SC.types.SessionType.Access)
						eventArgs.buttonDefinitions.push({ commandName: 'RunTool', imageUrl: 'Images/CommandRunTool.svg' });
					else
						eventArgs.buttonDefinitions.push({ commandName: 'Delete', imageUrl: 'Images/CommandDelete.svg' });
					eventArgs.buttonDefinitions.push({ commandName: 'More', commandArgument: eventArgs.area === 'HostCommandListPanel' ? 'HostCommandListMorePopoutPanel' : 'SubDetailHeaderCommandListMorePopoutPanel', imageUrl: 'Images/CommandMore.svg' });
					break;
				case 'HostCommandListMorePopoutPanel':
				case 'SubDetailHeaderCommandListMorePopoutPanel':
					if (eventArgs.commandContext.sessionType === SC.types.SessionType.Access)
						eventArgs.buttonDefinitions.push({ commandName: 'Delete', imageUrl: 'Images/CommandDelete.svg' });
					else
						eventArgs.buttonDefinitions.push({ commandName: 'RunTool', imageUrl: 'Images/CommandRunTool.svg' });
					eventArgs.buttonDefinitions.push(...createCommonExtendedButtonDefinitions());
					break;
				case 'HostDetailTablePopoutPanel':
				case 'HostMultiSelectionPanel':
					eventArgs.buttonDefinitions.push(...createCommonMainButtonDefinitions());
					if (eventArgs.commandContext.sessionType === SC.types.SessionType.Access)
						eventArgs.buttonDefinitions.push({ commandName: 'RunTool', imageUrl: 'Images/CommandRunTool.svg' }, { commandName: 'Delete', imageUrl: 'Images/CommandDelete.svg' });
					else
						eventArgs.buttonDefinitions.push({ commandName: 'Delete', imageUrl: 'Images/CommandDelete.svg' }, { commandName: 'RunTool', imageUrl: 'Images/CommandRunTool.svg' });
					eventArgs.buttonDefinitions.push(...createCommonExtendedButtonDefinitions());
					break;
				case 'MoreInvitationOptionsPopoutPanel':
					eventArgs.buttonDefinitions.push(
						{ commandName: 'ChangeCodeToName' },
						{ commandName: 'MakeSessionPublic' },
						{ commandName: 'MakeSessionPrivate' },
					);
					break;
				case 'HostDetailTabList':
					eventArgs.buttonDefinitions.push(
						{ commandName: 'Select', commandArgument: 'Start', imageUrl: 'Images/TabStart.svg' },
						{ commandName: 'Select', commandArgument: 'General', imageUrl: 'Images/TabGeneral.svg' },
						{ commandName: 'Select', commandArgument: 'Timeline', imageUrl: 'Images/TabTimeline.svg' },
						{ commandName: 'Select', commandArgument: 'Messages', imageUrl: 'Images/TabMessages.svg' },
						{ commandName: 'Select', commandArgument: 'Commands', imageUrl: 'Images/TabCommands.svg' },
						{ commandName: 'Select', commandArgument: 'Notes', imageUrl: 'Images/TabNotes.svg' },
						{ commandName: 'Select', commandArgument: 'AccessManagement', imageUrl: 'Images/TabAccessManagement.svg' },
					);
					break;
				case 'ResponseCommandList':
					let responseCommandName =
						eventArgs.commandContext.event.eventType === SC.types.SessionEventType.RequestedElevation ? 'RespondToElevationRequest' :
							eventArgs.commandContext.event.eventType === SC.types.SessionEventType.RequestedAdministrativeLogon ? 'RespondToAdministrativeLogonRequest' :
								null;

					if (responseCommandName) {
						eventArgs.buttonDefinitions.push(
							{ commandName: responseCommandName, commandArgument: SC.util.getEnumValueName(SC.types.ResponseType, SC.types.ResponseType.Approve), imageUrl: 'Images/CommandApprove.svg' },
							{ commandName: responseCommandName, commandArgument: SC.util.getEnumValueName(SC.types.ResponseType, SC.types.ResponseType.Deny), imageUrl: 'Images/CommandDeny.svg' },
						);
					}
					break;
				case 'EventHistoryItem':
					eventArgs.buttonDefinitions.push(
						{ commandName: 'DeleteEvent', commandArgument: eventArgs.commandContext, imageUrl: 'Images/CommandDelete.svg' },
						{ commandName: 'ViewRawData', commandArgument: eventArgs.commandContext, imageUrl: 'Images/CommandViewRawData.svg' },
					);
					break;
			}
		});

		SC.event.addHandler($('.DetailTableContainer table'), 'contextmenu', function (eventArgs) {
			if (!SC.ui.isSelected(SC.ui.findAncestorByTag(eventArgs.target, 'TR'))) {
				SC.command.dispatchExecuteCommand(eventArgs.target, eventArgs.target, eventArgs.target, 'Select');
			}

			SC.popout.togglePanel({ x: eventArgs.clientX, y: eventArgs.clientY }, function (popoutPanel) {
				let context = window.getSelectedSessionsContext();
				SC.ui.setContents(popoutPanel, $div({ className: 'CommandList' }, [
					SC.command.queryAndCreateCommandButtons('HostDetailTablePopoutPanel', context),
					SC.command.queryAndCreateCommandButtons('HostDetailPopoutPanel'), // For extension backward compatibility
				]));
				SC.command.updateCommandButtonsState(popoutPanel, context);
			});

			eventArgs.preventDefault();
		});

		SC.event.addHandler($('.MasterListContainer'), SC.event.KeyNavigation, function (eventArgs) {
			// we don't check for null selected elements in this list because there will always be something selected here
			eventArgs.stopPropagation();

			var areRelated = function (firstElement, secondElement) {
				return firstElement != secondElement && firstElement.tagName == secondElement.tagName;
			};

			var isCollapsed = function (element) {
				return SC.css.containsClass(element, 'Collapsed') || !SC.ui.findDescendantBreadthFirst(element, function (_) { return areRelated(_, element); });
			};

			var ancestorWithSameTag = SC.ui.findAncestor(eventArgs.currentSelectedElement, function (_) { return areRelated(_, eventArgs.currentSelectedElement); });
			var descendantWithSameTag = SC.ui.findDescendantBreadthFirst(eventArgs.currentSelectedElement, function (_) { return areRelated(_, eventArgs.currentSelectedElement); });

			var elementToNavigateTo;

			if (eventArgs.arrowKeyInfo.isLeft || eventArgs.arrowKeyInfo.isRight) {
				if (isCollapsed(eventArgs.currentSelectedElement))
					elementToNavigateTo = eventArgs.arrowKeyInfo.isLeft ? ancestorWithSameTag : eventArgs.currentSelectedElement; // expands if collapsed
				else
					elementToNavigateTo = eventArgs.arrowKeyInfo.isLeft ? eventArgs.currentSelectedElement : descendantWithSameTag;
			} else if (eventArgs.arrowKeyInfo.isUp || eventArgs.arrowKeyInfo.isDown) {
				elementToNavigateTo = (eventArgs.arrowKeyInfo.isUp ?
					eventArgs.currentSelectedElement.previousElementSibling || ancestorWithSameTag :
					!isCollapsed(eventArgs.currentSelectedElement) && descendantWithSameTag
					|| eventArgs.currentSelectedElement.nextElementSibling
					|| ancestorWithSameTag && ancestorWithSameTag.nextElementSibling
				) || eventArgs.currentSelectedElement;

				if (isCollapsed(elementToNavigateTo)) // we double the dispatch to prevent the collapsed element from expanding if we got here by up/down
					SC.util.tryNavigateToElementUsingCommand(elementToNavigateTo, eventArgs.targetPreviousOrNext, eventArgs.hasShift);
			}

			SC.util.tryNavigateToElementUsingCommand(elementToNavigateTo, eventArgs.targetPreviousOrNext, eventArgs.hasShift);
		});

		SC.event.addGlobalHandler(SC.event.QueryTextEntryElement, function (eventArgs) {
			eventArgs.textEntryElement = $('filterBox');
		});

		SC.event.addGlobalHandler(SC.event.LiveDataDirtied, function (eventArgs) {
			window.setAnimationAttributeForLoadingState(eventArgs.dirtyLevel || window._dirtyLevels[Object.keys(window._dirtyLevels)[0]], true);
		});

		SC.event.addGlobalHandler(SC.event.QueryParticipantJoinedCount, function (eventArgs) {
			var rows = $('.DetailTableContainer table').rows;

			for (var i = 0; rows[i]; i++)
				if (rows[i]._dataItem.SessionID == eventArgs.clientLaunchParameters.s)
					eventArgs.participantJoinedCount = rows[i]._dataItem.ActiveConnections.filter(function (ac) { return ac.ProcessType == SC.types.ProcessType.Host && ac.ParticipantName == SC.context.userDisplayName; }).length;

			return 0;
		});

		SC.event.addGlobalHandler(SC.event.QueryLiveData, function (eventArgs) {
			eventArgs.requestInfoMap['HostSessionInfo'] = {
				sessionType: window.getSessionTypeUrlPartAndSetIfInvalid(),
				sessionGroupPathParts: window.getSessionGroupUrlPart(),
				filter: window.getSearchUrlPart(),
				findSessionID: window.getSessionGroupUrlPart().length === 0 ? window.getSessionUrlPart() : null,
				sessionLimit: window._currentSessionDisplayLimit,
			};
		});

		SC.event.addGlobalHandler(SC.event.PreRender, function () {
			SC.css.initializeExtendedCss(
				$('.MainPanel'),
				function (elementKey, settingKey) {
					return SC.util.loadSettings()['extendedCss']?.[settingKey]?.[elementKey]?.[window.getSessionTypeUrlPart()];
				},
				function (elementKey, settingKey, settingValue) {
					SC.util.modifySettings(function (settings) {
						SC.util.setValueAtPath(settings, ['extendedCss', settingKey, elementKey, window.getSessionTypeUrlPart()], settingValue);
					});
				}
			);

			window._dirtyLevels = SC.util.createEnum(['SessionGroupList', 'SessionList', 'SessionDetails']);

			window._currentSessionDisplayLimit = SC.context.sessionDisplayLimit;

			SC.css.ensureClass(document.documentElement, 'ShowMenu', window.getSessionGroupUrlPart().length == 0);

			SC.ui.setContents($('.DetailTableHeaderPanel'), [
				$a({ className: 'CheckBox', _commandName: 'Check' }, $img({ src: 'Images/Dropdown.svg' })),
				SC.ui.createFilterBox({ id: 'filterBox' }, window.onFilterBoxSearch),
			]);

			SC.command.queryAndAddCommandButtons($('.DetailTabList'), 'HostDetailTabList', null, { tagName: 'DIV', descriptionRenderStyle: SC.command.DescriptionRenderStyle.Tooltip });
			SC.ui.addContent($('.SubDetailPanel'), $a({ _commandName: 'ToggleDetailPanel', className: 'ToggleDetailPanelButton' }));
			SC.event.addHandler(window, 'hashchange', window.onHashChange);

			window.updateHashBasedElements(true);
		});

		SC.event.addGlobalHandler(SC.event.QueryTabContainsRelativeTimes, function (eventArgs) {
			if (eventArgs.tabName == 'Start' || eventArgs.tabName == 'General')
				eventArgs.hasRelativeTimes = true;
		});

		SC.event.addGlobalHandler(SC.event.InitializeTab, function (eventArgs) {
			var createFieldProc = function (propertyName, contents, updateContentFunc) {
				return [
					SC.util.isNullOrEmpty(propertyName) ? null : $dt({ _textResource: 'SessionProperty.' + propertyName + '.LabelText' }),
					$dd({ _dataItem: { propertyName: propertyName }, _updateContentFunc: updateContentFunc }, contents),
				];
			};

			var createSimpleFieldProc = function (propertyName, getSessionValuesFunc, isPopulatedFunc, getBarPercentageFunc) {
				return createFieldProc(propertyName, null, function (container, session, sessionDetails, sessionAgeSeconds, sessionDetailsAgeSeconds) {
					if (isPopulatedFunc && !isPopulatedFunc(session, sessionDetails))
						return '';

					var values = getSessionValuesFunc(session, sessionDetails, sessionAgeSeconds, sessionDetailsAgeSeconds);
					var valueFormat = SC.res['SessionProperty.' + propertyName + '.ValueFormat'];
					SC.ui.setContents(container, SC.util.isNullOrEmpty(valueFormat) ? values : SC.util.formatString(valueFormat, values));
					if (getBarPercentageFunc) {
						SC.ui.addBarGraph(container, getBarPercentageFunc(session, sessionDetails, sessionAgeSeconds, sessionDetailsAgeSeconds));
					}
				});
			};

			var createEditableFieldProc = function (commandName, propertyName, properties, getSessionValuesFunc, isPopulatedFunc) {
				var sessionType = eventArgs.sessionType;
				return createFieldProc(
					propertyName,
					SC.ui.createEditableInput(
						commandName,
						properties,
						null,
						function (eventArgs) {
							var customPropertyIndex = SC.util.getCustomPropertyIndex(propertyName);

							if (customPropertyIndex != -1)
								SC.service.GetDistinctCustomPropertyValues([customPropertyIndex], sessionType, function (values) {
									SC.ui.setInputHintValues(eventArgs.target, values[0]);
								});
						}
					),
					function (container, session, sessionDetails, sessionAgeSeconds, sessionDetailsAgeSeconds) {
						if (isPopulatedFunc && !isPopulatedFunc(session, sessionDetails))
							return '';

						var values = getSessionValuesFunc(session, sessionDetails, sessionAgeSeconds, sessionDetailsAgeSeconds);
						var valueFormat = SC.res['SessionProperty.' + propertyName + '.ValueFormat'];
						container._dataItem.SessionID = session.SessionID;
						var input = container.querySelector('input');
						if (input != document.activeElement) {
							input.value = SC.util.isNullOrEmpty(valueFormat) ? values.toString() : SC.util.formatString(valueFormat, values);
							input.disabled = !window.isCommandEnabled('Edit', null, { sessions: [session], permissions: session.Permissions });
						}
					}
				);
			};

			var createCustomPropertyGetFunc = function (i) { return function (session) { return session.CustomPropertyValues[i]; }; };
			var isEventOnTabFunc = function (event) { return SC.nav.getHostTabName(event.eventType) === eventArgs.tabName; };

			switch (eventArgs.tabName) {
				case 'Start':
					SC.ui.setContents(eventArgs.container, [
						$dl({ className: 'EditSessionPanel' }, [
							createEditableFieldProc('UpdateSession', 'Name', null, function (session) { return session.Name; }),
							SC.util.getVisibleCustomPropertyIndices(eventArgs.sessionType)
								.map(function (index) { return createEditableFieldProc('UpdateSession', SC.util.getCustomPropertyName(index), null, createCustomPropertyGetFunc(index)); }),
						]),
						$div({ className: 'InvitationPanel', _visible: eventArgs.sessionType != SC.types.SessionType.Access }, [
							$div({ className: 'InvitationTabList' }, [
								$span([SC.res['InvitationPanel.InvitationTabListMessage'], $nbsp(), $nbsp()]),
								SC.command.createCommandButtons([
									{ commandName: 'Select', commandArgument: 'Code' },
									{ commandName: 'Select', commandArgument: 'Email' },
									{ commandName: 'Select', commandArgument: 'Link' },
									{ commandName: 'Select', commandArgument: 'Calendar' }
								]),
							]),
							$div({ className: 'InvitationTabContent' }, [
								$div({ className: 'CodeTab', _tabName: 'Code' }, [
									$a({ _commandName: 'MoreInvitationOptions', className: 'MoreOptionsButton' }),
									$p({ _textResource: 'InvitationPanel.CodeTabText' }),
									$h3(SC.context.guestUrl),
									$p({ className: 'InvitationInstruction' }),
									$dl([
										createEditableFieldProc('SaveInvitationCode', '', { className: 'EditInvitationCodeBox' }, function (session) { return session.Code; }),
										createEditableFieldProc('UpdateSession', '', { className: 'PublicSessionNameBox' }, function (session) { return session.Name; }),
									]),
								]),
								$div({ className: 'EmailTab', _tabName: 'Email' }, [
									$dl([
										$dt({ _textResource: 'InvitationPanel.EmailTabLabel' }),
										$dd([
											$div([
												$input({ className: 'GuestEmailBox', type: 'text', _commandName: 'SendInvitationEmail', placeholder: SC.res['InvitationPanel.EmailTabPlaceholder'] }),
												$button({ _commandName: 'SendInvitationEmail', _textResource: 'InvitationPanel.EmailTab.SendButtonText' }),
											]),
											$p({ className: 'ResultPanel' })
										]),
										$dt(),
										$dd({ _visible: SC.util.getBooleanResource('InvitationPanel.ComposeEmailVisible') }, [
											$span({ _textResource: 'InvitationPanel.EmailTabText' }),
											$nbsp(),
											$nbsp(),
											$a({ _commandName: 'Compose', _commandArgument: 'Email', _textResource: 'InvitationPanel.EmailTab.ComposeEmailButtonText' }),
										]),
									]),
								]),
								$div({ className: 'LinkTab', _tabName: 'Link' }, [
									$dl([
										$dt({ _textResource: 'InvitationPanel.LinkTabLabel' }),
										$dd([
											$div([
												$input({ type: 'text', className: 'ShareableLinkText', readOnly: true }),
												$button({
													_eventHandlerMap: {
														click: function (eventArgs) {
															SC.ui.executeCopyToClipboard(eventArgs.target.parentNode.firstChild, $('.LinkTab .ResultPanel'));
														},
													},
													_textResource: 'InvitationPanel.LinkTab.CopyButtonText',
												}),
											]),
											$p({ className: 'ResultPanel' })
										])
									]),
								]),
								$div({ className: 'CalendarTab', _tabName: 'Calendar' }, [
									$dl([
										$dd([
											$p({ _textResource: 'InvitationPanel.SendClientEventLinkText' }),
											$p($button({ _commandName: 'Compose', _commandArgument: 'Event', _textResource: 'InvitationPanel.CalendarTab.OpenButtonText' })),
										])
									]),
								]),
							]),
						]),
						$div({ className: 'JoinButtonPanel' }, [
							$input({ type: 'button', _commandName: 'Join', value: SC.res['Command.Join.Text'] }),
						]),
						$div({ className: 'JoinInfoPanel' }, [
							$div({ className: 'NoGuestJoinedPanel' }, [
								$h3(SC.util.getSessionTypeResource('NoGuestJoinedPanel.{0}Heading', eventArgs.sessionType)),
								$p(SC.util.getSessionTypeResource('NoGuestJoinedPanel.{0}Text', eventArgs.sessionType)),
							]),
							$div({ className: 'GuestJoinedPanel' }, [
								$h3(SC.util.getSessionTypeResource('GuestJoinedPanel.{0}Heading', eventArgs.sessionType)),
								$p(SC.util.getSessionTypeResource('GuestJoinedPanel.{0}Text', eventArgs.sessionType)),
							]),
						]),
						$div({ className: 'ScreenshotPanel' }),
					]);

					var firstTabItem = $$('.InvitationTabList a').find(function (_) {
						return SC.util.getBooleanResource('InvitationPanel.' + _._commandArgument + 'TabVisible');
					});

					if (firstTabItem) {
						SC.ui.setSelected(firstTabItem, true);
						Array.from($('.InvitationTabContent').childNodes).forEach(function (_) { SC.ui.setSelected(_, _._tabName == firstTabItem._commandArgument); });
					}

					break;
				case 'General':
					var formatDeletableItemsFunc = function (items, deleteCommandName, getItemTextFunc, getItemTitleFunc, getCommandArgument) {
						return items.map(function (it, i) {
							return [
								i !== 0 ? ', ' : null,
								$span({ title: getItemTitleFunc(it) }, getItemTextFunc(it)),
								$nbsp(),
								$a({ _commandName: deleteCommandName, _commandArgument: getCommandArgument(it) }, '[X]'),
							];
						});
					};

					var formatConnectionsFunc = function (session, sessionAgeSeconds, processType) {
						return formatDeletableItemsFunc(
							session.ActiveConnections.filter(function (it) { return it.ProcessType === processType }),
							'ForceDisconnect',
							(it) => SC.util.formatString(
								'{0} ({1})',
								SC.util.isNullOrEmpty(it.ParticipantName) ? SC.res['HostPanel.GuestAnonymousName'] : it.ParticipantName,
								SC.util.formatDateTimeFromSecondsAgo(it.ConnectedTime + sessionAgeSeconds, { includeRelativeDate: true })
							),
							(it) => SC.util.formatDateTimeFromSecondsAgo(it.ConnectedTime + sessionAgeSeconds, { includeFullDate: true, includeSeconds: true }),
							(it) => it
						);
					};

					SC.ui.setContents(eventArgs.container, [
						SC.ui.createCollapsiblePanel(
							$h3({ _textResource: 'General.Screenshot.Title' }),
							$div({ className: 'ScreenshotPanel' })
						),
						SC.ui.createCollapsiblePanel(
							$h3({ _textResource: 'General.Session.Title' }),
							$dl([
								createSimpleFieldProc('Name', function (session) { return session.Name; }),
								SC.util.getVisibleCustomPropertyIndices(eventArgs.sessionType)
									.map(function (index) { return createSimpleFieldProc(SC.util.getCustomPropertyName(index), createCustomPropertyGetFunc(index)); }),
								eventArgs.sessionType == SC.types.SessionType.Access ? null : [
									createSimpleFieldProc('JoinMode', function (session) { return window.getJoinModeText(session); }),
									createSimpleFieldProc('Host', function (session) { return session.Host; }),
								],
								createSimpleFieldProc('HostsConnected', function (session, sessionDetails, sessionAgeSeconds) { return formatConnectionsFunc(session, sessionAgeSeconds, SC.types.ProcessType.Host); }),
								createSimpleFieldProc('GuestsConnected', function (session, sessionDetails, sessionAgeSeconds) { return formatConnectionsFunc(session, sessionAgeSeconds, SC.types.ProcessType.Guest); }),
								createSimpleFieldProc('LastGuestDisconnectedEventTime', function (session, sessionDetails, sessionAgeSeconds) {
									return session.LastGuestDisconnectedEventTime < 0 ? '' : $span(
										{ title: SC.util.formatDateTimeFromSecondsAgo(session.LastGuestDisconnectedEventTime + sessionAgeSeconds, { includeFullDate: true, includeSeconds: true }) },
										SC.util.formatDateTimeFromSecondsAgo(session.LastGuestDisconnectedEventTime + sessionAgeSeconds, { includeRelativeDate: true })
									);
								}),
								eventArgs.sessionType == SC.types.SessionType.Meeting ? null : [
									createSimpleFieldProc('LoggedOnUser', function (session) { return SC.util.formatDomainMember(session.GuestLoggedOnUserDomain, session.GuestLoggedOnUserName); }),
									createSimpleFieldProc('IdleTime', function (session, sessionDetails, sessionAgeSeconds) { return SC.util.formatDurationFromSeconds(session.GuestIdleTime + sessionAgeSeconds); }),
								],
								createSimpleFieldProc('PendingActivity', function (session, _, sessionAgeSeconds) {
									return formatDeletableItemsFunc(
										session.QueuedEvents,
										'DeleteEvent',
										(it) => SC.util.formatString(
											'{0} ({1})',
											SC.util.getEnumValueName(SC.types.SessionEventType, it.EventType),
											SC.util.formatDateTimeFromSecondsAgo(it.Time + sessionAgeSeconds, { includeRelativeDate: true })
										),
										(it) => SC.util.formatDateTimeFromSecondsAgo(it.Time + sessionAgeSeconds, { includeFullDate: true, includeSeconds: true }),
										(it) => ({ event: { eventID: it.EventID, eventType: it.EventType }, processedEvents: [] })
									);
								}),
								createSimpleFieldProc('Attributes', function (session, sessionDetails) { return [sessionDetails.Session.GuestAttributes]; }),
							])
						),
						eventArgs.sessionType == SC.types.SessionType.Meeting ? null : [
							SC.ui.createCollapsiblePanel(
								$h3({ _textResource: 'General.Device.Title' }),
								$dl([
									createSimpleFieldProc('Machine', function (session, sessionDetails) { return SC.util.formatDomainMember(sessionDetails.Session.GuestMachineDomain, sessionDetails.Session.GuestMachineName); }),
									createSimpleFieldProc('OperatingSystem', function (session, sessionDetails) { return [sessionDetails.Session.GuestOperatingSystemManufacturerName, session.GuestOperatingSystemName, session.GuestOperatingSystemVersion, sessionDetails.Session.GuestOperatingSystemLanguage]; }, function (session) { return !SC.util.isNullOrEmpty(session.GuestOperatingSystemName); }),
									createSimpleFieldProc('OperatingSystemInstallation', function (session, sessionDetails, sessionAgeSeconds) { 
										return $span({ 
													title:  SC.util.formatDateTimeFromSecondsAgo(sessionDetails.Session.GuestOperatingSystemInstallationTime + sessionAgeSeconds, { includeFullDate: true, includeSeconds: true })}, 
													SC.util.formatDateTimeFromSecondsAgo(sessionDetails.Session.GuestOperatingSystemInstallationTime + sessionAgeSeconds, { includeFullDate: true })); 
										}, function (session, sessionDetails) { return sessionDetails.Session.GuestOperatingSystemInstallationTime >= 0; }),
									createSimpleFieldProc('Processor', function (session, sessionDetails) { return [sessionDetails.Session.GuestProcessorName, sessionDetails.Session.GuestProcessorVirtualCount, sessionDetails.Session.GuestProcessorArchitecture]; }, function (session, sessionDetails) { return !SC.util.isNullOrEmpty(sessionDetails.Session.GuestProcessorName); }),
									createSimpleFieldProc('SystemMemory', function (session, sessionDetails) { return [sessionDetails.Session.GuestSystemMemoryTotalMegabytes, sessionDetails.Session.GuestSystemMemoryAvailableMegabytes]; }, function (session, sessionDetails) { return sessionDetails.Session.GuestSystemMemoryTotalMegabytes > 0; }, function (session, sessionDetails) { return 100 * (1 - sessionDetails.Session.GuestSystemMemoryAvailableMegabytes / sessionDetails.Session.GuestSystemMemoryTotalMegabytes); }),
									createSimpleFieldProc('MachineManufacturerModel', function (session, sessionDetails) { return [sessionDetails.Session.GuestMachineManufacturerName, sessionDetails.Session.GuestMachineModel]; }),
									createSimpleFieldProc('MachineProductSerial', function (session, sessionDetails) { return [sessionDetails.Session.GuestMachineProductNumber, sessionDetails.Session.GuestMachineSerialNumber]; }),
									createSimpleFieldProc('MachineDescription', function (session, sessionDetails) { return [sessionDetails.Session.GuestMachineDescription]; }),
								])
							),
							SC.ui.createCollapsiblePanel(
								$h3({ _textResource: 'General.Network.Title' }),
								$dl([
									createSimpleFieldProc('NetworkAddress', function (session, sessionDetails) { return [sessionDetails.Session.GuestNetworkAddress]; }),
									createSimpleFieldProc('PrivateNetworkAddress', function (session, sessionDetails) { return [sessionDetails.Session.GuestPrivateNetworkAddress]; }),
									createSimpleFieldProc('HardwareNetworkAddress', function (session, sessionDetails) { return [sessionDetails.Session.GuestHardwareNetworkAddress]; }),
								])
							),
							SC.ui.createCollapsiblePanel(
								$h3({ _textResource: 'General.Other.Title' }),
								$dl([
									createSimpleFieldProc('ClientVersion', function (session) { return [session.GuestClientVersion] }),
									createSimpleFieldProc('TimeZoneName', function (session, sessionDetails) { return [sessionDetails.Session.GuestTimeZoneName]; }),
									createSimpleFieldProc('Uptime', function (session, sessionDetails, sessionAgeSeconds) { return SC.util.formatDurationFromSeconds(sessionDetails.Session.GuestLastBootTime + sessionAgeSeconds); }),
									createSimpleFieldProc('IsLocalAdminPresent', function (session, sessionDetails) {
										return [SC.res['SessionProperty.IsLocalAdminPresent.' + SC.util.getEnumValueName(SC.types.LocalAdminPresentStatus, sessionDetails.Session.GuestIsLocalAdminPresent)]];
									}),
								])
							),
						],
					]);
					break;
				case 'Messages':
					SC.ui.setContents(eventArgs.container, SC.entryhistory.createPanel(
						'Images/EmptyMessages.svg',
						SC.res['Command.SendMessage.EmptyTitle'],
						SC.res['Command.SendMessage.Message'],
						SC.res['Command.SendMessage.PlaceholderText'],
						SC.res['Command.SendMessage.ButtonText'],
						SC.res['HostPanel.GuestAnonymousName'],
						'SendMessage',
						isEventOnTabFunc
					));
					break;
				case 'Commands':
					SC.ui.setContents(eventArgs.container, SC.entryhistory.createPanel(
						'Images/EmptyCommands.svg',
						SC.res['Command.RunCommand.EmptyTitle'],
						SC.res['Command.RunCommand.Message'],
						SC.res['Command.RunCommand.PlaceholderText'],
						SC.res['Command.RunCommand.ButtonText'],
						SC.res['HostPanel.GuestAnonymousName'],
						'RunCommand',
						isEventOnTabFunc,
						function (e) { return e.eventType == SC.types.SessionEventType.QueuedCommand; }
					));
					break;
				case 'Notes':
					SC.ui.setContents(eventArgs.container, SC.entryhistory.createPanel(
						'Images/EmptyNotes.svg',
						SC.res['Command.AddNote.EmptyTitle'],
						SC.res['Command.AddNote.Message'],
						SC.res['Command.AddNote.PlaceholderText'],
						SC.res['Command.AddNote.ButtonText'],
						SC.res['HostPanel.GuestAnonymousName'],
						'AddNote',
						isEventOnTabFunc
					));
					break;
				case 'AccessManagement':
					SC.ui.setContents(eventArgs.container, SC.entryhistory.createPanel(
						'Images/EmptyAccessManagement.svg',
						SC.res['Command.AccessManagement.EmptyTitle'],
						SC.res['Command.AccessManagement.Message'],
						null,
						null,
						SC.res['HostPanel.GuestAnonymousName'],
						null,
						isEventOnTabFunc
					));
					break;
				default:
					break;
			}
		});

		SC.event.addGlobalHandler(SC.event.RefreshTab, function (eventArgs) {
			function refreshScreenshotPanel() {
				var screenshotPanel = eventArgs.container.querySelector('.ScreenshotPanel');
				var imageSrc = eventArgs.sessionDetails.Session.GuestScreenshotContentType ? SC.ui.createDataUri(eventArgs.sessionDetails.Session.GuestScreenshotContentType, eventArgs.sessionDetails.GuestScreenshotContent) : '';

				SC.ui.setContents(screenshotPanel, [
					$div({ _visible: eventArgs.sessionDetails.Session.GuestScreenshotContentType }, [
						$img({
							_commandName: 'ShowImage',
							_commandArgument: {
								src: imageSrc,
								dialogTitle: SC.res['ExpandedScreenshotPanel.Title'],
							},
							src: imageSrc,
						}),
						$span({ className: 'QueuedGuestInfoActivityIndicator' }),
					]),
					$p([
						$span(
							{ title: SC.util.formatDateTimeFromSecondsAgo(eventArgs.sessionDetails.Session.GuestInfoUpdateTime + eventArgs.sessionDetailsAgeSeconds, { includeFullDate: true, includeSeconds: true }) },
							SC.util.formatString(SC.res['SessionProperty.GuestInfoUpdateTime.ValueFormat'], SC.util.formatDateTimeFromSecondsAgo(eventArgs.sessionDetails.Session.GuestInfoUpdateTime + eventArgs.sessionDetailsAgeSeconds, { includeRelativeDate: true }))
						),
						SC.command.createCommandButtons([{ commandName: 'UpdateGuestInfo' }]),
					]),
				]);

				SC.css.ensureClass(screenshotPanel, 'Loading', eventArgs.session.QueuedEvents.find(function (queuedEvent) { return queuedEvent.EventType == SC.types.SessionEventType.QueuedGuestInfoUpdate }));
				SC.ui.setVisible(screenshotPanel, eventArgs.sessionDetails.Session.GuestInfoUpdateTime >= 0);
			}

			function refreshDetailInfos() {
				SC.ui.findDescendent(eventArgs.container, function (e) {
					if (e._updateContentFunc)
						e._updateContentFunc(e, eventArgs.session, eventArgs.sessionDetails, eventArgs.sessionAgeSeconds, eventArgs.sessionDetailsAgeSeconds);
				});
			}

			switch (eventArgs.tabName) {
				case 'Start':
					SC.css.ensureClass(eventArgs.container.querySelector('.MoreOptionsButton'), 'HiddenPanel', !window.isCommandEnabled('Edit', null, { sessions: [eventArgs.session], permissions: eventArgs.session.Permissions }));

					if (eventArgs.session.SessionType != SC.types.SessionType.Access) {
						SC.ui.setInnerText(eventArgs.container.querySelector('.InvitationInstruction'), SC.res[eventArgs.session.IsPublic ? 'InvitationPanel.InvitationInstruction.IsPublicText' : 'InvitationPanel.InvitationInstruction.IsNotPublicText']);
						eventArgs.container.querySelector('.EditInvitationCodeBox').value = eventArgs.session.Code;
						eventArgs.container.querySelector('.PublicSessionNameBox').value = eventArgs.session.Name;
						SC.css.ensureClass(eventArgs.container.querySelector('.CodeTab'), 'PublicSession', eventArgs.session.IsPublic);
						var shareableLinkTextBox = eventArgs.container.querySelector('.ShareableLinkText');
						shareableLinkTextBox.value = shareableLinkTextBox.title = SC.context.guestUrl + SC.util.getQueryString({ Session: eventArgs.session.SessionID });
					}

					SC.css.ensureClass(eventArgs.container.querySelector('.JoinInfoPanel'), 'NoGuest', !eventArgs.session.ActiveConnections.some(function (_) { return _.ProcessType == SC.types.ProcessType.Guest }));
					refreshScreenshotPanel();
					refreshDetailInfos();

					if (eventArgs.sortedEvents.length === 1 && (SC.util.getMillisecondCount() - eventArgs.sortedEvents[0].time < 1000) && eventArgs.session.Host === SC.context.userDisplayName )
						SC.ui.selectText($('.EditSessionPanel input'));

					return true;

				case 'General':
					refreshScreenshotPanel();
					refreshDetailInfos();
					return true;

				case 'Timeline':
					SC.ui.clear(eventArgs.container);
					window.buildTimeline(eventArgs.container, eventArgs.sessionDetails, eventArgs.sortedEvents);
					return false;

				case 'Messages':
				case 'Commands':
				case 'Notes':
				case 'AccessManagement':
					var commandName = SC.entryhistory.getAddCommandName(eventArgs.container.firstChild);
					var entryEnabled = window.isCommandEnabled(commandName, null, { sessions: [eventArgs.session], permissions: eventArgs.session.Permissions });
					SC.entryhistory.setEntryEnabled(eventArgs.container.firstChild, entryEnabled);
					SC.entryhistory.rebuildPanel(eventArgs.container.querySelector('.EntryHistoryPanel'), eventArgs.sortedEvents, eventArgs.tabContext);
					return true;

				default:
					return false;
			}
		});

		SC.event.addGlobalHandler(SC.event.QuerySessionEventRenderInfo, function (eventArgs) {
			switch (eventArgs.eventInfo.event.eventType) {
				case SC.types.SessionEventType.EncounteredElevationPrompt:
				case SC.types.SessionEventType.RequestedElevation:
				case SC.types.SessionEventType.RequestedAdministrativeLogon:
				case SC.types.SessionEventType.QueuedProceedElevation:
				case SC.types.SessionEventType.QueuedProceedAdministrativeLogon:
					eventArgs.renderInfo.isTitleVisible = true;
					eventArgs.renderInfo.isRawDataVisible = false;
					eventArgs.renderInfo.isDataFieldListVisible = !!eventArgs.eventInfo.event.data;
					break;
			}

			eventArgs.renderInfo.isRequestResolutionListVisible = eventArgs.eventInfo.requestResolutionEvents.length > 0 && SC.context.eventTypesAllowingResponse.includes(eventArgs.eventInfo.event.eventType)
			eventArgs.renderInfo.isResponseCommandListVisible = eventArgs.eventInfo.requestResolutionEvents.length === 0 && SC.context.eventTypesAllowingResponse.includes(eventArgs.eventInfo.event.eventType)
			eventArgs.renderInfo.isWaitingToProcessVisible = eventArgs.eventInfo.processedEvents.length === 0 && SC.context.eventTypesAllowingProcessing.includes(eventArgs.eventInfo.event.eventType)
		});

		SC.event.addGlobalHandler(SC.event.ExecuteCommand, window.onExecuteCommand);
		SC.event.addGlobalHandler(SC.event.QueryCommandButtonState, window.onQueryCommandButtonState);
		SC.event.addGlobalHandler(SC.event.LiveDataRefreshed, window.onLiveDataRefreshed);

	</script>
</asp:Content>
