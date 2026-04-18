<%@ WebHandler Language="C#" Class="ScreenConnect.TriggerService" %>

using System;
using System.Linq;
using System.Threading.Tasks;

namespace ScreenConnect;

[DemandPermission(PermissionInfo.AdministerPermission)]
[DemandLicense(BasicLicenseCapabilities.AdministerAutomations)]
[ActivityTrace]
public class TriggerService : WebServiceBase
{
	#region Backward Compatibility

	[Obsolete($"Use {nameof(GetEventTriggers)}")]
	public async Task<object> GetSessionEventTriggers() =>
		await SessionManagerPool.Demux.GetSessionEventTriggersAsync();

	[Obsolete($"Use {nameof(SaveSessionEventTrigger)}")]
	public Task SaveTrigger(string originalTriggerName, string newTriggerName, bool isDisabled, string eventFilter, SmtpTriggerAction[] smtpTriggerActions, HttpTriggerAction[] httpTriggerActions, SessionEventTriggerAction[] sessionEventTriggerActions) =>
		this.SaveSessionEventTrigger(originalTriggerName, newTriggerName, DateTime.UtcNow, isDisabled, eventFilter, smtpTriggerActions, httpTriggerActions, sessionEventTriggerActions);

	[Obsolete($"Use {nameof(DeleteSessionEventTrigger)}")]
	public Task DeleteTrigger(string triggerName) =>
		this.DeleteSessionEventTrigger(triggerName);

	[Obsolete($"Use {nameof(ToggleSessionEventTriggerEnabled)}")]
	public Task ToggleEnabled(string triggerName) =>
		this.ToggleSessionEventTriggerEnabled(triggerName);

	#endregion

	public async Task<object> GetEventTriggers() =>
		new
		{
			SessionEventTriggers = await SessionManagerPool.Demux.GetSessionEventTriggersAsync(),
			SecurityEventTriggers = await SecurityManagerPool.Demux.GetSecurityEventTriggersAsync(),
		};

	public async Task SaveSessionEventTrigger(
		string originalTriggerName,
		string newTriggerName,
		DateTime? creationDate,
		bool isDisabled,
		string eventFilter,
		SmtpTriggerAction[] smtpTriggerActions,
		HttpTriggerAction[] httpTriggerActions,
		SessionEventTriggerAction[] sessionEventTriggerActions
	) =>
		await SessionManagerPool.Demux.SaveSessionEventTriggersAsync(
			this.GetUpdatedTriggers(
				await SessionManagerPool.Demux.GetSessionEventTriggersAsync(),
				originalTriggerName,
				newTriggerName,
				creationDate,
				isDisabled,
				eventFilter,
				Array.Empty<TriggerAction>().Concat(smtpTriggerActions).Concat(httpTriggerActions).Concat(sessionEventTriggerActions).ToArray()
			)
		);

	public async Task SaveSecurityEventTrigger(
		string originalTriggerName,
		string newTriggerName,
		DateTime? creationDate,
		bool isDisabled,
		string eventFilter,
		SmtpTriggerAction[] smtpTriggerActions,
		HttpTriggerAction[] httpTriggerActions
	) =>
		await SecurityManagerPool.Demux.SaveSecurityEventTriggersAsync(
			this.GetUpdatedTriggers(
				await SecurityManagerPool.Demux.GetSecurityEventTriggersAsync(),
				originalTriggerName,
				newTriggerName,
				creationDate,
				isDisabled,
				eventFilter,
				Array.Empty<TriggerAction>().Concat(smtpTriggerActions).Concat(httpTriggerActions).ToArray()
			)
		);

	public async Task DeleteSessionEventTrigger(string triggerName)
	{
		var triggers = await SessionManagerPool.Demux.GetSessionEventTriggersAsync();
		await SessionManagerPool.Demux.SaveSessionEventTriggersAsync(triggers.Where(it => it.Name != triggerName).ToArray());
	}

	public async Task DeleteSecurityEventTrigger(string triggerName)
	{
		var triggers = await SecurityManagerPool.Demux.GetSecurityEventTriggersAsync();
		await SecurityManagerPool.Demux.SaveSecurityEventTriggersAsync(triggers.Where(it => it.Name != triggerName).ToArray());
	}

	public async Task ToggleSessionEventTriggerEnabled(string triggerName)
	{
		var triggers = await SessionManagerPool.Demux.GetSessionEventTriggersAsync();
		triggers.First(it => it.Name == triggerName).IsDisabled = !triggers.First(it => it.Name == triggerName).IsDisabled;
		await SessionManagerPool.Demux.SaveSessionEventTriggersAsync(triggers.ToArray());
	}

	public async Task ToggleSecurityEventTriggerEnabled(string triggerName)
	{
		var triggers = await SecurityManagerPool.Demux.GetSecurityEventTriggersAsync();
		triggers.First(it => it.Name == triggerName).IsDisabled = !triggers.First(it => it.Name == triggerName).IsDisabled;
		await SecurityManagerPool.Demux.SaveSecurityEventTriggersAsync(triggers.ToArray());
	}

	public async Task<object> GetEventTriggerExpressionMetadata(bool sessionOrSecurity) =>
		new
		{
			PropertyInfos = (sessionOrSecurity ? FilterManagerConstants.SessionEventTriggerEventSubjectDescriptor : FilterManagerConstants.SecurityEventTriggerEventSubjectDescriptor)
				.GetFilterablePropertyNames()
				.ToDictionary(it => it, it => new { }),
		};

#nullable enable

	T[] GetUpdatedTriggers<T>(T[] triggers, string originalTriggerName, string newTriggerName, DateTime? creationDate, bool isDisabled, string eventFilter, TriggerAction[] actions) where T : EventTrigger, new() =>
		triggers
			.Where(it => it.Name != originalTriggerName)
			.Select(trigger => trigger.Assert(it => it.Name != newTriggerName, _ => "Duplicate trigger name!"))
			.Append(
				new T
				{
					Name = newTriggerName.AssertNonNullOrEmpty("Automation name cannot be empty!"),
					IsDisabled = isDisabled,
					EventFilter = eventFilter.AssertNonNullOrEmpty("Event filter cannot be empty!"),
					ModifiedDate = DateTime.UtcNow,
					CreationDate = creationDate ?? DateTime.UtcNow,
					Actions = actions,
				}
			)
			.ToArray();
}
