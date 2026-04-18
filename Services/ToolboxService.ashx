<%@ WebHandler Language="C#" Class="ScreenConnect.ToolboxService" %>

using System;
using System.IO;
using System.Threading.Tasks;

namespace ScreenConnect
{
	[DemandPermission(PermissionInfo.ManageSharedToolboxPermission)]
	[ActivityTrace]
	public class ToolboxService : WebServiceBase
	{
		public async Task ProcessToolboxOperation(ToolboxOperation operation, string path, string originalPath)
		{
			if (operation == ToolboxOperation.Move || operation == ToolboxOperation.Delete)
			{
				bool DoesPathExist(string pathToCheck) => File.Exists(pathToCheck) || Directory.Exists(pathToCheck);

				if (!DoesPathExist(FileSystemExtensions.CombinePathsAndDemandInParent(
					FileSystemExtensions.GetAppDomainRelativePath(ConfigurationCache.ToolboxDirectoryPath),
					operation == ToolboxOperation.Move ? originalPath : path
				)))
					throw new NotSupportedException("Cannot edit virtual toolbox item");
			}

			await TaskExtensions.TryAsync(() => ServerToolboxExtensions.ProcessToolboxOperationAsync(operation, path, originalPath));
		}

		public void WriteToolboxFileContent(string path, bool isDirectory, bool appendOrReplace, string base64Content)
		{
			var physicalPath = FileSystemExtensions.CombinePathsAndDemandInParent(FileSystemExtensions.GetAppDomainRelativePath(ConfigurationCache.ToolboxDirectoryPath), path);

			if (isDirectory)
				Directory.CreateDirectory(physicalPath);
			else
				using (var fileStream = File.Open(physicalPath, appendOrReplace ? FileMode.Append : FileMode.Create))
					fileStream.WriteAllBytes(Convert.FromBase64String(base64Content));
		}

		public string GetToolboxItemDownloadUrl(string path)
		{
			return ToolboxItemHandler.GetUrl(path);
		}
	}
}
