import { EditorView } from 'codemirror'
import { hoverTooltip, tooltips } from '@codemirror/view'
import { SearchCursor } from '@codemirror/search'
import { filterInfosField } from './SC.editor.state'

export const filterHover = hoverTooltip(
	(view, pos, side) => {
		let filterInfos = view.state.field(filterInfosField, false);

		if (!filterInfos)
			return null;

		var rangeInfos = Object.entries(filterInfos)
			.map(([filter, info]) =>
				Array.from(new SearchCursor(view.state.doc, filter))
					.map(it => ({ filter, info, range: it }))
			)
			.flat()
			.toSorted((a, b) => (a.range.to - a.range.from) - (b.range.to - b.range.from))

		var index = rangeInfos.findIndex(it => it.range.from <= pos && it.range.to >= pos);

		if (index < 0)
			return null;

		var pos = Math.max(...rangeInfos.slice(0, index).filter(it => it.range.from <= rangeInfos[index].range.from).map(it => it.range.to), rangeInfos[index].range.from);
		var end = Math.min(...rangeInfos.slice(0, index).filter(it => it.range.to >= rangeInfos[index].range.to).map(it => it.range.from), rangeInfos[index].range.to);

		return {
			pos,
			end,
			above: true,
			arrow: true,
			create(view: EditorView) {
				let dom = document.createElement('div')
				//dom.className = 'subExpression tooltip';
				dom.innerText = `${rangeInfos[index].filter}: ${rangeInfos[index].info.Count}`;
				//dom.innerText = rangeInfos.map(it => it.subExpression).join('\n');
				return {
					dom,
					//offset: { x: -100, y: -100 } // doesn't seem to work?
				}
			}
		};
	},
	{ hoverTime: 1 /*ms*/ }
)

export const filterTooltip = () => [
	filterHover,
	tooltips()
];
