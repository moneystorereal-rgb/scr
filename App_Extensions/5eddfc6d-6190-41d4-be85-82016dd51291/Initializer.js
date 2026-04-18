if (SC.context.pageType === "GuestPage"){
	if (extensionContext.settingValues.tawkEmbedUrl !== null){
		var Tawk_API=Tawk_API||{}, Tawk_LoadStart=new Date();
		(function(){
			var s1=document.createElement("script"),s0=document.getElementsByTagName("script")[0];
			s1.async=true;
			s1.src= SC.util.sanitizeUrl(extensionContext.settingValues.tawkEmbedUrl);
			s1.charset='UTF-8';
			s1.setAttribute('crossorigin','*');
			s0.parentNode.insertBefore(s1,s0);
		})();
	} else {
		console.log("tawkID is null")
	}
}