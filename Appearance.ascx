<%@ Control %>

<dl class="AppearanceList"></dl>

<script>

	const CustomizationStateFilter = SC.util.createEnum(['All', 'Customized', 'NotCustomized']);
	const DataTypeFilter = SC.util.createEnum(['All', 'Image', 'Text']);
	const ResourceTypeFilter = SC.util.createEnum(['All', 'Web', 'Client']);
	const SortingOption = SC.util.createEnum(['Popularity', 'AscendingKey', 'DescendingKey']);

	function createTableCell(resource, cultureKey, additionalProperties) {
		const valueContainer = resource.ValueContainersByCultureKey[cultureKey] || {};
		// can't just say valueContainer.OverrideValue || valueContainer.DefaultValue because override can be empty string
		const value = valueContainer.OverrideValue == null ? valueContainer.DefaultValue : valueContainer.OverrideValue;
		return $td(
			{ _dataItem: cultureKey, _classNameMap: { 'Overridden': valueContainer.OverrideValue != null }, ...additionalProperties },
			$div(resource.IsImage && value ? SC.ui.createSimpleImageElement(value) : value)
		);
	}

	function createThemeThumbnail(themeName) {
		const thumbnailPath = 'App_Themes/' + themeName + '/' + themeName + '.png';
		const defaultThumbnailPath = 'App_Themes/DefaultThemeThumbnail.png';
		return $img({
			src: thumbnailPath,
			_eventHandlerMap: {
				'error': () => {
					if (!this.src.endsWith(defaultThumbnailPath))
						this.src = defaultThumbnailPath;
				},
			},
		});
	}

	SC.event.addGlobalHandler(SC.event.PreRender, () =>
		SC.pagedata.notifyDirty()
	);

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, () =>
		SC.service.GetThemeInfo(themeInfo => SC.service.GetResourceInfo(resourceListInfo => SC.pagedata.set({ themeInfo, resourceListInfo })))
	);

	SC.event.addGlobalHandler(SC.event.PageDataRefreshed, () => {
		const themeInfo = SC.pagedata.get().themeInfo;
		const resourceListInfo = SC.pagedata.get().resourceListInfo;
		const columnCultures = resourceListInfo.Cultures.filter(culture => culture.CultureKey !== resourceListInfo.InvariantCultureKey);

		let filterText = '';
		let sortingOption = SortingOption.Popularity;
		let activeFilterMap = {
			CustomizationStateFilter: CustomizationStateFilter.All,
			DataTypeFilter: DataTypeFilter.All,
			ResourceTypeFilter: ResourceTypeFilter.All,
		};

		let sortingOptionLink, filterPanelLink, resourcePanel, resourceTableBody;

		SC.ui.setContents(document.querySelector('.AppearanceList'), [
			$dt($h3({ _textResource: 'AppearancePanel.VisualThemeLabelText' })),
			$dd({ _dataItem: themeInfo, className: 'ThemeSelectorContentPanel' }, [
				$div({ _commandName: 'ChangeTheme', className: 'ChangeThemeButton' }, [
					createThemeThumbnail(themeInfo.CurrentThemeName),
					$span(themeInfo.CurrentThemeName),
				]),
			]),

			$dt([
				$h3({ _textResource: 'AppearancePanel.ResourcesLabelText' }),
				$div({ className: 'FlexSpacer' }),
				$div([
					$span({ className: 'LabelText', _textResource: 'SortPanel.LabelText' }),
					sortingOptionLink = $a({ _commandName: 'OpenSortingPopup' }),
				]),
				$div([
					$span({ className: 'LabelText', _textResource: 'FilterPanel.LabelText' }),
					filterPanelLink = $a({ _commandName: 'OpenFilterPopup' }),
				]),
				$div({ className: 'FilterBoxPanel' },
					SC.ui.createFilterBox({ placeholder: SC.res['ResourcesFilterBox.PlaceholderText'] }, eventArgs => {
						filterText = eventArgs.target.value;
						updateResourceTable();
					}),
				),
			]),

			resourcePanel = $dd({ className: 'ResourcePanel' }, [
				$div({ className: 'EmptyPanel' }, [
					$p($img({ src: 'Images/Search.svg' })),
					$h2({ _textResource: 'AppearancePanel.ResourcesTable.EmptyTitle' }),
					$p({ _textResource: 'AppearancePanel.ResourcesTable.EmptyMessage' }),
				]),
				$table({ className: 'DataTable', _dataItem: resourceListInfo }, [
					$thead([
						$tr([
							$th(),
							$th({ _textResource: 'AppearancePanel.KeyHeaderText' }),
							columnCultures.map(it => $th(it.DisplayName)),
						]),
					]),
					resourceTableBody = $tbody({ className: 'ResourceTableBody' }),
				]),
			]),
		]);

		function updateResourceTable() {
			const filteredResources = resourceListInfo.Resources
				.filter(resource => !filterText || SC.util.containsText(
					[resource.Key, ...(resource.IsImage ? [] : Object.values(resource.ValueContainersByCultureKey).flatMap(it => [it.OverrideValue, it.DefaultValue]))],
					filterText
				))
				.filter(resource =>
					activeFilterMap.CustomizationStateFilter === CustomizationStateFilter.All
					|| (activeFilterMap.CustomizationStateFilter === CustomizationStateFilter.Customized && Object.values(resource.ValueContainersByCultureKey).some(it => it.OverrideValue != null))
					|| (activeFilterMap.CustomizationStateFilter === CustomizationStateFilter.NotCustomized && Object.values(resource.ValueContainersByCultureKey).every(it => it.OverrideValue == null))
				)
				.filter(resource =>
					activeFilterMap.DataTypeFilter === DataTypeFilter.All
					|| (activeFilterMap.DataTypeFilter === DataTypeFilter.Image && resource.IsImage)
					|| (activeFilterMap.DataTypeFilter === DataTypeFilter.Text && !resource.IsImage)
				)
				.filter(resource =>
					activeFilterMap.ResourceTypeFilter === ResourceTypeFilter.All
					|| activeFilterMap.ResourceTypeFilter === resource.ResourceType
				);

			const activeFilterDisplayString = [
				activeFilterMap.CustomizationStateFilter !== CustomizationStateFilter.All && SC.res[`FilterPopout.CustomizationStateFilter.${activeFilterMap.CustomizationStateFilter}LabelText`],
				activeFilterMap.DataTypeFilter !== DataTypeFilter.All && SC.res[`FilterPopout.DataTypeFilter.${activeFilterMap.DataTypeFilter}LabelText`],
				activeFilterMap.ResourceTypeFilter !== ResourceTypeFilter.All && SC.res[`FilterPopout.ResourceTypeFilter.${activeFilterMap.ResourceTypeFilter}LabelText`],
			].filter(Boolean).join(', ') || SC.res['FilterPopout.AllResourcesLabelText'];

			SC.ui.setContents(sortingOptionLink, SC.res[`Command.${sortingOption}.Text`]);
			SC.ui.setContents(filterPanelLink, activeFilterDisplayString);
			SC.css.ensureClass(resourcePanel, 'Empty', filteredResources.length === 0);
			SC.ui.setContents(resourceTableBody,
				filteredResources
					.sort((a, b) => {
						if (sortingOption === SortingOption.Popularity && b.PopularityIndex !== a.PopularityIndex) {
							return b.PopularityIndex - a.PopularityIndex;
						} else {
							const result = a.Key.localeCompare(b.Key);
							return sortingOption === SortingOption.DescendingKey ? -result : result;
						}
					})
					.map(resource => $tr({ _dataItem: resource, _classNameMap: { 'ImageResource': resource.IsImage, 'StringResource': !resource.IsImage } }, [
						$td({ className: 'ActionCell' }, SC.command.createCommandButtons([{ commandName: 'EditResource' }])),
						$td(resource.Key),
						resource.ValueContainersByCultureKey[resourceListInfo.InvariantCultureKey] ?
							createTableCell(resource, resourceListInfo.InvariantCultureKey, { colSpan: columnCultures.length }) :
							columnCultures.map(culture => createTableCell(resource, culture.CultureKey)),
					]))
			);
		}

		updateResourceTable();

		SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
			switch (eventArgs.commandName) {
				case "OpenSortingPopup":
					SC.popout.showPanelFromCommand(eventArgs, { sortingOption });
					break;

				case SortingOption.Popularity:
				case SortingOption.AscendingKey:
				case SortingOption.DescendingKey:
					sortingOption = eventArgs.commandName;
					updateResourceTable();
					break;

				case 'OpenFilterPopup':
					SC.ui.toggleFilterPopout(eventArgs.commandElement, { CustomizationStateFilter: CustomizationStateFilter, DataTypeFilter: DataTypeFilter, ResourceTypeFilter: ResourceTypeFilter }, activeFilterMap, updateResourceTable);
					break;

				case 'ResetFilter':
					activeFilterMap = {
						CustomizationStateFilter: CustomizationStateFilter.All,
						DataTypeFilter: DataTypeFilter.All,
						ResourceTypeFilter: ResourceTypeFilter.All,
					};
					updateResourceTable();
					break;

				case 'EditResource':
					const dataElements = SC.command.getEventDataElements(eventArgs);
					const resource = dataElements[0]._dataItem;
					const resourceListInfo = dataElements[1]._dataItem;

					SC.dialog.showModalDialog('EditResource', {
						titleResourceName: 'EditResourcePanel.Title',
						content: [
							$p({ _innerHTMLToBeSanitized: SC.util.formatString(SC.res['EditResourcePanel.Message'], resource.ResourceType, resource.Key) }),
							$table({ className: 'DataTable' }, [
								$thead([
									$tr([
										$th({ _textResource: 'EditResourcePanel.CultureHeader' }),
										$th({ _textResource: 'EditResourcePanel.ValueHeader' }),
									]),
								]),
								$tbody(
									resourceListInfo.Cultures.map(function (culture) {
										const valueContainer = resource.ValueContainersByCultureKey[culture.CultureKey];
										if (!valueContainer)
											return null;

										return $tr({ _dataItem: culture.CultureKey }, [
											$td(culture.DisplayName),
											$td(
												resource.IsImage
													? SC.ui.createDefaultCustomSelector(
														valueContainer.OverrideValue != null,
														SC.ui.createImageSelector(valueContainer.DefaultValue, true),
														SC.ui.createImageSelector(valueContainer.OverrideValue),
														SC.ui.getImageDataFromSelector
													)
													: SC.ui.createDefaultCustomSelector(
														valueContainer.OverrideValue != null,
														SC.ui.createTextBox({ value: valueContainer.DefaultValue || '', readOnly: true }, true),
														SC.ui.createTextBox({ value: valueContainer.OverrideValue || '' }, true),
														textBox => textBox.value
													)
											),
										]);
									})
								),
							]),
						],
						buttonTextResourceName: 'EditResourcePanel.ButtonText',
						onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
							const overrideValuesByCulture = {};

							for (const dialogRow of dialog.querySelectorAll('tbody tr')) {
								overrideValuesByCulture[dialogRow._dataItem] = SC.ui.getCustomValueFromDefaultCustomSelector(dialogRow);
							}

							SC.service.SaveResource(
								resource.ResourceType,
								resource.Key,
								resource.IsImage,
								overrideValuesByCulture,
								function () {
									for (const [key, value] of Object.entries(overrideValuesByCulture)) {
										resource.ValueContainersByCultureKey[key].OverrideValue = value;
									}

									updateResourceTable();
									closeDialogProc();
								},
								setDialogErrorProc
							);
						},
					});
					break;

				case 'ChangeTheme':
					const themeInfo = SC.command.getEventDataItem(eventArgs);
					let themePreviewFrame;

					function stealFocusFromIframe() {
						window.setTimeout(() => $('.ButtonPanel input').focus(), 1000); // reset the focus back to the button to make sure Esc and Enter works
					}

					SC.dialog.showModalDialog('SelectTheme', {
						titleResourceName: 'SelectThemePanel.Title',
						content: [
							$div({ className: 'ThemeSelectionBox' },
								themeInfo.ThemeNames.map(themeName =>
									$div({ _dataItem: themeName, _commandName: 'SelectPreviewTheme', className: themeName === themeInfo.CurrentThemeName ? 'Selected' : '' }, [
										createThemeThumbnail(themeName),
										$span(themeName),
									])
								)
							),
							$div({ className: 'PreviewPanel' }, [
								themePreviewFrame = $iframe({ src: SC.util.formatString(themeInfo.PreviewUrlFormat, themeInfo.CurrentThemeName), onload: stealFocusFromIframe }),
							]),
						],
						buttonTextResourceName: 'SelectThemePanel.ButtonText',
						onExecuteCommandProc: function (dialogEventArgs, dialog, closeDialogProc, setDialogErrorProc) {
							switch (dialogEventArgs.commandName) {
								case 'SelectPreviewTheme':
									const selectedPreviewThemeName = SC.command.getEventDataItem(dialogEventArgs);
									for (const it of $$('.ThemeSelectionBox > div')) {
										SC.css.ensureClass(it, 'Selected', it._dataItem === selectedPreviewThemeName);
									}

									themePreviewFrame.src = SC.util.formatString(themeInfo.PreviewUrlFormat, selectedPreviewThemeName);
									stealFocusFromIframe();
									break;

								case 'Default':
									SC.service.SetTheme($('.ThemeSelectionBox .Selected')._dataItem, () => SC.dialog.showModalActivityAndReload('Save', true), setDialogErrorProc);
									break;
							}
						},
					});

					$('.ThemeSelectionBox .Selected').scrollIntoView();
					break;
			}
		});
	});

	SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
		switch (eventArgs.area) {
			case "OpenSortingPopupPopoutPanel":
				Object.keys(SortingOption).forEach((option) => {
					eventArgs.buttonDefinitions.push({
						commandName: option,
						commandArgument: eventArgs.commandContext.sortingOption === option ? "Selected" : undefined,
					});
				});
				break;
		}
	});
</script>
