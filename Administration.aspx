<%@ Page Language="C#" MasterPageFile="~/Default.master" ClassName="ScreenConnect.AdministrationPage" Async="true" %>

<%@ Register TagPrefix="asp" Namespace="ScreenConnect" Assembly="ScreenConnect.Web" %>

<script runat="server">

	protected override void OnLoad(EventArgs e)
	{
		base.OnLoad(e);

		this.Page.RegisterAsyncTask(async () =>
		{
			await Permissions.AssertPermissionAsync(PermissionInfo.AdministerPermission, this.Context.User);

			var hideTabKeys = ServerExtensions.GetConfigurationString(ServerConstants.HideAdministrationTabKeysSettingsKey)
				.SafeNav(it => it.Split(';'))
				.SafeEnumerate()
				.ToHashSet();

			var tabInfos = new[] { "Overview", "Extensions", "Security", "Database", "Mail", "Automations", "License", "Appearance", "Audit" }
				.Select(it => (Name: it, Path: "~/" + it + ".ascx"))
				.Concat((await ExtensionRuntime.GetAllActiveRuntimeObjectsAsync<AdministrationTabDefinition, string>()).Select(it => (Name: Path.GetFileNameWithoutExtension(it), Path: it)))
				.ToList();

			for (var i = tabInfos.Count - 1; i >= 0; i--)
				if (hideTabKeys.Contains(tabInfos[i].Name) || !await LicensingInfo.HasCapabilitiesAsync(Extensions.TryParseEnum<BasicLicenseCapabilities>("Administer" + tabInfos[i].Name).GetValueOrDefault()))
					tabInfos.RemoveAt(i);

			var tabParameter = this.Context.Request.QueryString["Tab"];
			var tabIndex = Extensions.GetBoundedValueMaxExclusive(
				0,
				tabParameter.TryParseInt32(tabInfos.IndexOf(it => it.Name.Equals(tabParameter, StringComparison.OrdinalIgnoreCase), 0)
				),
				tabInfos.Count
			);

			this.contentPanel.Controls.Add(this.LoadControl(tabInfos[tabIndex].Path));

			this.Page.AddFormlessScriptContent("SC.util.mergeIntoContext({0:json});", new
			{
				tabIndex = tabIndex,
				tabKeys = tabInfos.Select(_ => _.Name).ToList(),
			});
		});
	}

</script>
<asp:Content runat="server" ContentPlaceHolderID="Main">
	<div class="MasterPanel"></div>
	<div class="MainDetailHeaderPanel">
		<h2 id="detailTitleHeading"></h2>
	</div>
	<div class="DetailPanel">
		<div class="AdministrationPanel">
			<div class="InfoPanel"></div>
			<div runat="server" id="contentPanel" class="AdministrationContentPanel">
			</div>
		</div>
	</div>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="DeclareScript">
	<script>
		function getCommandNameUrlPart() { return SC.util.getWindowHashParameter(0); }
		function getCommandArgumentUrlPart() { return SC.util.getWindowHashParameter(1); }
		function setCommandNameUrlPart(value) { SC.util.setHashParameter(0, value); }
		function setCommandArgumentUrlPart(value) { SC.util.setHashParameter(1, value); }
		function dispatchCommandFromUrl() {
			var urlCommandName = window.getCommandNameUrlPart();
			var urlCommandArgument = window.getCommandArgumentUrlPart();

			if (SC.command.queryCommandButtonState(null, urlCommandName, urlCommandArgument).allowsUrlExecution) {
				SC.command.dispatchGlobalExecuteCommand(urlCommandName, urlCommandArgument);
			}

			window.setCommandNameUrlPart(null);
			window.setCommandArgumentUrlPart(null);
		}
	</script>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="RunScript">
	<script>

		SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
			SC.css.ensureClass($('.AdministrationPanel'), 'Loading', true);
		});

		SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
			SC.css.ensureClass($('.AdministrationPanel'), 'Loading', false);
			dispatchCommandFromUrl();
		});

		SC.event.addHandler(window, 'hashchange', function () {
			dispatchCommandFromUrl();
		});

		SC.event.addGlobalHandler(SC.event.PreRender, function () {
			var getTabNameFunc = function (tabIndex) {
				return SC.res['AdministrationPanel.' + SC.context.tabKeys[tabIndex] + 'TabName'] || SC.context.tabKeys[tabIndex];
			};

			SC.ui.setInnerText($('detailTitleHeading'), getTabNameFunc(SC.context.tabIndex));

			SC.ui.setContents($('.MasterPanel'), [
				$h2({ _textResource: 'AdministrationPanel.Title' }),
				$div({ className: 'MasterListContainer' },
					$ul(
						{ className: 'ArrowNavigation', tabIndex: 20 },
						SC.util.createRangeArray(0, SC.context.tabKeys.length)
							.map(function (i) {
								return $li({ _selected: i == SC.context.tabIndex },
									$span({ _commandName: 'Navigate', _commandArgument: "?Tab=" + i }, getTabNameFunc(i))
								);
							})
					)
				),
				$div({ className: 'InfoPanel' }),
			]);

			SC.event.addHandler($('.MasterListContainer > ul'), SC.event.KeyNavigation, function (eventArgs) {
				eventArgs.stopPropagation();

				var elementToNavigateTo = SC.ui.findDescendent(
					(eventArgs.targetPreviousOrNext ?
						eventArgs.currentSelectedElement.previousElementSibling :
						eventArgs.currentSelectedElement.nextElementSibling
					) || eventArgs.currentSelectedElement,
					function (_) { return _._commandName != null; }
				);

				// default handling removes hidden focus but for this page we want to maintain hidden focus for the parent container
				SC.ui.setHiddenFocusAndClearOthers($('.MasterListContainer > ul'));
				SC.util.tryNavigateToElementUsingCommand(elementToNavigateTo, eventArgs.targetPreviousOrNext, eventArgs.hasShift);
			});

			if (!window.location.search) // If not in any tab, open menu by default
				SC.css.ensureClass(document.documentElement, 'ShowMenu', true);
		});

		SC.event.addGlobalHandler(SC.event.PostRender, function () {
			if (window.location.href.length > SC.util.getParameterlessUrl(window.location.href).length) {
				SC.ui.setHiddenFocusAndClearOthers($('.MasterListContainer > ul'));
				$('.MasterListContainer > ul').focus();
			}
		});
	</script>
</asp:Content>
