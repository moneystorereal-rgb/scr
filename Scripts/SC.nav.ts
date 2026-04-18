// @ts-nocheck

export function getHostUrl(urlParts) {
	return SC.context.hostPageUrl + '#' + [
		SC.util.getEnumValueName(SC.types.SessionType, urlParts.sessionType) || '',
		(urlParts.sessionGroupPath || []).join('\x1F'),
		(urlParts.sessionFilter || ''),
		(urlParts.sessionID || ''),
		(urlParts.tabName || ''),
		(urlParts.tabContext || ''),
	]
		.map(function(it) { return encodeURI(it); })
		.join('/');
}

export function getHostTabName(sessionEventType) {
	switch (sessionEventType) {
		case SC.types.SessionEventType.QueuedMessage:
		case SC.types.SessionEventType.SentMessage:
			return 'Messages';
		case SC.types.SessionEventType.EncounteredElevationPrompt:
		case SC.types.SessionEventType.RequestedElevation:
		case SC.types.SessionEventType.RequestedAdministrativeLogon:
		case SC.types.SessionEventType.QueuedProceedAdministrativeLogon:
		case SC.types.SessionEventType.QueuedProceedElevation:
			return 'AccessManagement';
		case SC.types.SessionEventType.QueuedCommand:
		case SC.types.SessionEventType.RanCommand:
			return 'Commands';
		case SC.types.SessionEventType.AddedNote:
			return 'Notes';
		default:
			return null;
	}
}
