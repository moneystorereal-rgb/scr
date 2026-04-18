<%@ WebHandler Language="C#" Class="ScreenConnect.DatabaseService" %>

using System;
using System.Linq;
using System.Threading.Tasks;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.AdministerPermission)]
	[DemandLicense(BasicLicenseCapabilities.AdministerDatabase)]
	[ActivityTrace]
	public class DatabaseService : WebServiceBase
	{
		static MaintenancePlan GetMaintenancePlan() => MaintenancePlan.FromUserStringOrDefault(ServerExtensions.GetServerConfigurationString(ServerConstants.DatabaseMaintenancePlanSettingsKey));

		public object GetConfiguration()
		{
			return new
			{
				MaintenancePlan = DatabaseService.GetMaintenancePlan(),
				MaintenancePlanParameterDefinitions = MaintenancePlanParameterDefinition.All.ToDictionary(it => it.ParameterName, it => new
				{
					it.DefaultValue,
					it.AppliesToActionTypes,
					it.SelectableValues,
					EnumTypeIfApplicable = it.DefaultValue.GetType().IsArray ? it.DefaultValue.GetType().GetElementType()!.Name : it.DefaultValue.GetType().Name,
				}),
			};
		}

		public async Task SaveAction(MaintenancePlanAction action)
		{
			await DatabaseService.UsingMaintenancePlan(maintenancePlan =>
			{
				var existingActionIndex = maintenancePlan.Actions.IndexOf(it => it.ActionID == action.ActionID);
				var newAction = new MaintenancePlanAction
				{
					ActionID = existingActionIndex != -1 ? maintenancePlan.Actions[existingActionIndex].ActionID : Guid.NewGuid(),
					ActionType = action.ActionType,
					Parameters = MaintenancePlanParameterDefinition.All.Where(parameter => parameter.AppliesToActionTypes.Contains(action.ActionType)).ToDictionary(
						it => it.ParameterName,
						it => action.Parameters.TryGetValue(it.ParameterName, out var value) && value != null
							? JavaScriptSerializer.Instance.ConvertToType(value, it.DefaultValue.GetType())
							: throw new InvalidOperationException()
					),
				};

				if (existingActionIndex != -1)
					maintenancePlan.Actions = maintenancePlan.Actions.ToArray().Mutate(it => it[existingActionIndex] = newAction);
				else
					maintenancePlan.Actions = maintenancePlan.Actions.Append(newAction).ToArray();
			});
		}

		public async Task SaveSchedule(ushort runAtUtcTimeMinutes, bool daysIncludedOrExcluded, DayOfWeek[] days)
		{
			if ((daysIncludedOrExcluded && days.Length == 0) || (!daysIncludedOrExcluded && days.Length == 7))
				throw new InvalidOperationException("Must specify at least one day.");

			await DatabaseService.UsingMaintenancePlan(maintenancePlan =>
			{
				maintenancePlan.RunAtUtcTimeMinutes = runAtUtcTimeMinutes;
				maintenancePlan.DaysIncludedOrExcluded = daysIncludedOrExcluded;
				maintenancePlan.Days = days;
			});
		}

		public async Task DeleteAction(Guid actionID)
		{
			await DatabaseService.UsingMaintenancePlan(maintenancePlan =>
			{
				maintenancePlan.Actions = maintenancePlan.Actions.Where(it => it.ActionID != actionID).ToArray();
			});
		}

		static async Task UsingMaintenancePlan(Proc<MaintenancePlan> proc)
		{
			var maintenancePlan = DatabaseService.GetMaintenancePlan();

			proc(maintenancePlan);

			await ServerExtensions.SaveServerConfigurationSettingAsync(ServerConstants.DatabaseMaintenancePlanSettingsKey, MaintenancePlan.ToUserString(maintenancePlan));
		}
	}
}
