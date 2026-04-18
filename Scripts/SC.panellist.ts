// @ts-nocheck

export function queryAndInitializePanels(container) {
	SC.event.dispatchEvent(container, SC.event.QueryPanels, { area: 'GuestActionPanel', panelDefinitions: [] }).panelDefinitions.forEach(function (panelDefinition) {
		var panel = SC.ui.addElement(container, 'DIV');
		panel._panelDefinition = panelDefinition;
		panelDefinition.initProc(panel);
	});
}

export function refreshPanels(container, userData) {
	var panels = container.childNodes;
	var visibilities = SC.util.createArray(panels.length, function () { return false; });
	var previousPassVisibleCount = 0;

	for (var pass = 1; pass <= 10; pass++) {
		var currentPassVisibleCount = 0;

		for (var panelIndex = 0; panels[panelIndex]; panelIndex++)
			if (!visibilities[panelIndex])
				if (visibilities[panelIndex] = (!panels[panelIndex]._panelDefinition.isVisibleProc || panels[panelIndex]._panelDefinition.isVisibleProc(pass, previousPassVisibleCount, userData)))
					currentPassVisibleCount++;

		previousPassVisibleCount += currentPassVisibleCount;
	}

	for (var i = 0; panels[i]; i++) {
		var wasVisible = SC.ui.isVisible(panels[i]);

		SC.ui.setVisible(panels[i], visibilities[i]);

		if (visibilities[i] && panels[i]._panelDefinition.refreshProc)
			panels[i]._panelDefinition.refreshProc(panels[i], userData, !wasVisible);
	}
}
