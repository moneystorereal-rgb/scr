<%@ WebHandler Language="C#" Class="ScreenConnect.AuditService" %>

using System;
using System.Linq;
using System.Threading.Tasks;

#nullable enable

namespace ScreenConnect;

[DemandPermission(PermissionInfo.AdministerPermission)]
[ActivityTrace]
public class AuditService : WebServiceBase
{
	public async Task<object> QueryAuditLog(DateTime minTime, DateTime maxTime, [ActivityTraceIgnore] string sessionName, SessionEventType[] sessionEventTypes, SecurityEventType[] securityEventTypes) =>
		await Enumerable.Empty<ITimeStamp>().ToAsyncEnumerable()
			.Concat(SessionManagerPool.Demux.GetSessionAuditEntriesAsync(minTime, maxTime, sessionName, sessionEventTypes).ToAsyncEnumerable())
			.Concat(SecurityManagerPool.Demux.GetAuditEntriesAsync(minTime, maxTime, securityEventTypes).ToAsyncEnumerable())
			.OrderByDescending(it => it.Time)
			.SelectAwait(async auditEntry => auditEntry switch
			{
				SessionAuditEntry it => new
				{
					it.Time,
					it.SessionName,
					EventType = it.Event.EventType.ToStringCached(),
					it.Event.Host,
					it.Event.Data,
					it.ProcessType,
					it.ParticipantName,
					it.NetworkAddress,

					// a bit of a HACK and should really be part of some kind of extensibility of the display, so we can hold off until then to figure out
					DownloadUrl = it.Event.EventType == SessionEventType.EndedCapture
						? CaptureTranscoderHandler.GetUrl(
							it.SessionID,
							it.Event.CorrelationEventID,
							Extensions.MakeValidFileName(await WebResources.TryFormatStringAsync(
								"AuditPanel.AuditEntryDownloadFileNameFormat",
								it.SessionName,
								it.Time.ToLocalTime()
							))
						)
						: null,
				},
				SecurityAuditEntry it => new
				{
					it.Time,
					SessionName = await WebResources.GetStringAsync("AuditPanel.AuditEntrySessionNamePlaceholderText"),
					EventType = it.Event.EventType.ToStringCached(),
					it.Event.UserName,
					it.Event.OperationResult,
					it.Event.NetworkAddress,
					it.Event.UserAgent,
					it.Event.UserSource,
					it.Event.UrlReferrer,
				},
				_ => default(object?),
			})
			.ToArrayAsync();

	public async Task<object> GetAuditInfo() => new
	{
		AuditLevel = ServerExtensions.GetConfigurationEnum<AuditLevel>(ServerConstants.AuditLevelSettingsKey),
		HasExtendedAuditingCapability = await LicensingInfo.HasCapabilitiesAsync(BasicLicenseCapabilities.ExtendedAuditing),
	};

	public void ApplyAuditLevel(AuditLevel auditLevel)
	{
		var configuration = WebConfigurationManager.OpenWebConfiguration();
		configuration.AppSettings.SetValue(ServerConstants.AuditLevelSettingsKey, auditLevel.ToString());
		ServerToolkit.Instance.SaveConfiguration(configuration);
	}
}
