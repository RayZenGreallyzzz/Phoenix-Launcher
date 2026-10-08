@tool
extends EditorPlugin

var android_export_plugin: PPAAndroidExportPlugin

func _enter_tree() -> void:
    android_export_plugin = PPAAndroidExportPlugin.new()
    add_export_plugin(android_export_plugin)

func _exit_tree() -> void:
    if android_export_plugin != null:
        remove_export_plugin(android_export_plugin)
        android_export_plugin = null

class PPAAndroidExportPlugin extends EditorExportPlugin:
    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_name() -> String:
        return "PPAOriginalWebUI"

    func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
        return PackedStringArray([
            "PPAOriginalWebUI/bin/debug/PPAOriginalWebUI-debug.aar"
            if debug else
            "PPAOriginalWebUI/bin/release/PPAOriginalWebUI-release.aar"
        ])
