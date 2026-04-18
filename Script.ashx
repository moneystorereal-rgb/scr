<%@ WebHandler Language="C#" Class="ScreenConnect.Script" %>

using System;
using System.Web;
using System.Linq;
using System.Web.Caching;
using System.Threading.Tasks;

#nullable enable

namespace ScreenConnect;

public class Script : SingletonAsyncHandler, ICacheDependencyCreator
{
	public CacheDependency CreateCacheDependency(string physicalPath) =>
		WebExtensions.CreateAggregateCacheDependency(
			new CacheDependency(new[]
			{
				physicalPath,
				ServerExtensions.MapPath(WebConstants.ScriptsDirectoryName),
				ServerExtensions.MapPath(WebConstants.ServicesDirectoryName),
			}),
			ExtensionRuntime.CreateCacheDependency(),
			WebResourceManager.Instance.CreateCacheDependency()
		);

	public override async Task ProcessRequestAsync(HttpContext context)
	{
		CacheCookie.SetBasicResponseCachingFields(context, this.CreateCacheDependency(context.Request.GetPhysicalFilePathWithinApplicationDirectorySafe(AdditionalPathVerificationLevel.FileExists)));

		context.Response.Cache.VaryByHeaders["Accept-Language"] = true;
		// prevent cache poisoning in SC.context.clp
		context.Response.Cache.VaryByHeaders["Host"] = true;
		context.Response.Cache.VaryByHeaders[ServerConstants.ProxyHostRequestHeaderName] = true;
		context.Response.Cache.VaryByHeaders[ServerConstants.ProxyPortRequestHeaderName] = true;
		context.Response.Cache.VaryByHeaders[ServerConstants.ProxySchemeRequestHeaderName] = true;

		context.Response.ContentType = "text/javascript";

		await context.Response.Output.WriteAsync("SC = ");

		await context.Response.Output.WriteAsync(JavaScriptSerializer.SerializeCode(new
		{
			service = (await WebExtensions.GetWebServiceInfosAsync(context))
				.Pipe(webServiceInfos =>
					from webServiceInfo in webServiceInfos
					from webMethod in webServiceInfo.WebMethods
					select Extensions.CreateKeyValuePair(
						webMethod.Name,
						new JavaScriptFunctionDeclaration(
							string.Empty,
							webMethod.Parameters.Select(it => it.Name).Concat(WebConstants.StandardWebServiceParameterNames).ToArray(),
							string.Format(
								JavaScriptFormatter.Default,
								"return SC.http.invokeService({0:js}, {1:js}, [{2}], {3});",
								webServiceInfo.RelativeUrl,
								webMethod.Name,
								webMethod.Parameters.Select(it => it.Name).Join(", "),
								WebConstants.StandardWebServiceParameterNames.Join(", ")
							)
						)
					)
				)
				.GroupBy(it => it.Key)
				.ToDictionary(it => it.Key, it => it.First().Value),
			// configuration-based context - can be used across users and pages
			context = new
			{
				clp = ServerExtensions.GetRelayUri(context.Request.GetUrlWithTruePath(), true, true, context.Request.Headers)
					.Pipe(it => ServerExtensions.GetBaseClientLaunchParameters(it, ServerCryptoManager.Instance.PublicKey))
					.Pipe(it => new
					{
						// TODO it'd be nice to rely on CopyToParameters or something instead of having to explicitly know which parameters need serialized from GetBaseClientLaunchParameters,
						//      but Port needs to be an int instead of a string and EncryptionKey needs to be a base64 string (for backwards compatibility and correctness), so not clear how to do that..
						h = it.Host,
						p = it.Port,
						k = Convert.ToBase64String(it.EncryptionKey),
					}),
				installerHandlerPath = WebConfigurationManager.GetHandlerPath(typeof(InstallerHandler)),
				launchHandlerPaths = Extensions.GetPluginTypes(typeof(LaunchHandler))
					.Where(it => !it.IsAbstract)
					.ToDictionary(
						it => it.Name.TrimEnd("Handler"),
						it => WebConfigurationManager.GetHandlerPath(it)
					),
				scriptBaseUrl = string.Empty,
				productVersion = Constants.ProductVersion.ToString(), // needs explicit ToString since this uses JavaScriptSerializer
				restartCheckIntervalMilliseconds = ServerToolkit.Instance.GetWebServerRestartCheckIntervalMilliseconds(),
				customPropertyCount = Session.CustomPropertyCount,
				instanceUrlScheme = Extensions.GetInstanceUrlScheme(Extensions.GetFingerprint(ConfigurationCache.InstanceIdentifierBlob)),
				loginUrl = WebConstants.LoginPageUrl,
				loginReturnUrlParameterName = ServerConstants.LoginReturnUrlParameterName,
				loginReasonParameterName = WebConstants.LoginReasonParameterName,
				loginUserNameParameterName = WebConstants.LoginUserNameParameterName,
				guestPageUrl = WebConstants.GuestPageUrl,
				hostPageUrl = WebConstants.HostPageUrl,
				administrationPageUrl = WebConstants.AdministrationPageUrl,
				changePasswordPageUrl = WebConstants.ChangePasswordPageUrl,
				resetPasswordPageUrl = WebConstants.ResetPasswordPageUrl,
				accessTokenExpireSeconds = ConfigurationCache.AccessTokenLifetime.TotalSeconds,
				eventTypesAllowingDeletion = Extensions.GetEnumValues<SessionEventType>().Where(Session.CanEventTypeBeDeleted).ToArray(),
				eventTypesAllowingResponse = Extensions.GetEnumValues<SessionEventType>().Where(Session.CanEventTypeBeRespondedTo).ToArray(),
				eventTypesAllowingProcessing = Extensions.GetEnumValues<SessionEventType>().Where(Session.CanEventTypeBeProcessed).ToArray(),
				eventTypesAllowingAcknowledgement = Extensions.GetEnumValues<SessionEventType>().Where(Session.CanEventTypeBeAcknowledged).ToArray(),
				requestResolutionEventTypes = Extensions.GetEnumValues<SessionEventType>().Where(Session.IsEventTypeRequestResolution).ToArray(),
				guestWelcomePanelHeading = WebConstants.GuestWelcomePanelHeading,
				guestWelcomePanelMessage = WebConstants.GuestWelcomePanelMessage,
			},
			types = WebConstants.WebScriptTypes.ToDictionary(
				type => type.Name,
				type => Extensions.GetEnumNamesAndValues(type).Where(it => !it.Value.IsObsolete()).ToDictionary()
			),
			res = (await WebResourceManager.Instance.GetAllEntriesAsync())
				.Where(it => it.Value is string)
				.ToDictionary(it => it.Key, it => it.Value),
			extensions = await ExtensionRuntime.GetActiveExtensionRuntimesAsync().ToAsyncEnumerable()
				.ToDictionaryAwaitAsync(
					async er => er.ExtensionID.ToString(),
					async er => new
					{
						virtualPath = er.VirtualBasePath,
						settingValues = er.PublicSettingsValues,
						customContexts = await er.GetActiveRuntimeObjects<ClientScriptCustomContextProviderDefinition, IClientScriptCustomContextProvider>()
							.ToAsyncEnumerable()
							.SelectAwait(async it => await it.GetScriptCustomContextAsync(context))
							.ToArrayAsync(),
						initializeProcs = Array.Empty<object>(),
					}
				),
		}));

		await context.Response.Output.WriteLineAsync(";");
	}
}
