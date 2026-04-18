import { StateField, StateEffect, Facet } from '@codemirror/state'

export type FilterInfo = { Count: number }
export type FilterInfos = Record<string, FilterInfo>

export type SubExpressionInfo = { Results: { Value: string | number, Count: number }[] }
export type SubExpressionInfos = Record<string, SubExpressionInfo>

export type PropertyInfo = {}
export type PropertyInfos = Record<string, PropertyInfo>

export type VariableInfo = {}
export type VariableInfos = Record<string, VariableInfo>

export type StringTable = {
	PlaceholderText: string,
	TotalResultsTextFormat: string,
	SubExpressionResultsTextFormat: string,
}

export const stringTableFacet = Facet.define<StringTable, StringTable>({
	combine: (values) => values[0],
    static: true,
});

export const updateTotalResultCount = StateEffect.define<number | undefined>();
export const totalResultCountField = StateField.define<number | undefined>({
	create() { return undefined; },
	update(value, transaction) {
		for (const effect of transaction.effects)
			if (effect.is(updateTotalResultCount))
				return effect.value;

		return value;
	}
});

export const updateFilterInfos = StateEffect.define<FilterInfos>()
export const filterInfosField = StateField.define<FilterInfos>({
	create() { return {}; },
	update(value, transaction) {
		let newValue = { ...value };

		for (const effect of transaction.effects)
			if (effect.is(updateFilterInfos))
				for (const [filter, info] of Object.entries(effect.value))
					newValue[filter] = info;

		return newValue;
	}
});

export const updateSubExpressionInfos = StateEffect.define<SubExpressionInfos>()
export const subExpressionInfosField = StateField.define<SubExpressionInfos>({
	create() { return {}; },
	update(value, transaction) {
		let newValue = { ...value };

		for (const effect of transaction.effects)
			if (effect.is(updateSubExpressionInfos))
				for (const [filter, info] of Object.entries(effect.value))
					newValue[filter] = info;

		return newValue;
	}
});
