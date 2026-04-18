import * as Dialog from './SC.dialog';
import * as Event from './SC.event';
import * as UI from './SC.ui';

export interface TileDefinition {
	title?: string;
	titleResourceName?: string;
	titlePanelExtra?: HTMLElement;
	message?: string;
	content?: HTMLElement;
	significance?: number;
	fullSize?: boolean;
	initializeProc?: (tile: HTMLElement) => void;
}

export function queryTiles<T>(area: string, tileContext: T) {
	return Event.dispatchEvent(null, Event.QueryPanels, { area: area, tileDefinitions: [], tileContext: tileContext }).tileDefinitions;
}

export function queryAndCreateTiles<T>(area: string, tileContext: T) {
	var tileDefinitions = queryTiles(area, tileContext);
	return createSortedTiles(tileDefinitions);
}

export function queryAndAddTiles<T>(container: HTMLElement, area: string, tileContext: T) {
	var tileDefinitions = queryTiles(area, tileContext);
	addTiles(container, tileDefinitions);
}

export function addTiles(container: HTMLElement, tileDefinitions: TileDefinition[]) {
	createSortedTiles(tileDefinitions).forEach(function (it) { UI.addContent(container, it); });
}

export function createSortedTiles(tileDefinitions: TileDefinition[]) {
	return tileDefinitions
		.filter(Boolean)
		.sort(function (a, b) { return (b.significance || 0) - (a.significance || 0); })
		.map(function (it) {
			return createDashboardTile(it.fullSize ? 'FullSize' : '', it);
		});
}

export function createDashboardTile(subClassName: string, parameters: TileDefinition) {
	var tile = $div({ className: 'Tile ' + subClassName }, [
		$div({ className: 'TitlePanel' }, [
			$h2(parameters.title || (parameters.titleResourceName ? SC.res[parameters.titleResourceName] : '')),
			parameters.titlePanelExtra,
		]),
		Dialog.createContentPanel([
			parameters.message ? $p(parameters.message) : null,
			parameters.content,
		]),
	]);

	if (parameters.initializeProc) {
		parameters.initializeProc(tile);
	}

	return tile;
}
