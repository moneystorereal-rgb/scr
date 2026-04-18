<%@ WebHandler Language="C#" Class="ScreenConnect.PageService" %>

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;

namespace ScreenConnect;

[ActivityTrace]
[InternalApi]
public class PageService : WebServiceBase
{
	public async Task<object> GetLiveData(IDictionary<string, object> requestInfoMap, long version, IPrincipal user, CancellationToken cancellationToken)
	{
		var newVersion = await WaitForChangeManager.WaitForChangeAsync(version, cancellationToken);
		var permissions = await Permissions.GetForUserAsync(user);

		async Task<object> ProcessLiveDataRequestAsync(string name, object request)
		{
			var handlerType = typeof(LiveData).GetNestedType(name, BindingFlags.NonPublic).AssertNonNull("Live data type not found");
			var typedRequest = (LiveData.ILiveDataHandler)JsonSerializer.Instance.AsType(request, handlerType);
			return await typedRequest.ProcessRequestAsync(version, user, permissions, cancellationToken);
		}

		return new
		{
			Version = newVersion,
			Constants.ProductVersion,
			ResponseInfoMap = await requestInfoMap
				.ToAsyncEnumerable()
				.SelectAwait(async it => Extensions.CreateKeyValuePair(it.Key, await ProcessLiveDataRequestAsync(it.Key, it.Value)))
				.ToDictionaryAsync(),
		};
	}

	[UsedImplicitly(ImplicitUseTargetFlags.Members)]
	static class LiveData
	{
		public interface ILiveDataHandler
		{
			Task<object> ProcessRequestAsync(long version, IPrincipal user, PermissionSet permissions, CancellationToken cancellationToken);
		}

		record HostSessionInfo(SessionType SessionType, string[] SessionGroupPathParts, [CanBeNull] string Filter, Guid? FindSessionID, int SessionLimit) : ILiveDataHandler
		{
			public async Task<object> ProcessRequestAsync(long version, IPrincipal user, PermissionSet permissions, CancellationToken cancellationToken)
			{
				var userDisplayName = user.GetUserDisplayNameWithFallback();
				var variables = await ServerExtensions.GetStandardVariablesAsync(user);

				Permissions.AssertAnyPermission(permissions);

				await SessionManagerPool.Demux.EnsureEligibleHostAsync(userDisplayName);

				var viewableSessionGroupPathFilter = Permissions.ComputeSessionGroupPathFilterForPermissions(permissions, PermissionInfo.ViewSessionGroupPermission);

				async IAsyncEnumerable<(IList<SessionGroupSummary> SessionGroupSummaries, SessionGroupSummary SelectedSessionGroupSummary)> GetPathSummariesWithSelectedGroups(string[] sessionGroupPathParts)
				{
					var sessionGroupPathPartsQueue = new Queue<string>(sessionGroupPathParts);
					var currentSessionGroupSummaries = await SessionManagerPool.Demux.GetRootSessionGroupSummariesAsync(this.SessionType, viewableSessionGroupPathFilter, variables);
					var currentPath = new List<string>();

					while (true)
					{
						var currentSessionGroupName = sessionGroupPathPartsQueue.TryDequeue();
						var selectedSessionGroup = currentSessionGroupSummaries.FirstOrDefault(it => it.Name == currentSessionGroupName);

						if (selectedSessionGroup == null)
						{
							sessionGroupPathPartsQueue.Clear();

							if (currentPath.Count == 0)
								selectedSessionGroup = currentSessionGroupSummaries.FirstOrDefault();
						}

						yield return (currentSessionGroupSummaries, selectedSessionGroup);

						if (selectedSessionGroup == null || !selectedSessionGroup.HasSubgroupExpression)
							break;

						currentPath.Add(selectedSessionGroup.Name);

						currentSessionGroupSummaries = await SessionManagerPool.Demux.GetSessionGroupSummariesAsync(
							SessionGroupPath.FromParts(currentPath.ToArray()),
							viewableSessionGroupPathFilter,
							variables
						);
					}
				}

				var sessionGroupPathPartsToTry = await this.FindSessionID
					.SafePipeAwaitAsync(async sessionID => await SessionManagerPool.Demux.FindFirstSessionGroupWithSessionAsync(
						Enumerable.Range(0, this.SessionGroupPathParts.Length)
							.Select(index => SessionGroupPath.FromParts(this.SessionGroupPathParts).WithFirstParts(this.SessionGroupPathParts.Length - index))
							.Concat(await SessionManagerPool.Demux.GetRootSessionGroupSummariesAsync(this.SessionType, viewableSessionGroupPathFilter, variables).ToAsyncEnumerable().Select(it => SessionGroupPath.FromPart(it.Name)).ToListAsync())
							.ToArray(),
						variables,
						sessionID
					))
					.PipeAsync(it => it.Parts.Any() ? it.Parts : this.SessionGroupPathParts);

				var pathSummariesWithSelectedGroups = await GetPathSummariesWithSelectedGroups(sessionGroupPathPartsToTry).ToListAsync();

				var newSessionGroupPath = pathSummariesWithSelectedGroups
					.Select(it => it.SelectedSessionGroupSummary)
					.TakeUntil(it => it == null)
					.Select(it => it.Name)
					.ToArray()
					.Pipe(SessionGroupPath.FromParts);

				var sessionGroupPathChanged = !this.SessionGroupPathParts.ListEquals(newSessionGroupPath.Parts, StringComparer.Ordinal);
				var sessionGroupSummary = pathSummariesWithSelectedGroups.Select(it => it.SelectedSessionGroupSummary).LastOrDefault(it => it != null);
				var utcNow = DateTime.UtcNow;

				var sessionsWithPermissions = default(IEnumerable<(Session Session, SessionPermissions Permissions)>);
				var untruncatedSessionCount = default(int);

				if (newSessionGroupPath.Parts.Any() && sessionGroupSummary != null && (sessionGroupPathChanged || sessionGroupSummary.LastSetAlteredVersion > version || sessionGroupSummary.LastSessionAlteredVersion > version))
				{
					var sessions = default(IList<Session>);
					var sessionFirstBucketIndices = default(IList<int>);
					var moreSpecificPermissionEntries = Permissions.GetMoreSpecificPermissionEntries(permissions, newSessionGroupPath);
					var orderedBucketPaths = moreSpecificPermissionEntries.Select(it => it.SessionGroupPathParts).OrderByDescending(it => it.Length).Select(SessionGroupPath.FromParts).ToList();

					(sessions, sessionFirstBucketIndices, untruncatedSessionCount) = await SessionManagerPool.Demux.GetSessionsAsync(
						newSessionGroupPath,
						viewableSessionGroupPathFilter,
						variables,
						this.Filter,
						this.SessionLimit,
						this.FindSessionID,
						!sessionGroupPathChanged && sessionGroupSummary.LastSetAlteredVersion <= version ? version : default(long?),
						orderedBucketPaths
					);

					var permissionsForAllSessions = PermissionInfo.GetSessionPermissions(permissions, this.SessionType, newSessionGroupPath);
					var permissionsForBucketPaths = orderedBucketPaths.Select(it => PermissionInfo.GetSessionPermissions(permissions, this.SessionType, it)).ToList();

					sessionsWithPermissions = sessionFirstBucketIndices != null
						? sessions.SafeEnumerate().Zip(sessionFirstBucketIndices).Select(it => (it.Item1, it.Item2 == -1 ? permissionsForAllSessions : permissionsForBucketPaths[it.Item2]))
						: sessions.SafeEnumerate().Select(it => (it, permissionsForAllSessions));
				}

				return new
				{
					SessionGroupPath = newSessionGroupPath.Parts,
					PathSessionGroupSummaries = pathSummariesWithSelectedGroups.Select(it => it.SessionGroupSummaries).ToList(),
					Filter = this.Filter,
					UntruncatedSessionCount = untruncatedSessionCount,
					Sessions = sessionsWithPermissions.SafeEnumerate().Select(it => new
					{
						it.Session.SessionID,
						it.Session.SessionType,
						it.Session.Name,
						it.Session.Host,
						it.Session.IsPublic,
						it.Session.Code,
						it.Session.CustomPropertyValues,
						it.Session.LastAlteredVersion,
						GuestLoggedOnUserName = it.Session.GuestInfo.LoggedOnUserName,
						GuestLoggedOnUserDomain = it.Session.GuestInfo.LoggedOnUserDomain,
						GuestOperatingSystemName = it.Session.GuestInfo.OperatingSystemName,
						GuestOperatingSystemVersion = it.Session.GuestInfo.OperatingSystemVersion,
						it.Session.GuestClientVersion,
						it.Session.AddedNoteEvents,
						it.Session.Attributes,
						it.Session.UnacknowledgedEvents,
						it.Permissions,
						QueuedEvents = it.Session.QueuedEvents.Select(_ => new
						{
							_.EventType,
							_.EventID,
							_.ConnectionID,
							Time = WebExtensions.GetClientScriptDurationSeconds(_.Time, utcNow),
						}),
						ActiveConnections = it.Session.ActiveConnections.Select(ac => new
						{
							ac.ConnectionID,
							ac.ProcessType,
							ac.ParticipantName,
							ConnectedTime = WebExtensions.GetClientScriptDurationSeconds(ac.ConnectedTime, utcNow),
						}),
						it.Session.LogonSessions,
						it.Session.LastInitiatedJoinEventHost,
						GuestIdleTime = WebExtensions.GetClientScriptDurationSeconds(it.Session.GuestInfo.LastActivityTime, utcNow),
						LastInitiatedJoinEventTime = WebExtensions.GetClientScriptDurationSeconds(it.Session.LastInitiatedJoinEventTime, utcNow),
						LastConnectedEventTime = WebExtensions.GetClientScriptDurationSeconds(it.Session.LastConnectedEventTime, utcNow),
						LastGuestDisconnectedEventTime = WebExtensions.GetClientScriptDurationSeconds(it.Session.LastGuestDisconnectedEventTime, utcNow),
					}),
					// TODO could be internalized into session manager
					AlternateSessionGroupSummaries = string.IsNullOrEmpty(this.Filter) || untruncatedSessionCount != 0
						? null
						: await SessionManagerPool.Demux.GetSessionGroupsAsync(viewableSessionGroupPathFilter)
							.ToAsyncEnumerable()
							.Where(_ => string.IsNullOrEmpty(_.SessionFilter))
							.GroupBy(_ => _.SessionType)
							.SelectMany(_ => _.SafeEnumerate())
							.WhereNotNull()
							.SelectAwait(async _ => new
							{
								_.Name,
								_.SessionType,
								SessionCount = await SessionManagerPool.Demux.GetSessionCountAsync(new[] { _.Name }, viewableSessionGroupPathFilter, variables, this.Filter),
							})
							.Where(_ => _.SessionCount != 0)
							.ToListAsync(),
				};
			}
		}

		record GuestSessionInfo(string[] SessionCodes, Guid[] SessionIDs) : ILiveDataHandler
		{
			public async Task<object> ProcessRequestAsync(long version, IPrincipal user, PermissionSet permissions, CancellationToken cancellationToken)
			{
				foreach (var sessionCode in this.SessionCodes.SafeEnumerate())
					RateLimitManager.Instance.RecordDataOperationAndCheckAllowed((nameof(GuestSessionInfo), "SessionCodeLookup"), sessionCode);

				return new
				{
					DoNonPublicCodeSessionsExist = await SessionManagerPool.Demux.DoNonPublicCodeSessionsExistAsync(),
					Sessions = (await SessionManagerPool.Demux.GetPublicSessionsAsync())
						.Concat(await this.SessionCodes.SafeEnumerate().Select(_ => SessionManagerPool.Demux.GetSessionAsync(_)).ToArrayAsync())
						.Concat(await this.SessionIDs.SafeEnumerate().Select(_ => SessionManagerPool.Demux.GetSessionAsync(_)).ToArrayAsync())
						.WhereNotNull()
						.Select(_ => new
						{
							_.SessionID,
							_.SessionType,
							_.Host,
							_.Name,
							_.Code,
							_.IsPublic,
							ActiveConnections = _.ActiveConnections.Select(ac => new
							{
								ac.ProcessType,
								ac.ParticipantName,
							}),
						}),
				};
			}
		}

		record ActionCenterInfo : ILiveDataHandler
		{
			public async Task<object> ProcessRequestAsync(long version, IPrincipal user, PermissionSet permissions, CancellationToken cancellationToken)
			{
				var viewableSessionGroupPathFilter = Permissions.ComputeSessionGroupPathFilterForPermissions(permissions, PermissionInfo.ViewSessionGroupPermission);
				var variables = await ServerExtensions.GetStandardVariablesAsync(user);

				return new
				{
					ActionItems = await SessionManagerPool.Demux.GetSessionsAsync("UnacknowledgedEventCount > 0 OR PendingRequestEventCount > 0", viewableSessionGroupPathFilter, variables)
						.ToAsyncEnumerable()
						.SelectMany(it =>
							it.PendingRequestEvents
								.Concat(it.UnacknowledgedEvents)
								.Distinct(KeyComparer.CreateEqualityComparer<SessionEvent, Guid>(@event => @event.EventID))
								.Select(@event => (Session: it, Event: @event)).ToAsyncEnumerable()
						)
						.Take(50) // would be more efficient to put inside GetSessionsAsync as a sessionLimit parameter, but that would require new signature/etc
						.OrderByDescending(it => it.Event.Time)
						.Select(it => new
						{
							it.Session.SessionID,
							it.Session.SessionType,
							it.Session.Name,
							it.Event.EventID,
							it.Event.EventType,
							it.Event.Time,
							it.Event.Data,
						})
						.ToListAsync(),
				};
			}
		}
	}

	public async Task<object> GetSessionDetails(object sessionGroupPathPartsOrName, Guid sessionID, IPrincipal user)
	{
		var sessionGroupPath = SessionGroupPath.FromParts(sessionGroupPathPartsOrName.EnsureStringArray());
		var permissions = await Permissions.GetForUserAsync(user);
		var variables = await ServerExtensions.GetStandardVariablesAsync(user);

		if (
			!await SessionManagerPool.Demux.IsSessionInGroupAsync(
				sessionID,
				sessionGroupPath,
				Permissions.ComputeSessionGroupPathFilterForPermissions(permissions, PermissionInfo.ViewSessionGroupPermission),
				variables
			)
		)
			return null;

		var sessionDetails = await SessionManagerPool.Demux.GetSessionDetailsAsync(sessionID);

		if (sessionDetails?.Session == null)
			return null;

		var canViewGuestScreenshot = await SessionManagerPool.Demux.IsSessionInGroupAsync(
			sessionID,
			sessionGroupPath,
			Permissions.ComputeSessionGroupPathFilterForPermissions(permissions, PermissionInfo.ViewSessionGuestScreenshotPermission),
			variables
		);
		var utcNow = DateTime.UtcNow;

		return new
		{
			Session = new
			{
				GuestNetworkAddress = sessionDetails.Session.GuestNetworkAddress.ToShortString(),
				GuestMachineName = sessionDetails.Session.GuestInfo.MachineName,
				GuestMachineDomain = sessionDetails.Session.GuestInfo.MachineDomain,
				GuestProcessorName = sessionDetails.Session.GuestInfo.ProcessorName,
				GuestProcessorVirtualCount = sessionDetails.Session.GuestInfo.ProcessorVirtualCount,
				GuestSystemMemoryTotalMegabytes = sessionDetails.Session.GuestInfo.SystemMemoryTotalMegabytes,
				GuestSystemMemoryAvailableMegabytes = sessionDetails.Session.GuestInfo.SystemMemoryAvailableMegabytes,
				GuestScreenshotContentType = sessionDetails.Session.GuestInfo.ScreenshotContentType.If(_ => canViewGuestScreenshot),
				GuestInfoUpdateTime = WebExtensions.GetClientScriptDurationSeconds(sessionDetails.Session.GuestInfoUpdateTime, utcNow),
				GuestOperatingSystemManufacturerName = sessionDetails.Session.GuestInfo.OperatingSystemManufacturerName,
				GuestOperatingSystemLanguage = sessionDetails.Session.GuestInfo.OperatingSystemLanguage,
				GuestOperatingSystemInstallationTime = WebExtensions.GetClientScriptDurationSeconds(sessionDetails.Session.GuestInfo.OperatingSystemInstallationTime, utcNow),
				GuestMachineManufacturerName = sessionDetails.Session.GuestInfo.MachineManufacturerName,
				GuestMachineModel = sessionDetails.Session.GuestInfo.MachineModel,
				GuestMachineProductNumber = sessionDetails.Session.GuestInfo.MachineProductNumber,
				GuestMachineSerialNumber = sessionDetails.Session.GuestInfo.MachineSerialNumber,
				GuestMachineDescription = sessionDetails.Session.GuestInfo.MachineDescription,
				GuestProcessorArchitecture = sessionDetails.Session.GuestInfo.ProcessorArchitecture.ToStringCached(),
				GuestPrivateNetworkAddress = sessionDetails.Session.GuestInfo.PrivateNetworkAddress.ToShortString(),
				GuestHardwareNetworkAddress = sessionDetails.Session.GuestInfo.HardwareNetworkAddress.SafeToString(),
				GuestTimeZoneName = sessionDetails.Session.GuestInfo.TimeZoneName,
				GuestTimeZoneOffsetHours = sessionDetails.Session.GuestInfo.TimeZoneOffsetHours,
				GuestLastBootTime = WebExtensions.GetClientScriptDurationSeconds(sessionDetails.Session.GuestInfo.LastBootTime, utcNow),
				GuestAttributes = sessionDetails.Session.GuestInfo.Attributes.ToStringCached(),
				GuestIsLocalAdminPresent = sessionDetails.Session.GuestInfo.IsLocalAdminPresent,
			},
			GuestScreenshotContent = sessionDetails.GuestScreenshotContent.If(_ => canViewGuestScreenshot).SafeNav(sc => Convert.ToBase64String(sc)),
			Connections = sessionDetails.Connections.Select(it => new
			{
				it.ConnectionID,
				it.ProcessType,
				it.ClientType,
				it.ClientVersion,
				NetworkAddress = it.NetworkAddress.SafeToString(),
				it.ParticipantName,
			}),
			Events = sessionDetails.Events.Select(se => new
			{
				se.EventID,
				se.EventType,
				Time = WebExtensions.GetClientScriptDurationMilliseconds(se.Time, utcNow),
				se.Host,
				se.Data,
				// javascript shouldn't have to understand default(Guid)=0000000-000-000-00000, but this isn't pretty either.  I had the properties as Guid? but that wasn't great either
				ConnectionID = se.ConnectionID == default ? default(object) : se.ConnectionID,
				CorrelationEventID = se.CorrelationEventID == default ? default(object) : se.CorrelationEventID,
			}),
			BaseTime = WebExtensions.GetClientScriptTime(utcNow),
		};
	}

	[ActivityTraceIgnore]
	public async Task LogInitiatedJoin(Guid sessionID, ProcessType processType, string data, IPrincipal user) =>
		await SessionManagerPool.Demux.AddSessionEventAsync(
			sessionID,
			new SessionEvent
			{
				EventType = SessionEventType.InitiatedJoin,
				Host = processType == ProcessType.Guest ? string.Empty : user.GetUserDisplayNameWithFallback(),
				Data = data,
			}
		);

	public Task<object> GetAccessToken(object sessionGroupPathPartsOrName, Guid sessionID, IPrincipal user, WebServiceRequest request) =>
		this.GetAccessTokenAsync(user, request, sessionGroupPathPartsOrName, sessionID, AccessTokenType.Primary);

	public Task<object> GetDelegatedAccessToken(object sessionGroupPathPartsOrName, Guid sessionID, SessionPermissions sessionPermissions, int expireSeconds, string memo, IPrincipal user, WebServiceRequest request) =>
		this.GetAccessTokenAsync(
			user,
			request,
			sessionGroupPathPartsOrName,
			sessionID,
			AccessTokenType.Delegated,
			sessionPermissions.EnsureFlags(PermissionInfo.GetUndelegatableSessionPermissions(), false),
			expireSeconds,
			async name => string.IsNullOrEmpty(memo)
				? await WebResources.TryFormatStringAsync("DelegatedAccessTokenUserDisplayNameFormat", name)
				: await WebResources.TryFormatStringAsync("DelegatedAccessTokenUserDisplayNameWithMemoFormat", name, memo)
		);

	async Task<object> GetAccessTokenAsync(
		IPrincipal user,
		WebServiceRequest request,
		object sessionGroupPathPartsOrName,
		Guid sessionID,
		AccessTokenType accessTokenType,
		SessionPermissions sessionPermissions = SessionPermissions.All,
		int expireSeconds = int.MaxValue,
		Func<string, Task<string>> participantNameFormatter = null
	)
	{
		var userDisplayName = user.GetUserDisplayNameWithFallback();
		var variables = await ServerExtensions.GetStandardVariablesAsync(user);
		var permissions = await Permissions.GetForUserAsync(user);

		await this.DemandPermissionsAsync(
			user,
			sessionGroupPathPartsOrName,
			new[] { sessionID },
			accessTokenType == AccessTokenType.Delegated ? PermissionInfo.CreateDelegatedAccessTokenPermission : PermissionInfo.JoinSessionPermission,
			permissions
		);

		var session = await SessionManagerPool.Demux.DemandSessionAsync(sessionID);

		var possibleSessionPermissions = (await SessionManagerPool.Demux.GetMostSpecificSessionGroupsContainingSessionAsync(sessionID, variables))
			.Select(it => PermissionInfo.GetSessionPermissions(permissions, session.SessionType, it))
			.Union();

		return await ServerCryptoManager.Instance.GetAccessTokenStringAsync(
			sessionID,
			ProcessType.Host,
			accessTokenType,
			participantNameFormatter != null ? await participantNameFormatter(userDisplayName) : userDisplayName,
			PermissionInfo.IntersectSessionPermissions(possibleSessionPermissions, sessionPermissions),
			TimeSpan.FromSeconds(expireSeconds),
			ClientDeviceFingerprint.Create(NetworkExtensions.TryParseIPAddress(request.UserHostAddress)),
			user.As<IWebPrincipal>()?.AuthenticationSessionID
		);
	}

	public Task TransferSessions(object sessionGroupPathPartsOrName, Guid[] sessionIDs, string toHost, IPrincipal user) =>
		this.ExecuteSessionProcAsync(user, sessionGroupPathPartsOrName, sessionIDs, PermissionInfo.TransferSessionPermission, (session, _, userDisplayName) =>
			SessionManagerPool.Demux.UpdateSessionAsync(userDisplayName, session.SessionID, toHost)
		);

	public record SessionEventEntry(Guid SessionID, SessionEventType EventType, string Data, Guid? CorrelationEventID, Guid? ConnectionID);

	public async Task AddSessionEvents(object sessionGroupPathPartsOrName, SessionEventEntry[] eventEntries, IPrincipal user)
	{
		foreach (var entry in eventEntries)
			if (string.IsNullOrEmpty(entry.Data) && Session.ShouldEventTypeHaveData(entry.EventType))
				throw new InvalidOperationException("Data required for event type: " + entry.EventType);

		var permissionNameToEventEntriesMap = await eventEntries.ToAsyncEnumerable()
			.GroupByAwait(async entry => await PermissionInfo.GetAddEventPermissionNameAsync(entry.EventType, ServerExtensions.CreateAsyncLazy(() =>
				SessionManagerPool.Demux.GetSessionEventAsync(entry.SessionID, entry.CorrelationEventID.GetValueOrDefault()).SafePipeAsync(it => it.EventType)
			)))
			.ToDictionaryAsync();

		// validate all required permissions first to keep this somewhat atomic
		foreach (var (permissionName, entries) in permissionNameToEventEntriesMap)
			await this.DemandPermissionsAsync(
				user,
				sessionGroupPathPartsOrName,
				entries.SelectToArray(it => it.SessionID),
				permissionName,
				await Permissions.GetForUserAsync(user)
			);

		var userDisplayName = user.GetUserDisplayNameWithFallback();

		foreach (var eventEntry in permissionNameToEventEntriesMap.SelectMany(it => it.Value))
			await SessionManagerPool.Demux.AddSessionEventAsync(
				eventEntry.SessionID,
				new SessionEvent
				{
					EventType = eventEntry.EventType,
					Host = userDisplayName,
					Data = eventEntry.Data,
					CorrelationEventID = eventEntry.CorrelationEventID.GetValueOrDefault(),
					ConnectionID = eventEntry.ConnectionID.GetValueOrDefault(),
				}
			);
	}

	[ActivityTraceIgnore]
	public async Task<object> CreateSession(SessionType sessionType, string name, bool isPublic, string code, string[] customPropertyValues, IPrincipal user)
	{
		var permissionName = PermissionInfo.GetPermissionForCreatingSessionType(sessionType);
		await Permissions.AssertPermissionAsync(new PermissionRequest(permissionName), user);

		var userDisplayName = user.GetUserDisplayNameWithFallback();
		return (await SessionManagerPool.Demux.CreateSessionAsync(userDisplayName, sessionType, name, userDisplayName, isPublic, code, customPropertyValues)).SessionID;
	}

	[ActivityTraceIgnore]
	public Task UpdateSessions(object sessionGroupPathPartsOrName, Guid[] sessionIDs, string[] names, string[][] customPropertyValues, IPrincipal user) =>
		this.ExecuteSessionProcAsync(user, sessionGroupPathPartsOrName, sessionIDs, PermissionInfo.EditSessionPermission, (session, index, userDisplayName) =>
			SessionManagerPool.Demux.UpdateSessionAsync(userDisplayName, session.SessionID, names[index], session.IsPublic, session.Code, customPropertyValues[index])
		);

	[ActivityTraceIgnore]
	public Task UpdateSessionCode(object sessionGroupPathPartsOrName, Guid sessionID, string code, IPrincipal user) =>
		this.ExecuteSessionProcAsync(user, sessionGroupPathPartsOrName, new[] { sessionID }, PermissionInfo.EditSessionPermission, (session, _, userDisplayName) =>
			SessionManagerPool.Demux.UpdateSessionAsync(userDisplayName, session.SessionID, session.Name, session.IsPublic, code, session.CustomPropertyValues)
		);

	[ActivityTraceIgnore]
	public Task UpdateSessionName(object sessionGroupPathPartsOrName, Guid sessionID, string name, IPrincipal user) =>
		this.ExecuteSessionProcAsync(user, sessionGroupPathPartsOrName, new[] { sessionID }, PermissionInfo.EditSessionPermission, (session, _, userDisplayName) =>
			SessionManagerPool.Demux.UpdateSessionAsync(userDisplayName, session.SessionID, name, session.IsPublic, session.Code, session.CustomPropertyValues)
		);

	[ActivityTraceIgnore]
	public Task UpdateSessionCustomPropertyValue(object sessionGroupPathPartsOrName, Guid sessionID, int customPropertyIndex, string customPropertyValue, IPrincipal user) =>
		this.ExecuteSessionProcAsync(user, sessionGroupPathPartsOrName, new[] { sessionID }, PermissionInfo.EditSessionPermission, (session, _, userDisplayName) =>
			SessionManagerPool.Demux.UpdateSessionAsync(
				userDisplayName,
				session.SessionID,
				session.Name,
				session.IsPublic,
				session.Code,
				session.CustomPropertyValues.Select((existingValue, index) => index == customPropertyIndex ? customPropertyValue : existingValue).ToArray()
			)
		);

	[ActivityTraceIgnore]
	public Task UpdateSessionIsPublicAndCode(object sessionGroupPathPartsOrName, Guid sessionID, bool isPublic, string code, IPrincipal user) =>
		this.ExecuteSessionProcAsync(user, sessionGroupPathPartsOrName, new[] { sessionID }, PermissionInfo.EditSessionPermission, (session, _, userDisplayName) =>
			SessionManagerPool.Demux.UpdateSessionAsync(userDisplayName, session.SessionID, session.Name, isPublic, code, session.CustomPropertyValues)
		);

	public async Task<object> GetDistinctCustomPropertyValues(int[] customPropertyIndices, SessionType sessionType, IPrincipal user) =>
		await SessionManagerPool.Demux.GetDistinctCustomPropertyValuesAsync(
			customPropertyIndices,
			Permissions.ComputeSessionGroupPathFilterForPermissions(await Permissions.GetForUserAsync(user), PermissionInfo.ViewSessionGroupPermission).ForSessionType(sessionType),
			await ServerExtensions.GetStandardVariablesAsync(user)
		).PipeAsync(it => customPropertyIndices.Select(index => it[index].Sort().ToArray()).ToArray());

	[DemandAnyPermission]
	public async Task<object> GetEligibleHosts() =>
		await SessionManagerPool.Demux.GetEligibleHostsAsync();

	public async Task NotifyActivity() =>
		await WebAuthentication.TryRenewLoginContextAsync(WebContext.CurrentHttpContext);

	[DemandAnyPermission]
	public async Task<object> GetToolbox() =>
		await ServerToolboxExtensions.GetToolboxAsync();

	[ActivityTraceIgnore]
	public void SendFeedback(string rating, string comments, string email) =>
		Extensions.SendFeedback(
			rating,
			comments,
			new (string key, string value)[]
				{
					("Host", WebContext.CurrentHttpContext?.Request.GetRealUrl(false, false).Host),
					("ServerVersion", Constants.ProductVersion.ToString()),
				}
				.Select(it => $"{it.key}: {it.value}")
				.Join(", "),
			email
		);

	async Task DemandPermissionsAsync(IPrincipal user, object sessionGroupPathPartsOrName, IList<Guid> sessionIDs, string permissionName, PermissionSet permissions)
	{
		var sessionGroupPath = SessionGroupPath.FromParts(sessionGroupPathPartsOrName.EnsureStringArray());
		var variables = await ServerExtensions.GetStandardVariablesAsync(user);

		var areSessionsInGroup = await SessionManagerPool.Demux.AreSessionsInGroupAsync(
			sessionIDs,
			sessionGroupPath,
			Permissions.ComputeSessionGroupPathFilterForPermissions(permissions, permissionName),
			variables
		);

		if (!areSessionsInGroup)
			throw new InvalidOperationException("Session not in specified group, or you do not have permission to perform this operation on it");
	}

	async Task ExecuteSessionProcAsync(IPrincipal user, object sessionGroupPathPartsOrName, Guid[] sessionIDs, string permissionName, Func<Session, int, string, Task> proc)
	{
		var permissions = await Permissions.GetForUserAsync(user);
		var userDisplayName = user.GetUserDisplayNameWithFallback();

		await this.DemandPermissionsAsync(user, sessionGroupPathPartsOrName, sessionIDs, permissionName, permissions);

		var index = 0;
		foreach (var session in await SessionManagerPool.Demux.GetSessionsAsync(sessionIDs))
			await proc(session, index++, userDisplayName);
	}
}

