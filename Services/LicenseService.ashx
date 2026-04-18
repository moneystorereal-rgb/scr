<%@ WebHandler Language="C#" Class="ScreenConnect.LicenseService" %>

using System;
using System.Linq;
using System.Collections.Specialized;
using System.Threading.Tasks;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	public class LicenseService : WebServiceBase
	{
		public async Task<object> GetLicenseInfo()
		{
			return new
			{
				LicenseRuntimeInfos = await SessionManagerPool.Demux.GetLicenseRuntimeInfosAsync(),
			};
		}

		public Task AddLicense(string userString) => SessionManagerPool.Demux.AddLicenseAsync(userString);

		public Task RemoveLicense(string licenseID) => SessionManagerPool.Demux.RemoveLicenseAsync(licenseID);

		public async Task<object> GetBasicLicenseCapabilities() => await LicensingInfo.GetCapabilitiesAsync();

		public async Task<string> GetUpgradeUrl()
		{
			var parameters = new NameValueCollection();
			parameters["InstanceCode"] = ((uint)ServerExtensions.GetInstanceHashCode()).ToString();
			parameters["License"] = (await SessionManagerPool.Demux.GetLicenseRuntimeInfosAsync()).Select(_ => _.UserString).Join(Environment.NewLine + Environment.NewLine);
			return Extensions.EncodeUrl(ServerConstants.UpgradeUrl, parameters);
		}
	}
}
