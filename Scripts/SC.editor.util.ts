import { Tree, TreeCursor, SyntaxNode, NodeIterator } from '@lezer/common'

export function isBoundary(s: string) {
	for (let i = 0; i < s.length; i++)
		if (s[i] !== ' ' && s[i] !== '\n' && s[i] !== '\r' && s[i] !== '(' && s[i] !== ')')
			return false;

	return true;
}

export function* iterateTree(cursor: TreeCursor) {
	// TOOO rework this to be more efficient
	let array: SyntaxNode[] = [];
	cursor.iterate(it => { array.push(it.node); })
	for (let i of array)
		yield i.node;
}

export function* iterateTreeLeaves(cursor: TreeCursor) {
	for (let node of iterateTree(cursor))
		if (node.firstChild == null)
			yield node;
}

export function* iterateStack(cursor: NodeIterator) {
	for (let n: NodeIterator | null = cursor; n != null; n = n.next)
		yield n.node;
}

export function* iterate<T>(func: (index: number) => T | null) {
	for (let i = 0; ; i++) {
		const item = func(i);
		if (item == null)
			break;

		yield item;
	}
}

export function toTrimmed<T>(array: T[], shouldTrimFunc: (item: T) => boolean, shouldTrimStart: boolean, shouldTrimEnd: boolean) {
	let start = 0;
	let end = array.length;

	while (shouldTrimStart && start < end && shouldTrimFunc(array[start]))
		start++;

	while (shouldTrimEnd && end > start && shouldTrimFunc(array[end - 1]))
		end--;

	return array.slice(start, end);
}

export const getFirstErrorNodePosition = (tree: Tree) =>
	Array.from(iterateTree(tree.cursor()))
		.filter(it => it.type.isError)
		.map(it => it.from)
		.reduce((x, y) => Math.min(x, y), Number.MAX_VALUE);

type Slicer = (from: number, to: number) => string;

const assertNotReached = () => { throw "never should be reached" };

export const compareTreeCorrectness = (oldTree: Tree, oldDoc: Slicer, newTree: Tree, newDoc: Slicer) => {
	const getNodes = (tree: Tree) => {
		var nodes: SyntaxNode[] = [];

		tree.iterate({
			enter: (nodeRef) => {
				// leaf nodes and error nodes that may contain children
				if (!nodeRef.node.firstChild || nodeRef.type.isError)
					nodes.push(nodeRef.node);

				// sometimes it'll put a field/property reference in the tree inside an error node, so we add the error node above, but don't dive in
				return !nodeRef.type.isError;
			}
		});

		// trim off empty end error nodes because they really just mean unfinished
		return toTrimmed(nodes, it => it.type.isError && it.from == it.to, false, true);
	}

	const oldNodes = getNodes(oldTree);
	const newNodes = getNodes(newTree);
	let oldIndex = 0;
	let newIndex = 0;

	const isError = (node: SyntaxNode) =>
		node.type.isError || (node.from == node.to && node.firstChild?.type.isError);

	while (true) {
		if (!oldNodes[oldIndex]) {
			if (!newNodes[newIndex])
				return 0;

			return isError(newNodes[newIndex]) ? -1 : 1;
		} else if (!newNodes[newIndex]) {
			if (!oldNodes[oldIndex])
				assertNotReached();

			return isError(oldNodes[oldIndex]) ? 1 : -1;
		} else {
			if (isError(oldNodes[oldIndex]) != isError(newNodes[newIndex]))
				return isError(oldNodes[oldIndex]) ? 1 : -1;

			oldIndex++;
			newIndex++;
		}
	}
}

export const compareTreeCorrectnessOld = (oldTree: Tree, newTree: Tree) => {
	const previousErrorNodes = Array.from(iterateTree(oldTree.cursor()))
		.filter(it => it.type.isError)

	const newErrorNodesWithinPreviousRange = Array.from(iterateTree(newTree.cursor()))
		.filter(it => it.type.isError && it.from <= oldTree.topNode.to)

	if (newErrorNodesWithinPreviousRange.length > previousErrorNodes.length)
		return -1;

	for (let i = 0; i < newErrorNodesWithinPreviousRange.length; i++)
		if (newErrorNodesWithinPreviousRange[i].from <= previousErrorNodes[i].from)
			return -1;

	return 1;
}

export function pipe<T, U>(value: T, selector: (value: T) => U) { return selector(value) }
