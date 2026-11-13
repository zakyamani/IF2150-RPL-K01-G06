#!/usr/bin/env python3
"""Local operator workflow. Never shells user strings; restores only into disposable DBs."""
import fcntl, hashlib, json, os, pathlib, secrets, shutil, subprocess, sys, tarfile, tempfile, urllib.request
from datetime import datetime, timezone
ROOT=pathlib.Path(__file__).resolve().parent.parent
ENV=pathlib.Path(os.getenv('SISARASA_ENV_FILE',str(ROOT/'.env'))).resolve()
PROJECT=os.getenv('SISARASA_PROJECT','sisarasa-academic')
def run(args, **kw):
    return subprocess.run(args,check=True,**kw)
def dc(*args, **kw):
    return run(['docker','compose','--project-directory',str(ROOT),'--env-file',str(ENV),'-p',PROJECT,'-f',str(ROOT/'compose.yaml'),*args],**kw)
def config():
    return dict(line.split('=',1) for line in ENV.read_text().splitlines() if line and not line.startswith('#'))
def setup():
    ENV.parent.mkdir(parents=True,exist_ok=True)
    c=config() if ENV.exists() else {}
    for k in ('POSTGRES_PASSWORD','ACCESS_SECRET','CALLBACK_SECRET','PICKUP_KEY'):
        c.setdefault(k,secrets.token_hex(32))
    defaults=dict(APP_UID=str(os.getuid() or 1000),APP_GID=str(os.getgid() or 1000),NODE_ENV='production',PORT='3000',DATABASE_URL=f"postgres://sisarasa:{c['POSTGRES_PASSWORD']}@db:5432/sisarasa",MEDIA_DIR='/app/uploads',FEE_BPS='500',TRUST_PROXY='loopback',CORS_ORIGINS='',API_HOST_PORT=os.getenv('API_HOST_PORT','3100'),DB_HOST_PORT=os.getenv('DB_HOST_PORT','55432'))
    for k,v in defaults.items(): c.setdefault(k,v)
    # A refused/truncated write must not destroy the only existing key material.
    fd,tmp=tempfile.mkstemp(dir=ENV.parent,prefix='.env-')
    with os.fdopen(fd,'w') as f: f.write(''.join(f'{k}={v}\n' for k,v in c.items()));f.flush();os.fsync(f.fileno())
    os.chmod(tmp,0o600);os.replace(tmp,ENV)
    media=pathlib.Path(os.getenv('MEDIA_PATH',str(ROOT/'uploads')));media.mkdir(parents=True,exist_ok=True)
    # Match the host operator when non-root, so backups can read private uploads.
    app_uid=int(c['APP_UID']);app_gid=int(c['APP_GID'])
    if app_uid<=0 or app_gid<=0: raise ValueError('App container must use a non-root UID/GID')
    if media.stat().st_uid!=app_uid or media.stat().st_gid!=app_gid:
        run(['docker','run','--rm','-v',str(media)+':/media','postgres:15-alpine','chown',f'{app_uid}:{app_gid}','/media'],stdout=subprocess.DEVNULL)
    os.chmod(media,0o700)
    dc('build',stdout=sys.stderr);dc('up','-d','--wait','db',stdout=sys.stderr)
    if c.get('TRUST_PROXY')=='loopback':
        gateway=run(['docker','network','inspect',PROJECT+'_default','--format','{{(index .IPAM.Config 0).Gateway}}'],capture_output=True,text=True).stdout.strip()
        import ipaddress
        ipaddress.IPv4Address(gateway)
        c['TRUST_PROXY']='loopback,'+gateway+'/32'
        fd,tmp=tempfile.mkstemp(dir=ENV.parent,prefix='.env-')
        with os.fdopen(fd,'w') as f: f.write(''.join(f'{k}={v}\n' for k,v in c.items()));f.flush();os.fsync(f.fileno())
        os.chmod(tmp,0o600);os.replace(tmp,ENV)
    dc('run','--rm','migrate',stdout=sys.stderr)
def digest(path): return hashlib.file_digest(open(path,'rb'),'sha256').hexdigest()
def validate(folder):
    m=json.loads((folder/'manifest.json').read_text())
    if m.get('version')!=1 or set(m.get('sha256',{}))!={'database.dump','media.tar.gz','recovery.env'}: raise ValueError('Invalid backup manifest')
    for name,h in m['sha256'].items():
        if digest(folder/name)!=h: raise ValueError('Backup checksum mismatch: '+name)
    return m
def backup(destination):
    destination=pathlib.Path(destination).resolve();destination.mkdir(parents=True,exist_ok=True);os.chmod(destination,0o700)
    folder=destination/('sisarasa-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'));folder.mkdir(mode=0o700)
    running=set(dc('ps','--status','running','--services',capture_output=True,text=True).stdout.split())&{'api','worker'}
    good=False
    try:
        if running: dc('stop',*sorted(running),stdout=sys.stderr)
        if os.getenv('SISARASA_BACKUP_FAIL')=='dump': raise RuntimeError('Injected dump failure')
        with open(folder/'database.dump','wb') as f: dc('exec','-T','db','pg_dump','-U','sisarasa','-d','sisarasa','-Fc',stdout=f)
        if os.getenv('SISARASA_BACKUP_FAIL')=='archive': raise RuntimeError('Injected archive failure')
        media=pathlib.Path(os.getenv('MEDIA_PATH',str(ROOT/'uploads')))
        with tarfile.open(folder/'media.tar.gz','w:gz') as tar: tar.add(media,arcname='media')
        shutil.copyfile(ENV,folder/'recovery.env')
        for p in folder.iterdir(): os.chmod(p,0o600)
        manifest={'version':1,'created_at':datetime.now(timezone.utc).isoformat(),'project':PROJECT,'previously_running':sorted(running),'sha256':{name:digest(folder/name) for name in ('database.dump','media.tar.gz','recovery.env')}}
        (folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');os.chmod(folder/'manifest.json',0o600);validate(folder);good=True
    finally:
        if running: dc('up','-d','--no-deps','--wait','--wait-timeout','60',*sorted(running),stdout=sys.stderr)
        if not good: shutil.rmtree(folder)
    # Keep the most recent valid backup for each of seven UTC calendar days.
    days=set()
    for old in sorted(destination.glob('sisarasa-*'),reverse=True):
        try: date=validate(old)['created_at'][:10]
        except (OSError,ValueError,KeyError): continue
        if date in days or len(days)>=7: shutil.rmtree(old)
        else: days.add(date)
    print(folder)
def restore(folder,args):
    if args!=['--test']: raise ValueError('Restore requires --test; production data is never overwritten')
    folder=pathlib.Path(folder).resolve();validate(folder)
    name='sisarasa-restore-test-'+secrets.token_hex(6);password=secrets.token_hex(32)
    with tempfile.TemporaryDirectory(prefix='sisarasa-restore-test-') as target:
        # Inspect every member before extracting even a checksum-valid external archive.
        with tarfile.open(folder/'media.tar.gz') as tar:
            for item in tar.getmembers():
                p=pathlib.PurePosixPath(item.name)
                if p.is_absolute() or '..' in p.parts or not p.parts or p.parts[0]!='media' or (not item.isfile() and not item.isdir()): raise ValueError('Unsafe media archive')
            tar.extractall(target,filter='data')
        try:
            run(['docker','run','-d','--name',name,'--tmpfs','/var/lib/postgresql/data','-e','POSTGRES_USER=sisarasa','-e','POSTGRES_DB=sisarasa_restore_test','-e','POSTGRES_PASSWORD='+password,'postgres:15-alpine'],stdout=subprocess.DEVNULL)
            import time
            for i in range(60):
                p=subprocess.run(['docker','exec',name,'pg_isready','-h','127.0.0.1','-U','sisarasa','-d','sisarasa_restore_test'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                if p.returncode==0: break
                time.sleep(.25)
            else: raise RuntimeError('Restore DB unavailable')
            with open(folder/'database.dump','rb') as f: run(['docker','exec','-i',name,'pg_restore','-U','sisarasa','-d','sisarasa_restore_test','--exit-on-error','--no-owner'],stdin=f)
            q=run(['docker','exec',name,'psql','-U','sisarasa','-d','sisarasa_restore_test','-Atc',"SELECT json_build_object('paid_orders',(SELECT count(*) FROM orders WHERE status='paid'),'credentials',(SELECT count(*) FROM pickup_credentials),'media_rows',(SELECT count(*) FROM media_assets))"],capture_output=True,text=True)
            result=json.loads(q.stdout);media=pathlib.Path(target)/'media'
            rows=run(['docker','exec',name,'psql','-U','sisarasa','-d','sisarasa_restore_test','-At','-F','\t','-c','SELECT path,sha256 FROM media_assets'],capture_output=True,text=True).stdout.splitlines()
            for row in rows:
                filename,h=row.split('\t');p=(media/filename).resolve()
                if not p.is_relative_to(media.resolve()) or digest(p)!=h: raise ValueError('Restored media checksum mismatch')
            credentials=run(['docker','exec',name,'psql','-U','sisarasa','-d','sisarasa_restore_test','-At','-c',"SELECT coalesce(json_agg(encrypted_data),'[]'::json) FROM pickup_credentials"],capture_output=True,text=True).stdout
            code="import {decrypt} from './dist/src/core/crypto.js';let raw='';for await (const chunk of process.stdin) raw+=chunk;for(const value of JSON.parse(raw)){const credential=decrypt(value,process.env.PICKUP_KEY);if(!credential.token||!/^\\d{6}$/.test(credential.otp))throw Error('Credential recovery failed')}"
            run(['docker','run','--rm','-i','--network','none','--env-file',str(folder/'recovery.env'),'sisarasa-academic-api:local','node','--input-type=module','-e',code],input=credentials,text=True,stdout=subprocess.DEVNULL)
            result['media_files']=len(rows);result['decryptable_credentials']=result['credentials'];print(json.dumps(result))
        finally: subprocess.run(['docker','rm','-f',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def main():
    command,*args=sys.argv[1:]
    # Mutual exclusion protects backups/start/setup for this operator project.
    lockdir=ROOT/'.superpowers';lockdir.mkdir(exist_ok=True)
    with open(lockdir/('operator-'+PROJECT+'.lock'),'w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if command=='setup': setup()
        elif command=='seed':
            directory=ROOT/'.secrets';directory.mkdir(mode=0o700,exist_ok=True)
            file=directory/'demo-access.txt'
            if file.exists(): password=file.read_text().splitlines()[-1]
            else:
                password=secrets.token_urlsafe(24)
                file.write_text('buyer@demo.sisarasa.invalid\nseller@demo.sisarasa.invalid\n'+password+'\n');os.chmod(file,0o600)
            environment=dict(os.environ,DEMO_SEED_PASSWORD=password)
            dc('run','--rm','-e','DEMO_SEED_PASSWORD','migrate','node','dist/scripts/seed.js',env=environment,stdout=sys.stderr)
            print('Demo accounts stored privately in .secrets/demo-access.txt')
        elif command=='start': dc('up','-d','--wait','api','worker',stdout=sys.stderr)
        elif command=='stop': dc('stop','api','worker',stdout=sys.stderr)
        elif command=='health':
            c=config();port=os.getenv('API_HOST_PORT',c['API_HOST_PORT']);print(urllib.request.urlopen('http://127.0.0.1:'+port+'/health/ready',timeout=5).read().decode());dc('ps')
        elif command=='backup' and len(args)==1: backup(args[0])
        elif command=='restore' and args: restore(args[0],args[1:])
        else: raise ValueError('Unknown command or missing arguments')
if __name__=='__main__':
    try: main()
    except Exception as e: print('Operator failed: '+str(e),file=sys.stderr);sys.exit(1)
