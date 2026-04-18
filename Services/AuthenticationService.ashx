<%@ WebHandler Language="C#" Class="ScreenConnect.AuthenticationService" %>

using System;
using System.Threading.Tasks;
using System.Web;

namespace ScreenConnect
{
	[ActivityTrace]
	[AllowInvalidAntiForgeryToken("User can be in various, changing states of authentication while using these endpoints")]
	[OperationLimit]
	public class AuthenticationService : WebServiceBase
	{
		public async Task<string> GetExternalLoginUrl(string providerName, string applicationBaseUrl, string returnUrl, string loginHint) =>
			await WebAuthentication.GetExternalLoginUrlAsync(WebContext.CurrentHttpContext, providerName, new Uri(applicationBaseUrl), returnUrl, loginHint);

		[return: ActivityTrace]
		public Task<SecurityOperationResult> TryLogin(string userName, [ActivityTraceIgnore] string password, [ActivityTraceIgnore] string oneTimePassword, bool shouldTrust, [CanBeNull] string securityNonce) =>
			WebAuthentication.TryLoginAsync(WebContext.CurrentHttpContext, userName, password, oneTimePassword, shouldTrust, securityNonce);

		public Task<bool> TryLogout() =>
			WebAuthentication.TryLogoutAsync(WebContext.CurrentHttpContext);

		[return: ActivityTrace]
		public Task<SecurityOperationResult> ChangePassword(string userName, [ActivityTraceIgnore] string currentPassword, [ActivityTraceIgnore] string newPassword, [ActivityTraceIgnore] string verifyNewPassword) =>
			WebAuthentication.TryChangePasswordAsync(WebContext.CurrentHttpContext, userName, currentPassword, newPassword, verifyNewPassword);

		public async Task InitiatePasswordReset(string userName, [CanBeNull] string securityNonce) =>
			WebAuthentication.InitiatePasswordReset(WebContext.CurrentHttpContext, userName, securityNonce);

		[return: ActivityTrace]
		public Task<SecurityOperationResult> TryResetPassword([ActivityTraceIgnore] string resetCode, string userName, [ActivityTraceIgnore] string newPassword, [ActivityTraceIgnore] string verifyNewPassword, [CanBeNull] string securityNonce) =>
			WebAuthentication.TryResetPasswordAsync(WebContext.CurrentHttpContext, resetCode, userName, newPassword, verifyNewPassword, securityNonce);
	}
}
