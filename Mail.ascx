<%@ Control %>

<dl class="MailPanel"></dl>

<script>

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetMailConfigurationInfo(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
		var mailConfiguration = SC.pagedata.get();

		SC.ui.setContents($('.MailPanel'), [
			$dt([
				$h3({_textResource: 'MailPanel.MailTitle'}),
				$p({className: 'CommandList'}, SC.command.createCommandButtons([{commandName: 'EditMailConfiguration'}])),
			]),
			$dd([
				$dl([
					$dt({_textResource: 'MailPanel.MailDeliveryText'}),
					$dd(mailConfiguration.smtpDeliveryMethod == SC.types.SmtpDeliveryMethod.Network
						? SC.util.isNullOrEmpty(mailConfiguration.smtpRelayServerHostName)
							? SC.res['MailPanel.SmtpDirectRadioButtonText']
							: SC.util.formatString(SC.res['EditMailConfigurationPanel.MailPanel.RelaySettingsTextFormat'],
								mailConfiguration.smtpRelayServerHostName,
								mailConfiguration.smtpRelayServerPort == 25 ? null : ':' + mailConfiguration.smtpRelayServerPort,
								mailConfiguration.enableSSL ? SC.res['EditMailConfigurationPanel.MailPanel.UseSSLText'] : null,
								mailConfiguration.smtpUseDefaultCredentials
									? SC.util.formatString(
										SC.res['EditMailConfigurationPanel.MailPanel.UsingDefaultCredentialsTextFormat'],
										(!SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkTargetName)
											? SC.util.formatString(SC.res['EditMailConfigurationPanel.MailPanel.SPNLabelTextFormat'], mailConfiguration.smtpNetworkTargetName)
											: ''
										)
									)
									: !SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkUserName) && !SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkPassword)
										? SC.util.formatString(SC.res['EditMailConfigurationPanel.MailPanel.UsernameLabelTextFormat'], mailConfiguration.smtpNetworkUserName)
										: null
							)
						: mailConfiguration.smtpDeliveryMethod == SC.types.SmtpDeliveryMethod.PickupDirectoryFromIis
							? SC.res['EditMailConfigurationPanel.MailPanel.UsingIISPickupDirectoryText']
							: SC.util.formatString(SC.res['EditMailConfigurationPanel.MailPanel.UsingSpecifiedPickupDirectoryTextFormat'], mailConfiguration.smtpPickupDirectoryLocation)
					),
					$dt({_textResource: 'MailPanel.DefaultFromAddressLabelText'}),
					$dd(mailConfiguration.defaultMailFromAddress || SC.res['MailPanel.UnsetLabelText']),
					$dt({_textResource: 'MailPanel.DefaultToAddressLabelText'}),
					$dd(mailConfiguration.defaultMailToAddress || SC.res['MailPanel.UnsetLabelText']),
				]),
			]),
		]);
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'EditMailConfiguration':
				var mailConfiguration = SC.pagedata.get();

				function resetButtons() {
					const buttonPanel = SC.dialog.getButtonPanel(SC.dialog.getModalDialog());
					SC.ui.setVisible(SC.dialog.getButtonPanelButton(buttonPanel, 'Confirm'), false);
					SC.ui.setVisible(SC.dialog.getButtonPanelButton(buttonPanel, 'Default'), true);
					SC.dialog.setButtonPanelError(buttonPanel, null);
				}

				function updateUserInterfaceOnDeliveryMethodSelected(smtpDeliveryMethodName) {
					resetButtons();

					// SpecifiedPickupDirectory
					SC.ui.setDisabledAttribute($('.SmtpPickupDirectoryLocationBox'), smtpDeliveryMethodName != 'SpecifiedPickupDirectory');

					// SMTP relay - This isn't a value of SmtpDeliveryMethod, just Network with extra parameters
					const shouldDisableRelayItems = smtpDeliveryMethodName != 'Relay';
					SC.ui.setDisabledAttribute($('.SmtpRelayServerBox'), shouldDisableRelayItems);
					SC.ui.setDisabledAttribute($('.SmtpRelayServerPortBox'), shouldDisableRelayItems);
					SC.ui.setDisabledAttribute($('.SmtpRelayServerEnableSSLCheckbox'), shouldDisableRelayItems);
					// SMTP relay authentication types
					SC.ui.setDisabledAttribute($('.SmtpAuthenticationTypeNoneRadioButton'), shouldDisableRelayItems);
					SC.ui.setDisabledAttribute($('.SmtpAuthenticationTypeWindowsRadioButton'), shouldDisableRelayItems);
					SC.ui.setDisabledAttribute($('.SmtpAuthenticationTypeCredentialsRadioButton'), shouldDisableRelayItems);

					enableOrDisableAuthenticationItems(shouldDisableRelayItems ? '' : SC.ui.getSelectedRadioButtonValue(SC.dialog.getModalDialog().querySelector('.SmtpRelaySettingsList')));
				}

				function enableOrDisableAuthenticationItems(authenticationType) {
					SC.ui.setDisabledAttribute($('.SmtpAuthSPNBox'), authenticationType != 'Windows');

					SC.ui.setDisabledAttribute($('.SmtpAuthUsernameBox'), authenticationType != 'Credentials');
					SC.ui.setDisabledAttribute($('.SmtpAuthPasswordBox'), authenticationType != 'Credentials');
					SC.ui.setDisabledAttribute($('.SmtpAuthConfirmPasswordBox'), authenticationType != 'Credentials');
				}

				function updateUserInterfaceOnSmtpAuthenticationTypeSelected(authenticationType) {
					resetButtons();
					enableOrDisableAuthenticationItems(authenticationType);
				}

				function createSmtpAuthenticationTypeRadioButton(authenticationType, isChecked, textResourcePart) {
					return $label([
						$input({
							type: 'radio',
							name: 'SmtpAuthenticationType',
							className: 'SmtpAuthenticationType' + authenticationType + 'RadioButton',
							value: authenticationType,
							checked: isChecked,
							onchange: updateUserInterfaceOnSmtpAuthenticationTypeSelected.bind(null, authenticationType),
						}),
						$span(SC.res['EditMailConfigurationPanel.' + textResourcePart + 'CredentialsLabelText']),
					]);
				}

				SC.dialog.showModalDialog('EditMailConfiguration', {
					titleResourceName: 'EditMailConfigurationPanel.Title',
					content: [
						$dl([
							$dt({_textResource: 'MailPanel.MailDeliveryText'}),
							$dd(
								mailConfiguration.availableSmtpDeliveryMethods.map(function (deliveryMethodName) {
									return [
										$label([
											$input({
												type: 'radio',
												name: 'MailDelivery',
												className: deliveryMethodName + 'RadioButton',
												value: deliveryMethodName,
												onchange: updateUserInterfaceOnDeliveryMethodSelected.bind(null, deliveryMethodName),
											}),
											$span({_textResource: 'MailPanel.Smtp' + (deliveryMethodName == 'Network' ? 'Direct' : deliveryMethodName) + 'RadioButtonText'}),
										]),
										deliveryMethodName == 'Relay'
										? $dl({className: 'SmtpRelaySettingsList'}, [
											$dt(SC.res['EditMailConfigurationPanel.NetworkSettingsLabelText']),
											$dd([
												$label([
													$span(SC.res['EditMailConfigurationPanel.RelayServerLabelText']),
													$input({
														type: 'text',
														className: 'SmtpRelayServerBox',
														value: mailConfiguration.smtpRelayServerHostName,
													}),
												]),
											]),
											$dd([
												$label([
													$span(SC.res['EditMailConfigurationPanel.RelayServerPortLabelText']),
													$input({
														type: 'number',
														className: 'SmtpRelayServerPortBox',
														value: mailConfiguration.smtpRelayServerPort,
														_attributeMap: {
															max: 65535,
															min: 1,
															placeholder: 25,
														},
													}),
												]),
											]),
											$dd([
												$label([
													$input({
														type: 'checkbox',
														className: 'SmtpRelayServerEnableSSLCheckbox',
														checked: mailConfiguration.enableSSL,
													}),
													$span(SC.res['EditMailConfigurationPanel.UseSSLLabelText']),
												]),
											]),
											$dt(SC.res['EditMailConfigurationPanel.AuthenticationSettingsLabelText']),
											$dd([
												createSmtpAuthenticationTypeRadioButton(
													'None',
													(SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkUserName) || SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkPassword)) && !mailConfiguration.smtpUseDefaultCredentials,
													'Anonymous'
												),
											]),
											$dd([
												createSmtpAuthenticationTypeRadioButton(
													'Windows',
													mailConfiguration.smtpUseDefaultCredentials,
													'Default'
												),
												$label([
													$span(SC.res['EditMailConfigurationPanel.NetworkTargetNameLabelText']),
													$input({
														type: 'text',
														className: 'SmtpAuthSPNBox',
														value: mailConfiguration.smtpNetworkTargetName,
													}),
												]),
											]),
											$dd([
												createSmtpAuthenticationTypeRadioButton(
													'Credentials',
													!mailConfiguration.smtpUseDefaultCredentials && !SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkUserName) && !SC.util.isNullOrEmpty(mailConfiguration.smtpNetworkPassword),
													'Account'
												),
												$label([
													$span(SC.res['EditMailConfigurationPanel.UsernameLabelText']),
													$input({
														type: 'text',
														className: 'SmtpAuthUsernameBox',
														value: mailConfiguration.smtpNetworkUserName,
													}),
												]),
												$label([
													$span(SC.res['EditMailConfigurationPanel.PasswordLabelText']),
													$input({
														type: 'password',
														className: 'SmtpAuthPasswordBox',
														value: mailConfiguration.smtpNetworkPassword,
													}),
												]),
												$label([
													$span(SC.res['EditMailConfigurationPanel.ConfirmPasswordLabelText']),
													$input({
														type: 'password',
														className: 'SmtpAuthConfirmPasswordBox',
														value: mailConfiguration.smtpNetworkPassword,
													}),
												]),
											]),
										])
										: deliveryMethodName == 'SpecifiedPickupDirectory'
										? $input({
											type: 'text',
											className: 'SmtpPickupDirectoryLocationBox',
											value: mailConfiguration.smtpPickupDirectoryLocation,
										})
										: null, // network, iispickup
									];
								})
							),
							$dt({_textResource: 'MailPanel.DefaultFromAddressLabelText'}),
							$dd([
								$input({
									type: 'text',
									className: 'DefaultMailFromAddressBox',
									value: mailConfiguration.defaultMailFromAddress,
								}),
							]),
							$dt({_textResource: 'MailPanel.DefaultToAddressLabelText'}),
							$dd([
								$div([
									$input({
										type: 'text',
										className: 'DefaultMailToAddressBox',
										value: mailConfiguration.defaultMailToAddress,
									}),
									$button({
										className: 'SecondaryButton',
										_textResource: 'MailPanel.SendTestMailButtonText',
										_commandName: 'SendTestEmail',
									}),
								]),
							]),
						]),
						$p({ className: 'ResultPanel' }),
					],
					buttonPanelExtraContent: SC.dialog.createButtonPanelButton(SC.res['EditMailConfigurationPanel.ConfirmButtonText'], 'Confirm'),
					buttonTextResourceName: 'EditMailConfigurationPanel.ButtonText',
					initializeProc: function(dialog) {
						SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Confirm'), false);
						SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Default'), true);

						// Select the saved delivery method and update corresponding controls through click event. On-change event is not working.
						const selectedDeliveryMethodName = SC.util.isNullOrEmpty(mailConfiguration.smtpRelayServerHostName)
							? SC.util.getEnumValueName(SC.types.SmtpDeliveryMethod, mailConfiguration.smtpDeliveryMethod)
							: 'Relay';

						const element = dialog.querySelector('.' + selectedDeliveryMethodName + 'RadioButton');
						if (element)
							element.click();
					},
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						var smtpDeliveryMethodName = SC.ui.getSelectedRadioButtonValue(dialog);
						var authenticationMethod = SC.ui.getSelectedRadioButtonValue(dialog.querySelector('.SmtpRelaySettingsList'));

						var useExtraNetworkSettings = false;
						if (smtpDeliveryMethodName == 'Relay') {
							smtpDeliveryMethodName = 'Network'; // convert to valid SmtpDeliveryMethod value
							useExtraNetworkSettings = true;
						}

						var defaultMailFromAddress = dialog.querySelector('.DefaultMailFromAddressBox').value.trim();
						var defaultMailToAddress = dialog.querySelector('.DefaultMailToAddressBox').value.trim();
						var smtpRelayServerHostName = useExtraNetworkSettings ? dialog.querySelector('.SmtpRelayServerBox').value.trim() || null : null;
						var smtpRelayServerPort = useExtraNetworkSettings ? dialog.querySelector('.SmtpRelayServerPortBox').value.trim() || null : null;
						var enableSSL = useExtraNetworkSettings ? dialog.querySelector('.SmtpRelayServerEnableSSLCheckbox').checked : null;
						var smtpPickupDirectoryLocation = smtpDeliveryMethodName == 'SpecifiedPickupDirectory' ? dialog.querySelector('.SmtpPickupDirectoryLocationBox').value.trim() || null : null;
						var smtpUseDefaultCredentials = useExtraNetworkSettings && authenticationMethod == 'Windows' || null;
						var smtpNetworkTargetName = useExtraNetworkSettings && authenticationMethod == 'Windows' ? dialog.querySelector('.SmtpAuthSPNBox').value.trim() || null : null;
						var smtpNetworkUserName = useExtraNetworkSettings && authenticationMethod == 'Credentials' ? dialog.querySelector('.SmtpAuthUsernameBox').value.trim() || null : null;
						var smtpNetworkPassword = useExtraNetworkSettings && authenticationMethod == 'Credentials' ? dialog.querySelector('.SmtpAuthPasswordBox').value.trim() || null : null;

						var resultPanel = dialog.querySelector('.ResultPanel');

						function validateSettings() {
							if (smtpDeliveryMethodName == 'Network' && useExtraNetworkSettings) {
								if (!smtpRelayServerHostName) {
									setDialogErrorProc({message: SC.res['EditMailConfigurationPanel.EmptyRelayServerBoxErrorText']});
									return false;
								} else if (authenticationMethod == 'Credentials') {
									if (SC.util.isNullOrEmpty(smtpNetworkUserName) || SC.util.isNullOrEmpty(smtpNetworkPassword)) {
										setDialogErrorProc({message: SC.res['EditMailConfigurationPanel.MissingCredentialsErrorText']});
										return false;
									}

									if (smtpNetworkPassword != dialog.querySelector('.SmtpAuthConfirmPasswordBox').value.trim()) {
										setDialogErrorProc({message: SC.res['EditMailConfigurationPanel.PasswordMismatchErrorText']});
										return false;
									}
								}
							} else if (smtpDeliveryMethodName == 'SpecifiedPickupDirectory') {
								if (SC.util.isNullOrEmpty(smtpPickupDirectoryLocation)) {
									setDialogErrorProc({message: SC.res['EditMailConfigurationPanel.EmptyPickupDirectoryBoxErrorText']});
									return false;
								}
							}

							return true;
						}

						switch (dialogEventArgs.commandName) {
							case 'Default':
								if (validateSettings())
									window.setTimeout(
										function () {
											SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Confirm'), true);
											SC.ui.setVisible(SC.dialog.getButtonPanelButton(SC.dialog.getButtonPanel(dialog), 'Default'), false);
											setDialogErrorProc({ message: SC.res['EditMailConfigurationPanel.WarningMessage'] });
										},
										1000
									);
								break;

							case 'Confirm':
								if (validateSettings())
									SC.service.SaveMailConfiguration(
										defaultMailFromAddress,
										defaultMailToAddress,
										smtpRelayServerHostName,
										smtpRelayServerPort,
										enableSSL,
										smtpDeliveryMethodName,
										smtpPickupDirectoryLocation,
										smtpUseDefaultCredentials,
										smtpNetworkTargetName,
										smtpNetworkUserName,
										smtpNetworkPassword,
										function () {
											SC.dialog.showModalActivityAndReload('Save', true, window.location.href);
										},
										setDialogErrorProc
									);
								break;

							case 'SendTestEmail':
								if (validateSettings()) {
									SC.service.SendTestEmail(
										defaultMailFromAddress,
										smtpRelayServerHostName,
										defaultMailToAddress,
										smtpDeliveryMethodName,
										smtpPickupDirectoryLocation,
										smtpRelayServerPort,
										enableSSL,
										smtpUseDefaultCredentials,
										smtpNetworkTargetName,
										smtpNetworkUserName,
										smtpNetworkPassword,
										function () {
											SC.css.ensureClass(resultPanel, 'Success', true);
											SC.css.ensureClass(resultPanel, 'Failure', false);
											SC.ui.setContents(resultPanel, SC.res['Command.SendEmail.SuccessMessage']);
											setTimeout(function () {
												SC.css.ensureClass(resultPanel, 'Success', false);
											}, 3000);
										},
										function (error) {
											SC.css.ensureClass(resultPanel, 'Failure', true);
											SC.css.ensureClass(resultPanel, 'Success', false);
											SC.ui.setContents(resultPanel, error.message);
											setTimeout(function () {
												SC.css.ensureClass(resultPanel, 'Failure', false);
											}, 30000);
										}
									);
								}
								break;
						}
					},
				});
				break;
		}
	});

</script>
