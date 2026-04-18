<%@ WebHandler Language="C#" Class="ScreenConnect.SessionGroupService" %>

using System;
using System.Linq;
using System.Threading.Tasks;
using System.Security.Principal;

namespace ScreenConnect;

[DemandPermission(PermissionInfo.ManageSessionGroupsPermission)]
[ActivityTrace]
public class SessionGroupService : WebServiceBase
{
	public Task<SessionGroup[]> GetSessionGroups() =>
		SessionManagerPool.Demux.GetSessionGroupsAsync();

	public async Task SaveSessionGroups([ActivityTraceIgnore] SessionGroup[] sessionGroups) =>
		await SessionManagerPool.Demux.SaveSessionGroupsAsync(sessionGroups);

	public async Task UpdateSessionGroup(SessionGroup originalSessionGroup, SessionGroup newSessionGroup)
	{
		var sessionGroups = await SessionManagerPool.Demux.GetSessionGroupsAsync();
		var index = sessionGroups.IndexOf(it => originalSessionGroup.SessionType == it.SessionType && originalSessionGroup.Name == it.Name);
		if (index == -1 || originalSessionGroup.SessionType != newSessionGroup.SessionType)
			throw new InvalidOperationException("Invalid session group");

		sessionGroups[index] = newSessionGroup;
		await SessionManagerPool.Demux.SaveSessionGroupsAsync(sessionGroups);

		if (originalSessionGroup.Name != newSessionGroup.Name)
		{
			var roles = await Permissions.GetAllRolesAsync();
			var sessionGroupPermissionEntries = roles.SelectMany(role => role.PermissionEntries)
				.OfType<SessionPermissionEntry>()
				.Where(it => it.IsSpecificSessionGroup())
				.ToList();

			var changed = false;
			foreach (var sessionPermissionEntry in sessionGroupPermissionEntries)
				if (originalSessionGroup.Name == sessionPermissionEntry.SessionGroupPathParts.FirstOrDefault())
				{
					sessionPermissionEntry.SessionGroupPathParts[0] = newSessionGroup.Name;
					changed = true;
				}

			if (changed)
				await Permissions.SaveRolesAsync(roles);
		}
	}

	public async Task<object> GetSessionExpressionMetadata() => new
	{
		PropertyInfos = FilterManagerConstants.SessionColumnDefinitions
			.ToDictionary(it => it.ColumnName, _ => new { }),
		VariableInfos = FilterManagerConstants.SampleSessionVariableNames
			.ToDictionary(it => it, _ => new { }),
	};

	public async Task<object> GetSessionExpressionResults(SessionType sessionType, string[] filters, string[] subExpressions, IPrincipal user) => new
	{
		FilterInfos = await filters.SelectMany(it => ExpressionParser.Instance.TryExtractBooleanExpressionSegments(it)).Distinct().ToAsyncEnumerable().ToDictionaryAwaitAsync(
			async it => it,
			async it => new
			{
				Count = await SessionManagerPool.Demux.GetSessionCountAsync(sessionType, it, await ServerExtensions.GetStandardVariablesAsync(user)),
			}
		),
		SubExpressionInfos = await subExpressions.Distinct().ToAsyncEnumerable().ToDictionaryAwaitAsync(
			async subExpression => subExpression,
			async subExpression => new
			{
				Results = await SessionManagerPool.Demux.GetSubExpressionValuesAsync(sessionType, subExpression, await ServerExtensions.GetStandardVariablesAsync(user))
					.ToAsyncEnumerable()
					.Select(it => new { it.Value, it.Count })
					.ToListAsync(),
			}
		),
		TotalResultCount = await SessionManagerPool.Demux.GetSessionCountAsync(
			sessionType,
			filters.OrderBy(it => it.Length).LastOrDefault() ?? string.Empty,
			await ServerExtensions.GetStandardVariablesAsync(user)
		),
	};
}
