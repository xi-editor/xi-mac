// Nav - simple menu folding in Vanilla JS (http://vanilla-js.com)

/*

Nav folding expects the following structure (toggle classes denoted by "?class?"):

<nav id="menu" class="?animate?">

  <* class="group ?collapsed?">
    <* name="name"></*>
    <* name="list">
      ...
      <* class="?active?"></*>
      ...
    </*>
  </*>
  ...
</nav>

*/

// For progressive enhancement, signal that JS is running
document.documentElement.classList.add('js');

document.onreadystatechange = function () {
	switch (document.readyState) {
		case 'interactive':
			var groups = document.querySelectorAll('nav#menu .group');
			Array.prototype.forEach.call(groups, function (group) {
				var anchor = group.querySelector('[name=name]');
				var list = group.querySelector('[name=list]');
				var active = list.querySelector('.active');
				
				// Store the height in data for use when expanding
				list.dataset.height = list.clientHeight + 'px';
				
				// Collapse list and mark group, unless it contains the active element
				list.style.maxHeight = active ? list.dataset.height : '0px';
				group.classList.toggle('collapsed', ! active);
				
				// Attach an expand-on-click handler
				anchor.addEventListener('click', function() {
					list.style.maxHeight = (list.style.maxHeight == '0px') ? list.dataset.height : '0px';
					group.classList.toggle('collapsed');
				});
			});
			break;
		case 'complete':
			// When the doc is fully loaded, turn on animation
			document.querySelector('nav#menu').classList.add('animate');
			break;
	}
};

// Setup TOC Button support when running in Help Viewer
if ("HelpViewer" in window && "showTOCButton" in window.HelpViewer) {
	function toggleBanner() {
		document.querySelector('body').classList.toggle('show-banner');
	}
	window.setTimeout(function () {
		window.HelpViewer.showTOCButton(true, toggleBanner, toggleBanner);
		window.HelpViewer.setTOCButton(true);

	}, 100);
}

