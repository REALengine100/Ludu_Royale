#!/usr/bin/env python3
"""Run AFTER `flutter create --platforms=android .` - patches the generated Android project:
   * internet permissions (needed by AdMob)
   * AdMob APP ID meta-data                     <<< replace ADMOB_APP_ID with YOUR real app id before publishing
   * minSdk 23 (google_mobile_ads)
   * app label
   * release signing (only when android/app/upload-keystore.jks exists)
"""
import os, re

# Official Google TEST app id. Replace with your real one (ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY).
ADMOB_APP_ID = os.environ.get("ADMOB_APP_ID", "ca-app-pub-3940256099942544~3347511713")  # <<< STEP 3
APP_LABEL = "Ludo Royale"

# ---- manifest
mp = "android/app/src/main/AndroidManifest.xml"
m = open(mp).read()
if "ADMOB_PATCHED" not in m:
    perms = ('<uses-permission android:name="android.permission.INTERNET"/>\n'
             '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    ')
    m = m.replace("<application", perms + "<application", 1)
    meta = ('\n        <!-- ADMOB_PATCHED -->\n'
            '        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>' % ADMOB_APP_ID)
    m = re.sub(r"(<application[^>]*>)", lambda x: x.group(1) + meta, m, count=1)
    m = re.sub(r'android:label="[^"]*"', 'android:label="%s"' % APP_LABEL, m, count=1)
    open(mp, "w").write(m)

# ---- gradle
for fname in ("build.gradle", "build.gradle.kts"):
    p = os.path.join("android/app", fname)
    if not os.path.exists(p):
        continue
    kts = fname.endswith(".kts")
    s = open(p).read()
    s = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23" if kts else "minSdkVersion 23", s)
    if os.path.exists("android/app/upload-keystore.jks") and "signingConfigs {" not in s:
        if kts:
            block = '''    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            props.load(java.io.FileInputStream(rootProject.file("key.properties")))
            storeFile = file(props["storeFile"] as String)
            storePassword = props["storePassword"] as String
            keyAlias = props["keyAlias"] as String
            keyPassword = props["keyPassword"] as String
        }
    }
'''
            s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        else:
            block = '''    signingConfigs {
        release {
            def props = new Properties()
            props.load(new FileInputStream(rootProject.file("key.properties")))
            storeFile file(props['storeFile'])
            storePassword props['storePassword']
            keyAlias props['keyAlias']
            keyPassword props['keyPassword']
        }
    }
'''
            s = s.replace("signingConfigs.debug", "signingConfigs.release")
        s = s.replace("buildTypes {", block + "    buildTypes {", 1)
        with open("android/key.properties", "w") as f:
            f.write("storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=upload-keystore.jks\n" % (
                os.environ["KEYSTORE_PASSWORD"], os.environ["KEY_PASSWORD"], os.environ["KEY_ALIAS"]))
    open(p, "w").write(s)
print("Android project patched.")
