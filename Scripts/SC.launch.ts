// @ts-nocheck

import type { Dialog } from "./SC.dialog";

export function getJoinPanelDefinitionTreeRoot(processType) {
	if (!window._joinPanelDefinitionTreeRoot) {
		var createPanelDefinitionFunc = function (key, parentSelectionHeadingTextOverride, parentSelectionButtonText, parentSelectionDescriptionText, childPanels, shouldAutoNavigateToFirstChild, shouldRememberSelection, joinProc, joinContentBuilderFunc, connectedContentBuilderFunc, cancelJoinProc) {
			return {
				key: key,
				parentSelectionHeadingText: parentSelectionHeadingTextOverride || key,
				parentSelectionButtonText: parentSelectionButtonText,
				parentSelectionDescriptionText: parentSelectionDescriptionText,
				childPanels: childPanels,
				shouldAutoNavigateToFirstChild: shouldAutoNavigateToFirstChild,
				shouldRememberSelection: shouldRememberSelection,
				joinProc: joinProc,
				joinContentBuilderFunc: joinContentBuilderFunc,
				connectedContentBuilderFunc: connectedContentBuilderFunc,
				cancelJoinProc: cancelJoinProc,
			};
		};

		var createBaseLauncherPanelDefinitionFunc = function (launcherKey, containsCapabilityFunc, parentSelectionHeadingTextOverride, shouldRememberSelection, timeoutMilliseconds, joinProc, joinContentBuilderFunc) {
			var mostRecentJoinAttemptTime;
			var isCancellationRequested;

			return createPanelDefinitionFunc(
				launcherKey,
				parentSelectionHeadingTextOverride,
				SC.util.getResourceWithFallback('JoinPanel.Launcher{0}.ButtonText', launcherKey),
				SC.util.getResourceWithFallback('JoinPanel.Launcher{0}.Description', launcherKey),
				null,
				false,
				shouldRememberSelection,
				function (clientLaunchParameters) {
					if (!isCancellationRequested) {
						mostRecentJoinAttemptTime = new Date();
						joinProc(clientLaunchParameters);
					}
				},
				function (childPanels, childStringPaths, nextPanelDefinition, nextPanelStringPath) {
					isCancellationRequested = false;
					mostRecentJoinAttemptTime = undefined;

					var launcherPanelElements = [];
					var joiningText = SC.util.getResourceWithFallback('JoinPanel.Launcher{0}.JoiningText', launcherKey);
					var joiningParagraph = $p(joiningText);
					launcherPanelElements.push(joiningParagraph);

					var joiningParagraphAnimateProc = function (counter) {
						if (counter == 0 || SC.ui.isInBody(joiningParagraph)) {
							var newDots = new Array((counter % 8) + 2).join('.');
							SC.ui.setInnerText(joiningParagraph, joiningText + newDots);

							if (counter < 100)
								window.setTimeout(function () { joiningParagraphAnimateProc(counter + 1); }, 400);
						}
					};

					joiningParagraphAnimateProc(0);

					launcherPanelElements = launcherPanelElements.concat(joinContentBuilderFunc(childPanels, childStringPaths, nextPanelDefinition, nextPanelStringPath));

					if (timeoutMilliseconds) {
						var nextParagraph = $p({ className: 'Help' });
						launcherPanelElements.push(nextParagraph);
						var blurred = false;
						var blurHandlerProc = function () { blurred = true; };

						var tickProc = function () {
							var done = false;

							if (mostRecentJoinAttemptTime != undefined && !isCancellationRequested) {
								var millisecondsUntilTimeout = timeoutMilliseconds - (new Date() - mostRecentJoinAttemptTime);
								if (blurred || document.webkitHidden || millisecondsUntilTimeout < -400) {
									done = true;
									SC.ui.setInnerText(nextParagraph, SC.res['JoinPanel.Launcher.NextDetectedText']);
								} else if (millisecondsUntilTimeout < 0) {
									SC.command.dispatchExecuteCommand(nextParagraph, nextParagraph, nextParagraph, 'Load', nextPanelStringPath);
									done = true;
								} else {
									SC.ui.setInnerText(nextParagraph, SC.util.formatString(SC.res['JoinPanel.Launcher.NextTryingTextFormat'], millisecondsUntilTimeout / 1000));
								}
							}

							if (done || isCancellationRequested)
								SC.event.removeHandler(window, 'blur', blurHandlerProc);
							else
								window.setTimeout(tickProc, 200);
						};

						SC.event.addHandler(window, 'blur', blurHandlerProc);
						tickProc();
					}

					launcherPanelElements.push($p({ className: 'Help' }, [
						$span(SC.res['JoinPanel.Launcher.NextTroubleText']),
						$nbsp(),
						$a({ _commandName: 'NavigateJoinPanel', _commandArgument: nextPanelStringPath }, SC.res['JoinPanel.Launcher.NextTryText']),
						$nbsp(),
						$span('(' + nextPanelDefinition.key + ')'),
					]));

					return launcherPanelElements;
				},
				function (sessionType, processType) {
					var launcherPanelElements = [];

					if (processType != SC.types.ProcessType.Guest)
						return null;

					var connectedText = SC.util.getResourceWithFallback('JoinPanel.Launcher{0}.ConnectedText', launcherKey);
					launcherPanelElements.push($p(connectedText));

					if (sessionType != SC.types.SessionType.Meeting) {
						launcherPanelElements = launcherPanelElements.concat(createHelpPanelsFunc(containsCapabilityFunc, [
							[SC.util.Caps.WindowsDesktop, helpPanels.WindowsGuestConnected],
							[SC.util.Caps.MacOSX, helpPanels.MacGuestConnected],
						]));
					}

					return launcherPanelElements;
				},
				function () {
					isCancellationRequested = true;
				}
			);
		};

		var createHandlerLauncherPanelDefinitionFunc = function (launcherKey, containsCapabilityFunc, parentSelectionHeadingTextOverride, shouldRememberSelection, joinContentBuilderFunc) {
			return createBaseLauncherPanelDefinitionFunc(
				launcherKey,
				containsCapabilityFunc,
				parentSelectionHeadingTextOverride,
				shouldRememberSelection,
				0,
				function (clp) {
					var url = getLauncherUrlFunc(launcherKey, clp);
					SC.util.launchUrl(url);
				},
				joinContentBuilderFunc
			);
		};

		var createSelectorLauncherPanelDefinitionFunc = function (launcherKey, containsCapabilityFunc, parentSelectionHeadingTextOverride, selectorKey, installLauncherKey) {
			return createPanelDefinitionFunc(
				launcherKey,
				parentSelectionHeadingTextOverride,
				SC.res['JoinPanel.LauncherSelector.ButtonText'],
				SC.res['JoinPanel.Launcher' + selectorKey + 'Selector.Description'],
				[
					createLauncherPanelDefinitionFunc(installLauncherKey, containsCapabilityFunc, SC.res['JoinPanel.Launcher' + selectorKey + 'SelectorInstall.Heading']),
					createLauncherPanelDefinitionFunc(launchers.UrlLaunch, containsCapabilityFunc, SC.res['JoinPanel.Launcher' + selectorKey + 'SelectorLaunch.Heading']),
				],
				false,
				true,
				null,
				function (childPanels, childStringPaths) {
					return createChildPanelDecoratedListFunc(childPanels, childStringPaths);
				},
				null
			);
		};

		var getLauncherUrlFunc = function (launcherKey, clientLaunchParameters) {
			return SC.context.scriptBaseUrl + SC.context.launchHandlerPaths[launcherKey] + SC.util.getQueryString(clientLaunchParameters);
		}

		var getSchemeUrlFunc = function (scheme, clientLaunchParameters, useUrlSafeBase64) {
			return SC.util.formatString(
				'{0}://{1}:{2}/{3}/{4}/{5}/{6}/{7}/{8}/{9}/{10}',
				scheme,
				clientLaunchParameters.h,
				clientLaunchParameters.p,
				clientLaunchParameters.s,
				encodeURIComponent(clientLaunchParameters.k || ''),
				encodeURIComponent(clientLaunchParameters.n || ''),
				encodeURIComponent(clientLaunchParameters.r || ''),
				clientLaunchParameters.e,
				encodeURIComponent(clientLaunchParameters.i || ''),
				encodeURIComponent(clientLaunchParameters.a || ''),
				encodeURIComponent(clientLaunchParameters.l || '')
			);
		}

		var getAndroidPackageNameFunc = function () {
			// previously matched samsung user agent, etc, but now the main app works best for all
			return 'com.screenconnect.androidclient';
		}

		var createChildPanelListFunc = function (childPanels, childStringPaths) {
			return $ul(Array.from(childPanels)
				.map(function (childPanel, index) {
					return $li([
						$a({ _commandName: 'NavigateJoinPanel', _commandArgument: childStringPaths[index] }, childPanel.parentSelectionHeadingText),
					]);
				})
			);
		};

		var createChildPanelDecoratedListFunc = function (childPanels, childStringPaths) {
			return Array.from(childPanels)
				.map(function (childPanel, index) {
					return $div({ className: 'Box' }, [
						$input({ type: 'button', value: childPanel.parentSelectionButtonText, _commandName: 'NavigateJoinPanel', _commandArgument: childStringPaths[index] }),
						$h3(childPanel.parentSelectionHeadingText),
						$p(childPanel.parentSelectionDescriptionText),
					]);
				});
		};

		var createHelpPanelsFunc = function (containsCapabilityFunc, helpItems) {
			var selectedhelpPanels = Array.prototype.map.call(
				Array.prototype.filter.call(helpItems, function (hi) {
					if (hi[0] != null) {
						if (hi[0] instanceof Array) {
							for (var i = 0; hi[0][i]; i++)
								if (!containsCapabilityFunc(hi[0][i]))
									return false;
						} else {
							if (!containsCapabilityFunc(hi[0]))
								return false;
						}
					}

					return true;
				}),
				function (hi) { return hi[1]; }
			);

			return Array.from(selectedhelpPanels)
				.map(function (selectedhelpPanel, index) {
					return $div({ className: 'Box' }, [
						$img({ src: SC.context.scriptBaseUrl + 'Images/Launch' + selectedhelpPanel + '.png' }),
						(selectedhelpPanels.length > 1) ? $h4((index + 1).toString()) : null,
						$p({ _htmlResource: 'JoinPanel.Launcher.Help' + selectedhelpPanel + 'Text' }),
					]);
				});
		};

		var createBackParagraphFunc = function (nextPanelStringPath) {
			return $p([
				$span({ _textResource: 'JoinPanel.Launcher.BackInstalledText' }),
				$nbsp(),
				$a({ _commandName: 'NavigateJoinPanel', _commandArgument: nextPanelStringPath, _textResource: 'JoinPanel.Launcher.BackJoinText' }),
			]);
		};

		var createLauncherPanelDefinitionFunc = function (launcherKey, containsCapabilityFunc, parentSelectionHeadingTextOverride) {
			switch (launcherKey) {
				case launchers.ClickOnceRun:
					return createHandlerLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						true,
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[SC.util.Caps.Chrome, helpPanels.ChromeFileRun],
								[SC.util.Caps.Safari, helpPanels.MacSafariFileRun],
								[SC.util.Caps.Firefox, helpPanels.WindowsFirefoxExeConfirmation],
								[SC.util.Caps.Firefox, helpPanels.WindowsFirefoxExeRun],
								[SC.util.Caps.InternetExplorer, helpPanels.WindowsInternetExplorerExeRun],
								[SC.util.Caps.WindowsDesktop, helpPanels.WindowsExeConfirmation],
							]);
						}
					);
				case launchers.WebStartDirect:
				case launchers.WebStartBootstrap:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						true,
						0,
						function (clp) {
							var url = getLauncherUrlFunc(launcherKey, clp);
							var launched = false;

							var pluginMimeType = Array.from(navigator.mimeTypes)
								.filter(function (mt) { return mt.enabledPlugin != null && mt.type.match(/java-applet.*jpi/); })
								.map(function (mt) { return mt.type; })
								.firstOrDefault();

							if (pluginMimeType != null) {
								try {
									// this isn't ready for prime time ... bug JI-9012231 was submitted for percent signs in URLs, and they are fairly unavoidable with us unfortunately
									//var embedElement = $('javaEmbed') || SC.ui.addElement(document.body, 'EMBED', { id: 'javaEmbed', type: pluginMimeType }, 'width: 0px; height: 0px;');
									//embedElement.launchApp({ url: url });
									//launched = true;
								} catch (ex) {
									// don't care, will launch normally
									console.log(ex);
								}
							}

							if (!launched)
								SC.util.launchUrl(url);
						},
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[SC.util.Caps.Chrome, helpPanels.ChromeDangerousFileConfirmation],
								[SC.util.Caps.Chrome, helpPanels.ChromeFileRun],
								[SC.util.Caps.Safari, helpPanels.MacSafariFileRun],
								[[SC.util.Caps.MacOSX, SC.util.Caps.Firefox], helpPanels.MacFirefoxJnlpConfirmation],
								[[SC.util.Caps.WindowsDesktop, SC.util.Caps.Firefox], helpPanels.WindowsFirefoxJnlpConfirmation],
								[SC.util.Caps.WindowsDesktop, helpPanels.WindowsWebStartConfirmation],
								[SC.util.Caps.MacOSX, helpPanels.MacFileConfirmation],
								[SC.util.Caps.MacOSX, helpPanels.MacWebStartConfirmation],
							]);
						}
					);
				case launchers.ClickOnceDirect:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						true,
						0,
						function (clp) {
							var url = getLauncherUrlFunc(launcherKey, clp);
							var launched = false;

							if (SC.util.isCapable(SC.util.Caps.Chrome)) {
								try {
									// this is specific to Chrome plugin for ClickOnce to prevent page reload
									var embedElement = $('clickOnceEmbed') || SC.ui.addElement(document.body, 'EMBED', { id: 'clickOnceEmbed', type: 'application/x-ms-application', _cssText: 'width: 0px; height: 0px;' });
									embedElement.launchClickOnce(url);
									launched = true;
								} catch (ex) {
									// don't care, will launch normally
									console.log(ex);
								}
							}

							if (!launched)
								SC.util.launchUrl(url);
						},
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[SC.util.Caps.WindowsDesktop, helpPanels.WindowsClickOnceConfirmation],
							]);
						}
					);
				case launchers.UrlLaunch:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						true,
						4000,
						function (clp) {
							var scheme = SC.util.isCapable(SC.util.Caps.WindowsDesktop) || SC.util.isCapable(SC.util.Caps.LinuxDesktop) ? SC.context.instanceUrlScheme
								: SC.util.isCapable(SC.util.Caps.WindowsModern) ? 'ms-local-stream'
									: 'relay';
							var url = getSchemeUrlFunc(scheme, clp, SC.util.isCapable(SC.util.Caps.WindowsDesktop) || SC.util.isCapable(SC.util.Caps.WindowsModern));
							SC.util.launchUrl(url);
						},
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[[SC.util.Caps.LinuxDesktop, SC.util.Caps.Firefox], helpPanels.LinuxFirefoxUrlConfirmation],
								[[SC.util.Caps.LinuxDesktop, SC.util.Caps.Chrome], helpPanels.LinuxChromeUrlConfirmation],
								[[SC.util.Caps.MacOSX, SC.util.Caps.Chrome], helpPanels.MacChromeUrlConfirmation],
								[[SC.util.Caps.MacOSX, SC.util.Caps.Firefox], helpPanels.MacFirefoxUrlConfirmation],
							]);
						}
					);
				case launchers.MacBundleSelector:
					return createSelectorLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						'MacBundle',
						launchers.MacBundleDownload
					);
				case launchers.LinuxAppSelector:
					return createSelectorLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						'LinuxApp',
						launchers.LinuxAppInstallerDownload
					);
				case launchers.IosSelector:
					return createSelectorLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						'Ios',
						launchers.AppStore
					);
				case launchers.AndroidSelector:
					return createSelectorLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						'Android',
						launchers.PlayStore
					);
				case launchers.WindowsSelector:
					return createSelectorLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						'Windows',
						launchers.WindowsInstallerDownload
					);
				case launchers.AndroidIntent:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						true,
						0,
						function (clp) {
							var relayUrl = getSchemeUrlFunc('relay', clp);
							var packageName = getAndroidPackageNameFunc();
							var intentUrl = relayUrl.replace('relay:', 'intent:') +
								'#Intent' +
								';scheme=relay' +
								';package=' + encodeURIComponent(packageName) +
								';S.market_referrer=' + encodeURIComponent(encodeURIComponent(relayUrl)) +
								';end';
							SC.util.launchUrl(intentUrl);
						},
						function () {
							return [];
						}
					);
				case launchers.WindowsInstallerDownload:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						false,
						0,
						function (clp) {
							var url = SC.context.scriptBaseUrl + SC.context.installerHandlerPath.replace('*', 'exe') + SC.util.getQueryString(clp);
							SC.util.launchUrl(url);
						},
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[SC.util.Caps.Chrome, helpPanels.ChromeFileRun],
								[SC.util.Caps.Firefox, helpPanels.WindowsFirefoxExeConfirmation],
								[SC.util.Caps.Firefox, helpPanels.WindowsFirefoxExeRun],
								[SC.util.Caps.InternetExplorer, helpPanels.WindowsInternetExplorerExeRun],
								[SC.util.Caps.WindowsDesktop, helpPanels.WindowsExeConfirmation],
							]);
						}
					);
				case launchers.LinuxAppInstallerDownload:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						false,
						0,
						function (clp) {
							var url = SC.context.scriptBaseUrl + SC.context.installerHandlerPath.replace('*', 'sh') + SC.util.getQueryString(clp);
							SC.util.launchUrl(url);
						},
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[SC.util.Caps.Firefox, helpPanels.LinuxFirefoxScriptDownload],
								[SC.util.Caps.Chrome, helpPanels.LinuxChromeScriptDownload],
								[SC.util.Caps.LinuxDesktop, helpPanels.LinuxScriptRun],
							]);
						}
					);
				case launchers.MacBundleDownload:
					return createHandlerLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						false,
						function () {
							return createHelpPanelsFunc(containsCapabilityFunc, [
								[SC.util.Caps.Firefox, helpPanels.MacFirefoxBundleConfirmation],
								[SC.util.Caps.Firefox, helpPanels.MacFirefoxBundleRun],
								[SC.util.Caps.Firefox, helpPanels.MacBundleExtraction],
								[SC.util.Caps.Chrome, helpPanels.ChromeFileRun],
								[SC.util.Caps.Chrome, helpPanels.MacBundleExtraction],
								[SC.util.Caps.Safari, helpPanels.MacSafariFileRun],
								[SC.util.Caps.MacOSX, helpPanels.MacFileConfirmation],
							]);
						}
					);
				case launchers.PlayStore:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						false,
						0,
						function (clp) {
							var relayUrl = getSchemeUrlFunc('relay', clp);
							var packageName = getAndroidPackageNameFunc();
							var url = 'market://details' + SC.util.getQueryString({ id: packageName, referrer: relayUrl });
							SC.util.launchUrl(url);
						},
						function (childPanels, childStringPaths, nextPanelDefinition, nextPanelStringPath) {
							return createBackParagraphFunc(nextPanelStringPath);
						}
					);
				case launchers.AppStore:
					return createBaseLauncherPanelDefinitionFunc(
						launcherKey,
						containsCapabilityFunc,
						parentSelectionHeadingTextOverride,
						false,
						0,
						function (clp) {
							SC.util.launchUrl('https://itunes.apple.com/us/app/screenconnect/id423995707');
						},
						function (childPanels, childStringPaths, nextPanelDefinition, nextPanelStringPath) {
							return createBackParagraphFunc(nextPanelStringPath);
						}
					);
			}
		}

		var processTreeItemsProc = function (systemProfiles, items, pathBuilder, score, capabilities) {
			items.forEach(function (item) {
				processTreeItemProc(systemProfiles, item, pathBuilder, score, capabilities);
			});
		};

		var processTreeItemProc = function (systemProfiles, item, pathBuilder, score, capabilities) {
			if (item[0] instanceof Array) {
				if (score >= 0) score += SC.util.isCapable(capabilities[capabilities.length - 1], item[0][0], item[0][1]) ? 2 : -100;
				pathBuilder += '[' + SC.util.getVersionString(item[0][0]) + '-' + SC.util.getVersionString(item[0][1]) + ']';
			} else if (item[0] instanceof Function) {
				if (score >= 0) score += SC.util.isCapable(item[0]) ? 2 : -100;
				capabilities = capabilities.slice(0).concat(item[0]);
				pathBuilder += (pathBuilder.length == 0 ? '' : ':') + SC.util.getEnumValueName(SC.util.Caps, item[0]);
			} else if (item[0] !== null) {
				score += processType == item[0] ? 2 : -100;
				pathBuilder += (pathBuilder.length == 0 ? '' : ':') + SC.util.getEnumValueName(SC.types.ProcessType, item[0]);
			} else {
				pathBuilder += (pathBuilder.length == 0 ? '' : ':') + 'Default';
			}

			var args = item.slice(1);

			if (item[1] instanceof Array)
				processTreeItemsProc(systemProfiles, args, pathBuilder, score, capabilities);
			else
				systemProfiles.push({ score: score, path: pathBuilder, launchers: args, capabilities: capabilities });
		};

		var launchers = SC.util.createEnum([
			'ClickOnceDirect',
			'ClickOnceRun',
			'WebStartBootstrap',
			'WebStartDirect',
			'MacBundleDownload',
			'WindowsInstallerDownload',
			'LinuxAppInstallerDownload',
			'UrlLaunch',
			'MacBundleSelector',
			'LinuxAppSelector',
			'AndroidSelector',
			'WindowsSelector',
			'IosSelector',
			'AndroidIntent',
			'PlayStore',
			'AppStore',
		]);

		var helpPanels = SC.util.createEnum([
			'ChromeDangerousFileConfirmation',
			'ChromeFileRun',
			'MacBundleExtraction',
			'MacChromeUrlConfirmation',
			'MacFileConfirmation',
			'MacFirefoxBundleConfirmation',
			'MacFirefoxBundleRun',
			'MacFirefoxJnlpConfirmation',
			'MacFirefoxUrlConfirmation',
			'MacGuestConnected',
			'MacSafariFileRun',
			'MacWebStartConfirmation',
			'LinuxFirefoxScriptDownload',
			'LinuxFirefoxUrlConfirmation',
			'LinuxChromeScriptDownload',
			'LinuxChromeUrlConfirmation',
			'LinuxScriptRun',
			'WindowsClickOnceConfirmation',
			'WindowsExeConfirmation',
			'WindowsFirefoxExeConfirmation',
			'WindowsFirefoxExeRun',
			'WindowsFirefoxJnlpConfirmation',
			'WindowsGuestConnected',
			'WindowsInternetExplorerExeRun',
			'WindowsWebStartConfirmation',
		]);

		var systemProfileTree = [
			[SC.util.Caps.WindowsDesktop,
				[[{ major: 6 }, null],
					[SC.util.Caps.InternetExplorer,
						[SC.types.ProcessType.Host,
							launchers.UrlLaunch,
							launchers.WindowsInstallerDownload,
							launchers.ClickOnceDirect,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
						[null,
							launchers.ClickOnceDirect,
							launchers.UrlLaunch,
							launchers.WindowsInstallerDownload,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
					],
					[SC.util.Caps.Chrome,
						[SC.types.ProcessType.Host,
							launchers.UrlLaunch,
							launchers.WindowsInstallerDownload,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
						[null,
							launchers.ClickOnceRun,
							launchers.UrlLaunch,
							launchers.WindowsInstallerDownload,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
					],
					[SC.util.Caps.Firefox,
						[SC.types.ProcessType.Host,
							launchers.UrlLaunch,
							launchers.WindowsInstallerDownload,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
						[null,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
							launchers.UrlLaunch,
							launchers.WindowsInstallerDownload,
						],
					],
					[SC.types.ProcessType.Host,
						launchers.WindowsSelector,
						launchers.ClickOnceRun,
						launchers.WebStartBootstrap,
						launchers.WebStartDirect,
					],
					[null,
						launchers.ClickOnceRun,
						launchers.WebStartBootstrap,
						launchers.WebStartDirect,
						launchers.WindowsSelector,
					],
				],
				[[{ major: 5 }, { major: 6 }],
					[SC.util.Caps.InternetExplorer,
						[SC.util.Caps.ClickOnce,
							launchers.ClickOnceDirect,
							launchers.WebStartBootstrap,
							launchers.ClickOnceRun,
							launchers.WebStartDirect,
							launchers.WindowsSelector,
						],
						[null,
							launchers.WebStartBootstrap,
							launchers.ClickOnceRun,
							launchers.WebStartDirect,
							launchers.WindowsSelector,
						],
					],
					[SC.util.Caps.Chrome,
						[SC.types.ProcessType.Host,
							launchers.WindowsSelector,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
						[SC.util.Caps.ClickOnce,
							launchers.ClickOnceDirect,
							launchers.WebStartBootstrap,
							launchers.ClickOnceRun,
							launchers.WebStartDirect,
							launchers.WindowsSelector,
						],
						[null,
							launchers.WindowsSelector,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
					],
					[SC.util.Caps.Firefox,
						[SC.types.ProcessType.Host,
							launchers.WindowsSelector,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
						],
						[SC.util.Caps.ClickOnce,
							launchers.ClickOnceDirect,
							launchers.WebStartBootstrap,
							launchers.ClickOnceRun,
							launchers.WebStartDirect,
							launchers.WindowsSelector,
						],
						[SC.util.Caps.WebStart,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
							launchers.WindowsSelector,
						],
						[null,
							launchers.ClickOnceRun,
							launchers.WebStartBootstrap,
							launchers.WebStartDirect,
							launchers.WindowsSelector,
						],
					],
					[SC.types.ProcessType.Host,
						launchers.WindowsSelector,
						launchers.ClickOnceRun,
						launchers.WebStartBootstrap,
						launchers.WebStartDirect,
					],
					[null,
						launchers.ClickOnceRun,
						launchers.WebStartBootstrap,
						launchers.WebStartDirect,
						launchers.WindowsSelector,
					],
				],
			],
			[SC.util.Caps.MacOSX,
				[[{ major: 10, minor: 9 }, null],
					[SC.util.Caps.Safari,
						launchers.MacBundleSelector,
						launchers.WebStartDirect,
					],
				],
				[[{ major: 10, minor: 7 }, { major: 10, minor: 9 }],
					[SC.util.Caps.Safari,
						launchers.UrlLaunch,
						launchers.MacBundleDownload,
						launchers.WebStartDirect,
					],
				],
				[[{ major: 10, minor: 7 }, null],
					[SC.util.Caps.Chrome,
						launchers.MacBundleSelector,
						launchers.WebStartDirect,
					],
					[SC.util.Caps.Firefox,
						launchers.MacBundleSelector,
						launchers.WebStartDirect,
					],
					[null,
						launchers.MacBundleSelector,
						launchers.WebStartDirect,
					],
				],
				[null,
					launchers.WebStartDirect,
				],
			],
			[SC.util.Caps.LinuxDesktop,
				[SC.util.Caps.Firefox,
					launchers.LinuxAppSelector,
					launchers.WebStartDirect,
				],
				[SC.util.Caps.Chrome,
					launchers.LinuxAppSelector,
					launchers.WebStartDirect,
				],
				[null,
					launchers.LinuxAppSelector,
					launchers.WebStartDirect,
				],
			],
			[SC.util.Caps.Android,
				[SC.util.Caps.WebKit,
					[SC.util.Caps.NativeClient,
						launchers.UrlLaunch,
					],
					[[{ major: 537 }, null],
						launchers.AndroidIntent,
					],
				],
				[SC.util.Caps.Firefox,
					launchers.AndroidSelector,
				],
				[null,
					launchers.UrlLaunch,
					launchers.PlayStore,
				],
			],
			[SC.util.Caps.iOS,
				[SC.util.Caps.NativeClient,
					launchers.UrlLaunch,
				],
				[SC.util.Caps.Safari,
					launchers.IosSelector,
				],
				[SC.util.Caps.Firefox,
					launchers.AppStore,
				],
				[null,
					launchers.UrlLaunch,
					launchers.AppStore,
				],
			],
			[SC.util.Caps.WindowsModern,
				launchers.UrlLaunch,
			],
			[null,
				launchers.WebStartDirect,
				launchers.UrlLaunch,
			],
		];

		(function () {
			var systemProfiles = [];
			processTreeItemsProc(systemProfiles, systemProfileTree, '', 0, []);

			systemProfiles.sort(function (x, y) {
				var scoreResult = y.score - x.score;
				return (scoreResult != 0 ? scoreResult : x.path.localeCompare(y.path));
			});

			var systemProfilePanelDefinitions = Array.prototype.map.call(systemProfiles, function (sc) {
				return createPanelDefinitionFunc(
					sc.path,
					null,
					null,
					null,
					Array.prototype.map.call(sc.launchers, function (launcher) {
						var containsCapabilityFunc = function (capability) { return Array.prototype.indexOf.call(sc.capabilities, capability) != -1; };
						return createLauncherPanelDefinitionFunc(launcher, containsCapabilityFunc);
					}),
					true,
					false,
					null,
					function (childPanels, childStringPaths) {
						return [$p({ _textResource: 'JoinPanel.Launcher.LauncherMessage' })].concat(createChildPanelDecoratedListFunc(childPanels, childStringPaths));
					},
					null
				);
			});

			window._joinPanelDefinitionTreeRoot = createPanelDefinitionFunc(
				'SystemProfiles',
				null,
				null,
				null,
				systemProfilePanelDefinitions,
				true,
				false,
				null,
				function (childPanels, childStringPaths) {
					return [$p({ _textResource: 'JoinPanel.Launcher.SystemProfileMessage' })].concat(createChildPanelListFunc(childPanels, childStringPaths));
				},
				null
			);
		})();
	}

	return window._joinPanelDefinitionTreeRoot;
}

export function getPanelDefinitionPath(stringPath, panelDefinitionTreeRoot) {
	var panelDefinitionPath = [panelDefinitionTreeRoot];

	if (stringPath != null) {
		var stringPathParts = stringPath.split('/');

		for (var i = 0; i < stringPathParts.length; i++) {
			var pathPart = Array.prototype.find.call(panelDefinitionPath[panelDefinitionPath.length - 1].childPanels, function (cp) { return cp.key == stringPathParts[i]; });

			if (pathPart == null)
				return null;

			panelDefinitionPath.push(pathPart);
		}
	}

	return panelDefinitionPath;
};

export function getInitialJoinPanelDefinitionPath(joinPanelDefinitionTreeRoot) {
	var panelDefinitionPath = null;
	var settings = SC.util.loadSettings();

	if (settings.joinPath)
		panelDefinitionPath = getPanelDefinitionPath(settings.joinPath, joinPanelDefinitionTreeRoot);

	if (panelDefinitionPath == null) {
		panelDefinitionPath = [joinPanelDefinitionTreeRoot];

		while (panelDefinitionPath[panelDefinitionPath.length - 1].shouldAutoNavigateToFirstChild)
			panelDefinitionPath.push(panelDefinitionPath[panelDefinitionPath.length - 1].childPanels[0]);
	}

	return panelDefinitionPath;
}

export function startJoinSession(
	initialJoinInfo,
	getClientLaunchParametersFunc
) {
	var dialog: Dialog;
	var joiningClientLaunchParameters = null;
	var joiningParticipantCount = null;
	var joiningPanelDefinition = null;
	var titlePanel = SC.dialog.createTitlePanel(SC.res['JoinPanel.Title']);
	var contentPanel = SC.dialog.createContentPanel();
	var buttonPanel = SC.dialog.createButtonPanel();
	var getClientLaunchParametersAbortController = undefined;

	var joinInfoEventArgs = SC.event.dispatchEvent(
		null,
		SC.event.QueryJoinInfo,
		Object.assign(
			{},
			{ // arguments[i] for extension backwards compatiblity
				shouldShowPrompt: arguments[2],
				promptText: arguments[3],
				fieldMap: arguments[4] || {},
				buttonText: arguments[5],
				processType: arguments[6] || SC.context.processType,
			},
			initialJoinInfo
		)
	);

	var joinPanelDefinitionTreeRoot = getJoinPanelDefinitionTreeRoot(joinInfoEventArgs.processType);

	var getStringPathFunc = function (panelDefinitionPath) {
		if (panelDefinitionPath.length == 1)
			return null;

		return Array.prototype.map.call(panelDefinitionPath.slice(1), function (pd) { return pd.key; }).join('/');
	};

	var queryParticipantJoinedCountProc = function (clientLaunchParameters) {
		var eventArgs = SC.event.dispatchGlobalEvent(SC.event.QueryParticipantJoinedCount, { session: joinInfoEventArgs.session, clientLaunchParameters: clientLaunchParameters, participantJoinedCount: 0 });
		return eventArgs.participantJoinedCount;
	};

	var renderPromptProc = function () {
		SC.ui.clear(contentPanel);

		SC.ui.addElement(contentPanel, 'P', { _innerHTMLToBeSanitized: joinInfoEventArgs.promptText });

		var definitionList = SC.ui.addElement(contentPanel, 'DL');
		var button = SC.ui.addElement(buttonPanel, 'INPUT', { type: 'button', _commandName: 'Enter', value: joinInfoEventArgs.buttonText });
		var focused = false;

		joinInfoEventArgs.fieldMap.forEachKeyValue(function (promptFieldKey, promptField) {
			if (promptField.visible) {
				var inputElement = promptField.type == 'L' ? SC.ui.createElement('SPAN', promptField.value) : SC.ui.createTextBox({ _commandName: 'Enter' }, promptField.type == 'B', promptField.type == 'P');

				if (typeof inputElement.value !== 'undefined') {
					inputElement.value = promptField.value;
					inputElement._promptField = promptField;
				}

				SC.ui.addElement(definitionList, 'DT', promptField.labelText);
				SC.ui.addElement(definitionList, 'DD', inputElement);

				if (!focused) {
					inputElement.autofocus = true;
					focused = true;
				}
			}
		});

		if (!focused)
			button.focus();
	};

	var renderJoinProc = function (panelDefinitionPath) {
		var panelDefinition = panelDefinitionPath[panelDefinitionPath.length - 1];

		contentPanel.scrollTop = 0;
		SC.dialog.hideButtonPanel();

		if (panelDefinition.joinContentBuilderFunc != null) {
			var childPanelStringPaths = panelDefinition.childPanels == null ? null : Array.prototype.map.call(panelDefinition.childPanels, function (cpd) { return getStringPathFunc(panelDefinitionPath.concat(cpd)); });
			var parentPanelDefinition = panelDefinitionPath[panelDefinitionPath.length - 2] || null;
			var parentPanelDefinitionPath = panelDefinitionPath.slice(0, panelDefinitionPath.length - 1);
			var selectedChildIndex = (parentPanelDefinition == null ? -1 : Array.prototype.indexOf.call(parentPanelDefinition.childPanels, panelDefinition));
			var nextPanelDefinition = (parentPanelDefinition == null || parentPanelDefinition.length == 1 ? null : parentPanelDefinition.childPanels[(selectedChildIndex + 1) % parentPanelDefinition.childPanels.length]);
			var nextPanelStringPath = (nextPanelDefinition == null ? null : getStringPathFunc(parentPanelDefinitionPath.concat(nextPanelDefinition)));
			var contentPanelContents = panelDefinition.joinContentBuilderFunc(panelDefinition.childPanels, childPanelStringPaths, nextPanelDefinition, nextPanelStringPath);
			if (contentPanelContents)
				SC.ui.setContents(contentPanel, contentPanelContents);
		}

		var lineageParagraph = SC.ui.addElement(contentPanel, 'P', { className: 'Help' });
		var lineagePanelDefinitionPath = [];

		Array.prototype.forEach.call(panelDefinitionPath, function (pd) {
			if (lineagePanelDefinitionPath.length != 0)
				SC.ui.addElement(lineageParagraph, 'SPAN', ' / ');

			lineagePanelDefinitionPath.push(pd);

			var stringPath = getStringPathFunc(lineagePanelDefinitionPath);

			if (lineagePanelDefinitionPath.length == panelDefinitionPath.length)
				SC.ui.addElement(lineageParagraph, 'SPAN', pd.key);
			else
				SC.ui.addElement(lineageParagraph, 'A', { _commandName: 'NavigateJoinPanel', _commandArgument: stringPath }, pd.key);
		});

		if (panelDefinition.joinProc != null) {
			joiningPanelDefinition = panelDefinition;
			joinIfReady();
		}
	};

	var joinIfReady = function () {
		if (joiningPanelDefinition && joiningClientLaunchParameters) {
			joiningParticipantCount = queryParticipantJoinedCountProc(joiningClientLaunchParameters);
			joiningPanelDefinition.joinProc(joiningClientLaunchParameters);

			var joinData = SC.util.formatString('({0}) {1}', joiningPanelDefinition.key, SC.util.getUserAgent());
			SC.service.LogInitiatedJoin(joiningClientLaunchParameters.s, SC.types.ProcessType[joiningClientLaunchParameters.y], joinData, null, function (error) {
				// we don't want to do anything if the status is 0 because most likely that was the result of an incomplete transaction (see https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/status)
				// this started because Chrome on iOS appears to make xhr call its onError handler when you set window.location.href and there is a pending xhr (see SCP-32789)
				return error.status != 0;
			});
		}
	};

	var endPromptProc = function (onErrorProc) {
		SC.event.dispatchGlobalEvent(SC.event.JoinPromptCompleted, joinInfoEventArgs);

		getClientLaunchParametersAbortController = getClientLaunchParametersFunc(
			joinInfoEventArgs,
			joinInfoEventArgs.fieldMap, // legacy
			function (clientLaunchParameters) {
				joiningClientLaunchParameters = clientLaunchParameters;
				joinIfReady();
			},
			onErrorProc
		);

		var initialPanelDefinitionPath = getInitialJoinPanelDefinitionPath(joinPanelDefinitionTreeRoot);
		renderJoinProc(initialPanelDefinitionPath);
	};

	var renderConnectedFunc = function () {
		SC.dialog.hideButtonPanel();

		var processType = SC.types.ProcessType[joiningClientLaunchParameters.y];
		var sessionType = SC.types.SessionType[joiningClientLaunchParameters.e];
		var contentPanelContents = joiningPanelDefinition.connectedContentBuilderFunc(sessionType, processType);
		if (contentPanelContents) {
			SC.ui.setContents(contentPanel, contentPanelContents);
			return true;
		}

		return false;
	};

	var onExecuteCommandProc: Parameters<typeof SC.dialog.showModalDialogRaw>[2] = function (eventArgs, _, __, onErrorProc) {
		if (eventArgs.commandName == 'NavigateJoinPanel' || eventArgs.commandName == 'Load') {
			var panelDefinitionPath = getPanelDefinitionPath(eventArgs.commandArgument, joinPanelDefinitionTreeRoot);

			if (eventArgs.commandName == 'NavigateJoinPanel' && panelDefinitionPath != null && panelDefinitionPath[panelDefinitionPath.length - 1].shouldRememberSelection) {
				SC.util.modifySettings(function (settings) {
					settings.joinPath = eventArgs.commandArgument;
				});
			}

			renderJoinProc(panelDefinitionPath);
		} else if (eventArgs.commandName == 'Enter') {
			SC.ui.findDescendant(contentPanel, function (n) {
				if (typeof n._promptField !== 'undefined')
					n._promptField.value = n.value;
			});

			endPromptProc(onErrorProc);
		}
	};

	var refreshProc = function () {
		if (joiningClientLaunchParameters && joiningParticipantCount != null) {
			if (queryParticipantJoinedCountProc(joiningClientLaunchParameters) > joiningParticipantCount) {
				if (!renderConnectedFunc())
					SC.dialog.hideModalDialog(dialog);

				joiningClientLaunchParameters = null;
			}
		}
	};

	(function () {
		SC.event.addGlobalHandler(SC.event.LiveDataRefreshed, refreshProc);

		if (joinInfoEventArgs.shouldShowPrompt)
			renderPromptProc();
		else
			endPromptProc();

		refreshProc();

		dialog = SC.dialog.showModalDialogRaw('JoinSession', [titlePanel, contentPanel, buttonPanel], onExecuteCommandProc, null, function () {
			SC.event.removeGlobalHandler(SC.event.LiveDataRefreshed, refreshProc);

			if (joiningPanelDefinition && joiningPanelDefinition.cancelJoinProc)
				joiningPanelDefinition.cancelJoinProc();

			if (getClientLaunchParametersAbortController && getClientLaunchParametersAbortController.abort)
				getClientLaunchParametersAbortController.abort();

			SC.event.dispatchEvent(dialog, SC.event.JoinSessionCompleted);
		});
	})();
}
