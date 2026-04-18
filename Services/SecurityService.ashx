<%@ WebHandler Language="C#" Class="ScreenConnect.SecurityService" %>

using System;
using System.Collections.Generic;
using System.Linq;
using System.Configuration;
using System.Web.Configuration;
using System.Collections.Specialized;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	[DemandLicense(BasicLicenseCapabilities.AdministerSecurity)]
	[ActivityTrace]
	public class SecurityService : WebServiceBase
	{
		public async Task<object> GetSecurityConfigurationInfo(IPrincipal user)
		{
			var context = WebContext.CurrentHttpContext;

			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var membershipSection = WebConfigurationManager.GetSection<MembershipSection>(configuration);
			var variables = await ServerExtensions.GetStandardVariablesAsync(user);

			return new
			{
				UserSources = await membershipSection.Providers
					.OfType<ProviderSettings>()
					.Select(_ => MembershipWebAuthenticationProvider.TryCreateMembershipProvider(_.Type, _.Name, _.Parameters))
					.WhereNotNull()
					.Select(async provider => new
					{
						Type = provider.GetType().FullName,
						ResourceKey = provider.GetType().Name,
						IsEnabled = provider.As<MembershipProviderBase>().SafePipe(it => it.IsEnabled),
						IsLocked = provider.As<MembershipProviderBase>().SafePipe(it => it.IsLocked),
						Name = provider.Name,
						Settings = provider.As<MembershipProviderBase>()
							.SafeNav(_ => _.GetSettings())
							.SafeEnumerate()
							.Select(it => new
							{
								Key = it.Name,
								Value = it.Value.SafeToString(),
								ShouldMask = it.EditFeatures.AreFlagsSet(EditFeatures.Mask),
								ShouldHideIfEmpty = it.EditFeatures.AreFlagsSet(EditFeatures.HideIfEmpty),
							}),
						IsReadOnly = provider is IReadOnlyMembershipProvider,
						IsExternal = provider is IExternalAuthenticationProvider,
						MetadataUrl = provider
							.If(it => it is IMetadataProvider)
							.SafePipe(it => WebAuthenticationProvider.GetProviderCommandUrl(context.Request.GetRealUrl(false), it.Name, WebConstants.ProcessExternalMetadataKey))
							.Else(string.Empty),
						Users = await provider
							.If(_ => !(_ is IReadOnlyMembershipProvider))
							.SafePipeAwaitAsync(_ => _.GetAllUsersAsync())
							.PipeAsync(it => it.SafeEnumerate())
							.ToAsyncEnumerable()
							.SelectAwait(async user => new
							{
								Name = user.UserName,
								PasswordQuestion = user.PasswordQuestion,
								Comment = user.Comment,
								Email = user.Email,
								DisplayName = user.As<IDisplayNameUser>().SafeNav(_ => _.UserDisplayName),
								RoleNames = await provider.To<IRoleMembershipProvider>().GetRolesForUserAsync(user.UserName, false),
							})
							.OrderBy(_ => _.Name)
							.ToListAsync(),
					})
					.Pipe(Task.WhenAll),
				Roles = (await Permissions.GetAllRolesAsync())
					.OrderBy(_ => _.Name),
				PermissionInfos = PermissionInfo.GetPermissionNames()
					.Select(_ => new
					{
						Name = _,
						IsGlobal = PermissionInfo.IsGlobalPermission(_),
						RelevantForSessionTypes = Enum.GetValues(typeof(SessionType))
							.Cast<SessionType>()
							.Where(sessionType => PermissionInfo.IsPermissionRelevant(_, sessionType)),
					}),
				SessionGroupInfos = (await SessionManagerPool.Demux.GetRootSessionGroupSummariesAsync(variables))
					.Select(_ => new
					{
						Name = _.Name,
						SessionType = _.SessionType,
						Path = Array.Empty<string>(),
						HasChildren = _.HasSubgroupExpression && _.SessionCount > 0,
					}),
				UserSourceTypeInfos = Extensions.GetPluginTypes(typeof(MembershipProviderBase))
					.Where(it => !it.IsAbstract)
					.OrderBy(it => it.IsOfType(typeof(IExternalAuthenticationProvider)))
					.ThenBy(it => it.Name)
					.Select(it => new
					{
						Type = it.FullName,
						ResourceKey = it.Name,
						CanAdd = !it.IsOfType(typeof(IUnAddableMembershipProvider)),
						CanRemove = !it.IsOfType(typeof(IUnremovableMembershipProvider)),
						CanUseMultiple = !it.IsOfType(typeof(ISingleInstanceMembershipProvider)),
					}),
				AccessRevocationInfos = new[]
				{
					new
					{
						Name = "DelegatedAccessTokens",
						EarliestValidIssueTime = ConfigurationCache.DelegatedAccessTokenEarliestValidIssueTime,
					},
					new
					{
						Name = "PrimaryAccessTokens",
						EarliestValidIssueTime = ConfigurationCache.PrimaryAccessTokenEarliestValidIssueTime,
					},
					new
					{
						Name = "AuthenticationSessions",
						EarliestValidIssueTime = ConfigurationCache.AuthenticationSessionEarliestValidIssueTime,
					},
				},
			};
		}

		public async Task<object> GetSessionGroupInfos(SessionType sessionType, string[] sessionGroupPathParts, IPrincipal user)
		{
			var variables = await ServerExtensions.GetStandardVariablesAsync(user);

			var sessionGroups = !sessionGroupPathParts.SafeAny()
				? await SessionManagerPool.Demux.GetRootSessionGroupSummariesAsync(sessionType, SessionGroupPathFilter.Default, variables)
				: await SessionManagerPool.Demux.GetSessionGroupSummariesAsync(SessionGroupPath.FromParts(sessionGroupPathParts), SessionGroupPathFilter.Default.ForSessionType(sessionType), variables);

			if (!sessionGroups.SafeAny())
				return null;

			return sessionGroups
				.Select(it => new
				{
					it.Name,
					it.SessionType,
					Path = sessionGroupPathParts,
					HasChildren = it.SessionCount > 0 && it.HasSubgroupExpression,
				});
		}

		public async Task CreateRole(
			string roleName,
			[ActivityTraceIgnore] PermissionEntry[] globalPermissionEntries,
			[ActivityTraceIgnore] SessionPermissionEntry[] scopedPermissionEntries
		)
		{
			if (roleName.IsNullOrEmpty())
				throw new InvalidOperationException("Role name cannot be empty!");

			if ((await Permissions.GetAllRoleNamesAsync()).Any(_ => string.Equals(_, roleName, StringComparison.OrdinalIgnoreCase)))
				throw new InvalidOperationException("Duplicate role name");

			await this.SaveRoleAsync(roleName, DateTime.UtcNow, globalPermissionEntries, scopedPermissionEntries);
		}

		// TODO: The parameter originalRoleName here is for only Backward compatibility.
		// When it is no longer needed, we should remove it from here and SaveRole API call in Security.ascx.
		// Also, remove the parts where using originalRoleName parameter for renaming role in this method.
		public async Task SaveRole(
			string originalRoleName,
			string roleName,
			[ActivityTraceIgnore] PermissionEntry[] globalPermissionEntries,
			[ActivityTraceIgnore] SessionPermissionEntry[] scopedPermissionEntries
		)
		{
			if (roleName.IsNullOrEmpty())
				throw new InvalidOperationException("Role name cannot be empty!");

			if (originalRoleName != roleName && (await Permissions.GetAllRoleNamesAsync()).Any(it => it == roleName))
				throw new InvalidOperationException("Duplicate role name");

			if (originalRoleName != null)
				foreach (var membershipProvider in MembershipWebAuthenticationProvider.MembershipProviders.Where(it => !(it is IReadOnlyMembershipProvider) && it is IRoleMembershipProvider))
				{
					var usersInRole = await membershipProvider.To<IRoleMembershipProvider>().GetUsersInRoleAsync(originalRoleName);
					await membershipProvider.To<IRoleMembershipProvider>().RemoveUsersFromRolesAsync(usersInRole, new[] { originalRoleName });
					await membershipProvider.To<IRoleMembershipProvider>().AddUsersToRolesAsync(usersInRole, new[] { roleName });
				}

			var existingRole = (await Permissions.GetAllRolesAsync()).Where(it => it.Name == originalRoleName).FirstOrDefault();
			var existingRoleCreationDate = existingRole?.CreationDate ?? DateTime.UtcNow;

			await this.SaveRoleAsync(roleName, existingRoleCreationDate, globalPermissionEntries, scopedPermissionEntries);
		}

		async Task SaveRoleAsync(
			string roleName,
			DateTime creationDate,
			[ActivityTraceIgnore] PermissionEntry[] globalPermissionEntries,
			[ActivityTraceIgnore] SessionPermissionEntry[] scopedPermissionEntries
		)
		{
			var newScopedEntries = new List<SessionPermissionEntry>();

			foreach (var entry in scopedPermissionEntries)
			{
				var duplicateNewEntry = newScopedEntries
					.Where(it => it.Name.Equals(entry.Name))
					.Where(it => Extensions.ListEquals(it.SessionGroupPathParts, entry.SessionGroupPathParts, StringComparer.Ordinal))
					.Where(it => it.SessionGroupFilter.Equals(entry.SessionGroupFilter))
					.FirstOrDefault();

				if (duplicateNewEntry == null)
					newScopedEntries.Add(entry);
				else if (duplicateNewEntry.AccessControlType == AccessControlType.Allow && entry.AccessControlType == AccessControlType.Deny)
					duplicateNewEntry.AccessControlType = AccessControlType.Deny;
			}

			var newRoles = (await Permissions.GetAllRolesAsync())
				.Where(it => it.Name != roleName)
				.Append(new Role
				{
					Name = roleName,
					CreationDate = creationDate,
					PermissionEntries = globalPermissionEntries
						.SafeEnumerate()
						.Concat(newScopedEntries.SafeEnumerate().OfType<PermissionEntry>())
						.ToArray(),
				})
				.ToList();

			this.AssertAnyRoleHasAdministerPermission(newRoles);

			await Permissions.SaveRolesAsync(newRoles);
		}

		public async Task DeleteRole(string roleName)
		{
			var newRoles = (await Permissions.GetAllRolesAsync()).Where(it => it.Name != roleName).ToList();
			this.AssertAnyRoleHasAdministerPermission(newRoles);

			foreach (var membershipProvider in MembershipWebAuthenticationProvider.MembershipProviders.Where(_ => !(_ is IReadOnlyMembershipProvider) && _ is IRoleMembershipProvider))
				await membershipProvider.To<IRoleMembershipProvider>().RemoveUsersFromRolesAsync(
					await membershipProvider.GetAllUsersAsync().ToAsyncEnumerable().Select(_ => _.UserName).ToArrayAsync(),
					new[] { roleName }
				);

			await Permissions.SaveRolesAsync(newRoles);
		}

		public async Task SaveUser(string userSourceName, string originalUserName, string newUserName, [ActivityTraceIgnore] string password, [ActivityTraceIgnore] string verifyPassword, [ActivityTraceIgnore] string passwordQuestion, [ActivityTraceIgnore] string displayName, [ActivityTraceIgnore] string comment, [ActivityTraceIgnore] string email, [ActivityTraceIgnore] string[] roleNames, bool forcePasswordChange)
		{
			if (newUserName.IsNullOrEmpty())
				throw new InvalidOperationException("User name cannot be empty");

			if (password != verifyPassword)
				throw new InvalidOperationException("Password does not match");

			if (email.IsNullOrEmpty())
				throw new InvalidOperationException("Email address cannot be empty");

			if (!email.Contains("@"))
				throw new InvalidOperationException("Invalid email address");

			if (!OneTimePasswordAuthenticationProvider.IsValidPasswordQuestion(passwordQuestion))
				throw new InvalidOperationException("Invalid OTP value");

			var membershipProvider = this.GetMembershipProvider(userSourceName, null, null);

			if (originalUserName != newUserName)
				foreach (var existingMembershipUser in await membershipProvider.GetAllUsersAsync())
					if (newUserName == existingMembershipUser.UserName)
						throw new InvalidOperationException("This user name has been used");

			if (originalUserName.IsNullOrEmpty())
			{
				await membershipProvider.CreateUserAsync(newUserName, password, passwordQuestion, displayName, comment, email);
			}
			else
			{
				if (originalUserName != newUserName)
					if (!await membershipProvider.To<IChangeUserNameProvider>().ChangeUserNameAsync(originalUserName, newUserName))
						throw new InvalidOperationException(string.Format("Unable to change user name for: {0}", originalUserName));

				if (password != null)
					if (!await membershipProvider.To<IMembershipWithoutOldPasswordProvider>().ResetPasswordWithoutOldPasswordAsync(newUserName, password))
						throw new InvalidOperationException(string.Format("Unable to change password for: {0}", newUserName));

				if (!await membershipProvider.To<IMembershipWithoutOldPasswordProvider>().ChangePasswordQuestionWithoutOldPasswordAsync(newUserName, passwordQuestion))
					throw new InvalidOperationException(string.Format("Unable to change password question for: {0}", newUserName));

				var user = await membershipProvider.GetUserAsync(newUserName);
				user.As<IDisplayNameUser>().SafeDo(_ => _.UserDisplayName = displayName).ElseDo(() =>
				{
					throw new InvalidOperationException(string.Format("Unable to change display name for: {0}", newUserName));
				});
				user.Comment = comment;
				user.Email = email;
				await membershipProvider.UpdateUserAsync(user);
			}

			if (membershipProvider is IRoleMembershipProvider roleMembershipProvider)
			{
				var userRoles = await roleMembershipProvider.GetRolesForUserAsync(newUserName, false);

				if (userRoles.Length != roleNames.Length || userRoles.Intersect(roleNames).Count() != userRoles.Length)
				{
					await roleMembershipProvider.RemoveUsersFromRolesAsync(new[] { newUserName }, userRoles);
					await roleMembershipProvider.AddUsersToRolesAsync(new[] { newUserName }, roleNames);
				}
			}

			if (forcePasswordChange && membershipProvider is IPasswordChangeEnforcingProvider passwordChangeEnforcingProvider)
				await passwordChangeEnforcingProvider.ForcePasswordChangeAsync(newUserName);
		}

		public async Task DeleteUser(string userSourceName, string existingMembershipUserName)
		{
			var membershipProvider = this.GetMembershipProvider(userSourceName, null, null);
			await membershipProvider.DeleteUserAsync(existingMembershipUserName);
		}

		public async Task<string> LookupUser([ActivityTraceIgnore] string userSourceName, [ActivityTraceIgnore] string testUserName, [ActivityTraceIgnore] string[] configurationKeys, [ActivityTraceIgnore] string[] configurationValues)
		{
			var membershipProvider = this.GetMembershipProvider(userSourceName, configurationKeys, configurationValues);
			var currentRoleSet = (await Permissions.GetAllRolesAsync()).Select(_ => _.Name).ToHashSet();
			var user = await membershipProvider.GetUserAsync(testUserName);
			var resultBuilder = new StringBuilder();

			if (user == null)
			{
				resultBuilder.Append(await WebResources.GetStringAsync("SecurityPanel.UserNotFoundText"));
			}
			else
			{
				var roleTexts = await membershipProvider
					.As<IRoleMembershipProvider>()
					.SafePipeAwaitAsync(it => it.GetRolesForUserAsync(testUserName, false))
					.PipeAsync(it => it.SafeEnumerate())
					.ToAsyncEnumerable()
					.OrderBy(it => !currentRoleSet.Contains(it))
					.SelectAwait(async it => await WebResources.TryFormatStringAsync(currentRoleSet.Contains(it) ? "SecurityPanel.UserLookupResult.RoleHasMatchesFormat" : "SecurityPanel.UserLookupResult.RoleHasNoMatchesFormat", it))
					.ToArrayAsync();

				foreach (var (userPropertyLabel, values) in new[]
				{
					(await WebResources.GetStringAsync("SecurityPanel.LookupFormUserNameLabelText"), new[] { user.UserName }),
					(await WebResources.GetStringAsync("SecurityPanel.LookupFormDisplayNameLabelText"), new[] { user.As<IDisplayNameUser>()?.UserDisplayName }),
					(await WebResources.GetStringAsync("SecurityPanel.LookupFormEmailLabelText"), new[] { user.Email }),
					(await WebResources.GetStringAsync("SecurityPanel.LookupFormCommentLabelText"), new[] { user.Comment }),
					(await WebResources.GetStringAsync("SecurityPanel.LookupFormPasswordQuestionLabelText"), new[] { user.PasswordQuestion }),
					(await WebResources.GetStringAsync("SecurityPanel.LookupFormRolesLabelText"), roleTexts),
				})
				{
					resultBuilder.AppendLine(userPropertyLabel);
					foreach (var value in values)
						resultBuilder.AppendLine('\t' + value);
					resultBuilder.AppendLine();
				}
			}

			return resultBuilder.ToString();
		}

		public void SaveUserSourceConfiguration(string userSourceName, string[] configurationKeys, [ActivityTraceIgnore] string[] configurationValues)
		{
			this.ModifyUserSource(userSourceName, (provider, parameters) => this.SaveParameters(provider, parameters, configurationKeys, configurationValues));
		}

		public void SetUserSourceEnabled(string userSourceName, bool enabledOrDisabled)
		{
			this.ModifyUserSource(userSourceName, (provider, parameters) => provider.SaveEnabledStateToConfiguration(parameters, enabledOrDisabled));
		}

		public void SetUserSourceLocked(string userSourceName, bool lockedOrUnlocked)
		{
			this.ModifyUserSource(userSourceName, (provider, parameters) => provider.SaveLockedStateToConfiguration(parameters, lockedOrUnlocked));
		}

		public void RemoveUserSource([ActivityTraceIgnore] string userSourceName)
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var membershipSection = WebConfigurationManager.GetSection<MembershipSection>(configuration);
			membershipSection.Providers.Remove(userSourceName);
			ServerToolkit.Instance.SaveConfiguration(configuration);
		}

		public string AddUserSource(string typeName, string userSourceName = null, bool enabledOrDisabled = false, bool lockedOrUnlocked = false, [ActivityTraceIgnore] string[] configurationKeys = null, [ActivityTraceIgnore] string[] configurationValues = null)
		{
			userSourceName = userSourceName.IfNotEmpty() ?? Guid.NewGuid().ToString();
			var providerSettings = new ProviderSettings { Name = userSourceName, Type = typeName };
			var dummyMembershipProvider = (MembershipProviderBase)MembershipWebAuthenticationProvider.TryCreateMembershipProvider(providerSettings.Type, providerSettings.Name, providerSettings.Parameters);
			dummyMembershipProvider.SaveEnabledStateToConfiguration(providerSettings.Parameters, enabledOrDisabled);
			dummyMembershipProvider.SaveLockedStateToConfiguration(providerSettings.Parameters, lockedOrUnlocked);
			this.SaveParameters(dummyMembershipProvider, providerSettings.Parameters, configurationKeys.Coalesce(), configurationValues.Coalesce());

			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var membershipSection = configuration.GetSection<MembershipSection>();
			membershipSection.Providers.Add(providerSettings);
			ServerToolkit.Instance.SaveConfiguration(configuration);
			return userSourceName;
		}

		public void RevokeAccess(string tokenType)
		{
			string earliestValidIssueDateTimeSettingsKey;
			switch (tokenType)
			{
				case "DelegatedAccessTokens":
					earliestValidIssueDateTimeSettingsKey = ServerConstants.DelegatedAccessTokenEarliestValidIssueTimeSettingsKey;
					break;
				case "PrimaryAccessTokens":
					earliestValidIssueDateTimeSettingsKey = ServerConstants.PrimaryAccessTokenEarliestValidIssueTimeSettingsKey;
					break;
				case "AuthenticationSessions":
					earliestValidIssueDateTimeSettingsKey = ServerConstants.AuthenticationSessionEarliestValidIssueTimeSettingsKey;
					break;
				default:
					throw new InvalidOperationException("Invalid token type");
			}

			// can't just set to the current time since it won't take effect until after restart
			// and stuff could still happen between now and then, so need the new value to be after that
			// (new value is set in ServerExtensions.InitializeConfiguration)
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			configuration.AppSettings.SetValue(earliestValidIssueDateTimeSettingsKey, DateTime.MaxValue.Ticks.ToString());
			ServerToolkit.Instance.SaveConfiguration(configuration);
		}

		// TODO REMOVE_OLD_AUTH
		public void SetCloudWebAuthenticationProviderEnabled(bool enabledOrDisabled)
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			configuration.GetSection<AppSettingsSection>().SetValue("DisableCloudWebAuthenticationProvider", enabledOrDisabled ? "false" : "true");
			ServerToolkit.Instance.SaveConfiguration(configuration);
		}

		IEnumerable<Role> AssertAnyRoleHasAdministerPermission(IEnumerable<Role> roles)
		{
			if (roles.None(it => it.PermissionEntries.Any(_ => _.Name == PermissionInfo.AdministerPermission)))
				throw new InvalidOperationException("Must have at least one role with Administer permission!");

			return roles;
		}

		void ModifyUserSource(string userSourceName, Proc<MembershipProviderBase, NameValueCollection> modifyProc)
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var providerSettings = this.GetProviderSettings(configuration, userSourceName);
			var dummyMembershipProvider = (MembershipProviderBase)MembershipWebAuthenticationProvider.TryCreateMembershipProvider(providerSettings.Type, providerSettings.Name, providerSettings.Parameters);
			modifyProc(dummyMembershipProvider, providerSettings.Parameters);
			ServerToolkit.Instance.SaveConfiguration(configuration);
		}

		ProviderSettings GetProviderSettings(Configuration configuration, string userSourceName)
		{
			return WebConfigurationManager
				.GetSection<MembershipSection>(configuration)
				.Providers
				.OfType<ProviderSettings>()
				.Where(_ => _.Name == userSourceName)
				.First();
		}

		MembershipProviderBase GetMembershipProvider(string userSourceName, string[] overrideKeys, string[] overrideValues)
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var providerSettings = this.GetProviderSettings(configuration, userSourceName);
			var dummyMembershipProvider = (MembershipProviderBase)MembershipWebAuthenticationProvider.TryCreateMembershipProvider(providerSettings.Type, providerSettings.Name, providerSettings.Parameters);
			var newParameters = new NameValueCollection(providerSettings.Parameters);
			this.SaveParameters(dummyMembershipProvider, newParameters, overrideKeys, overrideValues);
			return (MembershipProviderBase)MembershipWebAuthenticationProvider.TryCreateMembershipProvider(providerSettings.Type, providerSettings.Name, newParameters);
		}

		void SaveParameters(MembershipProviderBase membershipProvider, NameValueCollection providerSettingsParameters, string[] keys, string[] values)
		{
			if (keys != null && values != null)
				for (var i = 0; i < keys.Length; i++)
					membershipProvider.SaveSettingToConfiguration(providerSettingsParameters, keys[i], values[i]);
		}
	}
}
