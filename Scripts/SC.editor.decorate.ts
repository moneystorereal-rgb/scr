import { EditorView } from 'codemirror'
import { ViewUpdate, ViewPlugin, Decoration, DecorationSet } from '@codemirror/view'
import { EditorState, RangeSet, Range } from '@codemirror/state'
import { WidgetType } from '@codemirror/view'
import {filterInfosField, stringTableFacet} from './SC.editor.state'
import { HighlightStyle, defaultHighlightStyle, syntaxTree } from '@codemirror/language'
import { isBoundary, iterateTree, pipe } from './SC.editor.util'
import { FilterInfo } from './SC.editor.state'
import { SyntaxNode } from '@lezer/common'
import {tags} from '@lezer/highlight';
import { formatString } from "./SC.util";

class FilterExpressionWidget extends WidgetType {
	resultCount: number;

	constructor(resultCount: number) {
		super();
		this.resultCount = resultCount;
	}

	toDOM(view: EditorView): HTMLElement {
		const span = document.createElement('SPAN');
		span.className = 'cm-widget';
		span.innerText = formatString(view.state.facet(stringTableFacet).SubExpressionResultsTextFormat, this.resultCount);
		return span;
	}
}

function rangesOverlap(a: { from: number, to: number }, b: { from: number, to: number }) {
	return a.to >= b.from && a.from <= b.to;
}

function nonOverlapReducer<T>(rangeSelector: (item: T) => { from: number, to: number }) {
	return (accumulator: T[], currentValue: T) => {
		if (!accumulator.find(it => rangesOverlap(rangeSelector(it), rangeSelector(currentValue))))
			return [...accumulator, currentValue];

		return accumulator;
	}
}

export const decorate = () => [
	(ViewPlugin.fromClass(class {
		filterDecorations: DecorationSet

		constructor(view: EditorView) {
			this.filterDecorations = this.computeDecorations(view.state)
		}

		update(update: ViewUpdate) {
			this.filterDecorations = this.computeDecorations(update.state)
		}

		private computeDecorations(state: EditorState) {
			const filterInfos = state.field(filterInfosField, false)

			if (!filterInfos)
				return RangeSet.empty

			return Decoration.set(
				Array.from(iterateTree(syntaxTree(state).cursor()))
					.filter(it => it.node.type.name === 'BooleanExpression')
					.toSorted((a, b) => (a.to - a.from) - (b.to - b.from))
					.reduce(nonOverlapReducer(it => it), [])
					.toSorted((a, b) => a.to - b.to)
					.map(it => [it, filterInfos[state.sliceDoc(it.from, it.to)]])
					.filter(function (it): it is [SyntaxNode, FilterInfo] { return !!it[1] })
					.map(([node, filterInfo]) => [
						Decoration.mark({ class: 'cm-filter' }).range(node.from, node.to),
						pipe(state.doc.lineAt(node.to), it => (it.from > state.selection.main.anchor || it.to < state.selection.main.anchor) && isBoundary(it.text.substring(node.to - it.from)))
							? Decoration.widget({
								widget: new FilterExpressionWidget(filterInfo.Count),
								side: 1,
							}).range(node.to)
							: null,
					])
					.flat()
					.filter(function (it): it is Range<Decoration> { return !!it })
			)
		}
	}, {
		decorations: it => it.filterDecorations
	})),
];

export const syntaxTheme = HighlightStyle.define([
	...defaultHighlightStyle.specs,
	{ tag: tags.number, class: 'cm-number' },
	{ tag: tags.string, class: 'cm-string' },
	{ tag: tags.propertyName, class: 'cm-property-name' },
	{ tag: tags.controlKeyword, class: 'cm-control-keyword' },
	{ tag: tags.variableName, class: 'cm-variable-name' },
	{ tag: tags.logicOperator, class: 'cm-logic-operator' },
	{ tag: tags.compareOperator, class: 'cm-compare-operator' },
]);
