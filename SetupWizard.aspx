<%@ Page Language="C#" MasterPageFile="~/Default.master" ClassName="ScreenConnect.SetupWizardPage" Async="true" %>

<%@ Implements Interface="ScreenConnect.ISetupHandler" %>

<%@ Register TagPrefix="asp" Namespace="ScreenConnect" Assembly="ScreenConnect.Web" %>

<script runat="server">

	protected override void OnInit(EventArgs e)
	{
		base.OnInit(e);

		if (SetupModule.IsSetup)
			throw new InvalidOperationException("Already setup");

		this.ViewStateMode = ViewStateMode.Enabled;
	}

	protected override void OnPreRender(EventArgs e)
	{
		base.OnPreRender(e);

		this.ConfigureUnobtrusiveValidationMode();

		var buttonPath = default(string);

		if (this.wizard.ActiveStepIndex == 0)
			buttonPath = "StartNavigationTemplateContainerID$StartNextButton";
		else if (this.wizard.ActiveStepIndex == this.wizard.WizardSteps.Count - 1)
			buttonPath = "FinishNavigationTemplateContainerID$FinishButton";
		else
			buttonPath = "StepNavigationTemplateContainerID$StepNextButton";

		if (this.wizard.ActiveStepIndex == 1)
			this.wizard.FindControl("emailBox").Focus();

		var templateButton = this.wizard.FindControl(buttonPath);

		if (templateButton != null)
			this.Form.DefaultButton = templateButton.UniqueID.Substring(this.Form.UniqueID.Length + 1);
	}

	void OnCheckLicenseValidatorServerValidate(object sender, ServerValidateEventArgs e)
	{
		try
		{
			Envelope.FromUserString<LicenseEnvelope>(this.licenseBox.Text);
		}
		catch (Exception ex)
		{
			sender.To<CustomValidator>().ErrorMessage = ex.Message;
			e.IsValid = false;
		}
	}

	void OnCheckUserNamePasswordValidation(object sender, ServerValidateEventArgs e)
	{
		try
		{
			var configuration = ScreenConnect.WebConfigurationManager.OpenWebConfiguration();
			var membershipSection = ScreenConnect.WebConfigurationManager.GetSection<MembershipSection>(configuration);
			var userName = this.userNameBox.GetTrimmedOrNullText();
			var password = this.passwordBox.GetTrimmedOrNullText();
			var email = this.emailBox.GetTrimmedOrNullText();
#pragma warning disable 618
			var allRoles = Permissions.GetAllRoles();
			var administrationRole = allRoles.Where(r => r.PermissionEntries.Any(pe => pe.Name == PermissionInfo.AdministerPermission)).FirstOrDefault();
			var internalMembershipProviderName = membershipSection.Providers.OfType<ProviderSettings>().Where(_ => _.Type == typeof(InternalMembershipProvider).FullName).First().Name;

			if (administrationRole == null)
			{
				administrationRole = new Role { Name = PermissionInfo.AdministratorRoleName, PermissionEntries = new[] { new PermissionEntry { Name = PermissionInfo.AdministerPermission } } };
				Permissions.SaveRoles(allRoles.Append(administrationRole));
			}
#pragma warning restore 618

			var providerSettings = membershipSection.Providers
				.OfType<ProviderSettings>()
				.First(p => p.Name == internalMembershipProviderName);

			var membershipProvider = (InternalMembershipProvider)MembershipWebAuthenticationProvider.TryCreateMembershipProvider(providerSettings.Type, providerSettings.Name, providerSettings.Parameters).AssertNonNull();

			if (!membershipProvider.IsEnabled)
				membershipProvider.SaveEnabledStateToConfiguration(providerSettings.Parameters, true);

			TaskExtensions.InvokeSync(async () =>
			{
				await membershipProvider.ResetAsync();
				await membershipProvider.CreateUserAsync(userName, password, email: email);
				await membershipProvider.AddUsersToRolesAsync(new[] { userName }, new[] { administrationRole.Name });
			});
		}
		catch (Exception ex)
		{
			sender.To<CustomValidator>().ErrorMessage = ex.Message;
			e.IsValid = false;
		}
	}

	void OnWizardFinishButtonClick(object sender, EventArgs e) => this.Page.RegisterAsyncTask(async () =>
	{
		try
		{
			foreach (var licenseRuntimeInfo in await SessionManagerPool.Demux.GetLicenseRuntimeInfosAsync())
				await SessionManagerPool.Demux.RemoveLicenseAsync(licenseRuntimeInfo.LicenseID);

			await SessionManagerPool.Demux.AddLicenseAsync(this.licenseBox.Text);

			var userName = this.userNameBox.GetTrimmedOrNullText();
			var password = this.passwordBox.GetTrimmedOrNullText();

			var configuration = ScreenConnect.WebConfigurationManager.OpenWebConfiguration();

			SetupModule.MarkSetupComplete(configuration);

			ServerToolkit.Instance.SaveConfiguration(configuration);

			await WebAuthentication.TryLoginAsync(this.Context, userName, password, null);

			WebExtensions.RegisterPageStartupScript(this, "SC.dialog.showModalActivityAndReload('Save', {0:js}, {1:js});", true, WebConstants.HostPageUrl);
		}
		catch (Exception ex)
		{
			WebExtensions.RegisterPageStartupScript(this, "SC.dialog.showModalErrorBox({0:js});", ex.Message);
		}
	});

#pragma warning disable 618 // this disables warnings for all of the calls to WebResources.GetString

</script>
<asp:Content runat="server" ContentPlaceHolderID="Main">
	<div class="ContentPanel SetupWizard">
		<form runat="server">
			<asp:ScriptManager runat="server" EnablePartialRendering="true" />
			<asp:UnskippableWizard runat="server" ID="wizard" CssClass="Wizard" DisplaySideBar="false" NavigationStyle-CssClass="WizardNavigation" StepStyle-CssClass="WizardStep" OnFinishButtonClick="OnWizardFinishButtonClick">
				<WizardSteps>
					<asp:WizardStep runat="server" Title="<%$ WebResources:SetupWizard.WelcomeTitle %>">
						<div class="TopBar TopBar1of4"></div>
						<div class="WelcomeImage"></div>
						<h1><%= WebResources.GetString("SetupWizard.WelcomeTitle") %></h1>
						<h4><%= WebResources.GetString("SetupWizard.WelcomeSubtitle") %></h4>
						<p><%= WebResources.GetString("SetupWizard.WelcomeMessage") %></p>
					</asp:WizardStep>
					<asp:WizardStep runat="server" Title="<%$ WebResources:SetupWizard.SecurityTitle %>">
						<div class="TopBar TopBar2of4"></div>
						<h1><%= WebResources.GetString("SetupWizard.SecurityTitle") %></h1>
						<h4><%= WebResources.GetString("SetupWizard.SecuritySubtitle") %></h4>
						<p><%= WebResources.GetString("SetupWizard.SecurityMessage") %></p>
						<dl>
							<dt>
								<%= WebResources.GetString("SetupWizard.SecurityUserNameMessage") %>
								<asp:RequiredFieldValidator runat="server" ControlToValidate="userNameBox" Text="*" Display="Dynamic" CssClass="Failure" />
							</dt>
							<dd>
								<asp:TextBox runat="server" ID="userNameBox" Text="<%$ WebResources:SetupWizard.SecurityDefaultUserName %>" />
							</dd>
							<dt>
								<%= WebResources.GetString("SetupWizard.SecurityEmailMessage") %>
								<asp:RequiredFieldValidator runat="server" ControlToValidate="emailBox" Text="*" Display="Dynamic" CssClass="Failure" />
							</dt>
							<dd>
								<asp:TextBox runat="server" ID="emailBox" />
							</dd>
							<dt>
								<%= WebResources.GetString("SetupWizard.SecurityPasswordMessage") %>
								<asp:RequiredFieldValidator runat="server" ControlToValidate="PasswordBox" Text="*" Display="Dynamic" CssClass="Failure" />
							</dt>
							<dd>
								<asp:PasswordTextBox runat="server" ID="passwordBox" autocomplete="off" />
							</dd>
							<dt>
								<%= WebResources.GetString("SetupWizard.SecurityVerifyPasswordMessage") %>
								<asp:CompareValidator runat="server" ControlToValidate="passwordBox" ControlToCompare="verifyPasswordBox" Text="<%$ WebResources:SetupWizard.SecurityPasswordsDoNotMatchMessage %>" Display="Dynamic" CssClass="Failure" />
							</dt>
							<dd>
								<asp:PasswordTextBox runat="server" ID="verifyPasswordBox" />
							</dd>
						</dl>
						<p>
							<asp:CustomValidator runat="server" OnServerValidate="OnCheckUserNamePasswordValidation" Display="Dynamic" CssClass="Failure" />
						</p>
					</asp:WizardStep>
					<asp:WizardStep runat="server" Title="<%$ WebResources:SetupWizard.LicenseTitle %>">
						<div class="TopBar TopBar3of4"></div>
						<h1><%= WebResources.GetString("SetupWizard.LicenseTitle") %></h1>
						<p><%= WebResources.GetString("SetupWizard.LicenseMessage") %></p>
						<div>
							<asp:TextBox runat="server" ID="licenseBox" CssClass="LicenseTextBox" TextMode="MultiLine" Wrap="true" />
						</div>
						<p>
							<asp:CustomValidator runat="server" OnServerValidate="OnCheckLicenseValidatorServerValidate" Display="Dynamic" CssClass="Failure" />
						</p>
					</asp:WizardStep>
					<asp:WizardStep runat="server" Title="<%$ WebResources:SetupWizard.FinishTitle %>">
						<div class="TopBar TopBar4of4"></div>
						<div class="FinishImage"></div>
						<h1><%= WebResources.GetString("SetupWizard.FinishTitle") %></h1>
						<p><%= WebResources.GetString("SetupWizard.FinishMessage1") %></p>
						<p><%= WebResources.GetString("SetupWizard.FinishMessage2") %></p>
					</asp:WizardStep>
				</WizardSteps>
			</asp:UnskippableWizard>
		</form>
	</div>
</asp:Content>
