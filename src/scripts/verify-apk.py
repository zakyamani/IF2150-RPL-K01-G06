#!/usr/bin/env python3
import hashlib,json,os,pathlib,re,subprocess,xml.etree.ElementTree as ET,zipfile
root=pathlib.Path(__file__).resolve().parent.parent
sdk=pathlib.Path(os.getenv('ANDROID_HOME',str(pathlib.Path.home()/'Android/Sdk')))
apk=root/'artifacts/sisarasa.apk';manifest=root/'artifacts/manifest.json'
m=json.loads(manifest.read_text());assert m['sha256']==hashlib.file_digest(open(apk,'rb'),'sha256').hexdigest()
cert=subprocess.check_output([str(sdk/'build-tools/36.0.0/apksigner'),'verify','--verbose','--print-certs',str(apk)],text=True)
assert 'CN=SisaRasa Demo' in cert and 'CN=Android Debug' not in cert
(root/'artifacts/apk-signature.txt').write_text(cert)
m['signer_sha256']=re.search(r'certificate SHA-256 digest: (\w+)',cert).group(1)
xml=subprocess.check_output([str(sdk/'cmdline-tools/latest/bin/apkanalyzer'),'manifest','print',str(apk)],text=True)
ns='{http://schemas.android.com/apk/res/android}';tree=ET.fromstring(xml);app=tree.find('application');sdkxml=tree.find('uses-sdk')
assert app.get(ns+'debuggable') in (None,'false') and app.get(ns+'allowBackup')=='false' and app.get(ns+'usesCleartextTraffic')=='false'
assert sdkxml.get(ns+'minSdkVersion')=='29' and sdkxml.get(ns+'targetSdkVersion')=='36'
m['permissions']=[p.get(ns+'name') for p in tree.findall('uses-permission')]
with zipfile.ZipFile(apk) as z:
 for name in z.namelist():
  if name.endswith('libapp.so'):
   data=z.read(name)
   for pattern in [b'development-only-access-secret',b'Testing-password-2026',b'Native-Testing-2026',b'api.example.test']:
    assert pattern not in data,'Test/development value in release binary'
m['release_checks']=dict(debuggable=False,allow_backup=False,cleartext=False,project_signing=True)
manifest.write_text(json.dumps(m,indent=2)+'\n');print('APK signature, permissions, SHA-256 and release guards verified')
