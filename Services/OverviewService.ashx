<%@ WebHandler Language="C#" Class="ScreenConnect.OverviewService" %>

using System;
using System.Collections.Generic;
using System.Linq;
using System.Configuration;
using System.Threading.Tasks;
using System.Web;
using System.Web.Configuration;
using System.Web.Security;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	[ActivityTrace]
	public class OverviewService : WebServiceBase
	{
		public async Task<object> GetOverviewInfo()
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			return new
			{
				MaintenancePlan = MaintenancePlan.FromUserStringOrDefault(configuration.AppSettings.GetValue(ServerConstants.DatabaseMaintenancePlanSettingsKey)),
				UserSources = await MembershipWebAuthenticationProvider.CreateMembershipProviders()
					.ToAsyncEnumerable()
					.SelectAwait(async provider => new
					{
						ResourceKey = provider.GetType().Name,
						IsEnabled = provider.As<MembershipProviderBase>().SafePipe(it => it.IsEnabled),
						IsExternal = provider is IExternalAuthenticationProvider,
						Users = await provider
							.If(_ => !(_ is IReadOnlyMembershipProvider))
							.SafePipeAwaitAsync(_ => _.GetAllUsersAsync())
							.PipeAsync(it => it.SafeEnumerate())
							.ToAsyncEnumerable()
							.Select(it => new
							{
								Name = it.UserName,
								PasswordQuestion = it.PasswordQuestion,
							})
							.ToListAsync(),
					})
					.ToListAsync(),
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
	}
}
