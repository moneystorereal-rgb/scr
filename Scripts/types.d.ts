declare namespace SC {
	export const service: {
		[key: string]: (...args: any[]) => void;
	};
	export const context: { [key: string]: unknown } & {
		imports: {
			'SC.editor': typeof import('./SC.editor');
		};
	};
	export const res: {
		[key: string]: string;
	};
	export const types: {
		[typeName: string]: {
			[enumerationName: string]: number;
		};
	};
	export const extensions: {
		[key: string]: {
			virtualPath: string;
			settingValues: { [key: string]: string };
			customContexts: { [key: string]: unknown }[];
			initializeProcs: ((extensionContext: {
				baseUrl: string;
				settingValues: { [key: string]: string };
				custom: { [key: string]: unknown };
			}) => void)[];
		};
	};

	export const command: typeof import('./SC.command');
	export const css: typeof import('./SC.css');
	export const dashboard: typeof import('./SC.dashboard');
	export const dialog: typeof import('./SC.dialog');
	export const editfield: typeof import('./SC.editfield');
	export const entryhistory: typeof import('./SC.entryhistory');
	export const event: typeof import('./SC.event');
	export const extension: typeof import('./SC.extension');
	export const http: typeof import('./SC.http');
	export const installer: typeof import('./SC.installer');
	export const launch: typeof import('./SC.launch');
	export const livedata: typeof import('./SC.livedata');
	export const nav: typeof import('./SC.nav');
	export const pagedata: typeof import('./SC.pagedata');
	export const panellist: typeof import('./SC.panellist');
	export const popout: typeof import('./SC.popout');
	export const svg: typeof import('./SC.svg');
	export const toolbox: typeof import('./SC.toolbox');
	export const tooltip: typeof import('./SC.tooltip');
	export const ui: typeof import('./SC.ui');
	export const util: typeof import('./SC.util');
}

declare function namespace(name: string): void;

declare function $(query: string): HTMLElement | null;

declare function $$(globalQuery: string): HTMLElement[];
declare function $$(element: HTMLElement, elementQuery: string): HTMLElement[];

declare function $nbsp(): Text;

type CreateElementArgs = [...any]; // TODO
declare function $a(...args: CreateElementArgs): HTMLAnchorElement;
declare function $br(...args: CreateElementArgs): HTMLBRElement;
declare function $button(...args: CreateElementArgs): HTMLButtonElement;
declare function $dd(...args: CreateElementArgs): HTMLElement;
declare function $div(...args: CreateElementArgs): HTMLDivElement;
declare function $dl(...args: CreateElementArgs): HTMLDListElement;
declare function $dt(...args: CreateElementArgs): HTMLElement;
declare function $fieldset(...args: CreateElementArgs): HTMLFieldSetElement;
declare function $form(...args: CreateElementArgs): HTMLFormElement;
declare function $h1(...args: CreateElementArgs): HTMLHeadingElement;
declare function $h2(...args: CreateElementArgs): HTMLHeadingElement;
declare function $h3(...args: CreateElementArgs): HTMLHeadingElement;
declare function $h4(...args: CreateElementArgs): HTMLHeadingElement;
declare function $hr(...args: CreateElementArgs): HTMLHRElement;
declare function $iframe(...args: CreateElementArgs): HTMLIFrameElement;
declare function $img(...args: CreateElementArgs): HTMLImageElement;
declare function $input(...args: CreateElementArgs): HTMLInputElement;
declare function $label(...args: CreateElementArgs): HTMLLabelElement;
declare function $legend(...args: CreateElementArgs): HTMLLegendElement;
declare function $li(...args: CreateElementArgs): HTMLLIElement;
declare function $option(...args: CreateElementArgs): HTMLOptionElement;
declare function $p(...args: CreateElementArgs): HTMLParagraphElement;
declare function $script(...args: CreateElementArgs): HTMLScriptElement;
declare function $select(...args: CreateElementArgs): HTMLSelectElement;
declare function $span(...args: CreateElementArgs): HTMLSpanElement;
declare function $table(...args: CreateElementArgs): HTMLTableElement;
declare function $tbody(...args: CreateElementArgs): HTMLTableSectionElement;
declare function $td(...args: CreateElementArgs): HTMLTableCellElement;
declare function $textarea(...args: CreateElementArgs): HTMLTextAreaElement;
declare function $th(...args: CreateElementArgs): HTMLTableCellElement;
declare function $thead(...args: CreateElementArgs): HTMLTableSectionElement;
declare function $tr(...args: CreateElementArgs): HTMLTableRowElement;
declare function $ul(...args: CreateElementArgs): HTMLUListElement;

/** @deprecated use CSS styling instead */ declare function $dfn(...args: CreateElementArgs): HTMLElement;
/** @deprecated use CSS styling instead */ declare function $ins(...args: CreateElementArgs): HTMLModElement;
/** @deprecated use CSS styling instead */ declare function $pre(...args: CreateElementArgs): HTMLPreElement;
