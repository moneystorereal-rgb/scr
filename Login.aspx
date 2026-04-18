<%@ Page Language="C#" MasterPageFile="~/Default.master" ClassName="ScreenConnect.LoginPage" Async="true" %>

<%@ Implements Interface="ScreenConnect.ILoginRenewController" %>

<script runat="server">

	public bool ShouldTryRenewLoginContext() => false;

	protected override void OnLoad(EventArgs e)
	{
		base.OnLoad(e);

		this.RegisterAsyncTask(async () => this.Page.AddFormlessScriptContent("SC.util.mergeIntoContext({0:json});", new
		{
			allowPasswordAutoComplete = ConfigurationCache.AllowPasswordAutoComplete,
			trustDeviceDayCount = WebAuthentication.GetDeviceTrustLifetimeDayCount(),
			canTryLogin = await WebAuthentication.CanTryLoginAsync(this.Context),
			externalAuthenticationProviderInfos = WebAuthentication.GetExternalAuthenticationProviderInfos(this.Context).Select(it => new { providerName = it.ProviderName, displayName = it.DisplayName }),
			isForgotPasswordAvailable =
				await MembershipWebAuthenticationProvider.GetEnabledMembershipProviders()
					.OfType<IMembershipWithoutOldPasswordProvider>()
					.OfType<IUserStatisticsProvider>()
					.ToAsyncEnumerable()
					.AnyAwaitAsync(async it => await it.HasAnyUsersWithEmailAddressAsync())
				&& Extensions.TryParseBool(await WebResources.GetStringAsync("LoginPanel.ForgotPasswordLinkVisible")),
			loginReason = this.Request.QueryString[WebConstants.LoginReasonParameterName].SafePipe(it => Extensions.TryParseEnum<LoginReason>(it).GetValueOrDefault()),
			loginReturnUrl = this.Context.GetValidReturnUrlOrDefault(),
			userNameHint = this.Request.QueryString[WebConstants.LoginUserNameParameterName] ?? (
				this.Context.User is ScreenConnect.WebAuthenticationPrincipal webAuthenticationPrincipal && webAuthenticationPrincipal.ProviderName == "InternalMembershipProvider"
					? this.Context.User.Identity.Name
					: string.Empty
			),
			shouldShowUserNameAndPasswordFields = await MembershipWebAuthenticationProvider.IsAnyDisplayUsernameAndPasswordMembershipEnabled() || CloudWebAuthenticationProvider.IsCloudWebAuthenticationProviderActive(this.Context),
		}));
	}

</script>
<asp:Content runat="server" ContentPlaceHolderID="Main">
	<div class="ContentPanel Authentication">
		<div class="AuthPanel"></div>
		<div class="InfoPanel"></div>
	</div>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="DeclareScript">
	<script>

		// Enums
		const Page = Object.freeze({
			Login: 'Login',
			ChangePassword: 'ChangePassword',
			ResetPassword: 'ResetPassword',
		});
		const FormStep = Object.freeze({
			Default: 'Default',
			OneTimePassword: 'OneTimePassword',
			ResetPassword: 'ResetPassword',
		});
		const Field = Object.freeze({
			UserName: 'userName',
			Password: 'password',
			OneTimePassword: 'oneTimePassword',
			ShouldTrust: 'shouldTrust',
			NewPassword: 'newPassword',
			VerifyNewPassword: 'verifyNewPassword',
			ResetCode: 'resetCode',
		});

		const _authState = {
			page: Page.Login,
			formStep: FormStep.Default,
			isFormSubmitting: false,
			error: '',
			fieldNameToFocus: '',
			securityNonce: '',
			formState: {},
		};

		function refreshAuthPanel() {
			const textInput = (labelTextResource, inputOptions) =>
				$label([
					$span({ _textResource: labelTextResource }),
					$input(SC.util.combineObjects(inputOptions, { placeholder: SC.res[labelTextResource], className: 'AuthTextBox' })),
				]);

			const authPanelElement = $('.AuthPanel');

			switch (_authState.page) {
				case Page.Login:
					switch (_authState.formStep) {
						case FormStep.Default:
							SC.ui.setContents(authPanelElement, [
								$div({ className: 'LogoContainer' }),
								$h1({ _textResource: 'LoginPanel.LoginHeading' }),
								$p({ className: 'Instructions', _htmlResource: 'LoginPanel.LoginReason.' + SC.util.getEnumValueName(SC.types.LoginReason, SC.context.loginReason) + '.Message' }),
								SC.context.externalAuthenticationProviderInfos.length && $div({ className: 'ExternalAuthenticationPanel' }, [
									SC.context.externalAuthenticationProviderInfos.map(({ providerName, displayName }) =>
										$form({ _commandName: 'InitiateExternalProviderAuth', _commandArgument: providerName }, [
											$input({ type: 'submit', name: providerName, value: SC.util.formatString(SC.res['LoginPanel.ExternalAuthenticationButtonTextFormat'], displayName) }),
										])
									),
								]),
								SC.context.externalAuthenticationProviderInfos.length && SC.context.shouldShowUserNameAndPasswordFields && $div({ className: 'PanelDivider' }, [
									$div({ className: 'AuthenticationDividerContainer' }, [
										$hr(),
										$span({ className: 'AuthenticationDividerText', _textResource: 'LoginPanel.DividerText' }),
										$hr()
									]),
									$h3({ _textResource: 'LoginPanel.ContinueWithInternalAuthenticationText' }),
								]),
								SC.context.shouldShowUserNameAndPasswordFields && $form({ _commandName: 'SubmitLogin' }, [
									textInput('LoginPanel.EmailAddressPlaceholderText', { type: 'text', name: Field.UserName, autocomplete: 'username' }),
									textInput('LoginPanel.PasswordPlaceholderText', { type: 'password', name: Field.Password, autocomplete: SC.context.allowPasswordAutoComplete ? 'current-password' : 'off' }),
									SC.context.isForgotPasswordAvailable && $p({ className: 'ForgotPasswordLinkContainer' }, $a({ className: 'ForgotPasswordLinkButton', _textResource: 'LoginPanel.ForgotPasswordLinkButtonText', _commandName: 'ResetPassword' })),
									$input({ type: 'submit', value: SC.res['LoginPanel.LoginButtonText'] }),
									$p({ className: 'ErrorLabel' }),
								]),
							]);
							break;
						case FormStep.OneTimePassword:
							SC.ui.setContents(authPanelElement, $form({ _commandName: 'SubmitLogin' }, [
								$h1({ _textResource: 'LoginPanel.LoginHeading' }),
								$p({ className: 'Instructions', _htmlResource: 'LoginPanel.OneTimePasswordMessage' }),
								textInput('LoginPanel.OneTimePasswordPlaceholderText', { type: 'text', name: Field.OneTimePassword, autocomplete: 'one-time-code' }),
								SC.context.trustDeviceDayCount > 0 && $label({ className: 'AuthCheckBox' }, [
									$input({ type: 'checkbox', name: Field.ShouldTrust }),
									$span(SC.util.formatString(SC.res['LoginPanel.OneTimePasswordShouldTrustCheckBoxFormat'], SC.context.trustDeviceDayCount)),
								]),
								$input({ type: 'submit', value: SC.res['LoginPanel.LoginButtonText'] }),
								$p({ className: 'ErrorLabel' }),
							]));
							break;
					}
					break;

				case Page.ChangePassword:
					SC.ui.setContents(authPanelElement, $form({ _commandName: 'SubmitChangePassword' }, [
						$h1({ _textResource: 'ChangePasswordPanel.ChangePasswordHeading' }),
						$p({ className: 'Instructions', _htmlResource: 'ChangePasswordPanel.Description' }),
						textInput('ChangePasswordPanel.UserNamePlaceholderText', { type: 'text', name: Field.UserName, autocomplete: 'username' }),
						textInput('ChangePasswordPanel.CurrentPasswordPlaceholderText', { type: 'password', name: Field.Password, autocomplete: SC.context.allowPasswordAutoComplete ? 'current-password' : 'off' }),
						textInput('ChangePasswordPanel.NewPasswordPlaceholderText', { type: 'password', name: Field.NewPassword, autocomplete: 'new-password' }),
						textInput('ChangePasswordPanel.VerifyNewPasswordPlaceholderText', { type: 'password', name: Field.VerifyNewPassword, autocomplete: 'new-password' }),
						$input({ type: 'submit', value: SC.res['ChangePasswordPanel.ChangePasswordButtonText'] }),
						$p({ className: 'ErrorLabel' }),
					]));
					break;

				case Page.ResetPassword:
					switch (_authState.formStep) {
						case FormStep.Default:
							SC.ui.setContents(authPanelElement, $form({ _commandName: 'SubmitResetPassword' }, [
								$h1({ _textResource: 'ResetPasswordPanel.RequestPasswordResetHeading' }),
								$p({ className: 'Instructions', _htmlResource: 'ResetPasswordPanel.RequestPasswordResetMessage' }),
								textInput('ResetPasswordPanel.UserNamePlaceholderText', { type: 'text', name: Field.UserName, autocomplete: 'username' }),
								$input({ type: 'submit', value: SC.res['ResetPasswordPanel.RequestPasswordResetButtonText'] }),
								$p({ className: 'ErrorLabel' }),
							]));
							break;
						case FormStep.ResetPassword:
							SC.ui.setContents(authPanelElement, $form({ _commandName: 'SubmitResetPassword' }, [
								$h1({ _textResource: 'ResetPasswordPanel.ResetPasswordHeading' }),
								$p({ className: 'Instructions', _htmlResource: 'ResetPasswordPanel.PasswordResetEmailSentMessage' }),
								textInput('ResetPasswordPanel.UserNamePlaceholderText', { type: 'text', name: Field.UserName, autocomplete: 'username', readOnly: true }),
								textInput('ResetPasswordPanel.ResetCodePlaceholderText', { type: 'text', name: Field.ResetCode }),
								textInput('ResetPasswordPanel.NewPasswordPlaceholderText', { type: 'password', name: Field.NewPassword, autocomplete: 'new-password' }),
								textInput('ResetPasswordPanel.VerifyNewPasswordPlaceholderText', { type: 'password', name: Field.VerifyNewPassword, autocomplete: 'new-password' }),
								$input({ type: 'submit', value: SC.res['ResetPasswordPanel.ResetPasswordButtonText'] }),
								$p({ className: 'ErrorLabel' }),
							]));
							break;
					}
					break;
			}

			SC.css.ensureClass(authPanelElement, `${_authState.page}Page`, true);

			for (const form of authPanelElement.querySelectorAll('form')) {
				SC.ui.applyFormState(form, _authState.formState);
				for (const formControl of Array.from(form.elements))
					formControl.disabled = _authState.isFormSubmitting;
				for (const linkElement of form.querySelectorAll('a'))
					SC.ui.setDisabled(linkElement, _authState.isFormSubmitting);
				for (const errorLabel of form.querySelectorAll('.ErrorLabel'))
					SC.ui.setInnerText(errorLabel, _authState.error);
			}

			// DEBUG
			// SC.ui.setContents($('.InfoPanel'), $pre({ style: 'background-color: white' }, JSON.stringify(_authState, null, 2)));
		}

		function smartFocusFormField() {
			SC.ui.smartFocusFormField(
				_authState.fieldNameToFocus
					? [_authState.fieldNameToFocus]
					: [Field.UserName, Field.Password, Field.OneTimePassword, Field.ResetCode, Field.NewPassword]
			);
		}

	</script>
</asp:Content>
<asp:Content runat="server" ContentPlaceHolderID="RunScript">
	<script>
		SC.event.addGlobalHandler(SC.event.PreRender, function () {
			const pageFromUrl = SC.util.getParameterlessUrl(window.location.href).replace(SC.context.scriptBaseUrl, '').toLowerCase();
			_authState.page = Object.keys(Page).find(key => SC.util.equalsCaseInsensitive(Page[key], pageFromUrl)) || Page.Login;
			_authState.formState[Field.UserName] = SC.context.userNameHint;
			_authState.securityNonce = SC.util.getRandomAlphanumericString(16);

			// in order to preserve the full url through authentication redirects, the frontend must append the hash parameters, since only it has access to them
			SC.context.loginReturnUrl = SC.context.loginReturnUrl + SC.util.getWindowHashString();

			if (SC.context.isUserAuthenticated && (SC.context.loginReason === SC.types.LoginReason.Logout || SC.context.loginReason === SC.types.LoginReason.IdleTooLong)) {
				SC.service.TryLogout(function (success) {
					if (!success) {
						return; // ostensibly we're still authenticated, so don't trigger infinite redirect loop
					}

					const externalLogoutUrl = "";
					// TODO SCP-36247
					//const externalLogoutUrl = WebAuthentication.GetExternalLogoutUrl(this.Context, this.Request.GetRealUrl(false), this.Request.GetRealUrl().AbsoluteUri);

					if (externalLogoutUrl) {
						window.location.href = externalLogoutUrl;
					} else {
						// refresh page so nav bar notices we're logged out
						window.location.reload();
					}
				});
			}
			else if (
				SC.context.loginReason !== SC.types.LoginReason.Logout
				&& SC.context.externalAuthenticationProviderInfos.length === 1
				&& (!SC.context.isUserAuthenticated || SC.context.loginReason !== SC.types.LoginReason.PermissionsInsufficient)
				&& !SC.context.canTryLogin
			) {
				const loneProvider = SC.context.externalAuthenticationProviderInfos[0];
				SC.command.dispatchGlobalExecuteCommand('InitiateExternalProviderAuth', loneProvider.providerName);
			}

			refreshAuthPanel();
		});

		SC.event.addGlobalHandler(SC.event.PostRender, function () {
			smartFocusFormField();
		});

		SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
			/**
			 * @param {function(function(function(): boolean?): void, function(Error): void): void} submitFunc
			 */
			function handleFormSubmission(submitFunc) {
				_authState.isFormSubmitting = true;
				_authState.error = '';
				refreshAuthPanel();

				/**
				 * @param {function(): boolean?} continueFunc
				 */
				function handleSuccess(continueFunc) {
					_authState.isFormSubmitting = false;
					_authState.error = '';
					_authState.fieldNameToFocus = '';

					try {
						if (continueFunc) {
							if (continueFunc()) // true if redirecting
								_authState.isFormSubmitting = true; // keep disabled state until browser handles redirect
						}
					} catch (error) {
						handleError(error);
					}

					refreshAuthPanel();
					smartFocusFormField();
				}

				/**
				 * @param {Error} error
				 */
				function handleError(error) {
					_authState.isFormSubmitting = false;
					_authState.error = error.message;
					refreshAuthPanel();
					smartFocusFormField();
				}

				try {
					submitFunc(handleSuccess, handleError);
				} catch (error) {
					handleError(error);
				}
			}

			switch (eventArgs.commandName) {
				case 'SubmitLogin':
					_authState.formState = Object.assign(
						{
							[Field.UserName]: _authState.formState[Field.UserName],
							[Field.Password]: _authState.formState[Field.Password],
						},
						SC.ui.extractFormState(eventArgs.commandElement)
					);

					handleFormSubmission((handleSuccess, handleError) => SC.service.TryLogin(
						_authState.formState[Field.UserName],
						_authState.formState[Field.Password],
						_authState.formState[Field.OneTimePassword],
						_authState.formState[Field.ShouldTrust],
						_authState.securityNonce,
						result => handleSuccess(() => {
							switch (result) {
								case SC.types.SecurityOperationResult.Success:
									window.location.href = SC.context.loginReturnUrl;
									return true;
								case SC.types.SecurityOperationResult.ChangeablePasswordExpired:
									SC.command.dispatchGlobalExecuteCommand('ChangePassword', _authState.formState[Field.UserName]);
									return true;
								case SC.types.SecurityOperationResult.UnchangeablePasswordExpired:
									throw new Error(SC.res['LoginPanel.UnchangeablePasswordExpiredText']);
								case SC.types.SecurityOperationResult.OneTimePasswordRequired:
									_authState.formStep = FormStep.OneTimePassword;
									return false;
								case SC.types.SecurityOperationResult.OneTimePasswordInvalid:
									throw new Error(SC.res['LoginPanel.InvalidCredentialsText']);
								case SC.types.SecurityOperationResult.OneTimePasswordProviderInvalid:
									throw new Error(SC.res['LoginPanel.InvalidOneTimePasswordProviderText']);
								case SC.types.SecurityOperationResult.OneTimePasswordUserKeyInvalid:
									throw new Error(SC.res['LoginPanel.InvalidOneTimePasswordUserKeyText']);
								case SC.types.SecurityOperationResult.UserNameInvalid:
								case SC.types.SecurityOperationResult.PasswordInvalid:
								case SC.types.SecurityOperationResult.CredentialsInvalid:
									throw new Error(SC.res['LoginPanel.InvalidCredentialsText']);
								case SC.types.SecurityOperationResult.LockedOut:
									throw new Error(SC.res['LoginPanel.LockoutText']);
								case SC.types.SecurityOperationResult.Unknown:
								default:
									throw new Error(SC.res['LoginPanel.UnknownText']);
							}
						}),
						handleError
					));

					break;

				case 'ResetPassword':
					window.location.href = SC.context.resetPasswordPageUrl + SC.util.getQueryString({ [SC.context.loginUserNameParameterName]: _authState.formState[Field.UserName] });
					break;

				case 'InitiateExternalProviderAuth':
					const providerName = eventArgs.commandArgument;

					handleFormSubmission((handleSuccess, handleError) => SC.service.GetExternalLoginUrl(
						providerName,
						SC.context.scriptBaseUrl,
						SC.context.loginReturnUrl,
						SC.context.userNameHint,
						externalLoginUrl => handleSuccess(() => { window.location.href = externalLoginUrl; return true; }),
						handleError
					));

					break;

				case 'SubmitChangePassword':
					_authState.formState = SC.ui.extractFormState(eventArgs.commandElement);

					handleFormSubmission((handleSuccess, handleError) => SC.service.ChangePassword(
						_authState.formState[Field.UserName],
						_authState.formState[Field.Password],
						_authState.formState[Field.NewPassword],
						_authState.formState[Field.VerifyNewPassword],
						result => handleSuccess(() => {
							switch (result) {
								case SC.types.SecurityOperationResult.Success:
									window.location.href = SC.context.loginUrl + SC.util.getQueryString({ [SC.context.loginUserNameParameterName]: _authState.formState[Field.UserName] });
									return true;
								case SC.types.SecurityOperationResult.UserNameInvalid:
									_authState.fieldNameToFocus = Field.UserName;
									break;
								case SC.types.SecurityOperationResult.CurrentPasswordInvalid:
									_authState.fieldNameToFocus = Field.Password;
									break;
								case SC.types.SecurityOperationResult.NewPasswordInvalid:
									_authState.fieldNameToFocus = Field.NewPassword;
									break;
								case SC.types.SecurityOperationResult.NewPasswordMatchInvalid:
									_authState.fieldNameToFocus = Field.VerifyNewPassword;
									break;
							}

							throw new Error(SC.util.getResourceWithFallback('ChangePasswordPanel.{0}ErrorMessage', SC.util.getEnumValueName(SC.types.SecurityOperationResult, result)));
						}),
						handleError
					));

					break;

				case 'SubmitResetPassword':
					_authState.formState = SC.ui.extractFormState(eventArgs.commandElement);

					handleFormSubmission((handleSuccess, handleError) => {
						switch (_authState.formStep) {
							case FormStep.Default:
								SC.service.InitiatePasswordReset(
									_authState.formState[Field.UserName],
									_authState.securityNonce,
									() => handleSuccess(() => { _authState.formStep = FormStep.ResetPassword; }),
									handleError
								);
								break;

							case FormStep.ResetPassword:
								SC.service.TryResetPassword(
									_authState.formState[Field.ResetCode],
									_authState.formState[Field.UserName],
									_authState.formState[Field.NewPassword],
									_authState.formState[Field.VerifyNewPassword],
									_authState.securityNonce,
									result => handleSuccess(() => {
										switch (result) {
											case SC.types.SecurityOperationResult.Success:
												window.location.href = SC.context.loginUrl + SC.util.getQueryString({ [SC.context.loginUserNameParameterName]: _authState.formState[Field.UserName] });
												return true;
											case SC.types.SecurityOperationResult.ResetCodeInvalid:
												_authState.fieldNameToFocus = Field.ResetCode;
												break;
											case SC.types.SecurityOperationResult.NewPasswordInvalid:
												_authState.fieldNameToFocus = Field.NewPassword;
												break;
											case SC.types.SecurityOperationResult.NewPasswordMatchInvalid:
												_authState.fieldNameToFocus = Field.VerifyNewPassword;
												break;
										}

										throw new Error(SC.util.getResourceWithFallback('ResetPasswordPanel.{0}ErrorMessage', SC.util.getEnumValueName(SC.types.SecurityOperationResult, result)));
									}),
									handleError
								);
								break;
						}
					});

					break;
			}
		});
	</script>
</asp:Content>
