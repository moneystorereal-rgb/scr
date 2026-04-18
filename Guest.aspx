<%@ Page Language="C#" MasterPageFile="~/Default.master" ClassName="ScreenConnect.GuestPage" Async="true" %>

<asp:Content runat="server" ContentPlaceHolderID="Main">
	<div class="ContentPanel">
		<div>
			<div class="WelcomePanel"></div>
			<div class="ActionPanel"></div>
		</div>
		<div class="InfoPanel"></div>
	</div>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="DeclareScript">
	<script>

		function setTaggedSessionInfo(tag, taggedSessionInfo) {
			var oldTaggedSessionInfo = window._taggedSessionInfos[tag];
			window._taggedSessionInfos[tag] = taggedSessionInfo;

			if (!oldTaggedSessionInfo || taggedSessionInfo.SessionID != oldTaggedSessionInfo.SessionID || taggedSessionInfo.Code != oldTaggedSessionInfo.Code)
				SC.livedata.notifyDirty();
		}

		// backwards compatibility with extensions
		function setTaggedSessionID(tag, sessionID) {
			window.setTaggedSessionInfo(tag, { SessionID: sessionID });
		}

		function getTaggedSessionInfo(tag) {
			return window._taggedSessionInfos[tag];
		}
		
		function getSessionInfo() {
			var liveData = SC.livedata.get();
			return liveData && liveData.ResponseInfoMap && liveData.ResponseInfoMap['GuestSessionInfo']
		}

	</script>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="RunScript">
	<script>

		SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
			var session = null;
			var hostAccessToken = null;

			switch (eventArgs.commandName) {
				case 'JoinBySessionID':
					session = window.getSessionInfo().Sessions.filter(function (s) { return s.SessionID == eventArgs.commandArgument; })[0];
					break;
				case 'JoinByTag':
					var taggedSessionInfo = window.getTaggedSessionInfo(eventArgs.commandArgument);
					hostAccessToken = taggedSessionInfo.HostAccessToken;
					session = window.getSessionInfo().Sessions.filter(function (s) { return s.SessionID == taggedSessionInfo.SessionID || (taggedSessionInfo.Code && s.Code.toLowerCase() == taggedSessionInfo.Code.toLowerCase()); })[0];
					break;
			}

			// older IE only allows launching urls on actual clicks and this could be sent by a keystroke
			if (session && (SC.command.doesClickDispatch(eventArgs.commandElement) || !SC.util.isCapable(SC.util.Caps.InternetExplorer, null, { major: 11 }))) {
				SC.launch.startJoinSession(
					{ session: session, hostAccessToken: hostAccessToken, processType: hostAccessToken ? SC.types.ProcessType.Host : SC.types.ProcessType.Guest },
					function (joinInfo, _, onSuccess, onFailure) {
						onSuccess(
							SC.util.getClientLaunchParameters(
								joinInfo.session.SessionID,
								joinInfo.session.SessionType,
								joinInfo.session.Name,
								joinInfo.fieldMap.participantName.value,
								null,
								joinInfo.hostAccessToken,
								joinInfo.processType
							)
						);
					}
				);
			}
		});

		SC.event.addGlobalHandler(SC.event.QueryJoinInfo, function (eventArgs) {
			if (eventArgs.session) {
				eventArgs.shouldShowPrompt = SC.util.getSessionTypeBooleanResource('JoinPanel.{0}PromptVisible', eventArgs.session.SessionType);
				eventArgs.promptText = SC.util.getSessionTypeResource('JoinPanel.{0}PromptMessage', eventArgs.session.SessionType);
				eventArgs.buttonText = SC.util.getSessionTypeResource('JoinPanel.{0}PromptButtonText', eventArgs.session.SessionType);

				eventArgs.fieldMap.participantName = {
					labelText: SC.util.getSessionTypeResource('JoinPanel.{0}ParticipantNameLabelText', eventArgs.session.SessionType),
					value: '',
					visible: SC.util.getSessionTypeBooleanResource('JoinPanel.{0}PromptParticipantNameVisible', eventArgs.session.SessionType),
				};
			}
		});

		SC.event.addGlobalHandler(SC.event.QueryParticipantJoinedCount, function (eventArgs) {
			var sessionInfo = window.getSessionInfo();
			var session = sessionInfo.Sessions.find(function (s) { return s.SessionID === eventArgs.clientLaunchParameters.s; });

			if (session !== undefined)
				eventArgs.participantJoinedCount = session.ActiveConnections.filter(function (ac) {
					if (eventArgs.clientLaunchParameters.n)
						return ac.ProcessType == SC.types.ProcessType.Host;

					return ac.ProcessType == SC.types.ProcessType.Guest && ac.ParticipantName == eventArgs.clientLaunchParameters.r;
				}).length;
		});

		SC.event.addGlobalHandler(SC.event.QueryPanels, function (eventArgs) {
			switch (eventArgs.area) {
				case 'GuestActionPanel':
					eventArgs.panelDefinitions.push({
						initProc: function (container) {
							SC.ui.setContents(container, $div({ className: 'Loading' }));
						},
						isVisibleProc: function (pass, previousPassVisibleCount, sessionInfo) {
							return pass == 1 && sessionInfo == null;
						}
					});

					eventArgs.panelDefinitions.push({
						initProc: function (container) {
							SC.ui.setContents(container, [
								$a({ _commandName: 'JoinByTag', _commandArgument: 'DefaultSession', className: 'GoLink Large', _attributeMap: { 'aria-label': SC.res['GuestActionPanel.ButtonDescription'] } }),
								$h2({ _htmlResource: 'GuestActionPanel.InvitationSession.Heading' }),
								$p({ _htmlResource: 'GuestActionPanel.InvitationSession.Message' }),
							]);
						},
						isVisibleProc: function (pass, previousPassVisibleCount, sessionInfo) {
							return pass == 3 &&
								previousPassVisibleCount == 0 &&
								sessionInfo != null &&
								sessionInfo.Sessions.find(function (s) { return s.SessionID == window.getTaggedSessionInfo('DefaultSession').SessionID; });
						}
					});

					eventArgs.panelDefinitions.push({
						initProc: function (container) {
							SC.ui.setContents(container, [
								$h2({ _htmlResource: 'GuestActionPanel.CodeSession.Heading' }),
								$p({ _htmlResource: 'GuestActionPanel.CodeSession.Message' }),
								$p({ className: 'GuestActionBar' }, [
									SC.ui.createSearchTextBox({ _commandName: 'JoinByTag', _commandArgument: 'DefaultCode', value: window.getTaggedSessionInfo('DefaultCode').Code || '' }, function (eventArgs) {
										var sessionCode = SC.util.getTrimmedOrNull(SC.event.getElement(eventArgs).value);
										window.setTaggedSessionInfo('DefaultCode', { Code: sessionCode });
									}),
									$a({ _commandName: 'JoinByTag', _commandArgument: 'DefaultCode', className: 'GoLink Medium', _attributeMap: { 'aria-label': SC.res['GuestActionPanel.ButtonDescription'] } }),
								]),
							]);
						},
						isVisibleProc: function (pass, previousPassVisibleCount, sessionInfo) {
							return pass == 5 && previousPassVisibleCount == 0 && sessionInfo != null && sessionInfo.DoNonPublicCodeSessionsExist;
						},
						refreshProc: function (container, sessionInfo, wasMadeVisible) {
							var taggedSessionInfo = window.getTaggedSessionInfo('DefaultCode');

							SC.ui.setDisabled(
								SC.ui.findDescendentByTag(container, 'A'),
								!sessionInfo.Sessions.find(function (s) { return taggedSessionInfo.Code && s.Code.toLowerCase() == taggedSessionInfo.Code.toLowerCase(); })
							);

							if (wasMadeVisible)
								SC.ui.findDescendentByTag(container, 'INPUT').focus();
						}
					});

					eventArgs.panelDefinitions.push({
						initProc: function (container) {
							SC.ui.setContents(container, [
								$h2({ _htmlResource: 'GuestActionPanel.PublicSession.Heading' }),
								$p({ _htmlResource: 'GuestActionPanel.PublicSession.Message' }),
								$p({ className: 'GuestActionBar' }, [
									$select(),
									$a({ _commandName: 'JoinBySessionID', className: 'GoLink Medium', _attributeMap: { 'aria-label': SC.res['GuestActionPanel.ButtonDescription'] } }),
								]),
							]);

							SC.event.addHandler(SC.ui.findDescendentByTag(container, 'SELECT'), 'change', function (eventArgs) {
								var selectBox = SC.event.getElement(eventArgs);
								SC.ui.findDescendentByTag(container, 'A')._commandArgument = selectBox.options[selectBox.selectedIndex].value;
							});
						},
						isVisibleProc: function (pass, previousPassVisibleCount, sessionInfo) {
							return pass == 5 && previousPassVisibleCount == 0 && sessionInfo != null && sessionInfo.Sessions.filter(function (s) { return s.IsPublic; }).length > 0;
						},
						refreshProc: function (container, sessionInfo, wasMadeVisible) {
							var selectBox = SC.ui.findDescendentByTag(container, 'SELECT');
							var link = SC.ui.findDescendentByTag(container, 'A');

							SC.ui.setContents(selectBox,
								sessionInfo.Sessions.filter(function (s) { return s.IsPublic; }).map(function (s) {
									return $option({ value: s.SessionID }, s.Name);
								})
							);

							var optionIndex = Array.prototype.findIndex.call(selectBox.options, function (o) { return o.value == link._commandArgument; });

							if (optionIndex != -1)
								selectBox.selectedIndex = optionIndex;
							else
								link._commandArgument = selectBox.options[selectBox.selectedIndex].value;
						}
					});

					eventArgs.panelDefinitions.push({
						initProc: function (container) {
							SC.ui.setContents(container, [
								$h2({ _htmlResource: 'GuestActionPanel.NoAvailableSessions.Heading' }),
								$p({ _htmlResource: 'GuestActionPanel.NoAvailableSessions.Message' }),
							]);
						},
						isVisibleProc: function (pass, previousPassVisibleCount, sessionInfo) {
							return pass == 8 && previousPassVisibleCount == 0;
						}
					});

					break;
			}
		});

		SC.event.addGlobalHandler(SC.event.QueryLiveData, function (eventArgs) {
			var getTaggedValuesFunc = function (propertyName) {
				return Object.keys(window._taggedSessionInfos)
					.map(function (key) { return window._taggedSessionInfos[key]; })
					.filter(function (_) { return _[propertyName]; })
					.map(function (_) { return _[propertyName]; });
			}

			eventArgs.requestInfoMap['GuestSessionInfo'] = {
				sessionCodes: getTaggedValuesFunc('Code'),
				sessionIDs: getTaggedValuesFunc('SessionID'),
			};
		});

		SC.event.addGlobalHandler(SC.event.PreRender, function () {
			window._taggedSessionInfos = {};

			SC.css.ensureClass(document.documentElement, 'ShowMenu', false);

			var queryStringMap = SC.util.parseQueryString(window.location.search);
			window.setTaggedSessionInfo('DefaultCode', { Code: queryStringMap.Code });
			window.setTaggedSessionInfo('DefaultSession', { SessionID: queryStringMap.Session, HostAccessToken: queryStringMap.HostAccessToken });

			var welcomePanel = $('.WelcomePanel');
			var actionPanel = $('.ActionPanel');

			SC.ui.setVisible(welcomePanel, SC.util.getBooleanResource('GuestWelcomePanel.Visible'));

			SC.ui.setContents(welcomePanel, [
				$h2(SC.context.guestWelcomePanelHeading),
				$p(SC.context.guestWelcomePanelMessage),
			]);

			SC.panellist.queryAndInitializePanels(actionPanel);
			SC.panellist.refreshPanels(actionPanel, null);
		});

		SC.event.addGlobalHandler(SC.event.LiveDataRefreshed, function () {
			SC.panellist.refreshPanels($('.ActionPanel'), window.getSessionInfo());

			if (!window._hasJoinedDefault && !SC.util.isCapable(SC.util.Caps.InternetExplorer, null, { major: 11 })) {
				SC.command.dispatchExecuteCommand(window.document.body, window.document.body, window.document.body, 'JoinByTag', 'DefaultSession');
				window._hasJoinedDefault = true;
			}
		});

	</script>
</asp:Content>
