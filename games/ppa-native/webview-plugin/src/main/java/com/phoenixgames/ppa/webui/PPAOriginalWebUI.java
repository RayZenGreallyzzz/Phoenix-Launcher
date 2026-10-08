package com.phoenixgames.ppa.webui;

import android.app.Activity;
import android.graphics.Color;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.util.Log;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Set;
import org.json.JSONObject;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * A single Android WebView presenting the *unmodified* PPA charFrame iframe.
 * Godot continues to render the real 3D world underneath it.
 *
 * Security model for first integration:
 * - No game session, bearer token, Telegram initData, save or wallet injected.
 * - The page is generated locally from a separately verified original srcdoc.
 * - No arbitrary navigation, downloads, file access or third-party websites.
 * - JavaScript sends only allowlisted UI lifecycle events into native code.
 * - Original transactional postMessage actions are NOT executed until they
 *   can be bound to the authoritative Phoenix server, never a fake wallet.
 */
public final class PPAOriginalWebUI extends GodotPlugin {
    private static final String TAG = "PPAOriginalWebUI";
    private static final String BASE_URL =
            "https://ppa-phoenixpixarena.1988stella1988.workers.dev/";
    private static final String EVENT_NAME = "ppa_ui_event";
    private WebView browser;
    private volatile boolean showing = false;
    private long openedAtNanos = 0L;

    public PPAOriginalWebUI(Godot godot) { super(godot); }

    @Override
    public String getPluginName() { return "PPAOriginalWebUI"; }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        return Collections.singleton(new SignalInfo(EVENT_NAME, String.class));
    }

    @UsedByGodot
    public boolean isShowing() { return showing; }

    @UsedByGodot
    public void showCharacter(String className, int initialPage) {
        // The native visual-class key is NOT the Telegram character's actual
        // saved profession. Until a verified player snapshot arrives,
        // this title is only the currently selected 3D test model.
        final String safeClassName = sourceClassLabel(className);
        final int page = Math.max(0, Math.min(4, initialPage));
        runOnHostThread(() -> {
            final Activity activity = getActivity();
            if (activity == null) {
                emitSignal(EVENT_NAME, "error:activity_unavailable");
                return;
            }
            try {
                removeWebView();
                final String original = readOriginalCharacter(activity);
                final FrameLayout root = activity.findViewById(android.R.id.content);
                if (root == null) {
                    emitSignal(EVENT_NAME, "error:android_root_missing");
                    return;
                }

                browser = new WebView(activity);
                browser.setBackgroundColor(Color.TRANSPARENT);
                browser.setLayerType(View.LAYER_TYPE_HARDWARE, null);
                browser.setOverScrollMode(View.OVER_SCROLL_NEVER);
                browser.setVerticalScrollBarEnabled(false);
                browser.setHorizontalScrollBarEnabled(false);
                browser.setFocusableInTouchMode(true);

                final WebSettings settings = browser.getSettings();
                settings.setJavaScriptEnabled(true);
                settings.setDomStorageEnabled(false);
                settings.setAllowFileAccess(false);
                settings.setAllowContentAccess(false);
                settings.setAllowFileAccessFromFileURLs(false);
                settings.setAllowUniversalAccessFromFileURLs(false);
                settings.setJavaScriptCanOpenWindowsAutomatically(false);
                settings.setSupportMultipleWindows(false);
                settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
                settings.setCacheMode(WebSettings.LOAD_DEFAULT);

                browser.setWebViewClient(new WebViewClient() {
                    @Override
                    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                        // The original charFrame is a menu, not a new game browser.
                        return true;
                    }
                });
                browser.setDownloadListener((u, ua, c, m, l) -> {
                    Log.w(TAG, "Blocked untrusted download");
                    emitSignal(EVENT_NAME, "blocked_download");
                });
                browser.addJavascriptInterface(new JsEvents(), "PPA_NATIVE");

                browser.setOnKeyListener((view, keyCode, event) -> {
                    if (keyCode == KeyEvent.KEYCODE_BACK && event.getAction() == KeyEvent.ACTION_UP) {
                        closeFromPage();
                        return true;
                    }
                    return false;
                });
                final FrameLayout.LayoutParams bounds = new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT);
                root.addView(browser, bounds);
                showing = true;
                openedAtNanos = System.nanoTime();
                browser.loadDataWithBaseURL(BASE_URL,
                        buildHostDocument(original, safeClassName, page),
                        "text/html", "UTF-8", null);
                browser.requestFocus();
                emitSignal(EVENT_NAME, "opened");
            } catch (Exception ex) {
                Log.e(TAG, "Unable to open original PPA character iframe", ex);
                removeWebView();
                emitSignal(EVENT_NAME, "error:original_frame_unavailable");
            }
        });
    }

    @UsedByGodot
    public void hideUi() { runOnHostThread(this::removeWebView); }

    private String readOriginalCharacter(Activity activity) throws Exception {
        try (InputStream stream = activity.getAssets().open("ppa_original/charFrame.html");
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] bytes = new byte[16384];
            int read;
            while ((read = stream.read(bytes)) != -1) {
                output.write(bytes, 0, read);
                if (output.size() > 400_000) {
                    throw new IllegalStateException("PPA menu asset larger than expected");
                }
            }
            String html = output.toString(StandardCharsets.UTF_8.name());
            if (!html.contains("parent.postMessage(") ||
                    !html.contains("id=\"activeSkills\"") ||
                    !html.contains("id=\"viewport\"")) {
                throw new IllegalStateException("Original PPA srcdoc validation failed");
            }
            return html;
        }
    }

    private static String sourceClassLabel(String key) {
        if (key == null) return "ГЕРОЙ";
        switch (key.toLowerCase(java.util.Locale.ROOT)) {
            case "tank": return "СТРАЖ";
            case "barbarian": return "ВАРВАР";
            case "paladin": return "ПАЛАДИН";
            case "gnome": return "ГНОМ · КАНОНИР";
            case "archer": return "ЛУЧНИК";
            case "mage": return "МАГ";
            case "assassin": return "АССАСИН";
            case "priest": return "ЖРЕЦ";
            default: return "ГЕРОЙ";
        }
    }

    private static String htmlAttribute(String text) {
        return text.replace("&", "&amp;").replace("\"", "&quot;")
                .replace("<", "&lt;").replace(">", "&gt;");
    }

    private static String buildHostDocument(String original, String className, int page) {
        // Preserve original Telegram host's #charFrame CSS and browser touch
        // mechanics. iframe.srcdoc retains its exact HTML, JS and CSS bytes.
        return "<!doctype html><html lang=\"ru\"><head><meta charset=\"UTF-8\">" +
                "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no\">" +
                "<style>*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}" +
                "#shade{position:fixed;inset:0;background:rgba(0,0,0,.34)}" +
                "#charFrame{position:fixed;left:50%;top:50%;transform:translate(-50%,-50%);" +
                "width:min(88vw,400px);height:min(90dvh,760px);border:0;border-radius:14px;background:transparent}" +
                "@media(orientation:landscape){#charFrame{width:min(46vw,430px);height:min(91dvh,680px)}}" +
                "@media(orientation:portrait){#charFrame{width:min(88vw,400px);height:min(88dvh,760px)}}" +
                "@media(orientation:landscape) and (max-height:500px){#charFrame{width:min(48vw,410px);height:94dvh}}" +
                "@media(orientation:landscape) and (max-height:620px){#charFrame{left:0;top:0;transform:none;" +
                "width:100vw;height:100dvh;max-width:none;max-height:none;border-radius:0}}" +
                "</style><script>(function(){'use strict';" +
                "var initialPage=" + page + ";var className=" + JSONObject.quote(className) + ";" +
                "var pageApplied=false;" +
                "function tell(type){PPA_NATIVE.deliver(JSON.stringify({type:type}));}" +
                "function sendClass(){" +
                "var frame=document.getElementById('charFrame');" +
                "if(frame&&frame.contentWindow)frame.contentWindow.postMessage({type:'setClass',name:className},'*');}" +
                "function selectPageAfterOriginalBoot(){" +
                "if(pageApplied)return;pageApplied=true;" +
                // The original PPA srcdoc itself calls go(0) 300 ms after
                // loading. Request navigation only AFTER that original
                // initialization; we do not patch any original JS or CSS.
                "if(initialPage===0)return;" +
                "window.setTimeout(function(){" +
                "var f=document.getElementById('charFrame');" +
                "if(f&&f.contentWindow&&typeof f.contentWindow.go==='function')" +
                "f.contentWindow.go(initialPage);" +
                "},370);" +
                "}" +
                "window.addEventListener('message',function(e){" +
                "var f=document.getElementById('charFrame');" +
                "if(!f||e.source!==f.contentWindow)return;" +
                "var d=e.data||{};if(typeof d.type!=='string')return;" +
                "if(d.type==='charReady'){" +
                "sendClass();selectPageAfterOriginalBoot();tell('charReady');return;}" +
                "if(d.type==='closeChar'){tell('closeChar');return;}" +
                // Original PPA menu emits charRequestState whenever pages
                // switch. It is deliberately unanswered until the real
                // authenticated state bridge is ready. Empty server data
                // must never be confused with fabricated test inventory.
                "if(d.type==='charRequestState'){tell('stateRequested');return;}" +
                "});" +
                "window.closePpa=function(){tell('closeChar');};" +
                "window.onPpaFrameLoad=function(){sendClass();};" +
                "})();</script></head>" +
                "<body><div id=\"shade\" onclick=\"closePpa()\"></div>" +
                "<iframe id=\"charFrame\" title=\"Персонаж\" onload=\"onPpaFrameLoad()\" srcdoc=\"" +
                htmlAttribute(original) + "\"></iframe></body></html>";
    }

    private void closeFromPage() {
        removeWebView();
        emitSignal(EVENT_NAME, "closeChar");
    }

    private void removeWebView() {
        WebView previous = browser;
        browser = null;
        showing = false;
        if (previous == null) return;
        if (openedAtNanos > 0L) {
            final long elapsedMs = Math.max(0L, (System.nanoTime() - openedAtNanos) / 1_000_000L);
            Log.i(TAG, "PPA_ORIGINAL_WEBVIEW_LIFETIME_MS " + elapsedMs);
            openedAtNanos = 0L;
        }
        ViewGroup owner = (ViewGroup) previous.getParent();
        if (owner != null) owner.removeView(previous);
        previous.removeJavascriptInterface("PPA_NATIVE");
        previous.stopLoading();
        previous.loadUrl("about:blank");
        previous.destroy();
    }

    private final class JsEvents {
        @JavascriptInterface
        public void deliver(String value) {
            if (value == null || value.length() > 384 || !showing) return;
            try {
                JSONObject object = new JSONObject(value);
                String type = object.optString("type", "");
                if ("closeChar".equals(type)) {
                    runOnHostThread(PPAOriginalWebUI.this::closeFromPage);
                } else if ("charReady".equals(type) || "stateRequested".equals(type)) {
                    emitSignal(EVENT_NAME, type);
                }
                // No iframe action ever changes accounts, inventory, books,
                // currency, skills or purchases in this read-only pilot.
            } catch (Exception e) {
                Log.w(TAG, "Ignored invalid UI message");
            }
        }
    }
}
