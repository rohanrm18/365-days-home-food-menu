from pathlib import Path
import xml.etree.ElementTree as ET

path = Path("android/app/src/main/AndroidManifest.xml")
if not path.exists():
    raise SystemExit("AndroidManifest.xml was not generated")

ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
A = "{http://schemas.android.com/apk/res/android}"
tree = ET.parse(path)
root = tree.getroot()

permissions = {
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.WAKE_LOCK",
}
existing = {node.get(A + "name") for node in root.findall("uses-permission")}
for permission in sorted(permissions - existing):
    ET.SubElement(root, "uses-permission", {A + "name": permission})

app = root.find("application")
if app is None:
    raise SystemExit("Manifest has no application element")

def ensure_receiver(name, actions):
    for receiver in app.findall("receiver"):
        if receiver.get(A + "name") == name:
            return
    receiver = ET.SubElement(app, "receiver", {
        A + "name": name,
        A + "exported": "false",
    })
    filt = ET.SubElement(receiver, "intent-filter")
    for action in actions:
        ET.SubElement(filt, "action", {A + "name": action})

ensure_receiver(
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
    ["com.dexterous.flutterlocalnotifications.SCHEDULED_NOTIFICATION"],
)
ensure_receiver(
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
    ["android.intent.action.BOOT_COMPLETED",
     "android.intent.action.MY_PACKAGE_REPLACED",
     "android.intent.action.QUICKBOOT_POWERON"],
)
tree.write(path, encoding="utf-8", xml_declaration=True)
