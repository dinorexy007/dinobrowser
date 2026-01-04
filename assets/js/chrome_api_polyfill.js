/**
 * Chrome Extension API Polyfill for Dino Browser
 * 
 * Implements commonly used Chrome extension APIs using JavaScript
 * Injected before content scripts to provide compatibility layer
 */

(function () {
    'use strict';

    // Prevent re-initialization
    if (window.__dinoExtensionPolyfill) return;
    window.__dinoExtensionPolyfill = true;

    // ============================================
    // Storage Implementation
    // ============================================

    const STORAGE_PREFIX = '__dino_ext_storage_';

    function createStorage(type) {
        const prefix = STORAGE_PREFIX + type + '_';

        return {
            get: function (keys, callback) {
                try {
                    let result = {};

                    if (keys === null || keys === undefined) {
                        // Get all items
                        for (let i = 0; i < localStorage.length; i++) {
                            const key = localStorage.key(i);
                            if (key && key.startsWith(prefix)) {
                                const actualKey = key.substring(prefix.length);
                                try {
                                    result[actualKey] = JSON.parse(localStorage.getItem(key));
                                } catch (e) {
                                    result[actualKey] = localStorage.getItem(key);
                                }
                            }
                        }
                    } else if (typeof keys === 'string') {
                        const value = localStorage.getItem(prefix + keys);
                        if (value !== null) {
                            try {
                                result[keys] = JSON.parse(value);
                            } catch (e) {
                                result[keys] = value;
                            }
                        }
                    } else if (Array.isArray(keys)) {
                        keys.forEach(function (key) {
                            const value = localStorage.getItem(prefix + key);
                            if (value !== null) {
                                try {
                                    result[key] = JSON.parse(value);
                                } catch (e) {
                                    result[key] = value;
                                }
                            }
                        });
                    } else if (typeof keys === 'object') {
                        Object.keys(keys).forEach(function (key) {
                            const value = localStorage.getItem(prefix + key);
                            if (value !== null) {
                                try {
                                    result[key] = JSON.parse(value);
                                } catch (e) {
                                    result[key] = value;
                                }
                            } else {
                                result[key] = keys[key]; // Default value
                            }
                        });
                    }

                    if (callback) callback(result);
                    return Promise.resolve(result);
                } catch (e) {
                    console.error('[Dino] Storage get error:', e);
                    if (callback) callback({});
                    return Promise.resolve({});
                }
            },

            set: function (items, callback) {
                try {
                    Object.keys(items).forEach(function (key) {
                        localStorage.setItem(prefix + key, JSON.stringify(items[key]));
                    });
                    if (callback) callback();
                    return Promise.resolve();
                } catch (e) {
                    console.error('[Dino] Storage set error:', e);
                    if (callback) callback();
                    return Promise.resolve();
                }
            },

            remove: function (keys, callback) {
                try {
                    if (typeof keys === 'string') {
                        localStorage.removeItem(prefix + keys);
                    } else if (Array.isArray(keys)) {
                        keys.forEach(function (key) {
                            localStorage.removeItem(prefix + key);
                        });
                    }
                    if (callback) callback();
                    return Promise.resolve();
                } catch (e) {
                    console.error('[Dino] Storage remove error:', e);
                    if (callback) callback();
                    return Promise.resolve();
                }
            },

            clear: function (callback) {
                try {
                    const keysToRemove = [];
                    for (let i = 0; i < localStorage.length; i++) {
                        const key = localStorage.key(i);
                        if (key && key.startsWith(prefix)) {
                            keysToRemove.push(key);
                        }
                    }
                    keysToRemove.forEach(function (key) {
                        localStorage.removeItem(key);
                    });
                    if (callback) callback();
                    return Promise.resolve();
                } catch (e) {
                    console.error('[Dino] Storage clear error:', e);
                    if (callback) callback();
                    return Promise.resolve();
                }
            }
        };
    }

    // ============================================
    // Message Passing Implementation
    // ============================================

    const messageListeners = [];

    function createMessageChannel() {
        return {
            addListener: function (callback) {
                messageListeners.push(callback);
            },

            removeListener: function (callback) {
                const index = messageListeners.indexOf(callback);
                if (index > -1) {
                    messageListeners.splice(index, 1);
                }
            },

            hasListener: function (callback) {
                return messageListeners.includes(callback);
            }
        };
    }

    function sendMessage(message, responseCallback) {
        // In Dino Browser, messages are handled within the same page context
        // For extension popups/background, we use postMessage

        let responded = false;
        const sendResponse = function (response) {
            if (!responded) {
                responded = true;
                if (responseCallback) responseCallback(response);
            }
        };

        // Notify all listeners
        messageListeners.forEach(function (listener) {
            try {
                const result = listener(message, { id: 'dino-browser' }, sendResponse);
                if (result === true) {
                    // Listener will call sendResponse asynchronously
                }
            } catch (e) {
                console.error('[Dino] Message listener error:', e);
            }
        });

        // Return true if async response expected
        return true;
    }

    // ============================================
    // Chrome API Object
    // ============================================

    const chrome = {
        // Runtime API
        runtime: {
            id: 'dino-browser-extension',

            sendMessage: sendMessage,

            onMessage: createMessageChannel(),

            getURL: function (path) {
                // Return relative path for now
                return path;
            },

            getManifest: function () {
                return {
                    manifest_version: 3,
                    name: 'Dino Browser Extension',
                    version: '1.0.0'
                };
            },

            lastError: null,

            connect: function (extensionId, connectInfo) {
                // Stub for port connections
                return {
                    name: connectInfo?.name || '',
                    onMessage: createMessageChannel(),
                    onDisconnect: createMessageChannel(),
                    postMessage: function (msg) {
                        console.log('[Dino] Port message:', msg);
                    },
                    disconnect: function () { }
                };
            },

            onConnect: createMessageChannel(),
            onInstalled: createMessageChannel()
        },

        // Storage API
        storage: {
            local: createStorage('local'),
            sync: createStorage('sync'),
            session: createStorage('session'),

            onChanged: {
                addListener: function (callback) {
                    // Storage change events - stub for now
                    console.log('[Dino] Storage onChanged listener added');
                },
                removeListener: function (callback) { },
                hasListener: function (callback) { return false; }
            }
        },

        // Tabs API (limited)
        tabs: {
            query: function (queryInfo, callback) {
                // Return current tab info
                const tabs = [{
                    id: 1,
                    url: window.location.href,
                    title: document.title,
                    active: true,
                    index: 0,
                    windowId: 1
                }];
                if (callback) callback(tabs);
                return Promise.resolve(tabs);
            },

            sendMessage: function (tabId, message, options, responseCallback) {
                if (typeof options === 'function') {
                    responseCallback = options;
                }
                return sendMessage(message, responseCallback);
            },

            create: function (createProperties, callback) {
                // Open in new tab - send to Dino Browser
                if (createProperties.url) {
                    window.open(createProperties.url, '_blank');
                }
                if (callback) callback({ id: 2, url: createProperties.url });
                return Promise.resolve({ id: 2, url: createProperties.url });
            },

            update: function (tabId, updateProperties, callback) {
                if (updateProperties.url) {
                    window.location.href = updateProperties.url;
                }
                if (callback) callback({ id: tabId });
                return Promise.resolve({ id: tabId });
            },

            getCurrent: function (callback) {
                const tab = {
                    id: 1,
                    url: window.location.href,
                    title: document.title,
                    active: true
                };
                if (callback) callback(tab);
                return Promise.resolve(tab);
            },

            onUpdated: createMessageChannel(),
            onActivated: createMessageChannel()
        },

        // Alarms API (stub)
        alarms: {
            create: function (name, alarmInfo) {
                console.log('[Dino] Alarm created:', name);
            },
            get: function (name, callback) {
                if (callback) callback(null);
                return Promise.resolve(null);
            },
            getAll: function (callback) {
                if (callback) callback([]);
                return Promise.resolve([]);
            },
            clear: function (name, callback) {
                if (callback) callback(true);
                return Promise.resolve(true);
            },
            clearAll: function (callback) {
                if (callback) callback(true);
                return Promise.resolve(true);
            },
            onAlarm: createMessageChannel()
        },

        // Scripting API (limited)
        scripting: {
            executeScript: function (injection, callback) {
                try {
                    if (injection.func) {
                        injection.func();
                    } else if (injection.files) {
                        console.log('[Dino] Script injection files:', injection.files);
                    }
                    if (callback) callback([{ result: true }]);
                    return Promise.resolve([{ result: true }]);
                } catch (e) {
                    console.error('[Dino] Script execution error:', e);
                    if (callback) callback([{ error: e.message }]);
                    return Promise.resolve([{ error: e.message }]);
                }
            },

            insertCSS: function (injection, callback) {
                try {
                    if (injection.css) {
                        const style = document.createElement('style');
                        style.textContent = injection.css;
                        (document.head || document.documentElement).appendChild(style);
                    }
                    if (callback) callback();
                    return Promise.resolve();
                } catch (e) {
                    if (callback) callback();
                    return Promise.resolve();
                }
            },

            removeCSS: function (injection, callback) {
                if (callback) callback();
                return Promise.resolve();
            }
        },

        // i18n API (stub)
        i18n: {
            getMessage: function (messageName, substitutions) {
                return messageName;
            },
            getUILanguage: function () {
                return navigator.language || 'en';
            },
            detectLanguage: function (text, callback) {
                if (callback) callback({ languages: [{ language: 'en' }] });
                return Promise.resolve({ languages: [{ language: 'en' }] });
            }
        },

        // Extension API
        extension: {
            getURL: function (path) {
                return path;
            },
            inIncognitoContext: false,
            getBackgroundPage: function (callback) {
                if (callback) callback(null);
                return Promise.resolve(null);
            }
        },

        // Action API (MV3 - stub for popup)
        action: {
            setIcon: function (details, callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            setTitle: function (details, callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            setBadgeText: function (details, callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            setBadgeBackgroundColor: function (details, callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            onClicked: createMessageChannel()
        },

        // Browser Action API (MV2 - alias to action)
        browserAction: null, // Set below

        // Web Request API (stub - can't fully implement)
        webRequest: {
            onBeforeRequest: createMessageChannel(),
            onBeforeSendHeaders: createMessageChannel(),
            onHeadersReceived: createMessageChannel(),
            onCompleted: createMessageChannel(),
            onErrorOccurred: createMessageChannel()
        },

        // Declarative Net Request API (stub)
        declarativeNetRequest: {
            updateDynamicRules: function (options, callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            getDynamicRules: function (callback) {
                if (callback) callback([]);
                return Promise.resolve([]);
            }
        },

        // Notifications API (stub)
        notifications: {
            create: function (notificationId, options, callback) {
                console.log('[Dino] Notification:', options.title, options.message);
                if (callback) callback(notificationId || 'notification-1');
                return Promise.resolve(notificationId || 'notification-1');
            },
            clear: function (notificationId, callback) {
                if (callback) callback(true);
                return Promise.resolve(true);
            },
            onClicked: createMessageChannel(),
            onClosed: createMessageChannel()
        },

        // Context Menus API (stub)
        contextMenus: {
            create: function (createProperties, callback) {
                if (callback) callback();
                return 'menu-item-1';
            },
            remove: function (menuItemId, callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            removeAll: function (callback) {
                if (callback) callback();
                return Promise.resolve();
            },
            onClicked: createMessageChannel()
        }
    };

    // Alias browserAction to action for MV2 compatibility
    chrome.browserAction = chrome.action;

    // ============================================
    // Install Chrome object globally
    // ============================================

    // Don't override if real Chrome APIs exist
    if (typeof window.chrome === 'undefined' || !window.chrome.runtime) {
        window.chrome = chrome;
    } else {
        // Merge with existing (add missing APIs)
        Object.keys(chrome).forEach(function (key) {
            if (!window.chrome[key]) {
                window.chrome[key] = chrome[key];
            }
        });
    }

    // Also expose as browser for Firefox extension compatibility
    if (typeof window.browser === 'undefined') {
        window.browser = chrome;
    }

    console.log('[Dino] Chrome Extension API Polyfill loaded');

})();
