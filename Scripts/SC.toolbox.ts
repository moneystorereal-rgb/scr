// @ts-nocheck

export function sendFilesToSharedToolbox(entries, destinationDirectoryAsArrayInToolbox, completeProc) {
	var fileUploadProc = function (file, path, uploadCompleteProc) {
		if (file.size <= Math.pow(2, 30)) {
			var fileReader = new FileReader();
			var chunkSize = 2883584; // approximate largest chunk size that can be sent
			var offset = 0;

			var startFileUpload = function (start, end) {
				fileReader.readAsDataURL(file.slice(start, end));
			}

			fileReader.onerror = function () {
				SC.dialog.showModalErrorBox(fileReader.error instanceof FileError ? 'FileReader error - code: ' + fileReader.error.code : fileReader.error.name + ': ' + fileReader.error.message);
				uploadCompleteProc();
			};

			fileReader.onload = function (event) {
				var base64Content = event.target.result; // result may be null if on Edge and reading an empty file
				var headerIndex = base64Content ? base64Content.indexOf(',') : 0;

				base64Content = headerIndex > 0 ? base64Content.slice(headerIndex + 1) : '';

				SC.service.WriteToolboxFileContent(SC.util.combinePath(path, file.name), false, offset != 0, base64Content, function () {
					offset += chunkSize;

					if (offset <= file.size)
						startFileUpload(offset, offset + chunkSize);
					else
						uploadCompleteProc();
				});
			};

			startFileUpload(offset, chunkSize);
		} else {
			uploadCompleteProc();
		}
	};

	var handleEntries = function (entries, basePath, completeProc) {
		if (entries.length > 0) {
			var entry = entries.shift();
			if (entry.isDirectory) {
				SC.service.WriteToolboxFileContent(SC.util.combinePath(basePath, entry.name), true, null, null, function () {
					entry.createReader().readEntries(function (e) {
						handleEntries(e, SC.util.combinePath(basePath, entry.name), function () {
							if (entries.length > 0)
								handleEntries(entries, basePath, completeProc);
							else
								completeProc();
						});
					});
				});
			} else {
				var handleFileUpload = function (file, basePath) {
					fileUploadProc(file, basePath, function () {
						if (entries.length == 0)
							completeProc();
						else
							handleEntries(entries, basePath, completeProc);
					});
				};

				if (entry.isFile) {
					entry.file(function (file) {
						// have to convert to file
						handleFileUpload(file, basePath);
					});
				} else {
					// base File type
					handleFileUpload(entry, basePath);
				}
			}
		} else {
			completeProc();
		}
	};

	handleEntries(
		Array.from(
			entries,
			function (e) {
				return e.getAsEntry && e.getAsEntry() ||
					e.webkitGetAsEntry && e.webkitGetAsEntry() ||
					typeof e.getAsFile === 'function' && e.getAsFile() ||
					e;
			}),
		destinationDirectoryAsArrayInToolbox,
		completeProc
	);
};

export function showToolboxDialog(commandName: string,
	runProc: (
		path: string,
		sessionEventType: number,
		onSuccess: (result, userContext) => void,
		onError: (result, userContext) => boolean
	) => void
) {
	// hopefully the only state that we will need
	var currentDragElement;

	var mainContentPanel;
	var directoryPanel;
	var listPanel;
	var fileLoadingOverlay;
	var toolboxPanel;
	var editModeInput;
	const runToolOptions = SC.util.createEnum(['RunToolInCurrentUserSession', 'RunToolElevated', 'RunToolSilentElevated']);
	const runToolOptionsToTypeMap = {
		[runToolOptions.RunToolInCurrentUserSession]: { SessionEventType: SC.types.SessionEventType.QueuedTool, Permission: SC.types.SessionPermissions.RunSharedTool },
		[runToolOptions.RunToolElevated]: { SessionEventType: SC.types.SessionEventType.QueuedElevatedTool, Permission: SC.types.SessionPermissions.RunSharedTool },
		[runToolOptions.RunToolSilentElevated]: { SessionEventType: SC.types.SessionEventType.QueuedSilentElevatedTool, Permission: SC.types.SessionPermissions.RunSharedToolAsSystemSilently },
	};
	var selectedRunToolOption = runToolOptions.RunToolInCurrentUserSession;
	var buttonPanel;

	var toolboxDialogComponents = [
		SC.dialog.createTitlePanel(SC.res['Command.' + commandName + '.ButtonText']),
		mainContentPanel = SC.dialog.createContentPanel([
			$p(SC.res['Command.' + commandName + '.Message']),
			$div({ className: 'ToolboxHeader' }, [
				$div({ className: 'ToolboxActionPanel' }, SC.command.createCommandButtons([
					{ commandName: 'StartCreateToolboxDirectory' },
					{ commandName: 'UploadToolboxFile' },
				])),
				$div({ className: 'TogglePanel', _visible: runProc && SC.context.canManageSharedToolbox }, [
					$span({ _textResource: 'ToolboxDialog.TogglePanel.Label' }),
					$label({ className: 'ToggleButton' }, [
						editModeInput = $input({ type: 'checkbox', checked: !runProc, _commandName: 'ToggleToolboxMode' }),
						$span({ className: 'Slider' }),
					]),
				]),
			]),
			toolboxPanel = $div({ className: 'ToolboxPanel' }, [
				$div({ className: 'EmptyPanel' }, $p({ _textResource: 'ToolboxDialog.EmptyPanelText' })),
				directoryPanel = $div({ className: 'DirectoryPanel' }),
				listPanel = $div({ className: 'ListPanel' }),
				fileLoadingOverlay = $div({
					className: 'FileLoadingOverlay Loading',
					_eventHandlerMap: {
						'drop': function (eventArgs) {
							eventArgs.preventDefault();
						},
						'dragover': function (eventArgs) {
							eventArgs.preventDefault();
							eventArgs.stopPropagation();
							eventArgs.dataTransfer.dropEffect = 'none';
						},
					},
				}),
			]),
		]),
		buttonPanel = SC.dialog.createButtonPanel(SC.res['ToolboxDialog.ButtonText'],
			$div([
				$select({ _commandName: 'ChangeRunToolOption' }, [
					Object.keys(runToolOptions).map(function (runToolOption) {
						return $option({
							value: runToolOption,
							_textResource: 'ToolboxDialog.RunToolOption.' + runToolOption + '.Text',
							selected: runToolOption === selectedRunToolOption,
						});
					}),
				]),
			])
		),
	];

	function showToolboxOperationError(error) {
		SC.ui.setVisible(buttonPanel, true);
		SC.dialog.setButtonPanelError(buttonPanel, error);
		SC.css.ensureClass(fileLoadingOverlay, 'Loading', false);
	};

	function updateToolboxItemsState() {
		var inEditMode = isInEditMode();

		function syncDragAndDropHandlersWithCurrentState(element) {
			if (inEditMode)
				element._activateDragAndDropHandlers();
			else
				element._deactivateDragAndDropHandlers();
		};

		Array.from(toolboxPanel.querySelectorAll('.ToolboxButton')).forEach(function (element) {
			if (element._isDragAndDropTarget)
				syncDragAndDropHandlersWithCurrentState(element);

			if (SC.ui.findAncestor(element, function (it) { return it.isSameNode(directoryPanel); }) == null)
				element.draggable = inEditMode;
		});

		syncDragAndDropHandlersWithCurrentState(listPanel);
	};

	function isInEditMode() {
		return editModeInput.checked;
	};

	function getToolboxAndRenderPath(pathAsArray, completeProc) {
		function renderToolboxPath(pathAsArray, toolbox) {
			function createItemLink(toolboxItem, pathToToolboxItemAsArray, isDirectoryPanelItem) {
				var isDirectory = (toolboxItem.Attributes & SC.types.ToolboxItemAttributes.Directory) > 0;

				var toolboxButton = $div(
					{
						_commandName: 'Select',
						_commandArgument: toolboxItem.Name,
						_dataItem: { pathAsArray: pathToToolboxItemAsArray, isDirectory: isDirectory },
						title: toolboxItem.Name,
						className: 'ToolboxButton',
					},
					$img({ className: 'FileIcon', src: SC.ui.createDataUri(toolboxItem.Image) }),
					$span({ className: 'FileName' }, toolboxItem.Name),
					$a({ _commandName: 'ShowToolboxButtonPopupMenu' })
				);

				// directory panel toolbox buttons should never be draggable (see updateToolboxItemsState)
				// we need to store what element is being dragged because the ondrag event protects its data so we can't figure out almost anything about what triggered the drag/drop
				// tried to do it stateless but the amount of awful code needed made state a better option at the time
				if (!isDirectoryPanelItem) {
					SC.event.addHandler(toolboxButton, 'dragstart', function (eventArgs) {
						currentDragElement = toolboxButton;
						eventArgs.dataTransfer.setData('text/plain', SC.command.getDataItem(eventArgs.target).pathAsArray.join('\\'));
					});

					SC.event.addHandler(toolboxButton, 'dragend', function () {
						currentDragElement = null;
					});
				}

				if (isDirectory)
					addDragAndDropHandlersToToolboxElement(toolboxButton, pathToToolboxItemAsArray);
				else
					SC.event.addHandler(toolboxButton, 'dragleave', function (eventArgs) { eventArgs.stopPropagation(); });

				return toolboxButton;
			};

			SC.popout.hidePanel();
			SC.dialog.enableOrDisableButtonPanelButtons(buttonPanel, false);

			var pathItems = [toolbox];

			pathAsArray.forEach(function (pathPart) {
				pathItems.push(
					pathItems[pathItems.length - 1].Items.find(function (item) { return item.Name === pathPart; })
				);
			});

			SC.ui.setContents(
				directoryPanel,
				pathItems.map(function (item, index) {
					return $span(createItemLink(item, pathAsArray.slice(0, index), true));
				})
			);

			var toolboxIsEmpty = toolbox.Items.length == 0;
			mainContentPanel._dataItem = { pathAsArray: pathAsArray, isDirectory: true }; // we use the mainContentPanel to store the root _dataItem because we want to grab this value if the event came from the listPanel or from a ToolboxActionPanel command button
			SC.ui.setContents(
				listPanel,
				toolboxIsEmpty ?
					$p({ _htmlResource: 'Command.Toolbox.EmptyMessage' }) :
					pathItems[pathItems.length - 1].Items.map(function (item) {
						return createItemLink(item, pathAsArray.concat(item.Name), false);
					})
			);

			updateToolboxItemsState();

			SC.css.ensureClass(toolboxPanel, 'Empty', toolboxIsEmpty);
			SC.css.ensureClass(toolboxPanel, 'Root', pathItems.length == 1);
			SC.css.ensureClass(fileLoadingOverlay, 'Loading', false);
		};

		SC.service.GetToolbox(function (toolbox) {
			renderToolboxPath(pathAsArray, toolbox);
			SC.css.ensureClass(fileLoadingOverlay, 'Loading', false);

			if (completeProc)
				completeProc(toolbox);
		});
	};

	function uploadFileProc(entries, pathAsArray) {
		SC.css.ensureClass(fileLoadingOverlay, 'Loading', true);

		sendFilesToSharedToolbox(
			entries,
			pathAsArray,
			function () {
				getToolboxAndRenderPath(pathAsArray);
			}
		);
	};

	function hasPermissionForRunToolOption(runToolOption) {
		for (session of window.getSelectedSessionsContext().sessions) {
			if ((session.Permissions & runToolOptionsToTypeMap[runToolOption]?.Permission) === 0)
				return false;
		}

		return true;
	}

	function addDragAndDropHandlersToToolboxElement(toolboxElement, pathToToolboxItemAsArray) {
		function isValidDropTarget() {
			// if currentDragElement is null/undefined, this came from outside the DOM so allow it to drop anywhere
			return !currentDragElement || (!toolboxElement.isSameNode(currentDragElement) && !SC.util.areArraysEqual(SC.command.getDataItem(toolboxElement).pathAsArray, SC.command.getDataItem(mainContentPanel).pathAsArray));
		};

		function clearDragEnterElements(includeSelf) {
			toolboxPanel.querySelectorAll('.DragEnter').forEach(function (element) {
				if (element !== toolboxElement || includeSelf)
					SC.css.ensureClass(element, 'DragEnter', false);
			});
		};

		SC.ui.addDragAndDropHandlersToElement(
			toolboxElement,
			function (dropEventArgs) {
				// we don't wrap these with isValidDropTarget because if the user dropped on an invalid drop target, we wouldn't want that event to propagate up and be handled incorrectly
				// we also need to clear any state
				dropEventArgs.stopPropagation();
				dropEventArgs.preventDefault();

				clearDragEnterElements(true);

				if (isValidDropTarget()) {
					if (!pathToToolboxItemAsArray)
						pathToToolboxItemAsArray = SC.command.getDataItem(dropEventArgs.currentTarget).pathAsArray;

					// datatransfer.items is always included in drag and drop events, so we cannot use them to determine if anything is being uploaded.
					if (dropEventArgs.dataTransfer.files.length > 0)
						uploadFileProc(dropEventArgs.dataTransfer.items ? dropEventArgs.dataTransfer.items : dropEventArgs.dataTransfer.files, pathToToolboxItemAsArray);
					else {
						var itemToMovePath = dropEventArgs.dataTransfer.getData('text');
						var currentPathAsArray = itemToMovePath.split('\\');

						SC.css.ensureClass(fileLoadingOverlay, 'Loading', true);
						SC.service.ProcessToolboxOperation(SC.types.ToolboxOperation.Move, pathToToolboxItemAsArray.concat(currentPathAsArray.pop()).join('/'), itemToMovePath.replace(/\\/g, '/'), function () {
							getToolboxAndRenderPath(currentPathAsArray);
						}, showToolboxOperationError);
					}
				}
			},
			function (dragOverEventArgs) {
				// we have to use drag over because the inner toolbox elements of the list panel prevent proper usage of dragenter
				dragOverEventArgs.stopPropagation();
				dragOverEventArgs.preventDefault();

				if (isValidDropTarget()) {
					dragOverEventArgs.dataTransfer.dropEffect = 'copy';

					// the list panel is troublesome in that when you enter a child element that is a valid drag over target
					// it doesn't get a drag leave which throws off any clean implementation
					// thus, this is why this is needed in the drag over handler
					clearDragEnterElements();
					SC.css.ensureClass(toolboxElement, 'DragEnter', true);
				} else {
					dragOverEventArgs.dataTransfer.dropEffect = 'none';
				}
			},
			function (dragLeaveEventArgs) {
				dragLeaveEventArgs.stopPropagation();
				SC.css.ensureClass(toolboxElement, 'DragEnter', false);
			},
			true // let updateToolboxItemsState handle drag and drop state state
		);
	};

	addDragAndDropHandlersToToolboxElement(listPanel);

	SC.event.addHandler(mainContentPanel, 'dragover', function (eventArgs) {
		eventArgs.preventDefault();
		SC.css.ensureClass(listPanel, 'DragEnter', false);
	});

	getToolboxAndRenderPath([], function () {
		SC.dialog.showModalDialogRaw(
			(!isInEditMode() ? 'RunToolboxMode RunToolAvailable ' : '') + 'ToolboxDialog',
			toolboxDialogComponents,
			function (eventArgs) {
				var listPanel = $('.ToolboxPanel .ListPanel');
				var selectedItem = Array.from(listPanel.childNodes).find(function (_) { return SC.ui.isSelected(_); });
				var dataItem = SC.command.getEventDataItem(eventArgs) || SC.command.getDataItem(selectedItem);
				var pathAsArray = dataItem?.pathAsArray;
				var isDirectory = dataItem?.isDirectory;

				switch (eventArgs.commandName) {
					case 'StartCreateToolboxDirectory':
						getToolboxAndRenderPath(pathAsArray, function () {
							var toolboxPanel = $('.ToolboxPanel');
							var input = SC.ui.createEditableInput('ProcessCreateToolboxDirectory', { className: 'RenameToolboxItemInput' }, function () { getToolboxAndRenderPath(pathAsArray); });
							var newToolboxButton = $div({ className: 'ToolboxButton' }, [
								$img({ src: '../Images/ToolboxFolder.png' }),
								input
							]);

							if (SC.css.containsClass(toolboxPanel, 'Empty'))
								SC.ui.setContents(listPanel, newToolboxButton);
							else
								listPanel.appendChild(newToolboxButton);

							SC.css.ensureClass(toolboxPanel, 'Empty', false);
							input.focus();
						});
						break;
					case 'ProcessCreateToolboxDirectory':
						SC.service.ProcessToolboxOperation(SC.types.ToolboxOperation.CreateDirectory, SC.util.combinePath(pathAsArray, eventArgs.commandArgument), null, function () {
							getToolboxAndRenderPath(pathAsArray);
						});
						break;
					case 'UploadToolboxFile':
						SC.ui.promptUserUploadFile(function (uploadEventArgs) {
							uploadFileProc(uploadEventArgs.currentTarget.files, pathAsArray);
							uploadEventArgs.currentTarget.value = '';
						});
						break;
					case 'ToggleToolboxMode':
						// there are 2 things we need to handle to ensure cohesive state: render and state change
						// on render, we need to respect whether or not it's in edit mode
						// on state change, we have to update the existing elements to be aligned with new state
						// this particular command deals with updating existing elements to be aligned with new state
						SC.css.toggleClass($('.ToolboxDialog'), 'RunToolboxMode');
						updateToolboxItemsState();
						break;
					case 'DownloadToolboxItem':
						SC.service.GetToolboxItemDownloadUrl(pathAsArray.join('/'), function (url) { SC.util.launchUrl(url); });
						break;
					case 'DeleteToolboxItem':
						SC.popout.showConfirmationDialog(
							SC.event.getElement(eventArgs),
							SC.util.formatString(SC.res['DeleteToolboxItemPanel.MessageFormat'], pathAsArray.join('/')),
							SC.res['DeleteToolboxItemPanel.DeleteText'],
							SC.res['DeleteToolboxItemPanel.CancelText'],
							function () {
								SC.css.ensureClass(SC.event.getElement(eventArgs), 'MarkedForDeletion', true);
								SC.service.ProcessToolboxOperation(SC.types.ToolboxOperation.Delete, pathAsArray.join('/'), null, function () {
									getToolboxAndRenderPath(pathAsArray.slice(0, -1));
								}, showToolboxOperationError);
							}
						);
						break;
					case 'StartRenameToolboxItem':
						var input;
						var editableToolboxItem;

						listPanel.replaceChild(
							editableToolboxItem = $div({ className: 'ToolboxButton', _dataItem: dataItem }, [
								SC.event.getElement(eventArgs).parentElement.querySelector('.FileIcon').cloneNode(),
								input = SC.ui.createEditableInput(
									'ProcessRenameToolboxItem',
									{ value: SC.event.getElement(eventArgs).parentElement.querySelector('.FileName').innerText, className: 'RenameToolboxItemInput' },
									function () { listPanel.replaceChild(SC.event.getElement(eventArgs).parentElement, editableToolboxItem); }
								),
							]),
							SC.event.getElement(eventArgs).parentElement
						);

						input.focus();
						input.select();
						break;
					case 'ProcessRenameToolboxItem':
						SC.service.ProcessToolboxOperation(SC.types.ToolboxOperation.Move, SC.util.combinePath(pathAsArray.slice(0, -1), eventArgs.commandArgument), pathAsArray.join('/'), function () {
							getToolboxAndRenderPath(pathAsArray.slice(0, -1));
						}, showToolboxOperationError);
						break;
					case 'NavigateDirectory':
						getToolboxAndRenderPath(pathAsArray);
						break;
					case 'Select':
						if (SC.ui.findAncestor(SC.event.getElement(eventArgs), function (_) { return SC.css.containsClass(_, 'DirectoryPanel'); }))
							getToolboxAndRenderPath(pathAsArray);
						else if (eventArgs.isIntense) {
							if (isDirectory)
								getToolboxAndRenderPath(pathAsArray);
							else if (runProc && SC.css.containsClass($('.ToolboxDialog'), 'RunToolboxMode') && hasPermissionForRunToolOption(selectedRunToolOption))
								runProc(pathAsArray.join('/'), runToolOptionsToTypeMap[selectedRunToolOption].SessionEventType, () => SC.dialog.hideModalDialog());
						} else {
							Array.from($('.ListPanel').childNodes).forEach(function (_) { SC.ui.setSelected(_, _._commandArgument == eventArgs.commandArgument); });
							SC.dialog.enableOrDisableButtonPanelButtons(buttonPanel, !isDirectory && hasPermissionForRunToolOption(selectedRunToolOption));
						}
						break;
					case 'ShowToolboxButtonPopupMenu':
						SC.popout.togglePanel(eventArgs.commandElement, function (popoutPanel) {
							popoutPanel._dataItem = dataItem;

							SC.ui.setContents(popoutPanel,
								$div({ className: 'CommandList' },
									['StartCreateToolboxDirectory', 'UploadToolboxFile', 'DownloadToolboxItem', 'DeleteToolboxItem', 'StartRenameToolboxItem'].map(function (commandName) {
										return $a({ _commandName: commandName }, $span({ _textResource: 'Command.' + commandName + '.Text' }));
									})
								)
							);

							SC.event.addHandler(popoutPanel, SC.event.QueryCommandButtonState, function (eventArgs) {
								switch (eventArgs.commandName) {
									case 'StartCreateToolboxDirectory':
									case 'UploadToolboxFile':
										eventArgs.isVisible = isDirectory;
										break;
									case 'DownloadToolboxItem':
										eventArgs.isVisible = !isDirectory;
										break;
								}
							});

							SC.command.updateCommandButtonsState(popoutPanel);
						});
						break;
					case 'ChangeRunToolOption':
						selectedRunToolOption = eventArgs.clickedElement.value;

						if (!isDirectory && pathAsArray && pathAsArray.length > 0)
							SC.dialog.enableOrDisableButtonPanelButtons(buttonPanel, hasPermissionForRunToolOption(selectedRunToolOption));
						break;
					case 'Run':
					case 'Default':
						if (runProc) runProc(pathAsArray.join('/'), runToolOptionsToTypeMap[selectedRunToolOption].SessionEventType, () => SC.dialog.hideModalDialog());
						break;
				}
			}
		);
	});
};
