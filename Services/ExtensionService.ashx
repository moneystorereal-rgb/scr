<%@ WebHandler Language="C#" Class="ScreenConnect.ExtensionService" %>

using System;
using System.Collections.Generic;
using System.Linq;
using System.IO;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Web;
using System.Text;
using System.Threading.Tasks;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	[ActivityTrace]
	public class ExtensionService : WebServiceBase
	{
		public async Task<object> GetExtensionInfos()
		{
			await ExtensionRuntime.EnsureComponentsTestLoadedAsync();

			return (await ExtensionRuntime.GetAllExtensionRuntimesAsync())
				.Select(e => new
				{
					e.ExtensionID,
					e.Name,
					e.Version,
					e.Author,
					e.ShortDescription,
					e.Status,
					e.LoadMessage,
					e.IsEnabled,
					e.AuthorKey,
					Settings = e.GetSettingInfos(),
					PromotionalImageDataString = e.SafeNav(m => m.GetPromotionalImageContent()).SafeNav(i => Convert.ToBase64String(i)),
				});
		}

		public Task SaveExtensionSettingValues(Guid extensionID, [ActivityTraceIgnore] IDictionary<string, string> settingValues) =>
			ExtensionRuntime.SaveExtensionSettingValuesAsync(extensionID, settingValues, true);

		public async Task<Guid> InstallExtension([ActivityTraceIgnore] string packageContent)
		{
			var packageContentBytes = Convert.FromBase64String(packageContent);
			var memoryStream = new MemoryStream(packageContentBytes);
			var extensionID = ExtensionRuntime.InstallExtension(memoryStream);
			await ExtensionRuntime.SetExtensionEnabledAsync(extensionID, true);
			return extensionID;
		}

		public Task UninstallExtension(Guid extensionID) =>
			ExtensionRuntime.UninstallExtensionAsync(extensionID);

		public Task SetExtensionEnabled(Guid extensionID, bool enabledOrDisabled) =>
			ExtensionRuntime.SetExtensionEnabledAsync(extensionID, enabledOrDisabled);

		[ActivityTraceIgnore]
		public object GetInstanceUserInfo(IPrincipal user)
		{
			using (var hashAlgorithm = Extensions.CreateCryptographyAlgorithm(() => SHA256.Create()))
				return new
				{
					publicKey = ServerCryptoManager.Instance.PublicKeyString,
					instanceKey = Convert.ToBase64String(hashAlgorithm.ComputeHash(ServerCryptoManager.Instance.PublicKey)), // TODO remove this once removed from extension marketplace
					userDisplayName = user.GetUserDisplayNameWithFallback(),
					version = Constants.ProductVersion,
				};
		}

		[ActivityTraceIgnore]
		public string SignReview(string reviewComment, string reviewerDisplayName, int reviewRating)
		{
			return Convert.ToBase64String(
				ServerCryptoManager.Instance.SignData(
					Encoding.UTF8.GetBytes(reviewComment + reviewerDisplayName + reviewRating)
				)
			);
		}
	}
}
