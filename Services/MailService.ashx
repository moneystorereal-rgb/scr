<%@ WebHandler Language="C#" Class="ScreenConnect.MailService" %>

using System;
using System.Web;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Net.Configuration;
using System.Security.Principal;
using System.Threading.Tasks;

namespace ScreenConnect
{
	[DemandAnyPermission]
	[ActivityTrace]
	public class MailService : WebServiceBase
	{
		const string EmptyPassword = "\ufffd\ufffd\ufffd\ufffd\ufffd\ufffd\ufffd\ufffd";

		[DemandPermission(PermissionInfo.AdministerPermission)]
		public object GetMailConfigurationInfo()
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var smtpSection = configuration.GetSection<SmtpSection>();

			return new
			{
				availableSmtpDeliveryMethods = ConfigurationCache.SmtpDeliveryMethods
					.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
					.Select(it => it.Trim()),
				defaultMailFromAddress = smtpSection.From,
				defaultMailToAddress = configuration.AppSettings.GetValue(ServerConstants.DefaultMailToAddressSettingsKey),
				smtpRelayServerHostName = smtpSection.Network.Host,
				smtpRelayServerPort = smtpSection.Network.Port,
				smtpDeliveryMethod = smtpSection.DeliveryMethod,
				smtpPickupDirectoryLocation = smtpSection.SpecifiedPickupDirectory.PickupDirectoryLocation,
				smtpUseDefaultCredentials = smtpSection.Network.DefaultCredentials,
				smtpNetworkTargetName = smtpSection.Network.TargetName,
				smtpNetworkUserName = smtpSection.Network.UserName,
				smtpNetworkPassword = string.IsNullOrEmpty(smtpSection.Network.Password) ? null : MailService.EmptyPassword,
				enableSSL = smtpSection.Network.EnableSsl,
			};
		}

		[DemandPermission(PermissionInfo.AdministerPermission)]
		public void SaveMailConfiguration(
			string defaultMailFromAddress,
			string defaultMailToAddress,
			string smtpRelayServerHostName,
			string smtpRelayServerPort,
			bool enableSsl,
			SmtpDeliveryMethod smtpDeliveryMethod,
			string smtpPickupDirectoryLocation,
			bool? smtpUseDefaultCredentials,
			string smtpNetworkTargetName,
			string smtpNetworkUserName,
			string smtpNetworkPassword
		)
		{
			var configuration = WebConfigurationManager.OpenWebConfiguration();
			var smtpSection = configuration.GetSection<SmtpSection>();

			smtpSection.From = defaultMailFromAddress;
			configuration.AppSettings.SetValue(ServerConstants.DefaultMailToAddressSettingsKey, defaultMailToAddress);

			smtpSection.DeliveryMethod = smtpDeliveryMethod;

			smtpSection.Network.Host = null;
			smtpSection.SpecifiedPickupDirectory.PickupDirectoryLocation = null;
			smtpSection.Network.EnableSsl = false;
			smtpSection.Network.DefaultCredentials = false;
			smtpSection.Network.Port = WebConstants.DefaultSmtpNetworkPort;
			smtpSection.Network.UserName = null;
			smtpSection.Network.Password = null;
			smtpSection.Network.TargetName = null;

			if (smtpDeliveryMethod == SmtpDeliveryMethod.Network)
			{
				if (!string.IsNullOrEmpty(smtpRelayServerHostName))
				{
					smtpSection.Network.Host = smtpRelayServerHostName;
					smtpSection.Network.Port = smtpRelayServerPort.TryParseInt32(WebConstants.DefaultSmtpNetworkPort);
					smtpSection.Network.EnableSsl = enableSsl;

					if (!(smtpSection.Network.DefaultCredentials = smtpUseDefaultCredentials.GetValueOrDefault()))
					{
						smtpSection.Network.UserName = smtpNetworkUserName.IfNotEmpty();
						smtpSection.Network.Password = smtpNetworkPassword != MailService.EmptyPassword ? smtpNetworkPassword : smtpSection.Network.Password;
					}
					else
						smtpSection.Network.TargetName = smtpNetworkTargetName.IfNotEmpty();
				}
			}
			else if (smtpDeliveryMethod == SmtpDeliveryMethod.SpecifiedPickupDirectory)
				smtpSection.SpecifiedPickupDirectory.PickupDirectoryLocation = smtpPickupDirectoryLocation.Trim();

			ServerToolkit.Instance.SaveConfiguration(configuration);
		}

		[DemandPermission(PermissionInfo.AdministerPermission)]
		[ActivityTraceIgnore]
		public async Task SendTestEmail(
			string from,
			string relayHost,
			string to,
			SmtpDeliveryMethod smtpDeliveryMethod,
			string smtpPickupDirectory,
			int relayPort,
			bool enableSsl,
			bool? useDefaultCredentials,
			string smtpTargetName,
			string smtpUserName,
			string smtpPassword,
			IPrincipal user
		)
		{
			RateLimitManager.Instance.RecordOperationAndDemandAllowed((nameof(SendEmail), user.Identity.Name)); // Treat this operation same as SendEmail

			using (var mailMessage = ServerToolkit.Instance.CreateMailMessage())
			{
				mailMessage.From = new MailAddress(from);
				mailMessage.To.Add(to);
				mailMessage.Subject = await WebResources.GetStringAsync("MailPanel.TestSubject");
				mailMessage.Body = await WebResources.GetStringAsync("MailPanel.TestBody");
				mailMessage.IsBodyHtml = false;

				using (var client = new SmtpClient())
				{
					client.DeliveryMethod = smtpDeliveryMethod;
					client.Host = relayHost;
					client.Port = relayPort;
					client.EnableSsl = enableSsl;
					client.PickupDirectoryLocation = smtpPickupDirectory;

					if (useDefaultCredentials != null && useDefaultCredentials.Value)
					{
						client.UseDefaultCredentials = true;
						client.Credentials = null;
					}
					else
					{
						client.UseDefaultCredentials = false;
						client.Credentials = new NetworkCredential(
							smtpUserName ?? string.Empty,
							smtpPassword != MailService.EmptyPassword
								? smtpPassword
								: WebConfigurationManager.OpenWebConfiguration().GetSection<SmtpSection>().Network.Password
						);
					}

					client.TargetName = smtpTargetName;

					await client.SendMailAsync(mailMessage);
				}
			}
		}

		public async Task SendEmail(
			[ActivityTraceIgnore] string to,
			string subjectResourceBaseNameFormat,
			object[] subjectResourceNameFormatArgs,
			[ActivityTraceIgnore] object[] subjectResourceFormatArgs,
			string bodyResourceBaseNameFormat,
			object[] bodyResourceNameFormatArgs,
			[ActivityTraceIgnore] object[] bodyResourceFormatArgs,
			[ActivityTraceIgnore] bool isBodyHtml,
			IPrincipal user
		)
		{
			RateLimitManager.Instance.RecordOperationAndDemandAllowed((nameof(SendEmail), user.Identity.Name));

			var subject = await WebResources.TryFormatStringWithFallbackAsync(
				subjectResourceBaseNameFormat + "EmailSubjectFormat",
				subjectResourceNameFormatArgs,
				false,
				subjectResourceFormatArgs
			);
			var body = await WebResources.TryFormatStringWithFallbackAsync(
				bodyResourceBaseNameFormat + (isBodyHtml ? "HtmlEmailBodyFormat" : "TextEmailBodyFormat"),
				bodyResourceNameFormatArgs,
				false,
				bodyResourceFormatArgs
			);

			using (var mailMessage = ServerToolkit.Instance.CreateMailMessage())
			{
				mailMessage.To.Add(to);
				mailMessage.Subject = subject;
				mailMessage.Body = body;
				mailMessage.IsBodyHtml = isBodyHtml;

				using (var client = new SmtpClient())
					await client.SendMailAsync(mailMessage);
			}
		}
	}
}
