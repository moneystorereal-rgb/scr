<%@ WebHandler Language="C#" Class="ScreenConnect.StatusService" %>

using System;
using System.Linq;
using System.Web;
using System.Threading.Tasks;
using System.Net;
using System.Net.Sockets;
using System.Collections.Specialized;
using System.ServiceModel.Configuration;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	public class StatusService : WebServiceBase
	{
		public async Task<object> PerformStatusCheck(string statusCheckName)
		{
			var context = WebContext.CurrentHttpContext!;
			var testData = default(object);
			var testResult = TestResult.Incomplete;
			var errorMessage = default(string);

			try
			{
				switch (statusCheckName)
				{
					case "SessionManager":
						testData = WebConfigurationManager.GetSection<ClientSection>().Endpoints.OfType<ChannelEndpointElement>().Where(ep => ep.Contract == typeof(ISessionManagerChannel).FullName).Select(ep => ep.Address.ToString()).FirstOrDefault();
						await SessionManagerPool.Demux.GetLicenseParametersAsync();
						testResult = TestResult.Passed;
						break;
					case "Relay":
						var relayUri = ServerExtensions.GetConfigurationUri(ServerConstants.RelayListenUriSettingsKey);
						var relayEndPoint = ServerExtensions.GetListenEndPoints(relayUri).First();

						if (relayEndPoint.Address.IsAny())
						{
							relayEndPoint.Address = IPAddress.Loopback;
							relayUri.Host = relayEndPoint.Address.ToString();
						}

						testData = relayUri.Uri;

						var socket = new Socket(relayEndPoint.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
						try
						{
							await TaskExtensions.UsingTimeoutCancellationToken(ServerConstants.RelayTestTimeoutMilliseconds, async cancellationToken =>
							{
								using (cancellationToken.Register(socket.ShutdownQuietly))
									await socket.ConnectAsync(relayEndPoint);
							});

							socket.ShutdownQuietly();
							testResult = TestResult.Passed;
						}
						finally
						{
							socket.DisposeFullyQuietly();
						}

						break;
					case "WebServer":
						var webServerUri = ServerExtensions.GetWebServerUri(null, false, false).Uri.AbsoluteUri;

						testData = webServerUri;

						using (ServerExtensions.TemporarilyAllowAnyServerCertificate())
						using (var httpClient = new HttpClient { Timeout = TimeSpan.FromMilliseconds(ServerConstants.WebRequestTestTimeoutMilliseconds) })
						{
							await httpClient.GetAndHandleResponseAsync(webServerUri);
							testResult = TestResult.Passed;
						}

						break;
					case "WindowsFirewall":
						var exeName = Toolkit.Instance.GetCurrentProcessMainModuleFileName();
						var webServerPort = ServerExtensions.GetConfigurationUri(ServerConstants.WebServerListenUriSettingsKey).SafeNav(_ => _.Port);
						var relayPort = ServerExtensions.GetConfigurationUri(ServerConstants.RelayListenUriSettingsKey).SafeNav(_ => _.Port);

						testData = new WindowsFirewallTestResult
						{
							IsFirewallEnabled = ServerToolkit.Instance.IsWindowsFirewallEnabled(),
							IsWebServerPortAllowed = ServerToolkit.Instance.IsWindowsFirewallTcpPortAllowed(exeName, webServerPort),
							IsRelayPortAllowed = ConfigurationCache.IsRelayTrafficRouted || ServerToolkit.Instance.IsWindowsFirewallTcpPortAllowed(exeName, relayPort),
						};

						testResult = testData.As<WindowsFirewallTestResult>().SafeNav(_ => _.IsWebServerPortAllowed && _.IsRelayPortAllowed) ? TestResult.Passed : TestResult.Failed;
						break;
					case "Version":
						var versionCheckParameters = new NameValueCollection
						{
							{ "Version", Constants.ProductVersion.ToString() },
							{ "Environment", EnvironmentInfo.Current.ToString() },
							{ "IsPreRelease", Constants.IsPreRelease.ToString() },
						};

						foreach (var licenseEnvelope in LicenseManager.LoadLicenseEnvelopes())
						{
							versionCheckParameters.Add("LicenseID", licenseEnvelope.Contents.LicenseID);
							versionCheckParameters.Add("LicenseVersion", licenseEnvelope.Contents.Version.ToString());
							versionCheckParameters.Add("LicenseType", licenseEnvelope.Contents.GetType().Name);
						}

						testData = await this.PerformHttpRequestAsync<VersionTestResult>(ServerConstants.VersionCheckUrl, versionCheckParameters);
						testResult = testData.As<VersionTestResult>().SafeNav(_ => _.NewVersionAvailable) ? TestResult.Warning : TestResult.Passed;
						break;
					case "ExternalAccessibility":
						var externalAccessibilityCheckParameters = ServerExtensions.GetExternalAccessibilityCheckParameters(context.Request.GetUrlWithTruePath(), null, context.Request.Headers);
						testData = await this.PerformHttpRequestAsync<ExternalAccessibilityTestResult>(ServerConstants.ExternalAccessibilityCheckUrl, externalAccessibilityCheckParameters);
						testResult = testData.As<ExternalAccessibilityTestResult>().SafeNav(_ => string.IsNullOrEmpty(_.WebServerErrorMessage) && string.IsNullOrEmpty(_.RelayErrorMessage)) ? TestResult.Passed : TestResult.Failed;
						break;
					case "BrowserUrl":
						var browserUrlCheckParameters = new NameValueCollection { { "Host", context.Request.GetRealUrl(false, false).Host } };
						testData = await this.PerformHttpRequestAsync<BrowserUrlTestResult>(ServerConstants.BrowserUrlCheckUrl, browserUrlCheckParameters);
						testResult = testData.As<BrowserUrlTestResult>().SafeNav(_ => _.IsHostResolvable) ? TestResult.Passed : TestResult.Failed;
						break;
				}
			}
			catch (Exception ex)
			{
				testResult = TestResult.Error;
				errorMessage = ex.Message;
			}

			return new
			{
				Result = testResult,
				Data = testData,
				ErrorMessage = errorMessage,
			};
		}

		async Task<T> PerformHttpRequestAsync<T>(string url, NameValueCollection parameters)
		{
			using (var httpClient = new HttpClient { Timeout = TimeSpan.FromMilliseconds(ServerConstants.WebRequestTestTimeoutMilliseconds) })
			using (var stream = await httpClient.GetStreamAsync(Extensions.EncodeUrl(url, parameters)))
				return ServerExtensions.DeserializeXml<T>(stream);
		}
	}
}
