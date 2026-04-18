import { acceptCompletion, autocompletion, closeBracketsKeymap, completionKeymap, completionStatus, startCompletion } from '@codemirror/autocomplete'
import { defaultKeymap } from '@codemirror/commands'
import { bracketMatching, syntaxHighlighting, syntaxTree } from '@codemirror/language'
import { linter } from '@codemirror/lint'
import type { EditorState } from '@codemirror/state'
import { drawSelection, keymap, placeholder, showPanel, ViewPlugin } from '@codemirror/view'
import { EditorView } from 'codemirror'
import { decorate, syntaxTheme } from './SC.editor.decorate'
import { languageSupport } from './SC.editor.language'
import {
	filterInfosField,
	stringTableFacet,
	subExpressionInfosField,
	totalResultCountField,
	updateFilterInfos,
	updateSubExpressionInfos,
	updateTotalResultCount,
	type FilterInfos,
	type PropertyInfos,
	type StringTable,
	type SubExpressionInfos,
	type VariableInfos,
} from './SC.editor.state'
import { iterateTree } from './SC.editor.util'
import { formatString } from './SC.util'

const autocompletePlugin = (spec: { startOnMouseUp: boolean, startOnKeyUp: boolean, startOnFocus: boolean }) => ViewPlugin.fromClass(class {}, {
	eventHandlers: {
		mouseup: (e, view) => {
			if (spec.startOnMouseUp)
				startCompletion(view);
		},
		keyup: (e, view) => {
			if (spec.startOnKeyUp) // maybe we want to redefine this as 'startOnTextChange' or something because the Escape key handling below is a little hacky?
				if (!completionStatus(view.state) && e.key !== 'Escape')
					startCompletion(view);
		},
		focus: (e, view) => {
			if (spec.startOnFocus)
				startCompletion(view);
		},
	}
})

function getExpressionEditorInfoFromState(state: EditorState) {
	const tree = syntaxTree(state);
	return {
		text: state.doc.toString(),
		filters: Array.from(iterateTree(tree.cursor()))
			.filter(it => it.node.type.name === 'BooleanExpression')
			.map(it => state.sliceDoc(it.from, it.to)),
		subExpressions: Array.from(iterateTree(tree.cursor()))
			.filter(it => it.node.type.name === 'NonBooleanExpression')
			.map(it => state.sliceDoc(it.from, it.to)),
	}
}

export function getExpressionEditorInfo(expressionEditor: HTMLElement) {
	return getExpressionEditorInfoFromState(EditorView.findFromDOM(expressionEditor)!.state);
}

export function setExpressionEditorText(expressionEditor: HTMLElement, text: string) {
	const view = EditorView.findFromDOM(expressionEditor)!;
	view.dispatch({
		changes: {
			from: 0,
			to: view?.state.doc.length,
			insert: text,
		},
		selection: { anchor: text.length },
	})
}

export function setExpressionEditorResults(expressionEditor: HTMLElement, filterInfos?: FilterInfos, subExpressionInfos?: SubExpressionInfos, totalResultCount?: number) {
	EditorView.findFromDOM(expressionEditor)!.dispatch({
		effects: [
			updateFilterInfos.of(filterInfos ?? {}),
			updateSubExpressionInfos.of(subExpressionInfos ?? {}),
			updateTotalResultCount.of(totalResultCount),
		]
	})
}

type ExpressionEditorConfig = {
	propertyInfos: PropertyInfos | {},
	variableInfos: VariableInfos | {},
	stringTable: StringTable
}

export function createExpressionEditor(config: ExpressionEditorConfig) {
	const container = SC.ui.createElement('div', { className: 'ExpressionEditor' });
	new EditorView({
		extensions: [
			autocompletePlugin({
				startOnMouseUp: true,
				startOnKeyUp: true,
				startOnFocus: true,
			}),
			autocompletion({
				maxRenderedOptions: 500,
				activateOnTyping: false, // we want this, but we want more control also, so we do it in autocompletePlugin
			}),
			bracketMatching(),
			decorate(),
			drawSelection(),
			EditorView.lineWrapping,
			EditorView.updateListener.of(update => {
				if (update.docChanged || update.selectionSet) {
					SC.event.dispatchEvent(
						container,
						'changed',
						getExpressionEditorInfoFromState(update.state)
					);
				}
			}),
			keymap.of([
				...closeBracketsKeymap,
				...defaultKeymap,
				...completionKeymap,
				{ key: 'Tab', run: acceptCompletion },
			]),
			languageSupport({ propertyInfos: config.propertyInfos, variableInfos: config.variableInfos }),
			linter(view =>
				Array.from(iterateTree(syntaxTree(view.state).cursor()))
					.filter(it => it.node.type.isError && it.node.from < view.state.doc.length)
					.map(it => ({
						from: it.node.from,
						to: it.node.to,
						severity: 'error',
						message: '',
					}))
			),
			placeholder(config.stringTable.PlaceholderText),
			showPanel.of(() => {
				let dom = document.createElement('div');
				return {
					dom,
					update(update) {
						if (update.state.facet(stringTableFacet).TotalResultsTextFormat) {
							const totalResultCount = update.state.field(totalResultCountField, false);
							SC.ui.setVisible(dom, totalResultCount !== undefined);
							dom.textContent = formatString(update.state.facet(stringTableFacet).TotalResultsTextFormat, totalResultCount);
						}
					},
					top: false,
				}
			}),
			syntaxHighlighting(syntaxTheme),
			subExpressionInfosField, // no reason to have to call setExpressionEditorResults after this if we can initialize here (if required) ... or if there is another reason to call setExpressionEditorResults, we should resolve it elsewhere
			filterInfosField,
			totalResultCountField,
			stringTableFacet.of(config.stringTable),
			// EditorView.editorAttributes.of({ class: 'ExpressionEditor' }), // could add our own class name to editor if we want
		],
		parent: container
	});
	return container;
}
