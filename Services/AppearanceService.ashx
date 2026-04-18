<%@ WebHandler Language="C#" Class="ScreenConnect.AppearanceService" %>

using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Configuration;
using System.Globalization;
using System.Threading.Tasks;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	[ActivityTrace]
	public class AppearanceService : WebServiceBase
	{
		const string InvariantCultureKey = "InvariantCultureKey";

		static string GetCultureKeyFromCulture(CultureInfo culture)
		{
			return culture.Name.IsNullOrEmpty() ? AppearanceService.InvariantCultureKey : culture.Name;
		}

		static CultureInfo GetCultureFromCultureKey(string cultureKey)
		{
			return cultureKey == AppearanceService.InvariantCultureKey ? CultureInfo.InvariantCulture : CultureInfo.GetCultureInfo(cultureKey);
		}

		static async Task<IDictionary<string, ServerResourceManager>> GetResourceManagerDictionaryAsync()
		{
			return new Dictionary<string, ServerResourceManager>
			{
				{ "Web", WebResourceManager.Instance },
				{ "Client", await ClientConfig.GetResourceManagerAsync() },
			};
		}

		static int GetPopularityIndex(string resourceName) => resourceName switch
		{
			"GuestActionPanel.CodeSession.Heading" => 100,
			_ => 0,
		};

		[DemandLicense(BasicLicenseCapabilities.AdministerAppearance)]
		public async Task<object> GetResourceInfo()
		{
			var resourcePackInfos = await AppearanceService.GetResourceManagerDictionaryAsync()
				.ToAsyncEnumerable()
				.SelectManyAwait(
					async it => (await it.Value.LoadResourcePacksAsync()).ToAsyncEnumerable(),
					async (it, resourcePack) => (ResourceType: it.Key, ResourcePack: resourcePack)
				)
				.ToListAsync();

			var resourceValueInfos = resourcePackInfos
				.SelectMany(
					resourcePackInfo => resourcePackInfo.ResourcePack.ResourceList,
					(resourcePackInfo, resource) => new
					{
						resource.Key,
						resourcePackInfo.ResourceType,
						resourcePackInfo.ResourcePack.Culture,
						resourcePackInfo.ResourcePack.Precedence,
						resource.Value,
					}
				)
				.ToList();

			var cultures = resourcePackInfos
				.Select(it => it.ResourcePack.Culture)
				.Distinct()
				.Where(culture => resourceValueInfos.Any(resourceValueInfo => resourceValueInfo.Precedence == ResourcePackPrecedence.Default && resourceValueInfo.Culture.Equals(culture)))
				.Select(culture => new
				{
					CultureKey = AppearanceService.GetCultureKeyFromCulture(culture),
					culture.DisplayName,
				})
				.OrderBy(culture => culture.DisplayName)
				.ToList();

			return new
			{
				InvariantCultureKey = AppearanceService.InvariantCultureKey,

				Cultures = cultures,

				Resources = resourceValueInfos
					.GroupBy(
						resourceValueInfo => resourceValueInfo.Key,
						(key, resourceValueInfosForKey) => new
						{
							Key = key,
							PopularityIndex = AppearanceService.GetPopularityIndex(key),
							ResourceType = resourceValueInfosForKey.First().ResourceType,
							IsImage = resourceValueInfosForKey.First().Value is byte[],
							ValueContainersByCultureKey = resourceValueInfosForKey
								.GroupToMap(resourceValueInfo => AppearanceService.GetCultureKeyFromCulture(resourceValueInfo.Culture))
								.SelectValues(resourceValueInfosForCulture =>
									resourceValueInfosForCulture.GroupToMap(
										resourceValueInfo => resourceValueInfo.Precedence,
										resourceValueInfo => resourceValueInfo.Value is byte[] byteArrayValue ? Convert.ToBase64String(byteArrayValue) : resourceValueInfo.Value
									)
									.SelectValues(valuesForPrecedence => valuesForPrecedence.First())
									.ToDictionary()
								)
								.SafeNav(cultureKeysToValuesByPrecedence => cultureKeysToValuesByPrecedence
									.Where(cultureKeyToValuesByPrecedence => cultureKeyToValuesByPrecedence.Key == AppearanceService.InvariantCultureKey)
									.If(invariantCultureKeysToValuesByPrecedence => invariantCultureKeysToValuesByPrecedence
										.Any(invariantCultureKeyToValuesByPrecedence => invariantCultureKeyToValuesByPrecedence.Value.ContainsKey(ResourcePackPrecedence.Default))
									)
									.Else(() => cultures
										.Where(culture => culture.CultureKey != AppearanceService.InvariantCultureKey)
										.GroupJoin(cultureKeysToValuesByPrecedence,
											culture => culture.CultureKey,
											cultureKeyToValuesByPrecedence => cultureKeyToValuesByPrecedence.Key,
											(culture, cultureKeysToValuesByPrecedenceForCulture) => cultureKeysToValuesByPrecedenceForCulture
												.DefaultIfEmpty(Extensions.CreateKeyValuePair(culture.CultureKey, new Dictionary<ResourcePackPrecedence, object>()))
												.FirstOrDefault()
										)
									)
								)
								.SelectValues(valuesByPreference => new
								{
									DefaultValue = valuesByPreference.TryGetValue(ResourcePackPrecedence.Default),
									OverrideValue = valuesByPreference.TryGetValue(ResourcePackPrecedence.Override),
								})
								.ToDictionary()
						}
					)
					.Where(resource => resource.ValueContainersByCultureKey.Any(cultureKeyToValueContainer => cultureKeyToValueContainer.Value.DefaultValue != null))
					.OrderBy(resource => resource.Key),
			};
		}

		[DemandLicense(BasicLicenseCapabilities.AdministerAppearance)]
		public async Task SaveResource(string resourceType, string key, bool isImage, IDictionary<string, string> overrideValuesByCultureKey)
		{
			var resourceManager = (await AppearanceService.GetResourceManagerDictionaryAsync())[resourceType];

			var maxImageSize = (await resourceManager.LoadResourcePacksAsync())
				.Where(resourcePack => resourcePack.Precedence == ResourcePackPrecedence.Default)
				.Select(resourcePack => resourcePack.ResourceList.ToDictionary().TryGetValue(key))
				.OfType<byte[]>()
				.FirstOrDefault()
				.SafePipe(imageBytes => 20 * imageBytes.Length + 20_000); // we make our images aggressively small, so be more lenient with user-uploaded images

			void CheckImageSize(byte[] imageBytes)
			{
				if (imageBytes.Length > maxImageSize)
					throw new ArgumentException($"Image too large: {imageBytes.Length / 1000:n0}kb > {maxImageSize / 1000:n0}kb");
			};

			resourceManager.SaveResourceOverride(key, overrideValuesByCultureKey.Select(cultureKeyToOverrideValue =>
				Extensions.CreateKeyValuePair(
					AppearanceService.GetCultureFromCultureKey(cultureKeyToOverrideValue.Key),
					isImage && cultureKeyToOverrideValue.Value != null ? Convert.FromBase64String(cultureKeyToOverrideValue.Value).Pass(CheckImageSize) : (object)cultureKeyToOverrideValue.Value
				)
			));
		}

		public object GetThemeInfo()
		{
			return new
			{
				ThemeNames = WebConfigurationManager.GetThemeNames(),
				CurrentThemeName = WebConfigurationManager.GetSection<PagesSection>().SafeNav(s => s.Theme),
				PreviewUrlFormat = "/?" + ServerConstants.ThemeParameterName + "={0}",
			};
		}

		public void SetTheme(string themeName)
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			WebConfigurationManager.GetSection<PagesSection>(configuration).Theme = themeName;
			ServerToolkit.Instance.SaveConfiguration(configuration);
		}
	}
}
