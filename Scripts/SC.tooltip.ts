// @ts-nocheck

export function getPanel() {
	return $('tooltipPanel');
};

export function hidePanel() {
	var tooltipPanel = getPanel();

	if (!tooltipPanel)
		return false;

	SC.ui.discardElement(tooltipPanel);
	return true;
};

export function showPanel(popoutFrom, tooltipText) {
	var tooltipPanel = SC.ui.addElement(document.body, 'DIV', { id: 'tooltipPanel', className: 'TooltipPanel' }, tooltipText);
	var popoutFromBounds = popoutFrom.getBoundingClientRect();
	var popoutFromDirection = SC.css.tryGetExtendedCssValueFromElement(popoutFrom, 'tooltip-popout-from');
	var popoutFromAbsoluteBounds = SC.ui.getAbsoluteBounds(popoutFrom);

	if (popoutFromDirection == 'up' || (popoutFromDirection == 'down' && popoutFromBounds.bottom + tooltipPanel.offsetHeight > document.body.offsetHeight)) {
		SC.ui.setLocation(tooltipPanel, popoutFromAbsoluteBounds.horizontalCenter, popoutFromAbsoluteBounds.top - tooltipPanel.offsetHeight);
		SC.css.ensureClass(tooltipPanel, 'PopoutFromTop', true);
		SC.css.runElementAnimation(tooltipPanel, 'TooltipScaleUpFromTop');
	} else if (popoutFromDirection == 'down' || (popoutFromDirection == 'up' && popoutFromBounds.top - tooltipPanel.offsetHeight < 0)) {
		SC.ui.setLocation(tooltipPanel, popoutFromAbsoluteBounds.horizontalCenter, popoutFromAbsoluteBounds.bottom);
		SC.css.ensureClass(tooltipPanel, 'PopoutFromBottom', true);
		SC.css.runElementAnimation(tooltipPanel, 'TooltipScaleUpFromBottom');
	} else if (popoutFromDirection == 'left' || (popoutFromDirection == 'right' && popoutFromBounds.right + tooltipPanel.offsetWidth > document.body.offsetWidth)) {
		SC.ui.setLocation(tooltipPanel, popoutFromAbsoluteBounds.left - tooltipPanel.offsetWidth, popoutFromAbsoluteBounds.verticalCenter);
		SC.css.ensureClass(tooltipPanel, 'PopoutFromLeft', true);
		SC.css.runElementAnimation(tooltipPanel, 'TooltipScaleUpFromLeft');
	} else { // right
		SC.ui.setLocation(tooltipPanel, popoutFromAbsoluteBounds.right, popoutFromAbsoluteBounds.verticalCenter);
		SC.css.ensureClass(tooltipPanel, 'PopoutFromRight', true);
		SC.css.runElementAnimation(tooltipPanel, 'TooltipScaleUpFromRight');
	}
}
