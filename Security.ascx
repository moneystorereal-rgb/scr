<%@ Control %>

<dl class="SecurityPanel"></dl>

<script>

	SC.event.addGlobalHandler(SC.event.PreRender, function () {
		SC.pagedata.notifyDirty();
	});

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		SC.service.GetSecurityConfigurationInfo(SC.pagedata.set);
	});

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, function () {
		var securityConfiguration = SC.pagedata.get();
		var optionalUserPropertyNames = ['PasswordQuestion', 'DisplayName', 'Comment', 'Email'];
		var expandedUserSources = Array.from($$('.SecurityPanel > .UserSourcesPanel > .Expanded')).map(function (it) { return it._dataItem.Name; });
		SC.ui.setContents($('.SecurityPanel'), [
			$dt([
				$h3({ _textResource: 'SecurityPanel.UserSourcesLabelText' }),
				$p({ className: 'CommandList' }, SC.command.queryAndCreateCommandButtons('AddUserSourcePanel')),
			]),
			$dd({ className: 'UserSourcesPanel' }, [
				securityConfiguration.UserSources.map(function (userSource) {
					return $div({ _dataItem: userSource, _classNameMap: { ReadOnly: userSource.IsReadOnly, External: userSource.IsExternal, Expanded: expandedUserSources.includes(userSource.Name) } }, [
						$div({ className: 'CommandPanel' }, SC.command.queryAndCreateCommandButtons('UserSourcePanel')),
						$div({ className: 'UserSourceTopPanel' }, [
							$h3(
								SC.util.formatString(
									SC.res[userSource.IsEnabled ? 'SecurityPanel.UserSourceEnabledHeadingFormat' : 'SecurityPanel.UserSourceDisabledHeadingFormat'],
									SC.util.formatString(
										SC.res[userSource.Settings.find(_ => _.Key == 'DisplayName').Value ? 'SecurityPanel.UserSourceDisplayNameSetHeadingFormat' : 'SecurityPanel.UserSourceDisplayNameUnsetHeadingFormat'],
										SC.res['SecurityPanel.' + userSource.ResourceKey + '.Heading'],
										userSource.Settings.find(_ => _.Key == 'DisplayName').Value
									)
								)
							),
							$p({ _textResource: 'SecurityPanel.' + userSource.ResourceKey + '.Text' }),
						]),
						$div({ className: 'UserSourceBottomPanel' }, [
							$p(
								SC.command.createCommandButtons([
									{ className: 'ShowButton UserLookupButton', commandName: 'ToggleExpanded', commandArgument: 'ShowUserLookup' },
									{ className: 'HideButton UserLookupButton', commandName: 'ToggleExpanded', commandArgument: 'HideUserLookup' },
									{ className: 'ShowButton UserTableButton', commandName: 'ToggleExpanded', commandArgument: 'ShowUserTable' },
									{ className: 'HideButton UserTableButton', commandName: 'ToggleExpanded', commandArgument: 'HideUserTable' },
								])
							),
							$div({ className: 'UserSourceDetailPanel' }, [
								$div({ className: 'UserLookupPanel' }, [
									$p([
										$input({ type: 'text', className: 'UserLookupBox', placeholder: SC.res['SecurityPanel.UserTestPlaceHolderText'] }),
										$nbsp(),
										SC.command.createCommandButtons([
											{ commandName: 'LookupUser' }
										]),
									]),
									$p($textarea({ disabled: true })),
								]),
								$div({ className: 'UserTablePanel' }, [
									$p({ className: 'CommandList' }, SC.command.createCommandButtons([
										{ commandName: 'CreateUser', _dataItem: { userSourceName: userSource.Name } },
									])),
									$div({ className: 'DataTableContainer' }, [
										$table({ className: 'DataTable' },
											$thead(
												$tr([
													$th(),
													$th({ _textResource: 'SecurityPanel.NameHeaderText' }),
													$th({ _textResource: 'SecurityPanel.RolesHeaderText' }),
													optionalUserPropertyNames.map(function (propertyName) {
														return $th({ _visible: SC.util.getBooleanResource('SecurityPanel.' + propertyName + 'Visible'), _textResource: 'SecurityPanel.' + propertyName + 'HeaderText' });
													}),
												])
											),
											$tbody(
												userSource.Users.map(function (user) {
													return $tr({ _dataItem: { userSourceName: userSource.Name, user: user } }, [
														$td({ className: 'ActionCell' },
															SC.command.createCommandButtons([
																{ commandName: 'EditUser' },
																{ commandName: 'DeleteUser' },
															])
														),
														$td({ title: user.Name }, user.Name),
														$td({ title: user.RoleNames.join(', ') }, user.RoleNames.join(', ')),
														optionalUserPropertyNames.map(function (propertyName) {
															return $td({ title: user[propertyName], _visible: SC.util.getBooleanResource('SecurityPanel.' + propertyName + 'Visible') }, user[propertyName]);
														}),
													]);
												})
											)
										),
									]),
								])
							])
						]),
					]);
				})
			]),
			$dt([
				$h3({ _textResource: 'SecurityPanel.RolesLabelText' }),
				$p({ className: 'CommandList' }, SC.command.createCommandButtons([{ commandName: 'CreateRole' }])),
			]),
			$dd({ className: 'RolesPanel' }, [
				$table({ className: 'DataTable' }, [
					$thead([
						$th(),
						$th({ _textResource: 'SecurityPanel.NameHeaderText' }),
						$th({ _textResource: 'SecurityPanel.SummaryHeaderText' }),
					]),
					$tbody([
						securityConfiguration.Roles.map(function (role) {
							return $tr({ _dataItem: role }, [
								$td({ className: 'ActionCell' }, [
									SC.command.createCommandButtons([
										{ commandName: 'EditRole' },
										{ commandName: 'DeleteRole' },
										{ commandName: 'CloneRole' },
									])
								]),
								$td(role.Name),
								$td(SC.util.formatString(SC.res['SecurityPanel.SummaryFormat'], role.PermissionEntries.length)),
							]);
						}),
					]),
				]),
			]),
			$dt($h3({ _textResource: 'SecurityPanel.RevokeAccessLabelText' })),
			$dd({ className: 'RevokeAccessPanel' }, $table({ className: 'DataTable' }, [
				$thead([
					$th(),
					$th({ _textResource: 'SecurityPanel.TokenTypeHeaderText' }),
					$th({ _textResource: 'SecurityPanel.EarliestValidIssueTimeHeaderText' }),
				]),
				$tbody(securityConfiguration.AccessRevocationInfos.map(function (revocationInfo) {
					return $tr({ _dataItem: revocationInfo }, [
						$td({ className: 'ActionCell' }, SC.command.createCommandButtons([
							{ commandName: 'RevokeAccess' },
						])),
						$td({ _textResource: 'SecurityPanel.' + revocationInfo.Name + 'Label' }),
						$td(SC.util.tryGetDateTime(revocationInfo.EarliestValidIssueTime)
							? SC.util.formatDateTime(SC.util.tryGetDateTime(revocationInfo.EarliestValidIssueTime), { includeFullDate: true, includeSeconds: true })
							: SC.res['SecurityPanel.EarliestValidIssueTimeNeverRevokedText']
						),
					]);
				})),
			])),
		]);
	});

	SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'Options':
				SC.popout.showPanelFromCommand(eventArgs, { userSourceInfo: SC.command.getEventDataItem(eventArgs) });
				break;

			case 'AddUserSource':
				SC.popout.showPanelFromCommand(eventArgs, { userSourceInfo: SC.command.getEventDataItem(eventArgs) });
				break;

			case 'EditSettings':
			case 'ViewSettings':
				var isEditable = eventArgs.commandName === 'EditSettings';
				var panelResourcePrefix = isEditable ? 'EditUserSourceConfigurationPanel' : 'ViewUserSourceConfigurationPanel';

				var userSource = SC.command.getEventDataItem(eventArgs);
				var userLookupBox, userLookupResultsBox;

				SC.dialog.showModalDialog('UserSourceConfiguration', {
					classNameMap: { 'ReadOnly': userSource.IsReadOnly, 'External': userSource.IsExternal },
					titleResourceName: panelResourcePrefix + '.Title',
					content: [
						$table({ className: 'DataTable' }, [
							$thead([
								$tr([
									$th({ _textResource: panelResourcePrefix + '.KeyHeaderText' }),
									$th({ _textResource: panelResourcePrefix + '.ValueHeaderText' }),
								]),
							]),
							$tbody(
								userSource.Settings
									.filter(function (setting) {
										return !setting.ShouldHideIfEmpty || (setting.Value || '').length;
									})
									.map(function (setting) {
										return $tr([
											$td({ className: 'ConfigurationKey' }, setting.Key),
											$td($input({ className: 'ConfigurationValueBox', type: setting.ShouldMask ? 'password' : 'text', value: setting.Value || '', disabled: !isEditable })),
										]);
									})
							),
						]),
						$div({ className: 'UserLookupPanel' }, [
							$p({ _textResource: 'SecurityPanel.UserLookupLabelText' }),
							$p([
								userLookupBox = $input({ className: 'UserLookupBox', type: 'text', placeholder: SC.res['SecurityPanel.UserTestPlaceHolderText'] }),
								SC.command.createCommandButtons([
									{ commandName: 'LookupUser' },
								]),
							]),
							userLookupResultsBox = $textarea({ disabled: true }),
						]),
					],
					buttonTextResourceName: panelResourcePrefix + '.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						var configurationKeys = Array.from(dialog.querySelectorAll('.ConfigurationKey')).map(function (_) { return _.innerText; });
						var configurationValues = Array.from(dialog.querySelectorAll('.ConfigurationValueBox')).map(function (_) { return _.value.trim(); });

						if (dialogEventArgs.commandName == 'Default') {
							if (isEditable) {
								SC.service.SaveUserSourceConfiguration(
									userSource.Name,
									configurationKeys,
									configurationValues,
									function () { SC.dialog.showModalActivityAndReload('Save', true); },
									setDialogErrorProc
								);
							} else {
								closeDialogProc();
							}
						} else if (dialogEventArgs.commandName == 'LookupUser') {
							SC.service.LookupUser(
								userSource.Name,
								userLookupBox.value,
								configurationKeys,
								configurationValues,
								function (result) { SC.ui.setInnerText(userLookupResultsBox, result); },
								function (error) { SC.ui.setInnerText(userLookupResultsBox, error.message); }
							);

							dialogEventArgs.stopPropagation();
						}
					},
				});
				break;

			case 'GenerateMetadata':
				window.open(SC.util.sanitizeUrl(SC.command.getEventDataItem(eventArgs).MetadataUrl), '_blank');
				break;

			case 'ManageUsers':
				window.open(SC.util.sanitizeUrl(SC.command.getEventDataItem(eventArgs).Settings.find(_ => _.Key == "ExternalUserManagementUrl").Value), '_blank');
				break;

			case 'EditUser':
			case 'CreateUser':
				var pageData = SC.pagedata.get();
				var dataItem = SC.command.getEventDataItem(eventArgs);
				var rolesCheckBoxContainer, forcePasswordChangeBox, buttonPanel;
				var textBoxes = {};
				var dummyPassword = 'CE5B9879';

				var createEditFieldProc = function (propertyName, shouldCheckVisible, resourceNameOverride) {
					var resourceName = resourceNameOverride || propertyName;
					var visible = !shouldCheckVisible || SC.util.getBooleanResource('SecurityPanel.' + resourceName + 'Visible');
					return [
						$dt({ _visible: visible, _textResource: 'EditUserPanel.' + resourceName + 'LabelText' }),
						$dd({ _visible: visible },
							textBoxes[propertyName] = $input({ type: 'text', value: dataItem.user && dataItem.user[propertyName] || '' })
						),
					];
				};

				SC.dialog.showModalDialog('EditUser', {
					titleResourceName: dataItem.user ? 'EditUserPanel.EditTitle' : 'EditUserPanel.CreateTitle',
					content: [
						$dl([
							createEditFieldProc('Name', false, 'UserName'),
							$dt({ _textResource: 'EditUserPanel.PasswordLabelText' }),
							$dd(textBoxes.Password = $input({ type: 'password', value: dataItem.user ? dummyPassword : '' })),
							$dt({ _textResource: 'EditUserPanel.VerifyPasswordLabelText' }),
							$dd(textBoxes.VerifyPassword = $input({ type: 'password', value: dataItem.user ? dummyPassword : '' })),
							$dt(),
							$dd($label([
								forcePasswordChangeBox = $input({ type: 'checkbox', className: 'ForcePasswordChange', checked: false }),
								$span({ _textResource: 'EditUserPanel.ForcePasswordChangeLabelText' }),
							])),
							createEditFieldProc('Email', false),
							createEditFieldProc('PasswordQuestion', true),
							createEditFieldProc('DisplayName', true),
							createEditFieldProc('Comment', true),
							$dt({ _textResource: 'EditUserPanel.RoleLabelText' }),
							$dd(
								rolesCheckBoxContainer = $div({ className: 'CheckBoxContainer' },
									pageData.Roles.map(function (_) {
										return $label([
											$input({ type: 'checkbox', value: _.Name, checked: dataItem.user && dataItem.user.RoleNames.includes(_.Name) }),
											$span(_.Name),
										]);
									})
								)
							),
						]),
					],
					buttonTextResourceName: 'EditUserPanel.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.SaveUser(
							dataItem.userSourceName,
							dataItem.user && dataItem.user.Name,
							textBoxes.Name.value.trim(),
							textBoxes.Password.value == dummyPassword ? null : textBoxes.Password.value.trim(),
							textBoxes.VerifyPassword.value == dummyPassword ? null : textBoxes.VerifyPassword.value.trim(),
							textBoxes.PasswordQuestion.value.trim(),
							textBoxes.DisplayName.value.trim(),
							textBoxes.Comment.value.trim(),
							textBoxes.Email.value.trim(),
							Array.from(rolesCheckBoxContainer.querySelectorAll('input[type=checkbox]:checked')).map(function (_) { return _.value; }),
							forcePasswordChangeBox.checked,
							function () { closeDialogProc(); SC.pagedata.notifyDirty(); },
							setDialogErrorProc
						);
					},
				});
				break;

			case 'DeleteUser':
				SC.dialog.showConfirmationDialog(
					'DeleteUser',
					SC.res['DeleteUserPanel.Title'],
					$p({ _innerHTMLToBeSanitized: SC.util.formatString(SC.res['DeleteUserPanel.Text'], SC.util.escapeHtml(SC.command.getEventDataItem(eventArgs).user.Name)) }),
					SC.res['DeleteUserPanel.ButtonText'],
					function (onSuccess, onFailure) {
						SC.service.DeleteUser(
							SC.command.getEventDataItem(eventArgs).userSourceName,
							SC.command.getEventDataItem(eventArgs).user.Name,
							function () { onSuccess(); SC.pagedata.notifyDirty(); },
							onFailure
						);
					}
				);
				break;

			case 'LookupUser':
				var userSource = SC.command.getEventDataItem(eventArgs);

				SC.service.LookupUser(
					userSource.Name,
					SC.command.getEventDataElement(eventArgs).querySelector('.UserLookupBox').value,
					userSource.Settings.map(function (_) { return _.Key; }),
					userSource.Settings.map(function (_) { return _.Value; }),
					function (_) { SC.ui.sanitizeAndSetInnerHtml(SC.command.getEventDataElement(eventArgs).querySelector('textarea'), _); },
					function (error) { SC.ui.sanitizeAndSetInnerHtml(SC.command.getEventDataElement(eventArgs).querySelector('textarea'), error.message); }
				);
				break;

			case 'DeleteRole':
				SC.dialog.showConfirmationDialog(
					'DeleteRole',
					SC.res['DeleteRolePanel.Title'],
					$p({
						_innerHTMLToBeSanitized: SC.util.formatString(
							SC.res['DeleteRolePanel.Text'],
							SC.util.escapeHtml(SC.command.getEventDataItem(eventArgs).Name),
						),
					}),
					SC.res['DeleteRolePanel.ButtonText'],
					function (onSuccess, onFailure) {
						SC.service.DeleteRole(
							SC.command.getEventDataItem(eventArgs).Name,
							function () { onSuccess(); SC.pagedata.notifyDirty(); },
							onFailure
						);
					}
				);
				break;

			case 'CloneRole':
			case 'EditRole':
			case 'CreateRole':
				var pageData = SC.pagedata.get();
				var isClone = (eventArgs.commandName == 'CloneRole');
				var role = SC.command.getEventDataItem(eventArgs);
				var newPermissionEntries = role == null ? [] : role.PermissionEntries.slice();
				var sessionGroupInfos = pageData.SessionGroupInfos.slice();
				var scopeBox, scopedPermissionPanel, roleNameBox, buttonPanel, isCtrlKeyDown;
				var cachedSessionGroupInfosEntry = SC.util.getCacheEntry('SessionGroupInfos', 0);

				if (cachedSessionGroupInfosEntry && cachedSessionGroupInfosEntry.item && cachedSessionGroupInfosEntry.item.length > 0)
					sessionGroupInfos = cachedSessionGroupInfosEntry.item;

				var onKeyDownFunc = function (e) {
					if (e.keyCode == 17 && !e.repeat)
						isCtrlKeyDown = true;
				};

				var onKeyUpFunc = function (e) {
					if (e.keyCode == 17)
						isCtrlKeyDown = false;
				};

				var sessionGroupFilterToSessionTypeList = [
					[SC.types.SessionGroupFilter.SupportSessionGroups, SC.types.SessionType.Support],
					[SC.types.SessionGroupFilter.MeetingSessionGroups, SC.types.SessionType.Meeting],
					[SC.types.SessionGroupFilter.AccessSessionGroups, SC.types.SessionType.Access],
				];

				var traverseSessionGroupsBreadthFirst = function (rootElement, predicate, action) {
					if (!rootElement)
						rootElement = scopeBox.firstChild;

					var queue = [rootElement];

					while (queue.length > 0) {
						var current = queue.shift();

						if (predicate(current))
							action(current);

						var childContainer = SC.ui.findDescendentByTag(current, 'UL');

						if (childContainer && childContainer.children)
							Array.from(childContainer.children).forEach(function (_) { queue.push(_); });
					}
				};

				var findSessionGroupAtPath = function (path, sessionType) {
					var current = SC.ui.findDescendantBreadthFirst(
						scopeBox.firstChild,
						function (_) {
							return _._sessionType == sessionType;
						},
						false);

					if (!path || path.length == 0)
						return current;

					for (var i = 0; i < path.length; i++) {
						var next = SC.ui.findDescendantBreadthFirst(
							current,
							function (_) {
								return _._name == path[i];
							},
							false
						);

						current = next;
					}

					return current;
				};

				var pathsEqual = function (path1, path2) {
					if (path1 == undefined || path1 == null || path1.length == 0)
						return path2 == undefined || path2 == null || path2.length == 0;

					if (path2 == undefined || path2 == null || path2.length == 0)
						return path1 == undefined || path1 == null || path1.length == 0;

					if (path1.length != path2.length)
						return false;

					for (var i = 0; i < path1.length; i++) {
						if (path1[i] != path2[i])
							return false;
					}

					return true;
				};

				var getFullPath = function (sessionGroup) {

					if (!sessionGroup)
						return null;

					var name = sessionGroup.Name;
					var path = sessionGroup.Path;

					return name === undefined || name === null ? path : path.concat([name]);
				};

				var isChildOfParentPath = function (parentPath, childPath) {
					if (parentPath == undefined || parentPath == null || parentPath.length == 0)
						return true;

					if (childPath == undefined || childPath == null || childPath.length == 0)
						return parentPath.length == 0;

					if (parentPath.length > childPath.length)
						return false;

					for (var i = 0; i < parentPath.length; i++) {
						if (parentPath[i] != childPath[i])
							return false;
					}

					return true;
				};

				var updateScopeBoxFunc = function () {
					traverseSessionGroupsBreadthFirst(
						scopeBox.firstChild,
						function (_) { return true; },
						function (_) {
							SC.css.ensureClass(_, 'DefinedOption', newPermissionEntries.some(function (entry) {
								if ((!_._dataItem.Path || _._dataItem.Path.length == 0) && (!entry.SessionGroupPathParts || entry.SessionGroupPathParts.length == 0)) {
									return entry.SessionGroupFilter == _._sessionGroupFilter && pathsEqual(getFullPath(_._dataItem), entry.SessionGroupPathParts);
								}

								return (entry.SessionGroupFilter == SC.types.SessionGroupFilter.SpecificSessionGroup || entry.SessionGroupFilter == _._sessionGroupFilter) && pathsEqual(getFullPath(_._dataItem), entry.SessionGroupPathParts);
							}));
						}
					);
				};

				var createScopeBoxElement = function (sessionGroup) {
					var sessionFilter;
					var displayName = sessionGroup.Name;

					if (sessionGroup.SessionType == SC.types.SessionType.Support)
						sessionFilter = SC.types.SessionGroupFilter.SpecificSupportSessionGroup;
					else if (sessionGroup.SessionType == SC.types.SessionType.Meeting)
						sessionFilter = SC.types.SessionGroupFilter.SpecificMeetingSessionGroup;
					else
						sessionFilter = SC.types.SessionGroupFilter.SpecificAccessSessionGroup;

					if (!displayName || displayName.length == 0)
						displayName = '(empty)';

					return $li({
						_classNameMap: { SpecificGroup: true, HasChildren: sessionGroup.HasChildren },
						_sessionGroupFilter: sessionFilter,
						_sessionType: sessionGroup.SessionType,
						_name: sessionGroup.Name,
						_dataItem: sessionGroup,
					},
						$span({
							_classNameMap: { Expandable: sessionGroup.HasChildren },
							_commandName: 'ToggleScopeExpanded',
						}),
						$p({ _commandName: 'SelectScope' }, displayName),
					);
				};

				var insertScopeBoxElementCollection = function (path, sessionType, sessionGroups) {
					var current = findSessionGroupAtPath(path, sessionType);
					var childContainer = SC.ui.findDescendentByTag(current, 'UL');

					if (!childContainer) {
						childContainer = $ul({}, sessionGroups.map(function (_) { return createScopeBoxElement(_); }));
						SC.ui.insertChild(current, childContainer);
					} else {
						for (var i = 0; i < sessionGroups.length; i++) {
							var existing = SC.ui.findDescendantBreadthFirst(
								current,
								function (_) {
									return _._name == sessionGroup.Name;
								},
								false
							);

							if (!existing)
								SC.ui.insertChild(childContainer, createScopeBoxElement(sessionGroups[i]));
						}
					}
				}

				var insertScopeBoxElement = function (sessionGroup) {
					var current = findSessionGroupAtPath(
						sessionGroup.Path,
						sessionGroup.SessionType
					);

					var childContainer = SC.ui.findDescendentByTag(current, 'UL');

					if (!childContainer)
						SC.ui.insertChild(current, $ul({}));

					childContainer = SC.ui.findDescendentByTag(current, 'UL');

					var existing = SC.ui.findDescendantBreadthFirst(
						current,
						function (_) {
							return _._name == sessionGroup.Name;
						},
						false
					);

					if (!existing)
						SC.ui.insertChild(childContainer, createScopeBoxElement(sessionGroup));
				};

				var sessionGroupHasChildrenPopulated = function (sessionGroup) {
					var current = findSessionGroupAtPath(
						sessionGroup.Path.concat(sessionGroup.Name),
						sessionGroup.SessionType
					);

					var childContainer = SC.ui.findDescendentByTag(current, 'UL');

					if (!childContainer)
						return false;

					var existing = SC.ui.findDescendantBreadthFirst(
						current,
						function (_) {
							return _._name != undefined && _._name != null;
						},
						false
					);

					if (existing)
						return true;

					return false;
				};

				var addSessionGroupsFromPermissionPath = function (path, knownSessionGroupInfos, sessionType) {
					var entries = newPermissionEntries.filter(function (entry) {
						return entry.SessionGroupPathParts &&
							path &&
							entry.SessionGroupPathParts.length > path.length &&
							isChildOfParentPath(path, entry.SessionGroupPathParts) &&
							(!knownSessionGroupInfos ||
								!knownSessionGroupInfos.some(function (_) {
									return _.Name == entry.SessionGroupPathParts[path.length];
								})
							);
					}).map(function (entry) {
						return {
							Name: entry.SessionGroupPathParts[path.length],
							SessionType: sessionType,
							Path: path,
							HasChildren: entry.SessionGroupPathParts.length > path.length + 1,
						};
					}).filter(function (_, i, arr) {
						var sessionGroupInfoPathParts = sessionGroupInfos.map(function (entry) { return entry.Path + '/' + entry.Name });
						var newSessionGroupInfoPathParts = arr.map(function (entry) { return entry.Path + '/' + entry.Name });
						return newSessionGroupInfoPathParts.indexOf(_.Path + '/' + _.Name) == i && !sessionGroupInfoPathParts.includes(_.Path + '/' + _.Name);
					});

					if (entries && entries.length > 0) {
						for (var i = 0; i < entries.length; i++) {
							sessionGroupInfos.push(entries[i]);
							insertScopeBoxElement(entries[i]);
						}
					}
				}

				var populateSessionGroupChildren = function (sessionGroup) {
					if (!sessionGroupHasChildrenPopulated(sessionGroup)) {

						var path = sessionGroup.Path.concat(sessionGroup.Name);
						var element = findSessionGroupAtPath(path, sessionGroup.SessionType);
						SC.css.addClass(element, 'Loading');

						var cachedSessionGroupInfos = sessionGroupInfos.filter(function (_) {
							return _.SessionType == sessionGroup.SessionType && pathsEqual(_.Path, path);
						});

						if (cachedSessionGroupInfos && cachedSessionGroupInfos.length > 0) {
							insertScopeBoxElementCollection(path, sessionGroup.SessionType, cachedSessionGroupInfos);

							addSessionGroupsFromPermissionPath(path, cachedSessionGroupInfos, sessionGroup.SessionType);

							SC.css.removeClass(element, 'Loading');
							updateScopeBoxFunc();
						} else {
							SC.service.GetSessionGroupInfos(
								sessionGroup.SessionType,
								path,
								function (response) {
									if (response) {
										insertScopeBoxElementCollection(path, sessionGroup.SessionType, response);
										response.forEach(function (_) { sessionGroupInfos.push(_); });
									}

									addSessionGroupsFromPermissionPath(path, response, sessionGroup.SessionType);

									SC.css.removeClass(element, 'Loading');
									updateScopeBoxFunc();
								},
								function (error) {
									SC.dialog.showModalErrorBox(error.detail || error.message);
									SC.css.removeClass(element, 'Loading');
								});
						}
					}
				};

				var getSelectedSessionGroups = function () {
					var result = [];
					traverseSessionGroupsBreadthFirst(
						scopeBox.firstChild,
						function (elem) {
							return SC.css.containsClass(elem, 'Selected');
						},
						function (elem) {
							result.push(elem);
						},
					);
					return result;
				};

				var isRootedInSessionGroupFunc = function (sessionGroupElement, permissionEntry) {
					if (permissionEntry.SessionGroupPathParts && permissionEntry.SessionGroupPathParts.length > 0) {
						var roots = [];

						traverseSessionGroupsBreadthFirst(
							sessionGroupElement,
							function (_) { return _._dataItem.Name && _._dataItem.Path && _._dataItem.Path.length == 0; },
							function (_) { roots.push(_._dataItem.Name); },
						);

						return roots.includes(permissionEntry.SessionGroupPathParts[0]);
					}

					return false;
				};

				var findChildSessionGroupFunc = function (sessionGroups, permissionEntry) {
					if (!sessionGroups)
						return null;

					if (!permissionEntry)
						return null;

					if (permissionEntry.SessionGroupPathParts === undefined)
						return null;

					return sessionGroups.find(function (sg) {
						var sessionGroupPathParts = getFullPath(sg._dataItem);
						var pathLengthsValid;
						var validSessionFilters;

						if (!permissionEntry.SessionGroupPathParts && sg._dataItem.Path.length == 0 && sg._sessionGroupFilter == SC.types.SessionGroupFilter.AllSessionGroups) {
							if (permissionEntry.SessionGroupFilter == SC.types.SessionGroupFilter.SupportSessionGroups ||
								permissionEntry.SessionGroupFilter == SC.types.SessionGroupFilter.MeetingSessionGroups ||
								permissionEntry.SessionGroupFilter == SC.types.SessionGroupFilter.AccessSessionGroups) {
								return true;
							} else {
								return false;
							}
						} else if (permissionEntry.SessionGroupPathParts == null) {
							return false;
						}

						if (sg._sessionGroupFilter == SC.types.SessionGroupFilter.AllSessionGroups) {
							validSessionFilters = [
								SC.types.SessionGroupFilter.SupportSessionGroups,
								SC.types.SessionGroupFilter.MeetingSessionGroups,
								SC.types.SessionGroupFilter.AccessSessionGroups,
								SC.types.SessionGroupFilter.SpecificSupportSessionGroup,
								SC.types.SessionGroupFilter.SpecificMeetingSessionGroup,
								SC.types.SessionGroupFilter.SpecificAccessSessionGroup,
								SC.types.SessionGroupFilter.SpecificSessionGroup,
							];
							pathLengthsValid = sessionGroupPathParts.length <= permissionEntry.SessionGroupPathParts.length;
						} else if (sg._sessionGroupFilter == SC.types.SessionGroupFilter.SupportSessionGroups) {
							if (!isRootedInSessionGroupFunc(sg, permissionEntry))
								return false;

							validSessionFilters = [
								SC.types.SessionGroupFilter.SpecificSupportSessionGroup,
								SC.types.SessionGroupFilter.SpecificSessionGroup,
							];
							pathLengthsValid = sessionGroupPathParts.length <= permissionEntry.SessionGroupPathParts.length;
						} else if (sg._sessionGroupFilter == SC.types.SessionGroupFilter.MeetingSessionGroups) {
							if (!isRootedInSessionGroupFunc(sg, permissionEntry))
								return false;

							validSessionFilters = [
								SC.types.SessionGroupFilter.SpecificMeetingSessionGroup,
								SC.types.SessionGroupFilter.SpecificSessionGroup,
							];
							pathLengthsValid = sessionGroupPathParts.length <= permissionEntry.SessionGroupPathParts.length;
						} else if (sg._sessionGroupFilter == SC.types.SessionGroupFilter.AccessSessionGroups) {
							if (!isRootedInSessionGroupFunc(sg, permissionEntry))
								return false;

							validSessionFilters = [
								SC.types.SessionGroupFilter.SpecificAccessSessionGroup,
								SC.types.SessionGroupFilter.SpecificSessionGroup,
							];
							pathLengthsValid = sessionGroupPathParts.length <= permissionEntry.SessionGroupPathParts.length;
						} else {
							validSessionFilters = [
								sg._sessionGroupFilter,
								SC.types.SessionGroupFilter.SpecificSessionGroup,
							];
							pathLengthsValid = sessionGroupPathParts.length < permissionEntry.SessionGroupPathParts.length;
						}

						return validSessionFilters.includes(permissionEntry.SessionGroupFilter) && pathLengthsValid && isChildOfParentPath(sessionGroupPathParts, permissionEntry.SessionGroupPathParts);
					});
				};

				var getConflictingChildPermissionNamesFunc = function (selectedSessionGroups) {
					return newPermissionEntries.filter(function (entry) {
						var sessionGroup = findChildSessionGroupFunc(selectedSessionGroups, entry);

						if (sessionGroup)
							return true;

						return false;
					})
						.map(function (entry) { return entry.Name; })
						.filter(function (_, i, arr) { return arr.indexOf(_) === i; });
				};

				var clearDownstreamPermissionsFunc = function (permissionName, selectedSessionGroups) {
					var indices = [];

					for (var i = 0; i < newPermissionEntries.length; i++) {

						if (newPermissionEntries[i].Name == permissionName) {

							var sessionGroup = findChildSessionGroupFunc(selectedSessionGroups, newPermissionEntries[i]);

							if (sessionGroup != null && sessionGroup != undefined)
								indices.push(i);
						}
					}

					indices.sort(function (a, b) { return a > b ? 1 : -1; });

					for (var i = indices.length - 1; i >= 0; i--)
						newPermissionEntries.splice(indices[i], 1);
				};

				var updatePermissionsBoxFunc = function () {
					var selectedSessionGroups = getSelectedSessionGroups();

					var mappedPermissionNames = selectedSessionGroups.map(function (_) {
						return newPermissionEntries.filter(function (entry) {
							return entry.SessionGroupFilter == _._sessionGroupFilter && pathsEqual(_._dataItem.Path.concat(_._dataItem.Name), entry.SessionGroupPathParts);
						}).map(function (entry) { return entry.Name; });
					});

					var areSelectionsSameSessionType = selectedSessionGroups.map(function (_) { return _._sessionType; }).every(function (_) { return _ == selectedSessionGroups[0]._sessionType; });
					var hasSamePermissionSet = mappedPermissionNames.every(function (_) { return SC.util.difference(_, mappedPermissionNames[0]).length == 0; });

					var scopedPermissionEntries = newPermissionEntries.filter(function (entry) {
						return selectedSessionGroups.find(function (sg) {
							if ((!sg._dataItem.Path || sg._dataItem.Path.length == 0) && (!entry.SessionGroupPathParts || entry.SessionGroupPathParts.length == 0)) {
								return entry.SessionGroupFilter == sg._sessionGroupFilter && pathsEqual(getFullPath(sg._dataItem), entry.SessionGroupPathParts);
							}

							return (entry.SessionGroupFilter == SC.types.SessionGroupFilter.SpecificSessionGroup || entry.SessionGroupFilter == sg._sessionGroupFilter) && pathsEqual(getFullPath(sg._dataItem), entry.SessionGroupPathParts);
						});
					});

					var sessionGroupInfo = sessionGroupInfos.find(function (_) { return pathsEqual(selectedSessionGroups[0]._dataItem.Path.concat(selectedSessionGroups[0]._dataItem.Name), _.Path.concat(_.Name)); });
					var sessionTypeGroupFilter = sessionGroupInfo == null ? selectedSessionGroups[0]._sessionGroupFilter : sessionGroupFilterToSessionTypeList.find(function (_) { return _[1] == sessionGroupInfo.SessionType; })[0];
					var sessionType = sessionTypeGroupFilter == SC.types.SessionGroupFilter.AllSessionGroups ? -1 : sessionGroupFilterToSessionTypeList.find(function (_) { return _[0] == sessionTypeGroupFilter; })[1];

					var getPermissionNamesFunc = function (sessionGroupFilter) {
						return pageData.PermissionInfos
							.filter(function (_) {
								return !_.IsGlobal &&
									(sessionType == -1 || _.RelevantForSessionTypes.includes(sessionType)) &&
									newPermissionEntries.find(function (entry) { return entry.Name == _.Name && entry.SessionGroupFilter == sessionGroupFilter; }) != null;
							})
							.map(function (_) { return _.Name; });
					};

					var hasSpecificGroupConflictsFunc = function () {
						for (var i = 0; i < selectedSessionGroups.length; i++) {
							var node = selectedSessionGroups[i].parentNode;

							while (node) {
								if (SC.css.containsClass(node, 'Selected')) {
									if (SC.css.containsClass(node, 'SpecificGroup'))
										return true;
									else if (SC.css.containsClass(node, 'TypeGroup'))
										return true;
									else if (SC.css.containsClass(node, 'GlobalGroup'))
										return true;
								}

								if (SC.css.containsClass(node, 'ScopedPermissionContainer'))
									break;

								node = node.parentNode;
							}
						}

						return false;
					};

					var getInheritedSpecificGroupPermissionsNamesFunc = function () {
						var mappedPermissions = newPermissionEntries
							.filter(function (entry) {
								if (entry.SessionGroupPathParts && entry.SessionGroupPathParts.length > 0) {
									var matchingSessionGroup = selectedSessionGroups.find(function (sg) {
										return (entry.SessionGroupFilter == SC.types.SessionGroupFilter.SpecificSessionGroup || entry.SessionGroupFilter == sg._sessionGroupFilter) &&
											entry.SessionGroupPathParts.length < getFullPath(sg._dataItem).length && isChildOfParentPath(entry.SessionGroupPathParts, getFullPath(sg._dataItem));
									});

									if (matchingSessionGroup)
										return true;
								}

								return false;
							})
							.map(function (entry) { return [entry.Name, entry.SessionGroupPathParts[entry.SessionGroupPathParts.length - 1]]; })
							.groupBy(function (mappedEntry) { return mappedEntry[1]; });

						return Object.keys(mappedPermissions).map(function (_) {
							return [_, mappedPermissions[_].map(function (item) { return item[0]; })];
						});
					};

					var permissionNamesInheritedFromAll = sessionTypeGroupFilter == SC.types.SessionGroupFilter.AllSessionGroups ? [] : getPermissionNamesFunc(SC.types.SessionGroupFilter.AllSessionGroups);
					var permissionNamesInheritedFromSessionType = sessionGroupInfo == null ? [] : getPermissionNamesFunc(sessionTypeGroupFilter);
					var permissionsInheritedFromSpecificGroupsMap = getInheritedSpecificGroupPermissionsNamesFunc();
					var selectedSpecificGroupConflicts = hasSpecificGroupConflictsFunc();
					var conflictingChildPermissionNames = getConflictingChildPermissionNamesFunc(selectedSessionGroups);

					var configurablePermissionInfos = pageData.PermissionInfos
						.filter(function (_) {
							return !_.IsGlobal &&
								!permissionNamesInheritedFromAll.includes(_.Name) &&
								!permissionNamesInheritedFromSessionType.includes(_.Name) &&
								!permissionsInheritedFromSpecificGroupsMap.map(function (entryMap) { return entryMap[1]; }).some(function (permissionNames) { return permissionNames.includes(_.Name); }) &&
								(sessionType == -1 || _.RelevantForSessionTypes.includes(sessionType));
						});

					if (areSelectionsSameSessionType && !selectedSpecificGroupConflicts) {
						SC.ui.setContents(scopedPermissionPanel, [
							$h3(SC.util.formatString(
								SC.res[selectedSessionGroups.length == 1 ? 'EditRolePanel.PermissionsForScopeLabelFormat' : 'EditRolePanel.PermissionsForMultiScopesLabelFormat'],
								selectedSessionGroups.length == 1 ? selectedSessionGroups[0]._name : selectedSessionGroups.length
							)),
							$div({ _visible: permissionNamesInheritedFromAll.length }, [
								$p(SC.util.formatString(SC.res['EditRolePanel.InheritedPermissionsLabelFormat'], SC.util.getEnumValueName(SC.types.SessionGroupFilter, SC.types.SessionGroupFilter.AllSessionGroups))),
								$ul(permissionNamesInheritedFromAll.map(function (_) { return $li(_); })),
							]),
							$div({ _visible: permissionNamesInheritedFromSessionType.length }, [
								$p(SC.util.formatString(SC.res['EditRolePanel.InheritedPermissionsLabelFormat'], SC.util.getEnumValueName(SC.types.SessionGroupFilter, sessionTypeGroupFilter))),
								$ul(permissionNamesInheritedFromSessionType.map(function (_) { return $li(_); })),
							]),
							permissionsInheritedFromSpecificGroupsMap.map(function (_) {
								return $div([
									$p(SC.util.formatString(SC.res['EditRolePanel.InheritedPermissionsLabelFormat'], _[0])),
									$ul(_[1].map(function (permissionName) { return $li(permissionName); })),
								]);
							}),
							$div({ _visible: configurablePermissionInfos.length, className: 'ConfigurablePermissionContainer' }, [
								$p({ _textResource: 'EditRolePanel.ConfigurablePermissionsLabelText' }),
								$p([
									$button({ className: 'SecondaryButton', _commandName: 'SelectAll', _textResource: 'SelectAllButtonText' }),
									$button({ className: 'SecondaryButton', _commandName: 'UnselectAll', _textResource: 'UnselectAllButtonText' }),
								]),
								$p({ _visible: !hasSamePermissionSet, _textResource: 'EditRolePanel.HasDifferentPermissionsWarningText' }),
								$ul({ _visible: hasSamePermissionSet },
									configurablePermissionInfos.map(function (_) {
										var isIndeterminate = conflictingChildPermissionNames.some(function (name) { return name == _.Name; });
										return $li($label([
											$input({
												type: 'checkbox',
												value: _.Name,
												_dataItem: _,
												_commandName: isIndeterminate ? 'ClearDownstreamPermissions' : 'TogglePermission',
												checked: scopedPermissionEntries.some(function (entry) { return entry.Name == _.Name && entry.AccessControlType == SC.types.AccessControlType.Allow; })
													&& !scopedPermissionEntries.some(function (entry) { return entry.Name == _.Name && entry.AccessControlType == SC.types.AccessControlType.Deny; })
													&& !isIndeterminate,
												indeterminate: isIndeterminate
											}),
											$span(_.Name),
										]));
									})
								),
							]),
						]);
					}
					else if (selectedSpecificGroupConflicts) {
						SC.ui.setContents(scopedPermissionPanel, [
							$h3({ _textResource: 'EditRolePanel.HasSpecificGroupConflictsWarningHeaderText' }),
							$p({ _textResource: 'EditRolePanel.HasSpecificGroupConflictsWarningLabelText' })
						]);
					}
					else {
						SC.ui.setContents(scopedPermissionPanel, [
							$h3({ _textResource: 'EditRolePanel.HasDifferentSessionTypesWarningHeaderText' }),
							$p({ _textResource: 'EditRolePanel.HasDifferentSessionTypesWarningLabelText' })
						]);
					}
				};

				SC.dialog.showModalDialog('EditRole', {
					titleResourceName: role == null ? 'EditRolePanel.CreateTitle' : isClone ? 'EditRolePanel.CloneTitle' : 'EditRolePanel.EditTitle',
					content: [
						$dl([
							$dt({ _textResource: 'EditRolePanel.RoleNameLabelText' }),
							$dd([
								roleNameBox = $input({ type: 'text', value: role == null ? '' : (isClone ? SC.util.formatString(SC.res['EditRolePanel.CloneNameFormat'], role.Name) : role.Name), readOnly: !(role == null || isClone) }),
								$p({ className: 'EditRoleReadOnlyMessage', _textResource: 'EditRolePanel.RoleNameReadOnlyMessage' }),
							]),
							$dt({ _textResource: 'EditRolePanel.GlobalPermissionsLabelText' }),
							$dd([
								$div({ className: 'CheckBoxContainer' }, [
									pageData.PermissionInfos
										.filter(function (_) { return _.IsGlobal; })
										.map(function (globalPermissionInfo) {
											return $label([
												$input({
													type: 'checkbox',
													value: globalPermissionInfo.Name,
													_dataItem: globalPermissionInfo,
													_eventHandlerMap: { 'change': function (eventArgs) { SC.command.dispatchExecuteCommand(eventArgs.target, eventArgs.target, eventArgs.target, 'ToggleGlobalPermission'); } },
													checked: newPermissionEntries.findIndex(function (_) { return _.Name == globalPermissionInfo.Name; }) > -1,
												}),
												$span(globalPermissionInfo.Name),
											]);
										}),
								]),
							]),
							$dt({ _textResource: 'EditRolePanel.ScopedPermissionsLabelText' }),
							$dd([
								$div({ className: 'ScopedPermissionContainer' }, [
									scopeBox = $ul({ className: 'ScopeBox' },
										$li({
											_classNameMap: { GlobalGroup: true, Selected: true },
											_sessionGroupFilter: SC.types.SessionGroupFilter.AllSessionGroups,
											_sessionType: null,
											_name: SC.util.getEnumValueName(SC.types.SessionGroupFilter, SC.types.SessionGroupFilter.AllSessionGroups),
											_dataItem: {
												Path: [],
												HasChildren: true,
												Name: null,
												SessionType: null,
											},
										},
											$span({
												_classNameMap: { Expandable: false },
												_commandName: 'ToggleScopeExpanded',
											}),
											$p({ _commandName: 'SelectScope' }, SC.util.getEnumValueName(SC.types.SessionGroupFilter, SC.types.SessionGroupFilter.AllSessionGroups)),
											$ul({},
												sessionGroupFilterToSessionTypeList.map(function (sessionTypeInfo) {
													var name = SC.util.getEnumValueName(SC.types.SessionGroupFilter, sessionTypeInfo[0]);
													var hasChildren = sessionGroupInfos.find(function (_) { return _.SessionType === sessionTypeInfo[1]; }) ? true : false;

													return [
														$li({
															_classNameMap: { TypeGroup: true, HasChildren: hasChildren, Expanded: hasChildren },
															_sessionGroupFilter: sessionTypeInfo[0],
															_sessionType: sessionTypeInfo[1],
															_name: name,
															_dataItem: {
																Path: [],
																HasChildren: hasChildren,
																Name: null,
																SessionType: sessionTypeInfo[1]
															},
														},
															$span({
																_classNameMap: { Expandable: hasChildren },
																_commandName: 'ToggleScopeExpanded',
															}),
															$p({ _commandName: 'SelectScope' }, name),
															$ul({}, sessionGroupInfos
																.filter(function (_) { return _.SessionType == sessionTypeInfo[1] && _.Path && _.Path.length == 0; })
																.map(function (_) { return createScopeBoxElement(_); }),
															),
														),
													];
												}),
											),
										)),
									scopedPermissionPanel = $div({ className: 'ScopedPermissionPanel' }),
								]),
							]),
						]),
					],
					buttonTextResourceName: 'EditRolePanel.ButtonText',
					buttonPanelExtraContent: [
						SC.command.createCommandButtons([
							{ commandName: 'ToggleReference', commandArgument: 'Hide' },
							{ commandName: 'ToggleReference', commandArgument: 'Show' },
						])
					],
					referencePanelTextResourceName: 'EditRolePanel.Instructions',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						switch (dialogEventArgs.commandName) {
							case 'ToggleReference':
								SC.css.toggleClass(dialog, 'Expanded');
								break;
							case 'ToggleGlobalPermission':
							case 'TogglePermission':
								var dataItem = SC.command.getEventDataItem(dialogEventArgs);
								var selectedSessionGroups = getSelectedSessionGroups();
								var toAdd = [];
								var toRemove = [];

								for (var i = 0; i < selectedSessionGroups.length; i++) {
									var permissionEntry = {
										AccessControlType: SC.types.AccessControlType.Allow,
										Name: dataItem.Name,
										SessionGroupFilter: dialogEventArgs.commandName == 'ToggleGlobalPermission' ? null : selectedSessionGroups[i]._sessionGroupFilter,
										SessionGroupPathParts: getFullPath(selectedSessionGroups[i]._dataItem),
									};

									var existingIndex = -1;

									for (var j = 0; j < newPermissionEntries.length; j++) {
										var entry = newPermissionEntries[j];

										if (permissionEntry.Name == entry.Name &&
											(entry.SessionGroupFilter == SC.types.SessionGroupFilter.SpecificSessionGroup || permissionEntry.SessionGroupFilter == entry.SessionGroupFilter) &&
											pathsEqual(permissionEntry.SessionGroupPathParts, entry.SessionGroupPathParts)) {
											if (existingIndex == -1)
												existingIndex = i;

											if (existingIndex >= 0) {
												if (entry.AccessControlType == SC.types.AccessControlType.Deny)
													newPermissionEntries[j].AccessControlType = SC.types.AccessControlType.Allow;
												else
													toRemove.push(j);
											}
										}
									}

									if (existingIndex == -1)
										toAdd.push(permissionEntry);
								}

								if (toRemove.length > 0) {
									toRemove.sort(function (a, b) { return a > b ? 1 : -1; });

									for (var i = toRemove.length - 1; i >= 0; i--)
										newPermissionEntries.splice(toRemove[i], 1);
								}

								if (toAdd.length > 0) {
									for (var i = 0; i < toAdd.length; i++)
										newPermissionEntries.push(toAdd[i]);
								}

								updateScopeBoxFunc();
								break;

							case 'ClearDownstreamPermissions':
								var dataItem = SC.command.getEventDataItem(dialogEventArgs);
								var selectedSessionGroups = getSelectedSessionGroups();

								clearDownstreamPermissionsFunc(dataItem.Name, selectedSessionGroups);

								updatePermissionsBoxFunc();
								updateScopeBoxFunc();
								break;

							case 'SelectScope':
								var listElement = SC.ui.findAncestorByTag(dialogEventArgs.commandElement, 'LI');
								var sessionGroup = listElement._dataItem;
								var isSelecting = !SC.css.containsClass(listElement, 'Selected');

								if (isSelecting && !isCtrlKeyDown) {
									traverseSessionGroupsBreadthFirst(
										scopeBox.firstChild,
										function (elem) { return true; },
										function (elem) { SC.css.removeClass(elem, 'Selected'); }
									);

									SC.css.addClass(listElement, 'Selected');
								} else if (isSelecting && isCtrlKeyDown) {
									SC.css.addClass(listElement, 'Selected');
								} else if (!isSelecting && !isCtrlKeyDown) {
									traverseSessionGroupsBreadthFirst(
										scopeBox.firstChild,
										function (elem) { return true; },
										function (elem) { SC.css.removeClass(elem, 'Selected'); }
									);

									SC.css.addClass(listElement, 'Selected');
								} else {
									var selectedCount = 0;
									traverseSessionGroupsBreadthFirst(
										scopeBox.firstChild,
										function (elem) { return SC.css.containsClass(elem, 'Selected'); },
										function (elem) { selectedCount++; }
									);

									var shouldSelect = selectedCount > 1 ? false : true;
									SC.css.ensureClass(listElement, 'Selected', shouldSelect);
								}

								updatePermissionsBoxFunc();
								break;

							case 'ToggleScopeExpanded':
								if (SC.css.containsClass(dialogEventArgs.commandElement, 'Expandable')) {
									var listElement = SC.ui.findAncestorByTag(dialogEventArgs.commandElement, 'LI');
									var sessionGroup = listElement._dataItem;

									if (sessionGroup.HasChildren && getFullPath(sessionGroup).length > 0)
										populateSessionGroupChildren(sessionGroup);

									SC.css.toggleClass(listElement, 'Expanded');

									if (!SC.css.containsClass(listElement, 'Expanded')) {
										traverseSessionGroupsBreadthFirst(
											listElement,
											function (elem) { return true; },
											function (elem) { SC.css.removeClass(elem, 'Expanded'); }
										);
									}
								}

								break;

							case 'Default':
								var globalPermissionEntries = newPermissionEntries.filter(function (_) { return _.SessionGroupFilter == null });
								var scopedPermissionEntries = newPermissionEntries.filter(function (_) { return _.SessionGroupFilter != null });
								var onCloseProc = function () {
									SC.dialog.hideModalDialog();
									SC.pagedata.notifyDirty();
								};

								if (role == null || isClone) {
									SC.service.CreateRole(
										roleNameBox.value.trim(),
										globalPermissionEntries,
										scopedPermissionEntries,
										onCloseProc,
										setDialogErrorProc
									);
								} else {
									SC.service.SaveRole(
										role.Name,
										role.Name,
										globalPermissionEntries,
										scopedPermissionEntries,
										onCloseProc,
										setDialogErrorProc
									);
								}

								break;

							case 'SelectAll':
							case 'UnselectAll':
								var selectedSessionGroups = getSelectedSessionGroups();

								var conflictingChildPermissionNames = getConflictingChildPermissionNamesFunc(selectedSessionGroups);

								if (conflictingChildPermissionNames && conflictingChildPermissionNames.length > 0) {
									for (var i = 0; i < conflictingChildPermissionNames.length; i++)
										clearDownstreamPermissionsFunc(conflictingChildPermissionNames[i], selectedSessionGroups);
								}

								var toAdd = [];
								var toRemove = [];

								for (var i = 0; i < selectedSessionGroups.length; i++) {
									var selectedSessionGroup = selectedSessionGroups[i];

									Array.from(scopedPermissionPanel.querySelectorAll('input'))
										.forEach(function (scopedPermissionCheckBox) {
											scopedPermissionCheckBox.checked = (dialogEventArgs.commandName == 'SelectAll');
											var permissionEntry = {
												AccessControlType: SC.types.AccessControlType.Allow,
												Name: scopedPermissionCheckBox.value,
												SessionGroupFilter: selectedSessionGroup._sessionGroupFilter,
												SessionGroupPathParts: getFullPath(selectedSessionGroup._dataItem),
											};

											var existingIndex = -1;

											for (var j = 0; j < newPermissionEntries.length; j++) {
												var entry = newPermissionEntries[j];
												if (permissionEntry.AccessControlType == entry.AccessControlType && permissionEntry.Name == entry.Name &&
													(entry.SessionGroupFilter == SC.types.SessionGroupFilter.SpecificSessionGroup || permissionEntry.SessionGroupFilter == entry.SessionGroupFilter) &&
													pathsEqual(permissionEntry.SessionGroupPathParts, entry.SessionGroupPathParts)) {

													if (dialogEventArgs.commandName == 'SelectAll') {
														if (existingIndex == -1)
															existingIndex = j;

														if (existingIndex >= 0 && existingIndex != j)
															toRemove.push(j);
													} else {
														if (existingIndex == -1)
															existingIndex = j;

														if (existingIndex >= 0)
															toRemove.push(j);
													}
												}
											}

											if (dialogEventArgs.commandName == 'SelectAll' && existingIndex == -1)
												toAdd.push(permissionEntry);
										});
								}

								if (toRemove.length > 0) {
									toRemove.sort(function (a, b) { return a > b ? 1 : -1; });

									for (var i = toRemove.length - 1; i >= 0; i--)
										newPermissionEntries.splice(toRemove[i], 1);
								}

								if (toAdd.length > 0) {
									for (var i = 0; i < toAdd.length; i++)
										newPermissionEntries.push(toAdd[i]);
								}

								updateScopeBoxFunc();
								updatePermissionsBoxFunc();
								break;
						}

						SC.command.updateCommandButtonsState(dialog);
					},
					onQueryCommandButtonStateProc: function (_, dialog) {
						switch (_.commandName) {
							case 'ToggleReference':
								_.isVisible = (_.commandArgument == 'Show') != SC.css.containsClass(dialog, 'Expanded');
								break;
						}
					},
					onHideProc: function (_, dialog) {
						SC.util.setCacheItem('SessionGroupInfos', 0, sessionGroupInfos);
						SC.event.removeGlobalHandler('keydown', onKeyDownFunc);
						SC.event.removeGlobalHandler('keyup', onKeyUpFunc);
					},
				});

				SC.event.addGlobalHandler('keydown', onKeyDownFunc);
				SC.event.addGlobalHandler('keyup', onKeyUpFunc);

				updateScopeBoxFunc();
				updatePermissionsBoxFunc();
				SC.command.updateCommandButtonsState(SC.dialog.getModalDialog());
				break;

			case 'Add':
				SC.service.AddUserSource(
					SC.pagedata.get().UserSourceTypeInfos.find(function (_) { return _.ResourceKey == eventArgs.commandArgument; }).Type,
					undefined,
					undefined,
					undefined,
					undefined,
					undefined,
					function () { SC.dialog.showModalActivityAndReload('Save', true); }
				);
				break;

			case 'Enable':
			case 'Disable':
				var userSource = SC.command.getEventDataItem(eventArgs);
				var enableOrDisable = eventArgs.commandName == 'Enable';

				SC.dialog.showModalDialog('EnableDisableUserSource', {
					titleResourceName: enableOrDisable ? 'EnableUserSourcePanel.Title' : 'DisableUserSourcePanel.Title',
					content: $p({ _textResource: enableOrDisable ? 'EnableUserSourcePanel.Text' : 'DisableUserSourcePanel.Text' }),
					buttonTextResourceName: enableOrDisable ? 'EnableUserSourcePanel.ButtonText' : 'DisableUserSourcePanel.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.SetUserSourceEnabled(userSource.Name, enableOrDisable, function () { SC.dialog.showModalActivityAndReload('Save', true); }, setDialogErrorProc);
					},
				});
				break;

			case 'Remove':
				var userSource = SC.command.getEventDataItem(eventArgs);

				SC.dialog.showModalDialog('RemoveUserSource', {
					titleResourceName: 'RemoveUserSourcePanel.Title',
					content: $p({ _htmlResource: 'RemoveUserSourcePanel.Text' }),
					buttonTextResourceName: 'RemoveUserSourcePanel.ButtonText',
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.RemoveUserSource(userSource.Name, function () { SC.dialog.showModalActivityAndReload('Save', true); }, setDialogErrorProc);
					},
				});
				break;

			case 'ToggleExpanded':
				SC.css.toggleClass(SC.command.getEventDataElement(eventArgs), 'Expanded');
				break;

			case 'RevokeAccess':
				var revocationInfo = SC.command.getEventDataItem(eventArgs);
				var tokenTypeText = SC.res['SecurityPanel.' + revocationInfo.Name + 'Label'];

				SC.dialog.showModalDialog('RevokeAccess', {
					title: SC.util.formatString(SC.res['RevokeAccessPanel.Title'], tokenTypeText),
					content: $p({ _htmlResource: 'RevokeAccessPanel.' + revocationInfo.Name + 'Text' }),
					buttonText: SC.util.formatString(SC.res['RevokeAccessPanel.ButtonText'], tokenTypeText),
					onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
						SC.service.RevokeAccess(revocationInfo.Name, function () { SC.dialog.showModalActivityAndReload('Save', true); }, setDialogErrorProc);
					},
				});
				break;
		}
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
		switch (eventArgs.area) {
			case 'UserSourcePanel':
				eventArgs.buttonDefinitions.push({ commandName: 'Options'});
				break;

			case 'AddUserSourcePanel':
				eventArgs.buttonDefinitions.push({ commandName: 'AddUserSource' });
				break;

			case 'AddUserSourcePopoutPanel':
				SC.pagedata.get().UserSourceTypeInfos.forEach(function (_) { eventArgs.buttonDefinitions.push({ commandName: 'Add', commandArgument: _.ResourceKey }); });
				break;

			case 'OptionsPopoutPanel':
				eventArgs.buttonDefinitions.push(
					{ commandName: 'EditSettings' },
					{ commandName: 'ViewSettings' },
					{ commandName: 'GenerateMetadata' },
					{ commandName: 'ManageUsers' },
					{ commandName: 'Enable' },
					{ commandName: 'Disable' },
					{ commandName: 'Remove' }
				);
				break;
		}
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtonState, function (eventArgs) {
		switch (eventArgs.commandName) {
			case 'EditSettings':
				eventArgs.isVisible = !eventArgs.commandContext.userSourceInfo.IsLocked;
				break;
			case 'ViewSettings':
				eventArgs.isVisible = eventArgs.commandContext.userSourceInfo.IsLocked;
				break;
			case 'GenerateMetadata':
				eventArgs.isVisible = !!eventArgs.commandContext.userSourceInfo.MetadataUrl;
				break;
			case 'ManageUsers':
				var externalManagementUrlObject = eventArgs.commandContext.userSourceInfo.Settings.find(_ => _.Key == "ExternalUserManagementUrl");
				eventArgs.isVisible = Boolean(externalManagementUrlObject && externalManagementUrlObject.Value);
				break;
			case 'Enable':
			case 'Disable':
				eventArgs.isVisible = !eventArgs.commandContext.userSourceInfo.IsLocked && eventArgs.commandContext.userSourceInfo.IsEnabled !== (eventArgs.commandName === 'Enable');
				break;
			case 'Remove':
				eventArgs.isVisible = !eventArgs.commandContext.userSourceInfo.IsLocked && SC.pagedata.get().UserSourceTypeInfos.filter(function (_) { return _.Type == eventArgs.commandContext.userSourceInfo.Type; })[0].CanRemove;
				break;
			case 'Add':
				eventArgs.isVisible = SC.pagedata.get().UserSourceTypeInfos.filter(function (_) { return _.ResourceKey == eventArgs.commandArgument })[0].CanAdd &&
				(
					SC.pagedata.get().UserSources.filter(function (_) { return _.ResourceKey == eventArgs.commandArgument; }).length == 0 ||
					SC.pagedata.get().UserSourceTypeInfos.filter(function (_) { return _.ResourceKey == eventArgs.commandArgument })[0].CanUseMultiple
				)
				break;
		}
	});

</script>
