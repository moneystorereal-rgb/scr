import { describe, it, expect } from 'vitest';
import { languageSupport } from './SC.editor.language'
import { compareTreeCorrectness } from './SC.editor.util';

const testLanguageSupport = languageSupport({
	propertyInfos: {
		TestProperty1: {},
		TestProperty2: {},
		TestLongerProperty: {},
	},
	variableInfos: {
		$USERNAME: {},
		$SERVERVERSION: {},
		$OTHERAND: {},
		$OTHEROR: {},
		$NOW: {},
		$2DAYSAGO: {},
	},
})

const expectWorse = (oldDoc: string, newDoc: string) =>
	expectCompareTreeCorrectness(oldDoc, newDoc, (result: number) => result < 0);

const expectNoImprovement = (oldDoc: string, newDoc: string) =>
	expectCompareTreeCorrectness(oldDoc, newDoc, (result: number) => result <= 0);

const expectImprovement = (oldDoc: string, newDoc: string) =>
	expectCompareTreeCorrectness(oldDoc, newDoc, (result: number) => result > 0);

const expectSame = (oldDoc: string, newDoc: string) =>
	expectCompareTreeCorrectness(oldDoc, newDoc, (result: number) => result == 0);

const expectCompareTreeCorrectness = (oldDoc: string, newDoc: string, satifyFunc: Function) => {
	const oldTree = testLanguageSupport.language.parser.parse(oldDoc);
	const newTree = testLanguageSupport.language.parser.parse(newDoc);

	expect(compareTreeCorrectness(
		oldTree,
		oldDoc.slice,
		newTree,
		newDoc.slice
	)).to.be.satisfy(
		satifyFunc,
		"unable to satisfy: old doc with new doc"
	);
}

describe('default', () => {
	it('add logical operator', async () =>
		expectImprovement(
			"TestProperty1 = ''",
			"TestProperty1 = '' AND"
		)
	);

	it('fix bad property name', async () =>
		expectImprovement(
			"asdf = ''",
			"TestProperty1 = ''"
		)
	);

	it('add parenthesis', async () =>
		expectImprovement(
			'LEN',
			'LEN('
		)
	);

	it('add argument', async () =>
		expectImprovement(
			'LEN(',
			'LEN(TestProperty1'
		)
	);

	it('add argument', async () =>
		expectImprovement(
			'LEN(',
			'LEN(TestProperty1)'
		)
	);

	it('add argument', async () =>
		expectImprovement(
			'LEN()',
			'LEN(TestProperty1)'
		)
	);

	it('change to longer property', async () =>
		expectSame(
			'TestProperty1 > 0',
			'TestLongerProperty > 0'
		)
	);

	it('change to shorter logical operator', async () =>
		expectSame(
			'TestProperty1 > 0 AND TestProperty1 > 0',
			'TestProperty1 > 0 OR TestProperty1 > 0'
		)
	);

	it('identical expression', async () =>
		expectSame(
			'TestProperty1 > 0',
			'TestProperty1 > 0'
		)
	);

	it('add compare operand without operator', async () =>
		expectNoImprovement(
			'TestProperty1',
			"TestProperty1 ''"
		)
	);

	it('add next logical operator without adding operand', async () =>
		expectWorse(
			'TestProperty1 =',
			'TestProperty1 = AND'
		)
	);

	it('add two operands without combine operator', async () =>
		expectWorse(
			"TestProperty1 = ''  AND TestProperty1 = ''",
			"TestProperty1 = '' TestProperty1 AND TestProperty1 = ''"
		)
	);
});

describe.skip("would like these to work, but they don't", async () => {
	it('remove premature parenthesis', async () =>
		expectImprovement(
			'LEN()',
			'LEN('
		)
	);

	it('improve after common earlier error', async () =>
		expectImprovement(
			'asdf = 0 AND TestProperty1',
			'asdf = 0 AND TestProperty1 > 0'
		)
	);
});
