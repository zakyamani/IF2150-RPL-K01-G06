#!/usr/bin/env python3
import os,pathlib,secrets,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
vault=ROOT/'.secrets';vault.mkdir(mode=0o700,exist_ok=True);os.chmod(vault,0o700)
key=vault/'release.jks';password=vault/'release-password.txt';properties=ROOT/'android-app/android/key.properties'
if key.exists() and not password.exists(): raise SystemExit('Existing keystore password is missing; restore it, do not replace the keystore')
if not password.exists():
 password.write_text(secrets.token_urlsafe(32)+'\n');os.chmod(password,0o600)
if not key.exists():
 subprocess.run(['keytool','-genkeypair','-noprompt','-keystore',str(key),'-storetype','JKS','-alias','sisarasa','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=SisaRasa Demo, OU=RPL, O=SisaRasa, C=ID','-storepass:file',str(password),'-keypass:file',str(password)],check=True,stdout=subprocess.DEVNULL)
 os.chmod(key,0o600)
pwd=password.read_text().strip()
fd,path=tempfile.mkstemp(dir=properties.parent,prefix='.signing-')
with os.fdopen(fd,'w') as f: f.write(f'storeFile={key}\nstorePassword={pwd}\nkeyAlias=sisarasa\nkeyPassword={pwd}\n')
os.chmod(path,0o600);os.replace(path,properties)
print('Project release signing configured. Back up .secrets/release.jks, release-password.txt and key.properties privately.')
