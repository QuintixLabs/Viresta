// The layout a Viresta global theme applies when "Desktop and window layout" is
// ticked. Without it, Plasma falls back to Breeze's default panel. setup.sh fills in
// the @...@ values, and the panel here should match the tracked appletsrc.

var panel = new Panel;
panel.location = "bottom";
panel.height = 44;
panel.floating = false;
panel.floatingApplets = false;

// Without Vicinae, the normal KDE app launcher takes its place.
var useVicinae = "@USE_VICINAE@" === "1";
var launchers = ["applications:org.kde.dolphin.desktop", "applications:firefox.desktop"];
if (useVicinae) {
    launchers.unshift("applications:viresta-vicinae.desktop");
} else {
    panel.addWidget("org.kde.plasma.kickoff");
}

panel.addWidget("org.kde.plasma.pager");

var taskManager = panel.addWidget("org.kde.plasma.icontasks");
taskManager.currentConfigGroup = ["General"];
taskManager.writeConfig("launchers", launchers);

panel.addWidget("org.kde.plasma.marginsseparator");

var systemTray = panel.addWidget("org.kde.plasma.systemtray");
systemTray.currentConfigGroup = ["General"];
systemTray.writeConfig("hiddenItems", [
    "org.kde.merkuro.contact.applet",
    "org.kde.plasma.browser_integration",
    "org.kde.plasma.brightness"
]);

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("fontWeight", 400);

var colorizer = panel.addWidget("luisbocanegra.panel.colorizer");
colorizer.currentConfigGroup = ["General"];
colorizer.writeConfig("hideWidget", true);
colorizer.writeConfig("lastPreset", "@PANEL_COLORIZER_PRESET_DIR@/");
colorizer.writeConfig("globalSettings", JSON.stringify(@PANEL_COLORIZER_SETTINGS@));

var desktopList = desktopsForActivity(currentActivity());
for (var i = 0; i < desktopList.length; i++) {
    var desktop = desktopList[i];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file://@WALLPAPER@");
}
