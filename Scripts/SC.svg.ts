// @ts-nocheck

export function setAttributes(element, attributes) {
	if (attributes)
		attributes.forEachKeyValue(function (key, value) {
			element.setAttributeNS(null, key, value);
		});
};

export function addElement(container, name, attributes, style, textContent, title) {
	var element = document.createElementNS('http://www.w3.org/2000/svg', name);

	setAttributes(element, attributes);

	if (style)
		element.style = style;

	if (title)
		setTitle(element, title);

	if (textContent)
		SC.ui.addTextNode(element, textContent);

	container.appendChild(element);

	return element;
};

export function setTitle(element, title) {
	addElement(element, 'title', null, null, title);
};

export function setTransform(element, translateX, translateY, postRotateAngle) {
	var transformString = '';

	if (translateX || translateY)
		transformString += 'translate(' + (translateX || 0) + ' ' + (translateY || 0) + ')';

	if (postRotateAngle)
		transformString += 'rotate(' + postRotateAngle + ')';

	setAttributes(element, { transform: transformString });
};

export function areRectsIntersecting(r1, r2) {
	return ((((r2.x < (r1.x + r1.width)) && (r1.x < (r2.x + r2.width))) && (r2.y < (r1.y + r1.height))) && (r1.y < (r2.y + r2.height)));
};
