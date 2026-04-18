import { tags, styleTags } from '@lezer/highlight'
import { buildParser } from '@lezer/generator'
import { TreeFragment, SyntaxNode } from '@lezer/common'
import { LanguageSupport, LRLanguage, syntaxTree } from '@codemirror/language'
import { EditorState } from '@codemirror/state'
import { Completion, insertCompletionText, CompletionContext } from '@codemirror/autocomplete';
import { subExpressionInfosField, PropertyInfos, VariableInfos } from './SC.editor.state'
import { compareTreeCorrectness, iterateTree, isBoundary, iterateStack, iterate } from './SC.editor.util'

type RangeSpec = { from: number, to: number };

const grammar = String.raw`
@top RootBooleanExpression { BooleanExpression }
@top RootNonBooleanExpression { NonBooleanExpression }

@precedence {
  logical @left,
  multdiv @left,
  addsub @left
}

@skip { whitespace }

ParentheticalExpression<expression> { "(" expression ")" }

NonBooleanExpression {
  Literal { numberLiteral | stringLiteral }
  | star
  | CombineExpression
  | FunctionCall<leftKeyword, twoArgument>
  | FunctionCall<rightKeyword, twoArgument>
  | FunctionCall<castKeyword, NonBooleanExpression asKeyword identifier>
  | FunctionCall<convertKeyword, twoArgument>
  | FunctionCall<iifKeyword, threeArgumentFirstBoolean>
  | FunctionCall<lenKeyword, oneArgument>
  | FunctionCall<trimKeyword, oneArgument>
  | FunctionCall<substringKeyword, threeArgument>
  | FunctionCall<getdatafieldKeyword, twoArgument>
  | FunctionCall<delimindexKeyword, threeArgument>
  | FunctionCall<yearKeyword, oneArgument>
  | FunctionCall<monthKeyword, oneArgument>
  | FunctionCall<dayKeyword, oneArgument>
  | FunctionCall<hourKeyword, oneArgument>
  | FunctionCall<minuteKeyword, oneArgument>
  | FunctionCall<secondKeyword, oneArgument>
  | FunctionCall<millisecondKeyword, oneArgument>
  | FunctionCall<dayofweekKeyword, oneArgument>
  | PropertyReference
  | VariableReference
  | ParentheticalExpression<NonBooleanExpression>
}

BooleanExpression {
  CompareExpression
  | LogicalExpression
  | FunctionCall<freetextKeyword, twoArgument>
  | ParentheticalExpression<BooleanExpression>
  | NotBooleanExpression { notKeyword BooleanExpression }
}

CompareExpression {
  NonBooleanExpression CompareOperator { "=" | "<>" | "!=" | ">" | ">=" | "<" | "<=" } NonBooleanExpression
  | NonBooleanExpression CompareOperator { notKeyword? inKeyword } OpenParenthesis commaSeparated<NonBooleanExpression> CloseParenthesis
  | NonBooleanExpression CompareOperator { notKeyword? likeKeyword } NonBooleanExpression
  | NonBooleanExpression CompareOperator { notKeyword? betweenKeyword } NonBooleanExpression andKeyword NonBooleanExpression
}

LogicalExpression {
  BooleanExpression !logical LogicalOperator { andKeyword | orKeyword } BooleanExpression
}

CombineExpression {
  NonBooleanExpression !multdiv CombineOperator{"*" | "/"} NonBooleanExpression
  | NonBooleanExpression !addsub CombineOperator{"+" | "-"} NonBooleanExpression
}

@tokens {
  spaces { $[\u0009 \u000b\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff]+ }
  newline { $[\r\n\u2028\u2029] }
  whitespace { spaces | newline }
  number { @digit+ | (@digit+ "." @digit+) }
  variable { DollarSign (@asciiLetter | @digit | "_")+ }
  identifier { @asciiLetter (@asciiLetter | @digit | ".")*}

  OpenParenthesis { "(" }
  CloseParenthesis { ")" }
  Comma { "," }
  DollarSign { "$" }
}

oneArgument { NonBooleanExpression }
twoArgument { NonBooleanExpression Comma NonBooleanExpression }
threeArgument { NonBooleanExpression Comma NonBooleanExpression Comma NonBooleanExpression }
threeArgumentFirstBoolean { BooleanExpression Comma NonBooleanExpression Comma NonBooleanExpression }

// TODO would be nice if this guy could be defined in a skip {} block where could disallow whitespace between function name and parens, but that did not work
FunctionCall<functionKeywords, arguments> { FunctionReference { functionKeywords } OpenParenthesis ArgumentList { arguments } CloseParenthesis }

commaSeparated<content> { "" | content (Comma content)* }

@local tokens {
  stringEnd { "'" }
  stringEscape { "''" }
  @else stringContent
  @precedence { stringEscape, stringEnd }
}

@skip {} {
  stringLiteral { "'" (stringContent | stringEscape)* stringEnd }
  numberLiteral { number }
  star { "*" }
}

@external specialize { identifier } Keyword from "" {
  andKeyword
  orKeyword

  notKeyword

  likeKeyword
  inKeyword
  
  betweenKeyword

  leftKeyword
  rightKeyword
  castKeyword
  convertKeyword
  iifKeyword

  lenKeyword
  trimKeyword
  substringKeyword
  getdatafieldKeyword
  delimindexKeyword

  yearKeyword
  monthKeyword
  dayKeyword
  hourKeyword
  minuteKeyword
  secondKeyword
  millisecondKeyword
  dayofweekKeyword

  asKeyword

  freetextKeyword
}

@external specialize { identifier } PropertyReference from "" { PropertyReference }
@external specialize { variable } VariableReference from "" { VariableReference }
`;

// function* getTermInfos(parser: LRParser) {
//   // TODO parser has nodeSet or something we could use instead
//   for (let term = 0, name = parser.getName(term); name !== undefined; name = parser.getName(++term))
//     yield { term, name };
// }

// function getTermByName(parser: LRParser, name: string) {
//   for (const termInfo of getTermInfos(parser))
//     if (termInfo.name === name)
//       return termInfo.term;

//   return -1;
// }

export type LanguageSupportConfig = {
	propertyInfos: PropertyInfos,
	variableInfos: VariableInfos,
}

export const languageSupport = (config: LanguageSupportConfig) => {
	let parser = buildParser(grammar, {
		externalSpecializer(name, terms) {
			if (name === 'Keyword') {
				const keywordMap = Object.fromEntries(
					Object.entries(terms)
						.map(([name, term]) => ([name.match(/(\w+)Keyword/)?.[1].toUpperCase(), term]))
						.filter((it): it is [string, number] => !!it[0]),
				);

				return value => keywordMap[value.toUpperCase()] || -1;
			} else if (name === 'PropertyReference') {
				return value => Object.keys(config.propertyInfos || {}).some(it => it.toUpperCase() == value.toUpperCase()) ? terms.PropertyReference : -1;
			} else if (name === 'VariableReference') {
				return value => /\$([0-9A-Z_]+)/.test(value) ? terms.VariableReference : -1;
			}

			throw new Error(`Specializer not found: ${name}`);
		},
	})
		.configure({
			top: 'RootBooleanExpression',
			props: [
				styleTags({
					'PropertyReference': tags.propertyName,
					'FunctionReference': tags.controlKeyword,
					'VariableReference': tags.variableName,
					'Literal': tags.string,
					'LogicalOperator': tags.logicOperator,
					'CombineOperator': tags.arithmeticOperator,
					'CompareOperator': tags.compareOperator,
				})
			],
		});

	return new LanguageSupport(LRLanguage.define({
		parser,
		languageData: {
			autocomplete: function (context: CompletionContext) {
				enum Boost {
					Highest = 99,
					High = 50,
					Normal = 0,
					Low = -50,
					Lowest = -99,
				}

				type NodeTypeInfo = {
					getOptions: (editorState: EditorState, equalsSubExpression: string | undefined) => Completion[],
					getTestToken: (editorState: EditorState) => string,
				}

				const nodeTypeInfos: Record<string, NodeTypeInfo> = {
					LogicalOperator: {
						getOptions: () =>
							['AND', 'OR'].map(it => getOption(it, Boost.High)),
						getTestToken: () => 'AND',
					},
					Literal: {
						getOptions: (state, equalsSubExpression) =>
							((state.field(subExpressionInfosField, false) || {})[equalsSubExpression || Number.MIN_VALUE]?.Results || [])
								.map(it => fixupPartialOption({
									label: typeof it.Value === 'string' && it.Value.includes('\'') ? `'${it.Value.replace('\'', '\'\'')}'` // need to escape single quotes if string literal contains them
										: typeof it.Value === 'string' ? `'${it.Value}'`
											: `${it.Value}`,
									detail: `${it.Count} results`,
									boost: Boost.High,
								})),
						getTestToken: () => "''",
					},
					PropertyReference: {
						getOptions: () =>
							Object.entries(config.propertyInfos)
								.map(([name]) => getOption(name, Boost.High)),
						getTestToken: () =>
							Object.keys(config.propertyInfos)[0],
					},
					VariableReference: {
						getOptions: () =>
							Object.keys(config.variableInfos)
								.map(it => getOption('$' + it, Boost.Low)),
						getTestToken: () => '$' + Object.keys(config.variableInfos)[0],
					},
					CombineOperator: {
						getOptions: () => ['+', '-', '*', '/'].map(it => getOption(it, Boost.Low)),
						getTestToken: () => '+',
					},
					CompareOperator: {
						getOptions: () => [
							getOption('=', Boost.Highest),

							getOption('LIKE', Boost.High),
							getOption('IN', Boost.High),
							getOption('<>', Boost.High),

							getOption('>', Boost.Normal),
							getOption('>=', Boost.Normal),
							getOption('<', Boost.Normal),
							getOption('<=', Boost.Normal),
							getOption('BETWEEN', Boost.Normal),
						],
						getTestToken: () => '=',
					},
					FunctionReference: {
						getOptions: () => Array.from(iterate(index => parser.getName(index)))
							.map(it => /FunctionCall<(\w+)Keyword.*>/.exec(it)?.[1].toUpperCase()) // got to be a better way to "tag" grammar or something to extract this better
							.filter(it => it && it != 'FREETEXT') // would be nice to define somewhere else.. but this is a really expensive function that we don't want to be autocompleted 
							.map(it => getOption(it + '(', Boost.Low)),
						getTestToken: () => 'LEN',
					},
					OpenParenthesis: {
						getOptions: () => [getOption('(', Boost.Normal)],
						getTestToken: () => '(',
					},
					CloseParenthesis: {
						getOptions: () => [getOption(')', Boost.Normal)],
						getTestToken: () => ')',
					},
					Comma: {
						getOptions: () => [getOption(',', Boost.Normal)],
						getTestToken: () => ',',
					},
				};

				const getOption = (label: string, boost?: number): Completion =>
					fixupPartialOption({
						label,
						boost,
					});

				const fixupPartialOption = (option: Completion): Completion => ({
					...option,
					apply: (view, completion, from, to) => {
						const baseInsertText = completion.label;
						const newSyntaxTree = parser.parse(getNewDoc(view.state, { from, to }, baseInsertText));
						const leftStack = newSyntaxTree.resolveStack(from + baseInsertText.length, -1);
						const booleanNode = Array.from(iterateStack(leftStack)).find(it => it.type.name == 'BooleanExpression');

						const insertText = baseInsertText +
							(to < view.state.doc.length ? ''
								: (booleanNode && Array.from(iterateTree(booleanNode.toTree().cursor())).every(it => !it.type.isError)) ? '\n'
									: ' '); // TODO figure out function stuff, IN, BETWEEN?

						view.dispatch(
							insertCompletionText(
								view.state,
								insertText,
								from,
								to + (baseInsertText.startsWith('\'') && baseInsertText.endsWith('\'') && to < view.state.doc.length ? 1 : 0) // to ensure we're not adding an extra quote if we're already in a string literal
							)
						);
					},
				});

				const getNewDoc = (state: EditorState, replaceRange: RangeSpec, content: string) =>
					state.sliceDoc(0, replaceRange.from)
					+ content
					+ state.sliceDoc(replaceRange.to);

				const currentSyntaxTree = syntaxTree(context.state);
				const leftStack = currentSyntaxTree.resolveStack(context.pos, -1);
				const rightStack = currentSyntaxTree.resolveStack(context.pos, 1);

				// TODO could probably make this guy better
				const leftStackArray = Array.from(iterateStack(leftStack));
				const compareExpressionStackIndex = leftStackArray.findIndex(it => it.type.name === 'CompareExpression');

				const equalsSubExpression = compareExpressionStackIndex < 0 || leftStackArray[compareExpressionStackIndex].firstChild?.from === leftStackArray[compareExpressionStackIndex - 1]?.from ? undefined
					: leftStackArray[compareExpressionStackIndex]
						.getChildren('NonBooleanExpression') // and goal to get left part
						.map(it => context.state.sliceDoc(it.from, it.to))
						.find(it => it) || ''

				const compareCorrectnessWithTokenType = function (replaceRange: RangeSpec, nodeType: string) {
					let newDoc = getNewDoc(context.state, replaceRange, nodeTypeInfos[nodeType].getTestToken(context.state))
					let newSyntaxTree = parser.parse(newDoc, TreeFragment.addTree(currentSyntaxTree));
					return compareTreeCorrectness(currentSyntaxTree, context.state.doc.sliceString, newSyntaxTree, newDoc.slice);
				}

				const isTokenNode = (node: SyntaxNode) => !!nodeTypeInfos[node.type.name] || node.type.isError;

				const getOptionsForRange = (range: RangeSpec, requireToImprove: boolean) =>
					Object.entries(nodeTypeInfos)
						.filter(([name]) => compareCorrectnessWithTokenType(range, name) > (requireToImprove ? 0 : -1))
						.map(([_, info]) => info.getOptions(context.state, equalsSubExpression))
						.flat();

				// states:
				// - valid token to left, whitespace/eof on right-- show unfiltered completions
				// - partial/invalid token to left, whitespace/eof on right-- show filtered completions
				// - in the middle of valid token-- show completions based on 
				// - in the middle of invalid token-- show unfiltered completions
				// - whitespace to left

				// most of the logic for parsing/interpretation should be reflected in here
				// so that it can be logged out easily and then consumed by decision stuff below
				// using this 'class' syntax so properties can refer to one another
				const calcs = new class {
					isLeftBoundary = context.pos === 0 || isBoundary(context.state.sliceDoc(context.pos - 1, context.pos));
					isRightBoundary = context.pos === context.state.doc.length || isBoundary(context.state.sliceDoc(context.pos, context.pos + 1));
					isInsideOfLiteral = leftStack.node?.type.name === 'Literal' || rightStack.node?.type.name === 'Literal';
					isInsideOfVariable = leftStack.node?.type.name === 'VariableReference' || rightStack.node?.type.name === 'VariableReference';
					isTokenNodeOnLeft = isTokenNode(leftStack.node);
					isTokenNodeOnRight = isTokenNode(rightStack.node);
					isBetweenTokens = (this.isTokenNodeOnLeft || this.isTokenNodeOnRight) && leftStack.node !== rightStack.node;
					isCurrentTokenValid =
						this.isTokenNodeOnLeft ? !leftStack.node.type.isError
							: this.isTokenNodeOnRight ? !rightStack.node.type.isError
								: false;
					currentTokenRange =
						this.isTokenNodeOnLeft ? { from: leftStack.node.from, to: leftStack.node.to }
							: this.isTokenNodeOnRight ? { from: rightStack.node.from, to: rightStack.node.to }
								: { from: context.pos, to: context.pos };
					isInsideOfCurrentToken = context.pos > this.currentTokenRange.from && context.pos < this.currentTokenRange.to;
					isParentheticalExpressionOnLeft = leftStack.node?.type.name === 'ParentheticalExpression' && context.state.sliceDoc(context.pos - 1, context.pos) === ')';
					isLiteralOnLeft = leftStack.node?.type.name === 'Literal' && context.state.sliceDoc(context.pos - 1, context.pos) === "'";
				}

				// console.dir(JSON.stringify(calcs, null, 2))
				const shouldShowOptions = !calcs.isParentheticalExpressionOnLeft;

				const options = shouldShowOptions ? getOptionsForRange(calcs.currentTokenRange, !calcs.isCurrentTokenValid) : [];
				let filter = !calcs.isCurrentTokenValid || calcs.isRightBoundary || calcs.isInsideOfCurrentToken;

				return {
					from: calcs.currentTokenRange.from,
					to: context.pos,
					filter: filter,
					options: options,
				}
			},
		},
	}));
}
